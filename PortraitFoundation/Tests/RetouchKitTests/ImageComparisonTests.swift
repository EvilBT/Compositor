import Testing
@testable import RetouchKit

@Suite("Diagnostic image comparison")
struct ImageComparisonTests {
    @Test("Identical pixels remain untouched in overlay and black in difference")
    func identical() throws {
        let image = try PixelBuffer.image([100, 80, 60, 255], width: 1, height: 1)
        let result = try ImageComparison.make(original: image, processed: image)
        #expect(result.changedPixels == 0)
        #expect(try PixelBuffer.read(result.changedOverlay) == [100, 80, 60, 255])
        #expect(try PixelBuffer.read(result.difference) == [0, 0, 0, 255])
    }

    @Test("A one-byte change is counted and gain changes display only")
    func smallChange() throws {
        let before = try PixelBuffer.image([100, 80, 60, 255, 50, 40, 30, 255], width: 2, height: 1)
        let after = try PixelBuffer.image([101, 78, 60, 255, 50, 40, 30, 255], width: 2, height: 1)
        let result = try ImageComparison.make(original: before, processed: after, gain: 4)
        #expect(result.changedPixels == 1 && result.totalPixels == 2)
        #expect(try PixelBuffer.read(result.difference) == [4, 8, 0, 255, 0, 0, 0, 255])
        #expect(Array(try PixelBuffer.read(result.changedOverlay).suffix(4)) == [50, 40, 30, 255])
        #expect(try PixelBuffer.read(before) == [100, 80, 60, 255, 50, 40, 30, 255])
    }

    @Test("Different dimensions and invalid amplification are rejected")
    func geometry() throws {
        let a = try PixelBuffer.image([0, 0, 0, 255], width: 1, height: 1)
        let b = try PixelBuffer.image([0, 0, 0, 255, 0, 0, 0, 255], width: 2, height: 1)
        #expect(throws: ImageComparison.ComparisonError.self) { try ImageComparison.make(original: a, processed: b) }
        #expect(throws: ImageComparison.ComparisonError.self) { try ImageComparison.make(original: a, processed: a, gain: 0) }
    }
}
