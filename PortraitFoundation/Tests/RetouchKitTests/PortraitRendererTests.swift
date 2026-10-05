import CoreGraphics
import Foundation
import Testing
import PortraitCore
@testable import RetouchKit

@Suite("Develop and skin pipeline")
struct PortraitRendererTests {
    private func image() throws -> CGImage {
        var bytes = [UInt8](repeating: 255, count: 24 * 16 * 4)
        for y in 0..<16 {
            for x in 0..<24 {
                let i = (y * 24 + x) * 4
                bytes[i] = UInt8(60 + x * 5); bytes[i + 1] = UInt8(50 + y * 5); bytes[i + 2] = 70
            }
        }
        return try PixelBuffer.image(bytes, width: 24, height: 16)
    }

    @Test("Neutral develop parameters preserve the input object")
    func neutral() throws {
        let image = try image(), renderer = PortraitRenderer()
        for kind in [RetouchOpKind.tone(ToneParams()), .presence(PresenceParams()),
                     .whiteBalance(WhiteBalanceParams()), .toneCurve(CurveParams())] {
            #expect(try renderer.renderStep(kind, input: image, context: RenderContext(scale: .full, assets: [:], faces: [])) === image)
        }
    }

    @Test("Develop plus skin round-trips and matches an independent fold", arguments: [1, 2])
    func parity(version: Int) throws {
        let image = try image(), renderer = PortraitRenderer()
        var tone = ToneParams(); tone.exposure = 0.2; tone.shadows = 10
        var presence = PresenceParams(); presence.texture = 5; presence.clarity = 5; presence.vibrance = 5
        var balance = WhiteBalanceParams(); balance.temperature = 5
        var curve = CurveParams(); curve.channels[.rgb] = [CurvePoint(x: 0, y: 0), CurvePoint(x: 0.45, y: 0.50), CurvePoint(x: 1, y: 1)]
        var skin = SkinParams(); skin.protectNonSkin = false
        var doc = PortraitDocument(photo: PhotoReference(source: .file(relativePath: "fixture.png"), pixelSize: SIMD2(24, 16)),
            ops: [.init(kind: .skin(skin)), .init(kind: .toneCurve(curve)), .init(kind: .tone(tone)),
                  .init(kind: .presence(presence)), .init(kind: .whiteBalance(balance))])
        doc.processVersion = version
        doc = try JSONDecoder().decode(PortraitDocument.self, from: JSONEncoder().encode(doc))
        let context = RenderContext(scale: .full, assets: [:], faces: [], processVersion: version)
        var fold = image
        for op in doc.renderOrder { fold = try renderer.renderStep(op.kind, input: fold, context: context) }
        #expect(try PixelBuffer.read(fold) == PixelBuffer.read(renderer.renderStack(doc, input: image, context: context)))
        #expect(try PixelBuffer.read(fold) != PixelBuffer.read(image))
    }

    @Test("Exposure increases linear light and leaves alpha intact")
    func exposure() throws {
        let image = try PixelBuffer.image([80, 80, 80, 255, 40, 40, 40, 128, 0, 0, 0, 0], width: 3, height: 1)
        var params = ToneParams(); params.exposure = 1
        let output = try PortraitRenderer().renderStep(.tone(params), input: image, context: RenderContext(scale: .full, assets: [:], faces: []))
        let bytes = try PixelBuffer.read(output)
        #expect(bytes[0] > 100 && bytes[0] < 120)
        #expect(bytes[3] == 255 && bytes[7] == 128 && bytes[11] == 0)
        #expect(bytes[8] == 0)
    }

    @Test("Curves remain inside each segment and reject ambiguous control points")
    func curves() throws {
        let curve = try MonotoneCurve([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.1, y: 0.8),
                                       CurvePoint(x: 0.8, y: 0.8), CurvePoint(x: 1, y: 1)])
        var previous = 0.0
        for step in 0...1000 {
            let value = curve.value(Double(step) / 1000)
            #expect(value >= previous - 0.000001)
            #expect((0...1).contains(value))
            previous = value
        }
        #expect(curve.value(0.5) == 0.8)
        #expect(throws: PortraitRenderError.invalidCurve) {
            try MonotoneCurve([CurvePoint(x: 0, y: 0), CurvePoint(x: 0, y: 1)])
        }
    }

    @Test("Invalid presence and unsupported curve features are explicit failures")
    func invalid() throws {
        var presence = PresenceParams(); presence.texture = .nan
        let context = RenderContext(scale: .full, assets: [:], faces: [])
        #expect(throws: PortraitRenderError.self) {
            try PortraitRenderer().renderStep(.presence(presence), input: image(), context: context)
        }
        var curve = CurveParams(); curve.parametric = ParametricCurve()
        #expect(throws: PortraitRenderError.unsupportedCurveOption) {
            try PortraitRenderer().renderStep(.toneCurve(curve), input: image(), context: context)
        }
    }
}
