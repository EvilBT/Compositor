import CoreGraphics
import Foundation
import PortraitAnalysis
import PortraitCore
import PortraitMCP

@main struct Trial {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3 else { fatalError("Usage: Trial PHOTO NEW_OUTPUT") }
        let source = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2])
        guard !FileManager.default.fileExists(atPath: output.path) else { fatalError("Output must not exist") }
        let photo = try PhotoIO.load(source, maximumDimension: 2048)
        let start = ContinuousClock.now
        let analysis = try FaceAnalyzer().analyze(photo.image)
        let elapsed = start.duration(to: .now)
        var times: [Double] = []
        for _ in 0..<3 {
            let before = ContinuousClock.now
            let repeated = try BlemishDetector().detect(photo.image, skinMask: analysis.skinMask, faces: analysis.faces)
            guard repeated == analysis.blemishes else { fatalError("Nondeterministic candidates") }
            let t = before.duration(to: .now).components
            times.append(Double(t.seconds) * 1000 + Double(t.attoseconds) / 1e15)
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try PhotoIO.encode(photo.image).write(to: output.appendingPathComponent("source.png"))
        try PhotoIO.encode(analysis.skinMask).write(to: output.appendingPathComponent("skin.png"))
        let width = photo.image.width, height = photo.image.height
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
        context.draw(photo.image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setStrokeColor(CGColor(red: 1, green: 0.75, blue: 0, alpha: 1))
        context.setLineWidth(1.5)
        var positions: [[String: JSONValue]] = []
        let mask = try PhotoIO.bytes(analysis.skinMask)
        for candidate in analysis.blemishes {
            let box = analysis.faces.first { $0.index == candidate.faceIndex }!.boundingBox
            let center = box.origin + candidate.at.value * box.size
            let x = center.x * Double(width), y = center.y * Double(height)
            let radius = candidate.radius * box.size.x * Double(width)
            let cx = Int(x), cy = Int(y), r = Int(radius.rounded())
            for py in (cy-r)...(cy+r) {
                for px in (cx-r)...(cx+r) where (px-cx)*(px-cx)+(py-cy)*(py-cy) <= r*r {
                    guard py >= 0, py < height, px >= 0, px < width, mask[(py*width+px)*4] > 0 else {
                        fatalError("Candidate exceeds skin")
                    }
                }
            }
            context.strokeEllipse(in: CGRect(x: x-radius-2, y: Double(height)-y-radius-2,
                width: (radius+2)*2, height: (radius+2)*2))
            positions.append(["face": .int(candidate.faceIndex), "x": .double(x), "y": .double(y),
                "radius": .double(radius), "confidence": .double(candidate.confidence)])
        }
        try PhotoIO.encode(context.makeImage()!).write(to: output.appendingPathComponent("candidates.png"))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        func json<T: Encodable>(_ value: T) throws -> JSONValue {
            try JSONDecoder().decode(JSONValue.self, from: encoder.encode(value))
        }
        let duration = elapsed.components
        let report = JSONValue.object(["source": .string(source.path), "photo_id": .string(photo.id),
            "width": .int(width), "height": .int(height), "faces": try json(analysis.faces),
            "candidates": try json(analysis.blemishes), "pixels": try json(positions),
            "detector_version": .string(BlemishDetector.version), "available": .bool(analysis.blemishDetectionAvailable),
            "analysis_ms": .double(Double(duration.seconds)*1000+Double(duration.attoseconds)/1e15),
            "detector_ms_three_runs": try json(times), "deterministic": .bool(true),
            "candidate_disks_inside_skin": .bool(true), "warnings": try json(analysis.warnings)])
        try encoder.encode(report).write(to: output.appendingPathComponent("report.json"))
        print("\(source.lastPathComponent): \(analysis.faces.count) faces, \(analysis.blemishes.count) candidates, detector ms \(times)")
    }
}
