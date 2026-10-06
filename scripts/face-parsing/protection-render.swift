import Foundation
import CoreGraphics
import PortraitCore
import RetouchKit
import PortraitMCP

// A diagnostic harness calls the existing versioned renderer, never a Python smoothing substitute.
let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let source = try PhotoIO.loadFullResolution(folder.appendingPathComponent("source.png"))
let masks = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasSuffix("-mask.png") }
for maskURL in masks {
    let mask = try PhotoIO.loadFullResolution(maskURL)
    for (title, strength, texture) in [("standard", 0.65, 0.30), ("stress", 0.85, 0.15)] {
        var params = SkinParams(); params.strength = strength; params.texturePreservation = texture
        let context = RenderContext(scale: .full, assets: [:], faces: [], quality: .best, processVersion: 2, sourcePixelSize: SIMD2(source.width, source.height), skinMask: mask)
        let image = try SkinRenderer().renderStep(.skin(params), input: source, context: context)
        let name = maskURL.lastPathComponent.replacingOccurrences(of: "-mask.png", with: "-\(title).png")
        try PhotoIO.encode(image).write(to: folder.appendingPathComponent(name), options: .withoutOverwriting)
    }
}
print("Rendered \(masks.count) masks at two strengths using SkinRenderer v2.")
