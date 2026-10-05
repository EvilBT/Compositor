import CoreGraphics
import Foundation
import PortraitCore

/// Failures are explicit: this first renderer must never silently skip known operations.
public enum SkinRenderError: Error, Equatable, Sendable {
    case unsupportedProcessVersion(Int)
    case unsupportedOperation
    case unsupportedBlemishStrength
    case missingSkinMask
    case invalidMaskSize
    case invalidPreviewGeometry
    case imageTooLarge
    case imageConversion
}

/// Deterministic RGBA8 reference renderer. Version 1 reconstructs separated frequencies;
/// version 2 retains more texture and limits low-frequency changes at strong edges.
/// No AppKit, UIKit, GPU state or authoring-device assumptions enter the pixel path.
public struct SkinRenderer: RetouchRenderer {
    /// Bound reference-renderer allocations. Hosts can raise this after budgeting memory.
    public let maximumPixels: Int

    /// Create a reference renderer with an explicit working-surface pixel ceiling.
    public init(maximumPixels: Int = 16_000_000) {
        self.maximumPixels = maximumPixels
    }

    /// Validate the document and fold enabled, understood operations at its saved version.
    public func renderStack(_ document: PortraitDocument, input: CGImage,
                            context: RenderContext) throws -> CGImage {
        try document.validate()
        try checkVersion(document.processVersion)
        return try foldStack(document, input: input, context: context)
    }

    /// Render one skin intent, preserving alpha and pixels outside the supplied coverage.
    public func renderStep(_ kind: RetouchOpKind, input: CGImage,
                           context: RenderContext) throws -> CGImage {
        try checkVersion(context.processVersion)
        guard case .skin(let params) = kind else { throw SkinRenderError.unsupportedOperation }
        let validation = PortraitDocument(
            photo: PhotoReference(source: .file(relativePath: ""), pixelSize: SIMD2(input.width, input.height)))
        try kind.validate(against: validation)
        guard params.blemishStrength == 0 else { throw SkinRenderError.unsupportedBlemishStrength }
        let ratio = try spatialScale(input, context: context)
        guard params.strength > 0 else { return input }
        if params.protectNonSkin && context.skinMask == nil {
            // A preset may arrive before detection. Once faces exist, missing segmentation
            // is an actionable error, rather than permission to smooth eyes and clothing.
            guard context.faces.isEmpty else { throw SkinRenderError.missingSkinMask }
            return input
        }
        let width = input.width, height = input.height
        guard maximumPixels > 0, width <= maximumPixels / height else {
            throw SkinRenderError.imageTooLarge
        }
        var coverage = [Float](repeating: 1, count: width * height)
        if let mask = context.skinMask {
            guard mask.width == width, mask.height == height else { throw SkinRenderError.invalidMaskSize }
            let bytes = try PixelBuffer.read(mask)
            for i in coverage.indices { coverage[i] = Float(bytes[i * 4]) / 255 }
            if params.maskExpansion != 0 {
                let extent = max(1, Int(ceil(abs(params.maskExpansion) * params.radius * ratio)))
                coverage = Self.morphology(coverage, width: width, height: height,
                                           radius: extent, grows: params.maskExpansion > 0)
            }
        }
        guard coverage.contains(where: { $0 > 0 }) else { return input }
        var bytes = try PixelBuffer.read(input)
        var weighted = [Float](repeating: 0, count: bytes.count)
        for i in coverage.indices {
            let alpha = Float(bytes[i * 4 + 3]) / 255
            let weight = coverage[i] * alpha
            for c in 0..<3 {
                weighted[i * 4 + c] = Float(bytes[i * 4 + c]) / 255 * coverage[i]
            }
            weighted[i * 4 + 3] = weight
        }
        let radius = max(1, Int((params.radius * ratio).rounded()))
        let low = Self.blur(weighted, width: width, height: height, radius: radius)
        // Normalize each neighborhood by editable coverage and alpha. Protected colors
        // and transparent RGB must not bleed into the skin at a mask boundary.
        var lowWeighted = weighted
        for i in coverage.indices {
            let weight = weighted[i * 4 + 3]
            let divisor = max(low[i * 4 + 3], 0.000001)
            for c in 0..<3 { lowWeighted[i * 4 + c] = low[i * 4 + c] / divisor * weight }
        }
        let smooth = Self.blur(lowWeighted, width: width, height: height, radius: radius)
        let texture = Float(context.processVersion == 1
            ? params.texturePreservation : sqrt(params.texturePreservation))
        for i in coverage.indices where coverage[i] > 0 && bytes[i * 4 + 3] > 0 {
            let alpha = Float(bytes[i * 4 + 3]) / 255
            let amount = Float(params.strength) * coverage[i]
            for c in 0..<3 {
                let original = Float(bytes[i * 4 + c]) / 255 / alpha
                let base = low[i * 4 + c] / max(low[i * 4 + 3], 0.000001)
                var change = smooth[i * 4 + c] / max(smooth[i * 4 + 3], 0.000001) - base
                if context.processVersion == 2 {
                    // Smoothly limit changes to large facial structures, while retaining
                    // small tonal variations. Version 1's behavior remains frozen.
                    change = change / (1 + abs(change) / 0.04)
                }
                let target = base + change + texture * (original - base)
                let value = min(1, max(0, original + amount * (target - original)))
                bytes[i * 4 + c] = UInt8(min(Float(bytes[i * 4 + 3]), (value * alpha * 255).rounded()))
            }
        }
        return try PixelBuffer.image(bytes, width: width, height: height)
    }

    private func checkVersion(_ version: Int) throws {
        guard (1...2).contains(version) else { throw SkinRenderError.unsupportedProcessVersion(version) }
    }

    private func spatialScale(_ input: CGImage, context: RenderContext) throws -> Double {
        switch context.scale {
        case .full: return 1
        case .preview(let maximum):
            guard maximum > 0, max(input.width, input.height) <= maximum,
                  let size = context.sourcePixelSize, size.x > 0, size.y > 0,
                  input.width <= size.x, input.height <= size.y else {
                throw SkinRenderError.invalidPreviewGeometry
            }
            let x = Double(input.width) / Double(size.x), y = Double(input.height) / Double(size.y)
            guard abs(x - y) <= max(1 / Double(size.x), 1 / Double(size.y)) else {
                throw SkinRenderError.invalidPreviewGeometry
            }
            return min(x, y)
        }
    }

    // Three separable box passes approximate a Gaussian in linear time. Clamped edges
    // keep constant images constant, including at the outermost pixel.
    static func blur(_ input: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        var result = input
        for _ in 0..<3 {
            result = box(result, width: width, height: height, radius: radius, horizontal: true)
            result = box(result, width: width, height: height, radius: radius, horizontal: false)
        }
        return result
    }

    /// Deliberately not written with a local `index(_:)` helper and `for p in 0..<length`.
    ///
    /// A capturing local function blocks generic specialization, so the `Range<Int>`
    /// iteration goes through `Collection._failEarlyRangeCheck`, which calls
    /// `_swift_getGenericMetadata` — a cache lookup on every iteration. Profiling put that
    /// inside this function.
    ///
    /// Measured on a 1200x1600 render of the analytic fixture, Release:
    ///   local function   503 ms
    ///   this version     372 ms   (1.35x)
    /// and in Debug, where the test suite runs: 18.7 s -> 5.1 s (3.7x).
    ///
    /// Worth keeping for the Debug figure more than the Release one. Unsafe buffers and
    /// `while` loops keep the arithmetic bit-identical — the saved-version fingerprints in
    /// `SkinRendererTests` pin that — so only the indexing changes.
    private static func box(_ input: [Float], width: Int, height: Int,
                            radius: Int, horizontal: Bool) -> [Float] {
        var output = input
        let length = horizontal ? width : height
        let lines = horizontal ? height : width
        let step = horizontal ? 4 : width * 4
        let window = 2 * radius + 1
        input.withUnsafeBufferPointer { src in
            output.withUnsafeMutableBufferPointer { dst in
                for line in 0..<lines {
                    let base = horizontal ? line * width * 4 : line * 4
                    for c in 0..<4 {
                        let start = base + c
                        var sum = 0.0
                        var p = -radius
                        while p <= radius {
                            let q = p < 0 ? 0 : (p >= length ? length - 1 : p)
                            sum += Double(src[start + q * step])
                            p += 1
                        }
                        p = 0
                        while p < length {
                            // Division, not multiplication by a reciprocal: the two differ
                            // in the last bit and the saved-version fingerprints pin these.
                            dst[start + p * step] = Float(sum / Double(window))
                            let high = p + radius + 1, low = p - radius
                            let qh = high >= length ? length - 1 : high
                            let ql = low < 0 ? 0 : low
                            sum += Double(src[start + qh * step]) - Double(src[start + ql * step])
                            p += 1
                        }
                    }
                }
            }
        }
        return output
    }

    private static func morphology(_ input: [Float], width: Int, height: Int,
                                   radius: Int, grows: Bool) -> [Float] {
        var result = input
        for horizontal in [true, false] {
            let source = result
            let length = horizontal ? width : height, lines = horizontal ? height : width
            for line in 0..<lines {
                func index(_ p: Int) -> Int { horizontal ? line * width + p : p * width + line }
                for p in 0..<length {
                    var value: Float = grows ? 0 : 1
                    for q in max(0, p - radius)...min(length - 1, p + radius) {
                        value = grows ? max(value, source[index(q)]) : min(value, source[index(q)])
                    }
                    result[index(p)] = value
                }
            }
        }
        return result
    }
}

/// Canonical premultiplied sRGB bytes, so channel order and alpha behavior do not depend
/// on the input's provider layout. Original images are never mutated.
enum PixelBuffer {
    static let space = CGColorSpace(name: CGColorSpace.sRGB)!
    static let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

    static func read(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space, bitmapInfo: info) else {
                throw SkinRenderError.imageConversion
            }
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    static func image(_ bytes: [UInt8], width: Int, height: Int) throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: info),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw SkinRenderError.imageConversion
        }
        return image
    }
}
