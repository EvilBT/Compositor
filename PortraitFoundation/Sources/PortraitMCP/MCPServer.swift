import Foundation
import PortraitCore

/// A small JSON-RPC/MCP server that owns no image state outside its in-process session.
/// Transport adapters send one complete UTF-8 message to `handle`; stdio is the first adapter.
public actor MCPServer {
    private let session: PortraitSession
    private var initialized = false
    private var ready = false
    private let encoder = JSONEncoder()

    /// Bind exactly one already-open local photo. Tools cannot open arbitrary filesystem paths.
    public init(session: PortraitSession) { self.session = session }

    /// Handle a JSON-RPC request or notification. Notifications never produce responses.
    public func handle(_ data: Data) async -> Data? {
        let value: JSONValue
        do { value = try JSONDecoder().decode(JSONValue.self, from: data) }
        catch { return response(id: .null, error: (-32700, "Parse error")) }
        guard let request = value.objectValue, request["jsonrpc"] == .string("2.0"),
              let method = request["method"]?.stringValue else {
            return response(id: .null, error: (-32600, "Invalid request"))
        }
        let id = request["id"]
        if let id {
            switch id { case .int, .string: break
            default: return response(id: .null, error: (-32600, "Invalid request ID")) }
        }
        if id == nil {
            if method == "notifications/initialized" && initialized { ready = true }
            return nil
        }
        let idValue = id ?? .null
        switch method {
        case "initialize":
            guard !initialized, let params = request["params"]?.objectValue,
                  let version = params["protocolVersion"]?.stringValue,
                  params["capabilities"]?.objectValue != nil,
                  params["clientInfo"]?.objectValue?["name"]?.stringValue != nil,
                  params["clientInfo"]?.objectValue?["version"]?.stringValue != nil else {
                return response(id: idValue, error: (-32602, "Invalid initialization"))
            }
            initialized = true
            let supported = ["2024-11-05", "2025-03-26", "2025-06-18"]
            let snapshot = await session.snapshot()
            return response(id: idValue, result: .object([
                "protocolVersion": .string(supported.contains(version) ? version : "2025-06-18"),
                "capabilities": .object(["tools": .object([:])]),
                "serverInfo": .object(["name": .string("portrait-mcp"), "version": .string("0.1.0")]),
                "instructions": .string("Open photo_id: \(session.photoID). Source dimensions: \(snapshot.document.photo.pixelSize.x)×\(snapshot.document.photo.pixelSize.y). Coordinate contract: image and face AnchoredPoint values are normalized 0...1, never pixel coordinates. image references the full image; face references the selected detected face bounding box. Origin is top-left, x right, y down. landmark values are signed finite offsets from a named landmark, measured in face-width fractions on both axes; negative values are valid and no 0...1 bound applies. Source dimensions are pixels; skin.radius is full-resolution pixels; blemish spot radius is a face-width fraction. Anchored-point operations are not yet exposed by this preview host. Analyze first, render a candidate, obtain human confirmation, then set_stack with that preview_id and expected_revision. Only skin, tone, presence, whiteBalance and point toneCurve are implemented. This host is a preview prototype.")
            ]))
        case "ping": return response(id: idValue, result: .object([:]))
        default: break
        }
        guard ready else { return response(id: idValue, error: (-32002, "Initialize the session first")) }
        switch method {
        case "tools/list": return response(id: idValue, result: .object(["tools": Self.tools]))
        case "tools/call":
            guard let params = request["params"]?.objectValue,
                  let name = params["name"]?.stringValue,
                  let arguments = params["arguments"]?.objectValue else {
                return response(id: idValue, error: (-32602, "Invalid tool call"))
            }
            guard ["analyze_faces", "render_preview_with", "set_stack"].contains(name) else {
                return response(id: idValue, error: (-32602, "Unknown tool"))
            }
            do { return response(id: idValue, result: try await call(name, arguments: arguments)) }
            catch { return response(id: idValue, result: .object([
                "isError": .bool(true), "content": .array([Self.text("\(error)")])
            ])) }
        default: return response(id: idValue, error: (-32601, "Method not found"))
        }
    }

    private func call(_ name: String, arguments: [String: JSONValue]) async throws -> JSONValue {
        guard arguments["photo_id"]?.stringValue == session.photoID else { throw PortraitSessionError.unknownPhoto }
        switch name {
        case "analyze_faces":
            let analysis = try await session.analyzeFaces(), snapshot = await session.snapshot()
            let info = JSONValue.object([
                "photo_id": .string(session.photoID), "revision": .int(snapshot.revision),
                "faces": try json(analysis.faces), "warnings": try json(analysis.warnings),
                "maskMethod": .string("landmark/chroma heuristic"), "blemishDetectionAvailable": .bool(false),
                "stack": try json(snapshot.document.ops), "process_version": .int(snapshot.document.processVersion)
            ])
            return .object(["content": .array([try textJSON(info),
                .object(["type": .string("image"), "mimeType": .string("image/png"),
                         "data": .string(try PhotoIO.encode(analysis.skinMask).base64EncodedString())])])])
        case "render_preview_with":
            let stack = try StackCodec.decode(arguments["stack"] ?? .null)
            let size: Int
            if let value = arguments["max_size"] {
                guard case .int(let requested) = value, (64...2048).contains(requested) else {
                    throw ToolArgumentError("max_size must be an integer in 64...2048.")
                }
                size = requested
            } else { size = 1024 }
            let version = try arguments["process_version"].map { try integer($0, default: 2) }
            let ticket = try await session.preview(stack: stack, maximumDimension: size, processVersion: version)
            let info = JSONValue.object([
                "photo_id": .string(session.photoID), "preview_id": .string(ticket.id.uuidString),
                "revision": .int(ticket.revision), "width": .int(ticket.image.width), "height": .int(ticket.image.height),
                "stack": try json(ticket.stack), "process_version": .int(ticket.processVersion), "applied": .bool(false)
            ])
            return .object(["content": .array([
                .object(["type": .string("image"), "mimeType": .string("image/jpeg"),
                         "data": .string(try PhotoIO.encode(ticket.image, jpeg: true).base64EncodedString())]),
                try textJSON(info)])])
        case "set_stack":
            guard arguments["confirmed"] == .bool(true) else {
                throw ToolArgumentError("confirmed must be true after human approval.")
            }
            let preview = try uuid(arguments["preview_id"], field: "preview_id")
            let sessionID = try uuid(arguments["session_id"], field: "session_id")
            let stack = try StackCodec.decode(arguments["stack"] ?? .null)
            let revision = try await session.setStack(stack, previewID: preview,
                expectedRevision: integer(arguments["expected_revision"], default: -1), sessionID: sessionID)
            return .object(["content": .array([try textJSON(.object([
                "photo_id": .string(session.photoID), "revision": .int(revision), "applied": .bool(true),
                "session_id": .string(sessionID.uuidString)
            ]))])])
        default: throw PortraitSessionError.unsupportedOperation
        }
    }

    private func uuid(_ value: JSONValue?, field: String) throws -> UUID {
        guard let text = value?.stringValue, let id = UUID(uuidString: text) else {
            throw ToolArgumentError("\(field) must be a UUID string.")
        }
        return id
    }

    private func integer(_ value: JSONValue?, default fallback: Int) throws -> Int {
        guard let value else { return fallback }
        guard case .int(let integer) = value else { throw PhotoIOError.invalidSize }
        return integer
    }

    private func json<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: encoder.encode(value))
    }
    private func textJSON(_ value: JSONValue) throws -> JSONValue {
        Self.text(String(decoding: try encoder.encode(value), as: UTF8.self))
    }
    private static func text(_ value: String) -> JSONValue { .object(["type": .string("text"), "text": .string(value)]) }
    private func response(id: JSONValue, result: JSONValue? = nil, error: (Int, String)? = nil) -> Data? {
        var response: [String: JSONValue] = ["jsonrpc": .string("2.0"), "id": id]
        if let error { response["error"] = .object(["code": .int(error.0), "message": .string(error.1)]) }
        else { response["result"] = result ?? .object([:]) }
        return try? encoder.encode(JSONValue.object(response))
    }

    private static let tools: JSONValue = {
        func tool(_ name: String, _ description: String, _ properties: [String: JSONValue], _ required: [String]) -> JSONValue {
            .object(["name": .string(name), "description": .string(description),
                "inputSchema": .object(["type": .string("object"), "properties": .object(properties),
                                        "required": .array(required.map(JSONValue.string)), "additionalProperties": .bool(false)])])
        }
        let string = JSONValue.object(["type": .string("string")])
        let uuid = JSONValue.object(["type": .string("string"), "format": .string("uuid")])
        let integer = JSONValue.object(["type": .string("integer")])
        func number(_ low: Double, _ high: Double) -> JSONValue {
            .object(["type": .string("number"), "minimum": .double(low), "maximum": .double(high)])
        }
        func parameters(_ properties: [String: JSONValue]) -> JSONValue {
            .object(["type": .string("object"), "properties": .object(properties), "additionalProperties": .bool(false)])
        }
        let adjustment = number(-100, 100)
        let point = JSONValue.object(["type": .string("object"), "properties": .object(["x": number(0, 1), "y": number(0, 1)]),
                                      "required": .array([.string("x"), .string("y")]), "additionalProperties": .bool(false)])
        let points = JSONValue.object(["type": .string("array"), "items": point, "minItems": .int(2), "maxItems": .int(32)])
        let curveChannels = parameters(Dictionary(uniqueKeysWithValues: ["rgb", "red", "green", "blue"].map { ($0, points) }))
        let kinds: [String: JSONValue] = [
            "skin": parameters(["strength": number(0, 1), "texturePreservation": number(0, 1), "radius": number(2, 80),
                                "maskExpansion": number(-1, 1), "blemishStrength": .object(["type": .string("number"), "const": .int(0)]),
                                "protectNonSkin": .object(["type": .string("boolean")])]),
            "tone": parameters(["exposure": number(-5, 5), "contrast": adjustment, "highlights": adjustment,
                                "shadows": adjustment, "whites": adjustment, "blacks": adjustment]),
            "presence": parameters(["texture": adjustment, "clarity": adjustment, "dehaze": adjustment,
                                    "vibrance": adjustment, "saturation": adjustment]),
            "whiteBalance": parameters(["temperature": adjustment, "tint": adjustment,
                "sampledNeutral": .object(["type": .string("array"), "items": number(0.000001, 1), "minItems": .int(3), "maxItems": .int(3)])]),
            "toneCurve": parameters(["channels": .object(["oneOf": .array([curveChannels, .object(["type": .string("array")])])]),
                                      "refineSaturation": .object(["type": .string("number"), "const": .int(0)])])
        ]
        let kindSchema = JSONValue.object(["oneOf": .array(kinds.keys.sorted().map { name in
            .object(["type": .string("object"), "properties": .object([name: kinds[name]!]),
                     "required": .array([.string(name)]), "additionalProperties": .bool(false)])
        })])
        let stack = JSONValue.object(["type": .string("array"), "maxItems": .int(100),
            "items": .object(["type": .string("object"), "required": .array([.string("kind")]),
                "properties": .object([
                    "id": .object(["type": .string("string"), "format": .string("uuid")]),
                    "isEnabled": .object(["type": .string("boolean")]),
                    "label": string,
                    "origin": .object(["type": .string("object")]),
                    "kind": kindSchema
                ])])])
        return .array([
            tool("analyze_faces", "Detect landmarks and return conservative skin coverage; no document edit.", ["photo_id": string], ["photo_id"]),
            tool("render_preview_with", "Render proposed stack and return an image plus a candidate ticket. Does not apply it.",
                 ["photo_id": string, "stack": stack, "max_size": .object(["type": .string("integer"), "minimum": .int(64), "maximum": .int(2048)]),
                  "process_version": .object(["type": .string("integer"), "enum": .array([.int(1), .int(2)])])], ["photo_id", "stack"]),
            tool("set_stack", "Apply exactly a previewed candidate after human confirmation. Keep the canonical IDs returned in the preview.",
                 ["photo_id": string, "stack": stack, "preview_id": uuid, "session_id": uuid,
                  "expected_revision": integer, "confirmed": .object(["type": .string("boolean"), "const": .bool(true)])],
                 ["photo_id", "stack", "preview_id", "session_id", "expected_revision", "confirmed"])
        ])
    }()
}

/// A tool boundary accepts partial known parameters; saved documents keep their native schema.
public enum StackCodec {
    /// Fill extractable defaults and stable operation envelopes before native decoding.
    public static func decode(_ value: JSONValue) throws -> [RetouchOp] {
        guard let values = value.arrayValue, values.count <= 100 else { throw PortraitSessionError.unsupportedOperation }
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        func defaults<T: Encodable>(_ params: T) throws -> [String: JSONValue] {
            try decoder.decode(JSONValue.self, from: encoder.encode(params)).objectValue ?? [:]
        }
        return try values.map { value in
            guard var envelope = value.objectValue, let kind = envelope["kind"]?.objectValue,
                  kind.count == 1, let (name, params) = kind.first, let partial = params.objectValue else {
                throw PortraitSessionError.unsupportedOperation
            }
            var full: [String: JSONValue]
            switch name {
            case "skin": full = try defaults(SkinParams())
            case "tone": full = try defaults(ToneParams())
            case "presence": full = try defaults(PresenceParams())
            case "whiteBalance": full = try defaults(WhiteBalanceParams())
            case "toneCurve": full = try defaults(CurveParams())
            default: throw PortraitSessionError.unsupportedOperation
            }
            let allowed = Set(full.keys).union(name == "whiteBalance" ? ["sampledNeutral"] : name == "toneCurve" ? ["parametric"] : [])
            guard partial.keys.allSatisfy({ allowed.contains($0) }) else { throw PortraitSessionError.unsupportedOperation }
            full.merge(partial) { _, new in new }
            if name == "toneCurve", let channels = full["channels"]?.objectValue {
                guard channels.keys.allSatisfy({ ["rgb", "red", "green", "blue"].contains($0) }) else { throw PortraitSessionError.unsupportedOperation }
                full["channels"] = .array(channels.keys.sorted().flatMap { [.string($0), channels[$0]!] })
            }
            envelope["kind"] = .object([name: .object(full)])
            if envelope["id"] == nil { envelope["id"] = .string(UUID().uuidString) }
            if envelope["isEnabled"] == nil { envelope["isEnabled"] = .bool(true) }
            if envelope["origin"] == nil { envelope["origin"] = .object(["user": .object([:])]) }
            return try decoder.decode(RetouchOp.self, from: encoder.encode(JSONValue.object(envelope)))
        }
    }
}

private struct ToolArgumentError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
