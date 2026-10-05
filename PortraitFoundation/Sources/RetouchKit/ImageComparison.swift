import CoreGraphics
import Foundation

/// Diagnostic images never enter a document's rendering or export path.
public struct ImageComparison: @unchecked Sendable {
    public let difference: CGImage
    public let changedOverlay: CGImage
    public let changedPixels: Int
    public let totalPixels: Int

    public enum ComparisonError: Error { case invalidGeometry, invalidGain }

    /// Compare canonical RGBA8 bytes, with no threshold hiding small edits.
    /// Difference uses absolute channel deltas; alpha changes are shown in every channel.
    /// Gain is display amplification only. The magenta overlay marks any changed byte.
    public static func make(original: CGImage, processed: CGImage, gain: Int = 4) throws -> ImageComparison {
        guard original.width == processed.width, original.height == processed.height,
              original.width > 0, original.height > 0,
              original.width <= 40_000_000 / original.height else { throw ComparisonError.invalidGeometry }
        guard (1...32).contains(gain) else { throw ComparisonError.invalidGain }
        let before = try PixelBuffer.read(original), after = try PixelBuffer.read(processed)
        var difference = before, overlay = before, changed = 0
        for i in stride(from: 0, to: before.count, by: 4) {
            let alphaDelta = abs(Int(before[i + 3]) - Int(after[i + 3]))
            var edited = alphaDelta > 0
            for c in 0..<3 {
                let delta = abs(Int(before[i + c]) - Int(after[i + c]))
                edited = edited || delta > 0
                difference[i + c] = UInt8(min(255, max(delta, alphaDelta) * gain))
            }
            difference[i + 3] = 255
            if edited {
                changed += 1
                let alpha = Int(before[i + 3])
                for c in 0..<3 {
                    let tint = c == 1 ? 0 : alpha
                    overlay[i + c] = UInt8((Int(before[i + c]) * 35 + tint * 65) / 100)
                }
            }
        }
        return ImageComparison(difference: try PixelBuffer.image(difference, width: original.width, height: original.height),
            changedOverlay: try PixelBuffer.image(overlay, width: original.width, height: original.height),
            changedPixels: changed, totalPixels: original.width * original.height)
    }
}
