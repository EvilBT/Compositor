import CoreGraphics
import Foundation
import Testing
import PortraitCore
@testable import PortraitAnalysis

@Suite("Conservative skin coverage")
struct FaceAnalyzerTests {
    private func image() throws -> CGImage {
        var bytes = [UInt8](repeating: 255, count: 100 * 100 * 4)
        for i in stride(from: 0, to: bytes.count, by: 4) { bytes[i] = 170; bytes[i + 1] = 120; bytes[i + 2] = 100 }
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        return try #require(CGImage(width: 100, height: 100, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: 400, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }

    @Test("Detected features and areas beyond the face stay protected")
    func geometryProtection() throws {
        var landmarks = LandmarkMap()
        landmarks[.cheekLeft] = SIMD2(0.65, 0.60); landmarks[.cheekRight] = SIMD2(0.35, 0.60)
        let face = FaceAnalysis(index: 0, boundingBox: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                                landmarks: landmarks, detectorVersion: "fixture")
        func box(_ x: Double, _ y: Double) -> [SIMD2<Double>] {
            [SIMD2(x, y), SIMD2(x + 0.12, y), SIMD2(x + 0.12, y + 0.05), SIMD2(x, y + 0.05)]
        }
        let shape = FaceGeometry(face: face, outline: [SIMD2(0.1, 0.1), SIMD2(0.9, 0.1), SIMD2(0.9, 0.9), SIMD2(0.1, 0.9)],
            protectedRegions: [box(0.25, 0.35), box(0.65, 0.35), box(0.25, 0.25), box(0.65, 0.25), box(0.44, 0.72)])
        let result = try FaceAnalyzer().coverage(image(), geometry: [shape])
        let data = try #require(result.skinMask.dataProvider?.data) as Data
        #expect(data[(60 * 100 + 65) * 4] > 200)
        #expect(data[(37 * 100 + 30) * 4] == 0)
        #expect(data[(74 * 100 + 48) * 4] == 0)
        #expect(data[(5 * 100 + 5) * 4] == 0)
        #expect(result.faces[0].skinTone?.coverage ?? 0 > 0.5)
    }

    @Test("No faces and incomplete landmarks yield an empty mask")
    func incomplete() throws {
        let face = FaceAnalysis(index: 0, boundingBox: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), detectorVersion: "fixture")
        for geometry in [[], [FaceGeometry(face: face, outline: [], protectedRegions: [])]] {
            let result = try FaceAnalyzer().coverage(image(), geometry: geometry)
            let data = try #require(result.skinMask.dataProvider?.data) as Data
            #expect(stride(from: 0, to: data.count, by: 4).allSatisfy { data[$0] == 0 })
        }
    }
}
