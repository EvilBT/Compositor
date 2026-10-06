import CoreGraphics
import Foundation
import PortraitCore
import Vision

/// Failures in image conversion or invalid normalized geometry.
public enum FaceAnalysisError: Error, Sendable {
    case imageConversion, invalidGeometry, imageTooLarge
}

/// Detector geometry, normalized to the upright image with top-left origin.
public struct FaceGeometry: Codable, Sendable {
    /// Semantic analysis to store in the document.
    public var face: FaceAnalysis
    /// Jaw contour plus inferred forehead corners; used only for conservative coverage.
    public var outline: [SIMD2<Double>]
    /// Detected eyes, brows and lips, expanded before rasterization.
    public var protectedRegions: [[SIMD2<Double>]]

    /// Supply geometry independently of Vision for deterministic coverage tests.
    public init(face: FaceAnalysis, outline: [SIMD2<Double>], protectedRegions: [[SIMD2<Double>]]) {
        self.face = face
        self.outline = outline
        self.protectedRegions = protectedRegions
    }
}

/// Analysis includes reproducible raster coverage; face rectangles alone cannot protect features.
public struct FaceAnalysisResult: @unchecked Sendable {
    public let faces: [FaceAnalysis]
    public let skinMask: CGImage
    public let geometry: [FaceGeometry]
    public let warnings: [String]
    public let blemishes: [BlemishCandidate]
    public let blemishDetectorVersion: String?
    public var blemishDetectionAvailable: Bool { blemishDetectorVersion != nil }

    /// Restore a validated analysis cache without rerunning a newer detector.
    public init(faces: [FaceAnalysis], skinMask: CGImage, geometry: [FaceGeometry], warnings: [String],
                blemishes: [BlemishCandidate] = [], blemishDetectorVersion: String? = nil) {
        self.faces = faces
        self.skinMask = skinMask
        self.geometry = geometry
        self.warnings = warnings
        self.blemishes = blemishes
        self.blemishDetectorVersion = blemishDetectorVersion
    }
}

/// Vision landmarks plus a conservative face-local chroma prior, not a learned skin classifier.
/// Inputs must have their EXIF orientation applied before calling the detector.
public struct FaceAnalyzer: Sendable {
    /// Limit working allocations; the host analyzes a bounded preview.
    public let maximumPixels: Int

    public init(maximumPixels: Int = 4_000_000) { self.maximumPixels = maximumPixels }

    /// Detect rectangles and landmarks, then generate coverage in the same image coordinates.
    public func analyze(_ image: CGImage) throws -> FaceAnalysisResult {
        guard maximumPixels > 0, image.width <= maximumPixels / image.height else { throw FaceAnalysisError.imageTooLarge }
        let rectangles = VNDetectFaceRectanglesRequest()
        rectangles.revision = VNDetectFaceRectanglesRequestRevision3
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([rectangles])
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        request.inputFaceObservations = rectangles.results ?? []
        if !(rectangles.results ?? []).isEmpty { try handler.perform([request]) }
        let observations = (request.results ?? []).sorted { a, b in
            if a.boundingBox.minX == b.boundingBox.minX { return a.boundingBox.minY > b.boundingBox.minY }
            return a.boundingBox.minX < b.boundingBox.minX
        }
        var geometry: [FaceGeometry] = []
        for observation in observations where observation.confidence >= 0.5 {
            guard let landmarks = observation.landmarks,
                  landmarks.leftEye != nil, landmarks.rightEye != nil, landmarks.outerLips != nil else { continue }
            let box = observation.boundingBox
            func points(_ region: VNFaceLandmarkRegion2D?) -> [SIMD2<Double>] {
                guard let region else { return [] }
                return region.normalizedPoints.map {
                    SIMD2(Double(box.minX) + Double($0.x) * Double(box.width),
                          1 - Double(box.minY) - Double($0.y) * Double(box.height))
                }
            }
            func center(_ points: [SIMD2<Double>]) -> SIMD2<Double> {
                points.reduce(.zero, +) / Double(max(1, points.count))
            }
            let eyes = [points(landmarks.leftEye), points(landmarks.rightEye)].sorted { center($0).x < center($1).x }
            let brows = [points(landmarks.leftEyebrow), points(landmarks.rightEyebrow)].sorted { center($0).x < center($1).x }
            let mouth = points(landmarks.outerLips), nose = points(landmarks.nose)
            let rect = PortraitCore.NormalizedRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
            let eyeLine = (center(eyes[0]) + center(eyes[1])) / 2
            let mouthCenter = center(mouth)
            var map = LandmarkMap()
            // Subject-left is image-right for an upright, unmirrored frontal portrait.
            // Highly turned profiles need a richer anatomical correspondence later.
            map[.eyeRight] = center(eyes[0]); map[.eyeLeft] = center(eyes[1])
            map[.browRight] = center(brows[0]); map[.browLeft] = center(brows[1])
            map[.faceCenter] = rect.center
            map[.mouthCenter] = mouthCenter
            map[.noseTip] = nose.max(by: { $0.y < $1.y }) ?? rect.center
            map[.cheekRight] = SIMD2(rect.origin.x + rect.size.x * 0.25, eyeLine.y * 0.45 + mouthCenter.y * 0.55)
            map[.cheekLeft] = SIMD2(rect.origin.x + rect.size.x * 0.75, eyeLine.y * 0.45 + mouthCenter.y * 0.55)
            let contour = points(landmarks.faceContour)
            map[.chin] = contour.max(by: { $0.y < $1.y })
            let eyeDelta = center(eyes[1]) - center(eyes[0])
            let face = FaceAnalysis(index: geometry.count, boundingBox: rect,
                roll: atan2(eyeDelta.y, eyeDelta.x) * 180 / .pi, landmarks: map,
                detectorVersion: "vision-rect3-landmarks3-chroma1")
            let forehead = [SIMD2(rect.origin.x + rect.size.x * 0.12, rect.origin.y + rect.size.y * 0.12),
                            SIMD2(rect.origin.x + rect.size.x * 0.88, rect.origin.y + rect.size.y * 0.12)]
            geometry.append(FaceGeometry(face: face, outline: contour + forehead,
                                         protectedRegions: eyes + brows + [mouth]))
        }
        return try coverage(image, geometry: geometry)
    }

    /// Rasterize conservative coverage from supplied geometry without invoking Vision.
    public func coverage(_ image: CGImage, geometry: [FaceGeometry]) throws -> FaceAnalysisResult {
        guard maximumPixels > 0, image.width <= maximumPixels / image.height else { throw FaceAnalysisError.imageTooLarge }
        let width = image.width, height = image.height
        let bytes = try raster(image)
        var mask = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<width * height { mask[i * 4 + 3] = 255 }
        var faces: [FaceAnalysis] = [], warnings: [String] = []
        for shape in geometry {
            let rect = shape.face.boundingBox
            guard rect.origin.x.isFinite, rect.origin.y.isFinite, rect.size.x.isFinite, rect.size.y.isFinite,
                  rect.size.x > 0, rect.size.y > 0,
                  rect.origin.x >= 0, rect.origin.y >= 0, rect.maxX <= 1.0001, rect.maxY <= 1.0001,
                  (shape.outline + shape.protectedRegions.flatMap { $0 } + Array(shape.face.landmarks.points.values)).allSatisfy({
                      $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y)
                  }) else { throw FaceAnalysisError.invalidGeometry }
            let hull = Self.convexHull(shape.outline)
            guard hull.count >= 3, shape.protectedRegions.count >= 5,
                  shape.protectedRegions.allSatisfy({ $0.count >= 2 }) else {
                warnings.append("Face \(shape.face.index): incomplete landmarks; coverage omitted.")
                faces.append(shape.face)
                continue
            }
            let x0 = max(0, Int(rect.origin.x * Double(width))), x1 = min(width, Int(ceil(rect.maxX * Double(width))))
            let y0 = max(0, Int(rect.origin.y * Double(height))), y1 = min(height, Int(ceil(rect.maxY * Double(height))))
            guard x0 < x1, y0 < y1 else { throw FaceAnalysisError.invalidGeometry }
            let feather = max(1.5, rect.size.x * Double(width) * 0.018)
            // Convex feature hulls with a distance margin protect lashes and lip edges.
            let features = shape.protectedRegions.map(Self.convexHull)
            func geometryWeight(_ x: Int, _ y: Int) -> Double {
                let point = SIMD2((Double(x) + 0.5) / Double(width), (Double(y) + 0.5) / Double(height))
                guard Self.inside(point, polygon: hull) else { return 0 }
                var weight = min(1, Self.edgeDistance(point, polygon: hull, width: width, height: height) / feather)
                for feature in features {
                    if Self.inside(point, polygon: feature) { return 0 }
                    let margin = feather * 2
                    let distance = Self.edgeDistance(point, polygon: feature, width: width, height: height)
                    weight = min(weight, min(1, max(0, (distance - margin) / feather)))
                }
                return weight
            }
            var samples: [SIMD3<Double>] = []
            for anchor in [shape.face.landmarks[.cheekLeft], shape.face.landmarks[.cheekRight]].compactMap({ $0 }) {
                let ax = Int(anchor.x * Double(width)), ay = Int(anchor.y * Double(height))
                let radius = max(2, Int(rect.size.x * Double(width) * 0.06))
                guard max(y0, ay - radius) < min(y1, ay + radius),
                      max(x0, ax - radius) < min(x1, ax + radius) else { continue }
                for y in max(y0, ay - radius)..<min(y1, ay + radius) {
                    for x in max(x0, ax - radius)..<min(x1, ax + radius) where geometryWeight(x, y) > 0.5 {
                        let i = (y * width + x) * 4
                        let rgb = SIMD3(Double(bytes[i]), Double(bytes[i + 1]), Double(bytes[i + 2])) / 255
                        if rgb.x + rgb.y + rgb.z > 0.25 && rgb.max() < 0.98 { samples.append(rgb) }
                    }
                }
            }
            guard samples.count >= 8 else {
                warnings.append("Face \(shape.face.index): insufficient cheek samples; coverage omitted.")
                faces.append(shape.face)
                continue
            }
            func median(_ values: [Double]) -> Double { values.sorted()[values.count / 2] }
            let chroma = samples.map { $0 / ($0.x + $0.y + $0.z) }
            let reference = SIMD3(median(chroma.map(\.x)), median(chroma.map(\.y)), median(chroma.map(\.z)))
            let referenceLight = median(samples.map { 0.2126 * $0.x + 0.7152 * $0.y + 0.0722 * $0.z })
            var total = SIMD3<Double>.zero, luminance: Double = 0, squared: Double = 0, count = 0
            for y in y0..<y1 {
                for x in x0..<x1 {
                    let i = (y * width + x) * 4
                    let rgb = SIMD3(Double(bytes[i]), Double(bytes[i + 1]), Double(bytes[i + 2])) / 255
                    let sum = rgb.x + rgb.y + rgb.z
                    guard sum > 0.18 else { continue }
                    let difference = rgb / sum - reference
                    let distance = sqrt(difference.x * difference.x + difference.y * difference.y + difference.z * difference.z)
                    let color = min(1, max(0, (0.10 - distance) / 0.065))
                    let light = 0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z
                    // Pale decorative highlights can have skin-like chroma. Protect them
                    // relative to this face's sampled illumination, not a global skin color.
                    let highlight = rgb.max() - rgb.min() < 0.15
                        ? min(1, max(0, (referenceLight + 0.22 - light) / 0.08)) : 1
                    let weight = geometryWeight(x, y) * color * highlight * min(1, max(0, (rgb.max() - 0.06) / 0.08))
                    let value = UInt8((weight * 255).rounded())
                    for c in 0..<3 { mask[i + c] = max(mask[i + c], value) }
                    if value > 127 {
                        let l = light
                        total += rgb; luminance += l; squared += l * l; count += 1
                    }
                }
            }
            var face = shape.face
            if count > 0 {
                let average = luminance / Double(count)
                face.skinTone = SkinToneStats(meanColor: total / Double(count),
                    luminanceStdDev: sqrt(max(0, squared / Double(count) - average * average)),
                    coverage: Double(count) / Double((x1 - x0) * (y1 - y0)), blemishFraction: 0)
            }
            faces.append(face)
        }
        warnings.append("Coverage is a conservative landmark/chroma heuristic; inspect makeup, hair and occlusions.")
        return try BlemishDetector(maximumPixels: maximumPixels).analyze(image,
            coverage: FaceAnalysisResult(faces: faces, skinMask: try makeImage(mask, width: width, height: height),
                                        geometry: geometry, warnings: warnings))
    }

    static func convexHull(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
        let points = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard points.count > 2 else { return points }
        func cross(_ o: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        func half(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
            var result: [SIMD2<Double>] = []
            for p in points {
                while result.count >= 2 && cross(result[result.count - 2], result[result.count - 1], p) <= 0 { result.removeLast() }
                result.append(p)
            }
            return result
        }
        return Array(half(points).dropLast()) + Array(half(points.reversed()).dropLast())
    }

    static func inside(_ p: SIMD2<Double>, polygon: [SIMD2<Double>]) -> Bool {
        guard polygon.count >= 3 else { return false }
        for i in polygon.indices {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            if (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) < 0 { return false }
        }
        return true
    }

    static func edgeDistance(_ p: SIMD2<Double>, polygon: [SIMD2<Double>], width: Int, height: Int) -> Double {
        let size = SIMD2(Double(width), Double(height)), p = p * size
        var distance = Double.greatestFiniteMagnitude
        for i in polygon.indices {
            let a = polygon[i] * size, b = polygon[(i + 1) % polygon.count] * size, delta = b - a
            let length = delta.x * delta.x + delta.y * delta.y
            let t = length > 0 ? min(1, max(0, ((p - a).x * delta.x + (p - a).y * delta.y) / length)) : 0
            let d = p - a - t * delta
            distance = min(distance, sqrt(d.x * d.x + d.y * d.y))
        }
        return distance
    }

    private func raster(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
                throw FaceAnalysisError.imageConversion
            }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    private func makeImage(_ bytes: [UInt8], width: Int, height: Int) throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw FaceAnalysisError.imageConversion
        }
        return image
    }
}
