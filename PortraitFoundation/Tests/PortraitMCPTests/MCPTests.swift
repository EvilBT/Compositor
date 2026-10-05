import Foundation
import Testing
import PortraitCore
import PortraitMCP

@Suite("MCP lifecycle and non-destructive transactions")
struct MCPTests {
    private func photo() throws -> LoadedPhoto {
        var bytes = [UInt8](repeating: 128, count: 100 * 80 * 4)
        for i in stride(from: 3, to: bytes.count, by: 4) { bytes[i] = 255 }
        return LoadedPhoto(image: try PhotoIO.image(bytes, width: 100, height: 80),
            reference: PhotoReference(source: .file(relativePath: "fixture.png"), pixelSize: SIMD2(100, 80)), id: "fixture")
    }

    private func rpc(_ server: MCPServer, _ method: String, _ params: JSONValue = .object([:]), id: Int? = 1) async throws -> JSONValue? {
        var value: [String: JSONValue] = ["jsonrpc": .string("2.0"), "method": .string(method), "params": params]
        if let id { value["id"] = .int(id) }
        guard let response = await server.handle(try JSONEncoder().encode(JSONValue.object(value))) else { return nil }
        return try JSONDecoder().decode(JSONValue.self, from: response)
    }

    @Test("Initialization exposes exactly three tools and notifications remain silent")
    func lifecycle() async throws {
        let server = MCPServer(session: PortraitSession(photo: try photo()))
        let early = try await rpc(server, "tools/list")
        #expect(early?.objectValue?["error"] != nil)
        let initialized = try await rpc(server, "initialize", .object([
            "protocolVersion": .string("2025-06-18"), "capabilities": .object([:]),
            "clientInfo": .object(["name": .string("test"), "version": .string("1")])]))
        #expect(initialized?.objectValue?["result"]?.objectValue?["protocolVersion"] == .string("2025-06-18"))
        #expect(try await rpc(server, "notifications/initialized", id: nil) == nil)
        let tools = try await rpc(server, "tools/list")
        #expect(tools?.objectValue?["result"]?.objectValue?["tools"]?.arrayValue?.count == 3)
        let malformed = await server.handle(Data("{".utf8))
        let error = try JSONDecoder().decode(JSONValue.self, from: #require(malformed))
        #expect(error.objectValue?["error"]?.objectValue?["code"] == .int(-32700))
    }

    @Test("Preview does not commit; apply stamps provenance; undo restores prior pixels")
    func transactions() async throws {
        let photo = try photo(), session = PortraitSession(photo: photo)
        var tone = ToneParams(); tone.exposure = 0.4
        let candidate = [RetouchOp(kind: .tone(tone))]
        let original = try await session.renderCurrent(maximumDimension: 100)
        let ticket = try await session.preview(stack: candidate, maximumDimension: 100)
        #expect(await session.snapshot().revision == 0)
        #expect(await session.snapshot().document.ops.isEmpty)
        #expect(try PhotoIO.bytes(ticket.image) != PhotoIO.bytes(original))
        let sessionID = UUID()
        #expect(try await session.setStack(candidate, previewID: ticket.id, expectedRevision: 0, sessionID: sessionID) == 1)
        #expect(await session.snapshot().document.ops[0].origin.sessionID == sessionID)
        #expect(try PhotoIO.bytes(await session.renderCurrent(maximumDimension: 100)) == PhotoIO.bytes(ticket.image))
        #expect(try await session.undo() == 2)
        #expect(await session.snapshot().document.ops.isEmpty)
        #expect(try PhotoIO.bytes(await session.renderCurrent(maximumDimension: 100)) == PhotoIO.bytes(original))
        await #expect(throws: PortraitSessionError.staleRevision) {
            try await session.setStack(candidate, previewID: ticket.id, expectedRevision: 0, sessionID: sessionID)
        }
    }

    @Test("Partial tool parameters become complete native parameters")
    func partialParameters() throws {
        let stack = try StackCodec.decode(.array([.object(["kind": .object(["skin": .object(["strength": .double(0.3)])])])]))
        guard case .skin(let skin) = stack[0].kind else { Issue.record("Missing skin"); return }
        #expect(skin.strength == 0.3)
        #expect(skin.protectNonSkin)
        #expect(skin.texturePreservation == 0.6)
        #expect(throws: PortraitSessionError.self) {
            try StackCodec.decode(.array([.object(["kind": .object(["skin": .object(["strengt": .double(0.3)])])])]))
        }
    }

    @Test("Protocol preview returns an image and only a matching confirmed ticket can commit")
    func toolTransactions() async throws {
        let session = PortraitSession(photo: try photo()), server = MCPServer(session: session)
        _ = try await rpc(server, "initialize", .object([
            "protocolVersion": .string("2025-06-18"), "capabilities": .object([:]),
            "clientInfo": .object(["name": .string("test"), "version": .string("1")])]))
        _ = try await rpc(server, "notifications/initialized", id: nil)
        func call(_ name: String, _ arguments: [String: JSONValue]) async throws -> JSONValue {
            try #require(await rpc(server, "tools/call", .object(["name": .string(name), "arguments": .object(arguments)]))?.objectValue?["result"])
        }
        let analysis = try await call("analyze_faces", ["photo_id": .string("fixture")])
        #expect(analysis.objectValue?["content"]?.arrayValue?.contains(where: { $0.objectValue?["type"] == .string("image") }) == true)
        let proposed = JSONValue.array([.object(["kind": .object(["tone": .object(["exposure": .double(0.3)])])])])
        let preview = try await call("render_preview_with", ["photo_id": .string("fixture"), "stack": proposed, "max_size": .int(100)])
        let content = try #require(preview.objectValue?["content"]?.arrayValue)
        #expect(content.first?.objectValue?["mimeType"] == .string("image/jpeg"))
        let imageData = try #require(content.first?.objectValue?["data"]?.stringValue.flatMap { Data(base64Encoded: $0) })
        #expect(imageData.count > 100)
        let metadataText = try #require(content.last?.objectValue?["text"]?.stringValue)
        let metadata = try #require(JSONDecoder().decode(JSONValue.self, from: Data(metadataText.utf8)).objectValue)
        var arguments: [String: JSONValue] = ["photo_id": .string("fixture"), "stack": metadata["stack"]!,
            "preview_id": metadata["preview_id"]!, "expected_revision": metadata["revision"]!,
            "session_id": .string(UUID().uuidString), "confirmed": .bool(false)]
        let rejected = try await call("set_stack", arguments)
        #expect(rejected.objectValue?["isError"] == .bool(true))
        #expect(await session.snapshot().revision == 0)
        arguments["confirmed"] = .bool(true)
        let applied = try await call("set_stack", arguments)
        #expect(applied.objectValue?["isError"] != .bool(true))
        #expect(await session.snapshot().revision == 1)
        let repeated = try await call("set_stack", arguments)
        #expect(repeated.objectValue?["isError"] == .bool(true))
        _ = try await session.undo()
        #expect(await session.snapshot().document.ops.isEmpty)
    }

    @Test("Invalid tool arguments explain the field without saving or consuming a preview")
    func invalidArguments() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("edit.json")
        let session = try PortraitSession.open(photo: photo(), documentURL: url)
        let server = MCPServer(session: session)
        _ = try await rpc(server, "initialize", .object([
            "protocolVersion": .string("2025-06-18"), "capabilities": .object([:]),
            "clientInfo": .object(["name": .string("test"), "version": .string("1")])]))
        _ = try await rpc(server, "notifications/initialized", id: nil)
        let listed = try #require(await rpc(server, "tools/list")?.objectValue?["result"]?.objectValue?["tools"]?.arrayValue)
        let applySchema = try #require(listed.first(where: { $0.objectValue?["name"] == .string("set_stack") })?.objectValue?["inputSchema"]?.objectValue?["properties"]?.objectValue)
        for field in ["session_id", "preview_id"] {
            #expect(applySchema[field]?.objectValue?["format"] == .string("uuid"))
        }
        func rejection(_ tool: String, _ arguments: [String: JSONValue], containing message: String) async throws {
            let result = try #require(await rpc(server, "tools/call", .object([
                "name": .string(tool), "arguments": .object(arguments)]))?.objectValue?["result"]?.objectValue)
            #expect(result["isError"] == .bool(true))
            #expect(result["content"]?.arrayValue?.first?.objectValue?["text"]?.stringValue?.contains(message) == true)
            #expect(await session.snapshot().revision == 0)
            #expect(await session.snapshot().document.ops.isEmpty)
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
        for size: JSONValue in [.int(63), .int(2049), .double(100.5), .string("100")] {
            try await rejection("render_preview_with", ["photo_id": .string("fixture"), "stack": .array([]), "max_size": size], containing: "max_size must be an integer in 64...2048")
        }
        let ticket = try await session.preview(stack: [], maximumDimension: 100)
        var arguments: [String: JSONValue] = ["photo_id": .string("fixture"), "stack": .array([]),
            "preview_id": .string(ticket.id.uuidString), "session_id": .string(UUID().uuidString),
            "expected_revision": .int(0), "confirmed": .bool(true)]
        for field in ["session_id", "preview_id"] {
            let valid = arguments[field]
            for invalid: JSONValue? in [nil, .string("s1"), .int(1)] {
                arguments[field] = invalid
                try await rejection("set_stack", arguments, containing: "\(field) must be a UUID string")
            }
            arguments[field] = valid
        }
        arguments["confirmed"] = .bool(false)
        try await rejection("set_stack", arguments, containing: "confirmed must be true")
        arguments["confirmed"] = .bool(true)
        let applied = try await rpc(server, "tools/call", .object(["name": .string("set_stack"), "arguments": .object(arguments)]))
        #expect(applied?.objectValue?["result"]?.objectValue?["isError"] != .bool(true))
        #expect(await session.snapshot().revision == 1)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Native approval uses user provenance and undo invalidates an older candidate")
    func nativeApproval() async throws {
        let session = PortraitSession(photo: try photo())
        var tone = ToneParams(); tone.exposure = 0.3
        let ticket = try await session.preview(stack: [RetouchOp(kind: .tone(tone))], maximumDimension: 100)
        #expect(try await session.approvePreview(ticket) == 1)
        #expect(await session.snapshot().document.ops.first?.origin == .user)
        #expect(try await session.undo() == 2)
        #expect(await session.snapshot().document.ops.isEmpty)
        await #expect(throws: PortraitSessionError.staleRevision) {
            try await session.approvePreview(ticket)
        }
    }

    @Test("Saving an in-memory session reopens approved pixels and rejects existing destinations")
    func saveSession() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = try photo(), session = PortraitSession(photo: photo)
        var tone = ToneParams(); tone.exposure = 0.3
        let ticket = try await session.preview(stack: [RetouchOp(kind: .tone(tone))], maximumDimension: 100)
        _ = try await session.approvePreview(ticket)
        let existing = directory.appendingPathComponent("existing.json")
        let external = Data("external".utf8)
        try external.write(to: existing)
        await #expect(throws: PortraitSessionError.externalChange) { try await session.save(to: existing) }
        #expect(try Data(contentsOf: existing) == external)
        #expect(await session.snapshot().revision == 1)
        let url = directory.appendingPathComponent("edit.json")
        try await session.save(to: url)
        let reopened = try PortraitSession.open(photo: photo, documentURL: url)
        #expect(await reopened.snapshot().document.ops.first?.origin == .user)
        #expect(try PhotoIO.bytes(await reopened.renderCurrent(maximumDimension: 100)) == PhotoIO.bytes(ticket.image))
        _ = try await session.undo()
        let restored = try PortraitSession.open(photo: photo, documentURL: url)
        #expect(await restored.snapshot().document.ops.isEmpty)
    }

    @Test("Sidecars persist successful edits and undo; failed writes leave state unchanged")
    func persistence() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = try photo(), url = directory.appendingPathComponent("edit.json")
        let session = try PortraitSession.open(photo: photo, documentURL: url)
        var p = ToneParams(); p.exposure = 0.2
        let stack = [RetouchOp(kind: .tone(p))], ticket = try await session.preview(stack: [RetouchOp(kind: .tone(p))], maximumDimension: 100)
        // Use the ticket's canonical IDs, rather than a newly constructed equivalent stack.
        #expect(ticket.stack != stack)
        _ = try await session.setStack(ticket.stack, previewID: ticket.id, expectedRevision: 0, sessionID: UUID())
        let reopened = try PortraitSession.open(photo: photo, documentURL: url)
        #expect(await reopened.snapshot().document.ops.count == 1)
        #expect(try PhotoIO.bytes(await reopened.renderCurrent(maximumDimension: 100)) == PhotoIO.bytes(ticket.image))
        _ = try await session.undo()
        let restored = try PortraitSession.open(photo: photo, documentURL: url)
        #expect(await restored.snapshot().document.ops.isEmpty)
        let impossible = try PortraitSession.open(photo: photo, documentURL: directory.appendingPathComponent("missing/edit.json"))
        let pending = try await impossible.preview(stack: ticket.stack, maximumDimension: 100)
        await #expect(throws: (any Error).self) {
            try await impossible.setStack(pending.stack, previewID: pending.id, expectedRevision: 0, sessionID: UUID())
        }
        #expect(await impossible.snapshot().revision == 0)
        #expect(await impossible.snapshot().document.ops.isEmpty)
    }

    @Test("Curve tool parameters accept named channels and retain the saved representation")
    func namedCurveChannels() throws {
        let points = JSONValue.array([.object(["x": .int(0), "y": .int(0)]), .object(["x": .int(1), "y": .int(1)])])
        let value = JSONValue.array([.object(["kind": .object(["toneCurve": .object(["channels": .object(["rgb": points])])])])])
        let stack = try StackCodec.decode(value)
        guard case .toneCurve(let curve) = stack[0].kind else { Issue.record("Missing curve"); return }
        #expect(curve.channels[.rgb]?.count == 2)
        let encoded = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(stack))
        #expect(try StackCodec.decode(encoded) == stack)
    }

    @Test("An external sidecar change is rejected without clobbering disk or actor state")
    func externalChange() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("edit.json")
        let session = try PortraitSession.open(photo: photo(), documentURL: url)
        var tone = ToneParams(); tone.exposure = 0.2
        let ticket = try await session.preview(stack: [.init(kind: .tone(tone))], maximumDimension: 100)
        let external = Data("external edit".utf8)
        try external.write(to: url)
        await #expect(throws: PortraitSessionError.externalChange) {
            try await session.setStack(ticket.stack, previewID: ticket.id, expectedRevision: 0, sessionID: UUID())
        }
        #expect(try Data(contentsOf: url) == external)
        #expect(await session.snapshot().revision == 0)
        #expect(await session.snapshot().document.ops.isEmpty)
    }
}
