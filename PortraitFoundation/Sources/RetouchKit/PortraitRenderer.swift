import CoreGraphics
import Foundation
import PortraitCore

// Point-curve interpolation follows Compositor/Document/Curves.swift, with weighted
// tangents for uneven spacing. Copyright (c) 2026 Wonder Assembly LLC, MIT;
// the original license is preserved in the repository's LICENSE.

/// Errors for develop parameters not yet implemented by the reference pipeline.
public enum PortraitRenderError: Error, Sendable, Equatable {
    case unsupportedCurveOption
    case invalidCurve
    case invalidParameter(String)
}

/// Develop plus skin, using the same authoritative single-step path on every platform.
public struct PortraitRenderer: RetouchRenderer {
    private let skin: SkinRenderer

    /// Bound all reference-renderer working surfaces, including develop-only stacks.
    public init(maximumPixels: Int = 16_000_000) { skin = SkinRenderer(maximumPixels: maximumPixels) }

    /// Validate and render the stable phase order with the document's process version.
    public func renderStack(_ document: PortraitDocument, input: CGImage, context: RenderContext) throws -> CGImage {
        try document.validate()
        guard (1...2).contains(document.processVersion) else {
            throw SkinRenderError.unsupportedProcessVersion(document.processVersion)
        }
        return try foldStack(document, input: input, context: context)
    }

    /// Render relative white balance, tone, presence, point curves or skin.
    public func renderStep(_ kind: RetouchOpKind, input: CGImage, context: RenderContext) throws -> CGImage {
        guard (1...2).contains(context.processVersion) else { throw SkinRenderError.unsupportedProcessVersion(context.processVersion) }
        guard skin.maximumPixels > 0, input.width <= skin.maximumPixels / input.height else { throw SkinRenderError.imageTooLarge }
        let doc = PortraitDocument(photo: PhotoReference(source: .file(relativePath: ""), pixelSize: SIMD2(input.width, input.height)))
        try kind.validate(against: doc)
        switch kind {
        case .skin:
            return try skin.renderStep(kind, input: input, context: context)
        case .tone(let p):
            if p == ToneParams() { return input }
            return try map(input) { rgb in
                var linear = rgb.applying(Self.linear)
                linear *= Float(pow(2, p.exposure))
                let l = Self.luminance(linear)
                let shadow = pow(max(0, 1 - Double(l)), 2), highlight = pow(Double(l), 2)
                let shift = Float((p.shadows * shadow + p.highlights * highlight) / 300
                    + p.whites * highlight / 400 + p.blacks * shadow / 400)
                linear += SIMD3(repeating: shift)
                var result = linear.applying(Self.encoded)
                result = SIMD3(repeating: 0.5) + (result - SIMD3(repeating: 0.5)) * Float(1 + p.contrast / 100)
                return result
            }
        case .whiteBalance(let p):
            try range(p.temperature, -100...100, "temperature"); try range(p.tint, -100...100, "tint")
            var gains = SIMD3(Float(pow(2, p.temperature / 300 + p.tint / 600)),
                              Float(pow(2, -p.tint / 300)), Float(pow(2, -p.temperature / 300 + p.tint / 600)))
            if let neutral = p.sampledNeutral {
                guard neutral.x > 0, neutral.y > 0, neutral.z > 0,
                      neutral.x <= 1, neutral.y <= 1, neutral.z <= 1 else { throw PortraitRenderError.invalidParameter("sampledNeutral") }
                let linear = SIMD3(Float(neutral.x), Float(neutral.y), Float(neutral.z)).applying(Self.linear)
                gains = SIMD3(repeating: Self.luminance(linear)) / linear
            }
            if p == WhiteBalanceParams() { return input }
            let fixedGains = gains
            return try map(input) { ($0.applying(Self.linear) * fixedGains).applying(Self.encoded) }
        case .presence(let p):
            for (name, value) in [("texture", p.texture), ("clarity", p.clarity), ("dehaze", p.dehaze),
                                  ("vibrance", p.vibrance), ("saturation", p.saturation)] { try range(value, -100...100, name) }
            if p == PresenceParams() { return input }
            let ratio: Double
            if case .preview = context.scale {
                guard let size = context.sourcePixelSize, size.x > 0, size.y > 0 else { throw SkinRenderError.invalidPreviewGeometry }
                ratio = min(Double(input.width) / Double(size.x), Double(input.height) / Double(size.y))
            } else { ratio = 1 }
            let bytes = try PixelBuffer.read(input)
            var colors = [Float](repeating: 0, count: bytes.count)
            for i in stride(from: 0, to: bytes.count, by: 4) {
                let alpha = Float(bytes[i + 3]) / 255
                for c in 0..<3 { colors[i + c] = alpha > 0 ? Float(bytes[i + c]) / 255 / alpha : 0 }
                colors[i + 3] = alpha
            }
            let weighted = bytes.map { Float($0) / 255 }
            let fine = p.texture != 0 ? SkinRenderer.blur(weighted, width: input.width, height: input.height, radius: max(1, Int((2 * ratio).rounded()))) : []
            let broad = p.clarity != 0 ? SkinRenderer.blur(weighted, width: input.width, height: input.height, radius: max(1, Int((12 * ratio).rounded()))) : []
            var result = bytes
            for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] > 0 {
                var rgb = SIMD3(colors[i], colors[i + 1], colors[i + 2])
                for c in 0..<3 {
                    if !fine.isEmpty { rgb[c] += Float(p.texture / 100) * (colors[i + c] - fine[i + c] / max(0.000001, fine[i + 3])) }
                    if !broad.isEmpty { rgb[c] += Float(p.clarity / 100) * (colors[i + c] - broad[i + c] / max(0.000001, broad[i + 3])) * 0.6 }
                }
                let dark = Float(p.dehaze / 500)
                rgb = (rgb - SIMD3(repeating: dark)) / (1 - dark)
                let l = Self.luminance(rgb)
                let saturation = rgb.max() - rgb.min()
                let scale = Float(1 + p.saturation / 100 + p.vibrance / 100 * Double(1 - saturation))
                rgb = SIMD3(repeating: l) + (rgb - SIMD3(repeating: l)) * max(0, scale)
                Self.store(rgb, into: &result, at: i)
            }
            return try PixelBuffer.image(result, width: input.width, height: input.height)
        case .toneCurve(let p):
            guard p.parametric == nil, p.refineSaturation == 0 else { throw PortraitRenderError.unsupportedCurveOption }
            if p.channels.isEmpty { return input }
            let curves = try p.channels.mapValues { try MonotoneCurve($0) }
            return try map(input) { rgb in
                var result = rgb
                for (c, channel) in [CurveParams.Channel.red, .green, .blue].enumerated() {
                    let value = curves[channel]?.value(Double(rgb[c])) ?? Double(rgb[c])
                    result[c] = Float(curves[.rgb]?.value(value) ?? value)
                }
                return result
            }
        default:
            throw SkinRenderError.unsupportedOperation
        }
    }

    private func range(_ value: Double, _ range: ClosedRange<Double>, _ name: String) throws {
        guard value.isFinite, range.contains(value) else { throw PortraitRenderError.invalidParameter(name) }
    }

    private func map(_ input: CGImage, transform: (SIMD3<Float>) -> SIMD3<Float>) throws -> CGImage {
        var bytes = try PixelBuffer.read(input)
        for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] > 0 {
            let alpha = Float(bytes[i + 3])
            let rgb = SIMD3(Float(bytes[i]), Float(bytes[i + 1]), Float(bytes[i + 2])) / alpha
            Self.store(transform(rgb), into: &bytes, at: i)
        }
        return try PixelBuffer.image(bytes, width: input.width, height: input.height)
    }

    private static func store(_ rgb: SIMD3<Float>, into bytes: inout [UInt8], at i: Int) {
        for c in 0..<3 { bytes[i + c] = UInt8((min(1, max(0, rgb[c])) * Float(bytes[i + 3])).rounded()) }
    }
    private static func luminance(_ rgb: SIMD3<Float>) -> Float { 0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z }
    private static func linear(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    private static func encoded(_ v: Float) -> Float { v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055 }
}

/// Shape-preserving cubic Hermite interpolation. Uneven point spacing participates in
/// the harmonic tangent weights, preventing overshoot without rasterizing control points.
struct MonotoneCurve {
    let points: [CurvePoint]
    let slopes: [Double]

    init(_ points: [CurvePoint]) throws {
        guard (2...32).contains(points.count), points.first?.x == 0, points.last?.x == 1,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }),
              zip(points, points.dropFirst()).allSatisfy({ $0.x < $1.x }) else { throw PortraitRenderError.invalidCurve }
        self.points = points
        let h = zip(points, points.dropFirst()).map { $1.x - $0.x }
        let d = zip(points, points.dropFirst()).map { ($1.y - $0.y) / ($1.x - $0.x) }
        var slopes = [Double](repeating: 0, count: points.count)
        slopes[0] = d[0]; slopes[points.count - 1] = d[d.count - 1]
        if points.count > 2 {
            for j in 1..<(points.count - 1) where d[j - 1] * d[j] > 0 {
                let a = 2 * h[j] + h[j - 1], b = h[j] + 2 * h[j - 1]
                slopes[j] = (a + b) / (a / d[j - 1] + b / d[j])
            }
        }
        self.slopes = slopes
    }

    func value(_ value: Double) -> Double {
        let i = min(points.count - 2, max(0, points.lastIndex(where: { $0.x <= value }) ?? 0))
        let h = points[i + 1].x - points[i].x, t = min(1, max(0, (value - points[i].x) / h))
        let y = (2 * t * t * t - 3 * t * t + 1) * points[i].y + (t * t * t - 2 * t * t + t) * h * slopes[i]
            + (-2 * t * t * t + 3 * t * t) * points[i + 1].y + (t * t * t - t * t) * h * slopes[i + 1]
        return min(1, max(0, y))
    }
}

private extension SIMD3 where Scalar == Float {
    func applying(_ transform: (Float) -> Float) -> Self {
        SIMD3(transform(x), transform(y), transform(z))
    }
}
