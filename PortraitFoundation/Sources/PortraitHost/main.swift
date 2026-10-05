import CoreGraphics
import Foundation
import PortraitCore
import PortraitMCP
import PortraitAnalysis
import RetouchKit

@main
struct PortraitHost {
    static func main() async {
        do {
            let args = CommandLine.arguments
            guard let photoIndex = args.firstIndex(of: "--photo"), args.indices.contains(photoIndex + 1) else {
                throw HostError.usage
            }
            let photo = try PhotoIO.load(URL(fileURLWithPath: args[photoIndex + 1]))
            let session: PortraitSession
            if let index = args.firstIndex(of: "--document"), args.indices.contains(index + 1) {
                session = try PortraitSession.open(photo: photo, documentURL: URL(fileURLWithPath: args[index + 1]))
            } else { session = PortraitSession(photo: photo) }
            let server = MCPServer(session: session)
            if let index = args.firstIndex(of: "--review"), args.indices.contains(index + 1) {
                try await review(photo, source: URL(fileURLWithPath: args[photoIndex + 1]), session: session,
                                 server: server, directory: URL(fileURLWithPath: args[index + 1]))
            } else {
                while let line = readLine(strippingNewline: true) {
                    if let response = await server.handle(Data(line.utf8)) {
                        FileHandle.standardOutput.write(response + Data([10]))
                    }
                }
            }
        } catch {
            FileHandle.standardError.write(Data("portrait-mcp: \(error)\nUsage: portrait-mcp --photo /path/photo.jpg [--document /path/edit.json] [--review /path/output]\n".utf8))
            exit(1)
        }
    }

    enum HostError: Error { case usage, protocolFailure }

    static func send(_ server: MCPServer, method: String, params: JSONValue, id: Int? = 1) async throws -> JSONValue {
        var message: [String: JSONValue] = ["jsonrpc": .string("2.0"), "method": .string(method), "params": params]
        if let id { message["id"] = .int(id) }
        let encoded = try JSONEncoder().encode(JSONValue.object(message))
        guard let response = await server.handle(encoded) else {
            if id == nil { return .null }
            throw HostError.protocolFailure
        }
        let json = try JSONDecoder().decode(JSONValue.self, from: response)
        guard json.objectValue?["error"] == nil, let result = json.objectValue?["result"],
              result.objectValue?["isError"] != .bool(true) else {
            throw NSError(domain: "PortraitHost", code: 1, userInfo: [NSLocalizedDescriptionKey: String(decoding: response, as: UTF8.self)])
        }
        return result
    }

    /// The three candidates `--review` renders, as (name, strength, texturePreservation).
    ///
    /// Defined once: this list used to be written out twice, in the MCP-driven pass and in the
    /// direct-render pass, which is a standing invitation for the two to drift apart.
    ///
    /// The centre of the range is the level the user chose on a real photograph. They picked
    /// strength 0.65 / texture 0.30 out of a sweep on `20261005.jpg` and said explicitly that
    /// men should be smoothed less than this — 0.10 and 0.00 read as overdone. The previous
    /// set (0.30/0.85, 0.50/0.70, 0.65/0.55) sampled only the gentlest end, which made the
    /// comparison uninformative: all three looked nearly the same in the contact sheet.
    ///
    /// The spread is deliberately wide enough to include a clearly-too-gentle and a
    /// clearly-too-strong option, so that a person looking at the sheet has something to
    /// reject at each end. One photograph sets a default, not a rule; see
    /// `SKILL-portrait-retouch.md`, which still needs samples across skin tones, lighting and
    /// gender before its table can be called calibrated.
    static let reviewCandidates: [(String, Double, Double)] = [
        ("conservative", 0.35, 0.60),
        ("standard", 0.65, 0.30),
        ("strong", 0.75, 0.12),
    ]

    static func review(_ photo: LoadedPhoto, source: URL, session: PortraitSession, server: MCPServer, directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = try await send(server, method: "initialize", params: .object([
            "protocolVersion": .string("2025-06-18"), "capabilities": .object([:]),
            "clientInfo": .object(["name": .string("portrait-review"), "version": .string("0.1")])]))
        _ = try await send(server, method: "notifications/initialized", params: .object([:]), id: nil)
        _ = try await send(server, method: "tools/list", params: .object([:]))
        let analyzed = try await send(server, method: "tools/call", params: .object([
            "name": .string("analyze_faces"), "arguments": .object(["photo_id": .string(photo.id)])]))
        for item in analyzed.objectValue?["content"]?.arrayValue ?? [] {
            let item = item.objectValue ?? [:]
            if let text = item["text"]?.stringValue { try Data(text.utf8).write(to: directory.appendingPathComponent("analysis.json"), options: .atomic) }
        }
        let analysis = try await session.analyzeFaces()
        try PhotoIO.encode(photo.image).write(to: directory.appendingPathComponent("original.png"), options: .atomic)
        try PhotoIO.encode(analysis.skinMask).write(to: directory.appendingPathComponent("skin-mask.png"), options: .atomic)
        let original = try PhotoIO.bytes(photo.image), coverage = try PhotoIO.bytes(analysis.skinMask)
        var overlay = original
        for i in stride(from: 0, to: overlay.count, by: 4) {
            let amount = Double(coverage[i]) / 255 * 0.55
            overlay[i] = UInt8((Double(original[i]) * (1 - amount)).rounded())
            overlay[i + 1] = UInt8((Double(original[i + 1]) * (1 - amount) + 255 * amount).rounded())
            overlay[i + 2] = UInt8((Double(original[i + 2]) * (1 - amount)).rounded())
        }
        try PhotoIO.encode(PhotoIO.image(overlay, width: photo.image.width, height: photo.image.height))
            .write(to: directory.appendingPathComponent("mask-overlay.png"), options: .atomic)
        for (name, strength, texture) in reviewCandidates {
            let stack = JSONValue.array([.object(["kind": .object(["skin": .object([
                "strength": .double(strength), "texturePreservation": .double(texture), "radius": .int(12)
            ])])])])
            let result = try await send(server, method: "tools/call", params: .object([
                "name": .string("render_preview_with"), "arguments": .object([
                    "photo_id": .string(photo.id), "stack": stack, "max_size": .int(2048)
                ])]))
            for item in result.objectValue?["content"]?.arrayValue ?? [] {
                let item = item.objectValue ?? [:]
                if let data = item["data"]?.stringValue.flatMap({ Data(base64Encoded: $0) }) {
                    try data.write(to: directory.appendingPathComponent("\(name).jpg"), options: .atomic)
                }
                if let text = item["text"]?.stringValue { try Data(text.utf8).write(to: directory.appendingPathComponent("\(name).json"), options: .atomic) }
            }
            let snapshot = await session.snapshot()
            guard snapshot.revision == 0, snapshot.document.ops.isEmpty else { throw HostError.protocolFailure }
        }
        if let face = analysis.faces.first {
            let crop = try PhotoIO.closeup(source, rect: face.boundingBox)
            func rebase(_ point: SIMD2<Double>) -> SIMD2<Double> {
                let value = (point - face.boundingBox.origin) / face.boundingBox.size
                return SIMD2(min(1, max(0, value.x)), min(1, max(0, value.y)))
            }
            var croppedFace = face
            croppedFace.boundingBox = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
            croppedFace.landmarks = LandmarkMap(face.landmarks.points.mapValues(rebase))
            let originalGeometry = analysis.geometry.first!
            let croppedGeometry = FaceGeometry(face: croppedFace, outline: originalGeometry.outline.map(rebase),
                protectedRegions: originalGeometry.protectedRegions.map { $0.map(rebase) })
            let croppedAnalysis = try FaceAnalyzer().coverage(crop, geometry: [croppedGeometry])
            try PhotoIO.encode(crop).write(to: directory.appendingPathComponent("face-original.png"), options: .atomic)
            try PhotoIO.encode(croppedAnalysis.skinMask).write(to: directory.appendingPathComponent("face-mask.png"), options: .atomic)
            var panels = [crop]
            var metrics: [JSONValue] = []
            let coverage = try PhotoIO.bytes(croppedAnalysis.skinMask), before = try PhotoIO.bytes(crop)
            for (name, strength, texture) in reviewCandidates {
                var params = SkinParams(); params.strength = strength; params.texturePreservation = texture
                let result = try PortraitRenderer().renderStep(.skin(params), input: crop,
                    context: RenderContext(scale: .full, assets: [:], faces: croppedAnalysis.faces, skinMask: croppedAnalysis.skinMask))
                panels.append(result)
                try PhotoIO.encode(result).write(to: directory.appendingPathComponent("face-\(name).png"), options: .atomic)
                let after = try PhotoIO.bytes(result)
                var changed = 0, protectedChanges = 0
                var originalEnergy = 0.0, resultEnergy = 0.0
                for y in 1..<(crop.height - 1) {
                    for x in 1..<(crop.width - 1) {
                        let i = (y * crop.width + x) * 4
                        if before[i..<i + 4] != after[i..<i + 4] {
                            changed += 1
                            if coverage[i] == 0 { protectedChanges += 1 }
                        }
                        let neighbors = [i - 4, i + 4, i - crop.width * 4, i + crop.width * 4]
                        if coverage[i] > 200 && neighbors.allSatisfy({ coverage[$0] > 200 }) {
                            let a = 4 * Double(before[i]) - neighbors.reduce(0) { $0 + Double(before[$1]) }
                            let b = 4 * Double(after[i]) - neighbors.reduce(0) { $0 + Double(after[$1]) }
                            originalEnergy += a * a; resultEnergy += b * b
                        }
                    }
                }
                metrics.append(.object(["candidate": .string(name), "changedPixels": .int(changed),
                    "protectedPixelsChanged": .int(protectedChanges),
                    "textureEnergyRatio": .double(originalEnergy > 0 ? resultEnergy / originalEnergy : 1)]))
            }
            // A contact sheet is a review artifact, not an additional editing operation.
            let w = crop.width, h = crop.height
            var sheet = [UInt8](repeating: 0, count: w * h * 4 * panels.count)
            for (panel, image) in panels.enumerated() {
                let bytes = try PhotoIO.bytes(image)
                for y in 0..<h {
                    let start = (y * w * panels.count + panel * w) * 4
                    sheet.replaceSubrange(start..<start + w * 4, with: bytes[y * w * 4..<(y + 1) * w * 4])
                }
            }
            try PhotoIO.encode(PhotoIO.image(sheet, width: w * panels.count, height: h))
                .write(to: directory.appendingPathComponent("face-comparison.png"), options: .atomic)
            try JSONEncoder().encode(JSONValue.array(metrics)).write(to: directory.appendingPathComponent("face-metrics.json"), options: .atomic)
        }
        let sourceUnchanged = try PhotoIO.load(source, maximumDimension: 64).reference.contentHash == photo.reference.contentHash
        guard sourceUnchanged else { throw HostError.protocolFailure }
        let report = JSONValue.object([
            "photo_id": .string(photo.id), "faces": .int(analysis.faces.count),
            "previewWidth": .int(photo.image.width), "previewHeight": .int(photo.image.height),
            "originalWidth": .int(photo.reference.pixelSize.x), "originalHeight": .int(photo.reference.pixelSize.y),
            "sourceUnchanged": .bool(sourceUnchanged), "applied": .bool(false),
            "warnings": .array(analysis.warnings.map(JSONValue.string))
        ])
        let encoded = try JSONEncoder().encode(report)
        try encoded.write(to: directory.appendingPathComponent("report.json"), options: .atomic)
        print(String(decoding: encoded, as: UTF8.self))
    }
}
