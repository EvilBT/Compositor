import CoreGraphics
import Foundation
import Testing
import PortraitCore
@testable import PortraitAnalysis

@Suite("Conservative blemish candidates")
struct BlemishDetectorTests {
    private func image(_ bytes: [UInt8], size: Int = 256) throws -> CGImage {
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        return try #require(CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }

    private func fixture(delta: SIMD3<Double> = .zero, sharp: Bool = false,
                         protected: Bool = false, highlight: Bool = false, weakRim: Bool = false) throws -> (CGImage, CGImage, FaceAnalysis) {
        var rgb = [UInt8](repeating: 255, count: 256 * 256 * 4)
        var mask = rgb
        for y in 0..<256 {
            for x in 0..<256 {
                let distance = Double((x - 128) * (x - 128) + (y - 128) * (y - 128))
                let factor = sharp ? (distance < 16 ? 1.0 : 0.0) : exp(-distance / 18)
                let color = SIMD3(0.65, 0.45, 0.36) + delta * factor
                let i = (y * 256 + x) * 4
                rgb[i] = UInt8((color.x * 255).rounded()); rgb[i + 1] = UInt8((color.y * 255).rounded())
                rgb[i + 2] = UInt8((color.z * 255).rounded())
                if highlight && x == 132 && y == 128 { rgb[i] = 255; rgb[i + 1] = 255; rgb[i + 2] = 255 }
                let covered = x >= 26 && x < 230 && y >= 26 && y < 230 && !(protected && distance < 100)
                for c in 0..<3 { mask[i + c] = covered ? (weakRim && distance > 0 && distance < 9 ? 40 : 255) : 0 }
            }
        }
        let stats = SkinToneStats(meanColor: SIMD3(0.65, 0.45, 0.36), luminanceStdDev: 0,
                                  coverage: 1, blemishFraction: 0)
        return (try image(rgb), try image(mask), FaceAnalysis(index: 0,
            boundingBox: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), skinTone: stats,
            detectorVersion: "fixture"))
    }

    @Test("A soft red/dark lesion is found once, deterministically, within skin coverage")
    func redLesion() throws {
        let (photo, mask, face) = try fixture(delta: SIMD3(-0.015, -0.12, -0.075))
        let detector = BlemishDetector()
        let first = try detector.detect(photo, skinMask: mask, faces: [face])
        #expect(first.count == 1)
        #expect(try detector.detect(photo, skinMask: mask, faces: [face]) == first)
        let candidate = try #require(first.first)
        #expect(abs(candidate.at.value.x - 0.5) < 0.02)
        #expect(abs(candidate.at.value.y - 0.5) < 0.02)
        #expect(candidate.confidence >= 0.5)
        let enriched = try detector.analyze(photo, coverage: FaceAnalysisResult(faces: [face], skinMask: mask,
            geometry: [], warnings: []))
        #expect(enriched.blemishDetectionAvailable)
        #expect(enriched.faces[0].skinTone?.blemishFraction ?? 0 > 0)
        #expect(enriched.faces[0].skinTone?.blemishFraction ?? 1 < 0.01)
        #expect(try BlemishDetector.bytes(enriched.skinMask) == BlemishDetector.bytes(mask))
        #expect(try JSONDecoder().decode([BlemishCandidate].self, from: JSONEncoder().encode(first)) == first)
    }

    @Test("Dark moles, neutral freckles, highlights and smooth skin are omitted")
    func permanentFeaturesAndSmoothSkin() throws {
        for (delta, sharp) in [(SIMD3<Double>(-0.35, -0.30, -0.24), true),
                               (SIMD3(-0.12, -0.09, -0.07), false),
                               (SIMD3(0.25, 0.25, 0.25), false), (.zero, false)] {
            let (photo, mask, face) = try fixture(delta: delta, sharp: sharp)
            #expect(try BlemishDetector().detect(photo, skinMask: mask, faces: [face]).isEmpty)
        }
    }

    @Test("Nearby decorative highlights suppress candidates while nonzero soft skin remains eligible")
    func decorativeHighlightsAndSoftCoverage() throws {
        let (photo, mask, face) = try fixture(delta: SIMD3(-0.015, -0.12, -0.075), highlight: true)
        #expect(try BlemishDetector().detect(photo, skinMask: mask, faces: [face]).isEmpty)
        let (softPhoto, softMask, softFace) = try fixture(delta: SIMD3(-0.015, -0.12, -0.075), weakRim: true)
        #expect(try BlemishDetector().detect(softPhoto, skinMask: softMask, faces: [softFace]).count == 1)
    }

    @Test("A red lesion in a protected feature is not offered; invalid inputs are refused")
    func protectedFeatures() throws {
        let (photo, mask, face) = try fixture(delta: SIMD3(-0.015, -0.12, -0.075), protected: true)
        #expect(try BlemishDetector().detect(photo, skinMask: mask, faces: [face]).isEmpty)
        #expect(throws: FaceAnalysisError.self) {
            try BlemishDetector().detect(photo, skinMask: mask, faces: [face], threshold: .nan)
        }
        #expect(throws: FaceAnalysisError.self) {
            try BlemishDetector(maximumPixels: 100).detect(photo, skinMask: mask, faces: [face])
        }
    }
}
