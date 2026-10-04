import CoreGraphics
import Foundation
import Testing
import PortraitCore
@testable import RetouchKit

private let width = 128, height = 96

private func fixture() throws -> CGImage {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let light = 16 * sin(Double(x) * .pi / 32) + 10 * cos(Double(y) * .pi / 24)
            let pores = 15 * sin(Double(x) * .pi / 2) * cos(Double(y) * .pi / 2)
            for (c, base) in [155.0, 115.0, 95.0].enumerated() {
                bytes[(y * width + x) * 4 + c] = UInt8((base + light + pores).rounded())
            }
        }
    }
    return try PixelBuffer.image(bytes, width: width, height: height)
}

private func document(_ params: [SkinParams], version: Int = 2) -> PortraitDocument {
    var result = PortraitDocument(
        photo: PhotoReference(source: .file(relativePath: "fixture.png"), pixelSize: SIMD2(width, height)),
        ops: params.map { RetouchOp(kind: .skin($0)) })
    result.processVersion = version
    return result
}

private func context(version: Int = 2, mask: CGImage? = nil) -> RenderContext {
    RenderContext(scale: .full, assets: [:], faces: [], processVersion: version, skinMask: mask)
}

private func params(texture: Double = 0.85) -> SkinParams {
    var result = SkinParams()
    result.strength = 1
    result.texturePreservation = texture
    result.radius = 4
    result.protectNonSkin = false
    return result
}

// A discrete Laplacian measures pore-scale energy, independently of the renderer's blur.
// Excluding the rim avoids conflating mask/image boundaries with retained texture.
private func energy(_ image: CGImage) throws -> Double {
    let bytes = try PixelBuffer.read(image)
    var sum: Double = 0
    for y in 20..<(height - 20) {
        for x in 20..<(width - 20) {
            let i = (y * width + x) * 4
            let laplacian = 4 * Double(bytes[i]) - Double(bytes[i - 4]) - Double(bytes[i + 4])
                - Double(bytes[i - width * 4]) - Double(bytes[i + width * 4])
            sum += laplacian * laplacian
        }
    }
    return sum
}

@Suite("Skin rendering contract")
struct SkinRendererTests {
    @Test("Preserving all texture still reduces slow tonal unevenness", arguments: [1, 2])
    func tonalSmoothing(version: Int) throws {
        func variation(_ image: CGImage) throws -> Double {
            let bytes = try PixelBuffer.read(image)
            var means: [Double] = []
            for y in stride(from: 20, to: height - 24, by: 4) {
                for x in stride(from: 20, to: width - 24, by: 4) {
                    var total: Double = 0
                    for dy in 0..<4 {
                        for dx in 0..<4 { total += Double(bytes[((y + dy) * width + x + dx) * 4]) }
                    }
                    means.append(total / 16)
                }
            }
            let mean = means.reduce(0, +) / Double(means.count)
            return means.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        }
        let image = try fixture()
        let result = try SkinRenderer().renderStep(.skin(params(texture: 1)), input: image,
                                                  context: context(version: version))
        #expect(try variation(result) < 0.95 * variation(image))
        #expect(try energy(result) / energy(image) >= 0.95)
    }

    @Test("Texture controls retain pores and catch plastic smoothing", arguments: [1, 2])
    func textureEnergy(version: Int) throws {
        let renderer = SkinRenderer(), image = try fixture()
        let original = try energy(image)
        let retained = try renderer.renderStep(.skin(params()), input: image, context: context(version: version))
        let flattened = try renderer.renderStep(.skin(params(texture: 0.10)), input: image, context: context(version: version))
        let blurOnly = try renderer.renderStep(.skin(params(texture: 0)), input: image, context: context(version: version))
        let high = try energy(retained) / original, low = try energy(flattened) / original
        let baseline = try energy(blurOnly) / original
        print("Skin v\(version): retained \(high * 100)%, low \(low * 100)%, blur \(baseline * 100)%")
        let checksum = try PixelBuffer.read(retained).reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        // Fixed byte fingerprints prevent later improvements from silently rewriting
        // either released process version. New behavior needs a new version and fixture.
        #expect(checksum == (version == 1 ? 18120792545136416706 : 7785058592950695833))
        #expect(high >= 0.60)
        #expect(low <= 0.25)
        #expect(baseline < 0.10)
        #expect(try PixelBuffer.read(retained) != PixelBuffer.read(image))
    }

    @Test("The saved version overrides current defaults and matches an independent fold", arguments: [1, 2])
    func stackParity(version: Int) throws {
        let renderer = SkinRenderer(), image = try fixture()
        var second = params(texture: 0.7)
        second.strength = 0.35
        var doc = document([params(), second], version: version)
        var disabled = RetouchOp(kind: .tone(ToneParams()))
        disabled.isEnabled = false
        doc.ops.insert(disabled, at: 1)
        doc.ops.append(RetouchOp(kind: .unsupported(UnsupportedOp(kind: "future", payload: .null))))
        let decoded = try JSONDecoder().decode(PortraitDocument.self, from: JSONEncoder().encode(doc))
        var folded = image
        for op in decoded.renderOrder {
            folded = try renderer.renderStep(op.kind, input: folded, context: context(version: version))
        }
        let stack = try renderer.renderStack(decoded, input: image, context: context(version: 3 - version))
        #expect(renderer.tolerance == 0)
        #expect(try PixelBuffer.read(stack) == PixelBuffer.read(folded))
        #expect(try PixelBuffer.read(stack) == PixelBuffer.read(renderer.renderStack(decoded, input: image, context: context())))
    }

    @Test("Two process versions differ, and legacy documents keep version 1")
    func versionSemantics() throws {
        let renderer = SkinRenderer(), image = try fixture()
        let old = try renderer.renderStack(document([params()], version: 1), input: image, context: context())
        let new = try renderer.renderStack(document([params()], version: 2), input: image, context: context())
        #expect(try PixelBuffer.read(old) != PixelBuffer.read(new))
        let encoded = try JSONEncoder().encode(document([params()]))
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "processVersion")
        let legacy = try JSONDecoder().decode(PortraitDocument.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.processVersion == 1)
        #expect(try PixelBuffer.read(old) == PixelBuffer.read(renderer.renderStack(legacy, input: image, context: context())))
        #expect(throws: SkinRenderError.unsupportedProcessVersion(3)) {
            try renderer.renderStack(document([], version: 3), input: image, context: context())
        }
    }

    @Test("Zero strength and missing analysis preserve the input")
    func identity() throws {
        let renderer = SkinRenderer(), image = try fixture()
        var p = params()
        p.strength = 0
        #expect(try renderer.renderStep(.skin(p), input: image, context: context()) === image)
        #expect(try renderer.renderStep(.skin(SkinParams()), input: image, context: context()) === image)
        #expect(try renderer.renderStack(document([]), input: image, context: context()) === image)
    }

    @Test("Mask boundaries protect pixels and exclude surrounding colors from smoothing")
    func masking() throws {
        let image = try fixture(), original = try PixelBuffer.read(image)
        var maskBytes = [UInt8](repeating: 255, count: original.count)
        var changedOutside = original
        for y in 0..<height {
            for x in 0..<width where x >= width / 2 || y < height / 4 {
                let i = (y * width + x) * 4
                for c in 0..<3 {
                    maskBytes[i + c] = 0
                    changedOutside[i + c] = c == 0 ? 250 : 5
                }
            }
        }
        let mask = try PixelBuffer.image(maskBytes, width: width, height: height)
        var p = params()
        p.protectNonSkin = true
        let renderer = SkinRenderer()
        let a = try PixelBuffer.read(renderer.renderStep(.skin(p), input: image, context: context(mask: mask)))
        let b = try PixelBuffer.read(renderer.renderStep(.skin(p), input: PixelBuffer.image(changedOutside, width: width, height: height), context: context(mask: mask)))
        var edited = false
        for i in stride(from: 0, to: a.count, by: 4) {
            if maskBytes[i] == 0 {
                #expect(Array(a[i..<i + 4]) == Array(original[i..<i + 4]))
            } else {
                #expect(Array(a[i..<i + 4]) == Array(b[i..<i + 4]))
                edited = edited || a[i] != original[i]
            }
        }
        #expect(edited)
    }

    @Test("Alpha is preserved, transparent pixels do not acquire color, and constants stay constant")
    func alphaAndConstants() throws {
        var bytes = [UInt8](repeating: 0, count: 13 * 9 * 4)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = UInt8((i / 4) % 3 == 0 ? 0 : 128)
            bytes[i] = alpha / 2
            bytes[i + 1] = alpha / 4
            bytes[i + 2] = alpha / 8
            bytes[i + 3] = alpha
        }
        let image = try PixelBuffer.image(bytes, width: 13, height: 9)
        let output = try SkinRenderer().renderStep(.skin(params()), input: image, context: context())
        #expect(try PixelBuffer.read(output) == bytes)
    }

    @Test("Unsupported features and invalid inputs fail rather than producing a misleading image")
    func failures() throws {
        let renderer = SkinRenderer(), image = try fixture()
        #expect(throws: SkinRenderError.unsupportedOperation) {
            try renderer.renderStep(.tone(ToneParams()), input: image, context: context())
        }
        var p = params()
        p.blemishStrength = 0.5
        #expect(throws: SkinRenderError.unsupportedBlemishStrength) {
            try renderer.renderStep(.skin(p), input: image, context: context())
        }
        p = params()
        p.radius = .nan
        #expect(throws: RetouchError.self) { try renderer.renderStep(.skin(p), input: image, context: context()) }
        #expect(throws: SkinRenderError.imageTooLarge) {
            try SkinRenderer(maximumPixels: 10).renderStep(.skin(params()), input: image, context: context())
        }
        let face = FaceAnalysis(index: 0, boundingBox: NormalizedRect(x: 0, y: 0, width: 1, height: 1), detectorVersion: "test")
        #expect(throws: SkinRenderError.missingSkinMask) {
            try renderer.renderStep(.skin(SkinParams()), input: image,
                context: RenderContext(scale: .full, assets: [:], faces: [face]))
        }
        let tiny = try PixelBuffer.image([255, 255, 255, 255], width: 1, height: 1)
        #expect(throws: SkinRenderError.invalidMaskSize) {
            try renderer.renderStep(.skin(params()), input: image, context: context(mask: tiny))
        }
    }

    @Test("Preview radius uses original dimensions and validates geometry")
    func preview() throws {
        let image = try fixture(), renderer = SkinRenderer()
        let preview = RenderContext(scale: .preview(maxDimension: width), assets: [:], faces: [],
                                    sourcePixelSize: SIMD2(width * 2, height * 2))
        var fullParams = params()
        fullParams.radius = 8
        let a = try renderer.renderStep(.skin(fullParams), input: image, context: preview)
        let b = try renderer.renderStep(.skin(params()), input: image, context: context())
        #expect(try PixelBuffer.read(a) == PixelBuffer.read(b))
        #expect(throws: SkinRenderError.invalidPreviewGeometry) {
            try renderer.renderStep(.skin(params()), input: image,
                context: RenderContext(scale: .preview(maxDimension: width), assets: [:], faces: []))
        }
    }

    @Test("Mask expansion changes the editable boundary without changing the parameter format")
    func maskExpansion() throws {
        let image = try fixture(), original = try PixelBuffer.read(image)
        var maskBytes = [UInt8](repeating: 255, count: original.count)
        for y in 0..<height {
            for x in width / 2..<width {
                for c in 0..<3 { maskBytes[(y * width + x) * 4 + c] = 0 }
            }
        }
        let mask = try PixelBuffer.image(maskBytes, width: width, height: height)
        var p = params(texture: 0.1)
        p.protectNonSkin = true
        p.maskExpansion = 1
        let grown = try PixelBuffer.read(SkinRenderer().renderStep(.skin(p), input: image, context: context(mask: mask)))
        p.maskExpansion = -1
        let shrunk = try PixelBuffer.read(SkinRenderer().renderStep(.skin(p), input: image, context: context(mask: mask)))
        let outside = (height / 2 * width + width / 2 + 1) * 4
        let inside = (height / 2 * width + width / 2 - 2) * 4
        #expect(grown[outside] != original[outside])
        #expect(shrunk[inside] == original[inside])
        #expect(shrunk[outside] == original[outside])
    }
}
