import CoreGraphics
import Foundation
import PortraitCore

/// A review candidate, not a diagnosis or permission to remove a permanent feature.
public struct BlemishCandidate: Codable, Sendable, Equatable {
    public let faceIndex: Int
    public let at: AnchoredPoint
    /// Fraction of the selected face width on both axes.
    public let radius: Double
    /// Heuristic ranking, not a calibrated probability.
    public let confidence: Double
    public let detectorVersion: String
}

/// Conservative multiscale local color anomalies on unchanged upright source pixels.
/// Dark-only spots, highlights and textured surroundings are deliberately omitted.
public struct BlemishDetector: Sendable {
    public static let version = "local-red-dark-v1"
    public let maximumPixels: Int

    public init(maximumPixels: Int = 4_000_000) { self.maximumPixels = maximumPixels }

    /// Return stable, face-relative candidates wholly inside nonzero skin coverage.
    public func detect(_ image: CGImage, skinMask: CGImage, faces: [FaceAnalysis],
                       threshold: Double = 0.8) throws -> [BlemishCandidate] {
        guard image.width == skinMask.width, image.height == skinMask.height,
              threshold.isFinite, (0...1).contains(threshold), maximumPixels > 0,
              image.width <= maximumPixels / image.height else { throw FaceAnalysisError.invalidGeometry }
        let rgb = try Self.bytes(image), mask = try Self.bytes(skinMask)
        let width = image.width, height = image.height
        var result: [BlemishCandidate] = []
        for face in faces {
            let box = face.boundingBox
            guard box.origin.x.isFinite, box.origin.y.isFinite, box.size.x.isFinite, box.size.y.isFinite,
                  box.origin.x >= 0, box.origin.y >= 0, box.size.x > 0, box.size.y > 0,
                  box.maxX <= 1.0001, box.maxY <= 1.0001 else { throw FaceAnalysisError.invalidGeometry }
            let x0 = Int(box.origin.x * Double(width)), y0 = Int(box.origin.y * Double(height))
            let x1 = min(width, Int(ceil(box.maxX * Double(width))))
            let y1 = min(height, Int(ceil(box.maxY * Double(height))))
            let fw = box.size.x * Double(width), w = x1 - x0, h = y1 - y0
            guard w > 0, h > 0 else { continue }
            let stride = w + 1
            var integral = [SIMD3<Double>](repeating: .zero, count: stride * (h + 1))
            for y in 0..<h {
                var row = SIMD3<Double>.zero
                for x in 0..<w {
                    let i = ((y + y0) * width + x + x0) * 4
                    row += SIMD3(Double(rgb[i]), Double(rgb[i + 1]), Double(rgb[i + 2])) / 255
                    integral[(y + 1) * stride + x + 1] = integral[y * stride + x + 1] + row
                }
            }
            func mean(_ x: Int, _ y: Int, _ radius: Int) -> SIMD3<Double> {
                let a = x - radius, b = x + radius + 1, c = y - radius, d = y + radius + 1
                return (integral[d * stride + b] - integral[c * stride + b]
                    - integral[d * stride + a] + integral[c * stride + a]) / Double((b - a) * (d - c))
            }
            func light(_ p: SIMD3<Double>) -> Double { 0.2126 * p.x + 0.7152 * p.y + 0.0722 * p.z }
            func red(_ p: SIMD3<Double>) -> Double { (p.x - p.y) / max(0.1, p.x + p.y + p.z) }
            struct Proposal { let x: Int; let y: Int; let radius: Int; let score: Double }
            var proposals: [Proposal] = []
            let scales = Set([0.006, 0.010, 0.016].map { max(2, Int((fw * $0).rounded())) }).sorted()
            for radius in scales {
                let inner = max(1, radius / 2), outer = radius * 3
                guard w > outer * 2, h > outer * 2 else { continue }
                for y in outer..<(h - outer) {
                    for x in outer..<(w - outer) {
                        let index = ((y + y0) * width + x + x0) * 4
                        guard mask[index] >= 128, rgb[index + 3] >= 250 else { continue }
                        if let left = face.landmarks[.eyeLeft], let right = face.landmarks[.eyeRight],
                           let nose = face.landmarks[.noseTip] {
                            let a = (left + right) / 2 * SIMD2(Double(width), Double(height))
                            let b = nose * SIMD2(Double(width), Double(height)), delta = b - a
                            let point = SIMD2(Double(x + x0), Double(y + y0)), length = delta.x * delta.x + delta.y * delta.y
                            let t = length > 0 ? min(1, max(0, ((point - a).x * delta.x + (point - a).y * delta.y) / length)) : 0
                            let distance = point - a - delta * t
                            // A conservative nose corridor avoids colored shading and nostril edges.
                            if distance.x * distance.x + distance.y * distance.y < pow(fw * 0.075, 2) { continue }
                        }
                        let center = mean(x, y, inner)
                        let wide = mean(x, y, outer)
                        let area = Double((outer * 2 + 1) * (outer * 2 + 1))
                        let smallArea = Double((inner * 2 + 1) * (inner * 2 + 1))
                        let background = (wide * area - center * smallArea) / (area - smallArea)
                        let bgLight = light(background), darkness = bgLight - light(center)
                        let redExcess = red(center) - red(background)
                        guard bgLight > 0.12, darkness > 0.008, darkness < bgLight * 0.30,
                              redExcess > 0.025,
                              (center.x - center.y) - (background.x - background.y) > 0.015 else { continue }
                        var ring: [SIMD3<Double>] = []
                        var protected = false
                        for dy in -radius...radius {
                            for dx in -radius...radius where dx * dx + dy * dy <= radius * radius {
                                if mask[((y + dy + y0) * width + x + dx + x0) * 4] == 0 { protected = true }
                            }
                        }
                        guard !protected else { continue }
                        for offset in [(2,0),(-2,0),(0,2),(0,-2),(1,1),(-1,1),(1,-1),(-1,-1)] {
                            let rx = x + offset.0 * radius, ry = y + offset.1 * radius
                            guard mask[((ry + y0) * width + rx + x0) * 4] >= 128 else { protected = true; break }
                            ring.append(mean(rx, ry, inner))
                        }
                        guard !protected, ring.count == 8 else { continue }
                        let lights = ring.map(light), avg = lights.reduce(0, +) / 8
                        let deviation = sqrt(lights.reduce(0) { $0 + ($1 - avg) * ($1 - avg) } / 8)
                        // Hair, glitter edges and wrinkles rarely have a uniform surrounding ring.
                        guard deviation < 0.025,
                              ring.filter({ red($0) < red(center) - 0.006 && light($0) > light(center) + 0.004 }).count >= 7 else { continue }
                        var nearHighlight = false
                        for dy in -outer...outer {
                            for dx in -outer...outer {
                                let i = ((y + dy + y0) * width + x + dx + x0) * 4
                                let p = SIMD3(Double(rgb[i]), Double(rgb[i + 1]), Double(rgb[i + 2])) / 255
                                if mask[i] > 0, p.max() - p.min() < 0.22, light(p) > bgLight + 0.12 {
                                    nearHighlight = true
                                }
                            }
                        }
                        // Favor omission beside glitter or specular points over damaging decorations.
                        guard !nearHighlight else { continue }
                        let score = min(1, 0.35 + redExcess * 7 + darkness * 3 - deviation * 4)
                        guard score >= threshold else { continue }
                        proposals.append(Proposal(x: x + x0, y: y + y0, radius: radius, score: score))
                    }
                }
            }
            proposals.sort {
                if $0.score != $1.score { return $0.score > $1.score }
                if $0.y != $1.y { return $0.y < $1.y }
                if $0.x != $1.x { return $0.x < $1.x }
                return $0.radius < $1.radius
            }
            var accepted: [Proposal] = []
            for p in proposals {
                guard !accepted.contains(where: {
                    let dx = Double($0.x - p.x), dy = Double($0.y - p.y)
                    return dx * dx + dy * dy < pow(Double($0.radius + p.radius) * 1.5, 2)
                }) else { continue }
                accepted.append(p)
                result.append(BlemishCandidate(faceIndex: face.index,
                    at: AnchoredPoint(space: .face(index: face.index), value: SIMD2(
                        ((Double(p.x) + 0.5) / Double(width) - box.origin.x) / box.size.x,
                        ((Double(p.y) + 0.5) / Double(height) - box.origin.y) / box.size.y)),
                    radius: Double(p.radius) / fw, confidence: p.score, detectorVersion: Self.version))
            }
        }
        return result
    }

    /// Enrich an existing mask without regenerating coverage or changing rendered pixels.
    public func analyze(_ image: CGImage, coverage: FaceAnalysisResult) throws -> FaceAnalysisResult {
        let candidates = try detect(image, skinMask: coverage.skinMask, faces: coverage.faces)
        let mask = try Self.bytes(coverage.skinMask), width = image.width, height = image.height
        var faces = coverage.faces
        for index in faces.indices {
            let face = faces[index], box = face.boundingBox
            var footprint = Set<Int>()
            for candidate in candidates where candidate.faceIndex == face.index {
                let center = box.origin + candidate.at.value * box.size
                let cx = Int(center.x * Double(width)), cy = Int(center.y * Double(height))
                let radius = Int((candidate.radius * box.size.x * Double(width)).rounded())
                for y in max(0, cy - radius)...min(height - 1, cy + radius) {
                    for x in max(0, cx - radius)...min(width - 1, cx + radius)
                        where (x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius {
                        if mask[(y * width + x) * 4] >= 128 { footprint.insert(y * width + x) }
                    }
                }
            }
            var skinCount = 0
            let x0 = Int(box.origin.x * Double(width)), x1 = min(width, Int(ceil(box.maxX * Double(width))))
            let y0 = Int(box.origin.y * Double(height)), y1 = min(height, Int(ceil(box.maxY * Double(height))))
            for y in y0..<y1 {
                for x in x0..<x1 where mask[(y * width + x) * 4] >= 128 { skinCount += 1 }
            }
            faces[index].skinTone?.blemishFraction = skinCount > 0 ? Double(footprint.count) / Double(skinCount) : 0
        }
        let warnings = coverage.warnings.map {
            $0.replacingOccurrences(of: " Blemish detection is unavailable; blemishFraction is not measured.", with: "")
        } +
            ["Blemish candidates are conservative color/scale heuristics, not diagnoses; review moles, freckles, facial hair and decorations before removal."]
        return FaceAnalysisResult(faces: faces, skinMask: coverage.skinMask, geometry: coverage.geometry,
            warnings: warnings, blemishes: candidates, blemishDetectorVersion: Self.version)
    }

    static func bytes(_ image: CGImage) throws -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try data.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
                throw FaceAnalysisError.imageConversion
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }
}
