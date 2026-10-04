import Foundation
import Testing
@testable import Compositor

// =====================================================================================
// The safety net for localizing a format.
//
// Several enums serve twice: their `rawValue` is written into the `.comp` manifest, and
// the same string used to be what the interface showed. Localizing by translating the
// raw value is the obvious move and it is catastrophic — `LayerBlendMode(rawValue: "正常")`
// returns nil, `ProjectStore.validate` rejects the whole package, and the live-reload path
// swallows that rejection silently, so the person just sees the canvas stop updating.
//
// `LocalizedDisplay.swift` splits the two: rawValue frozen, displayName localized. These
// tests keep it that way. They are expected to fail loudly and be *read* when they do —
// a raw value is not an implementation detail to be updated when convenient, it is other
// people's saved files.
// =====================================================================================

@Suite("Wire values are frozen")
struct WireValueTests {

    /// Exact spellings from `docs/project-format.md` and `docs/writing-comp-files.md`.
    /// If one of these changes, every project saved before the change stops loading —
    /// so update the docs, add a format version bump, and provide a migration.
    @Test("Blend mode raw values match the documented format")
    func blendModeRawValues() {
        #expect(LayerBlendMode.allCases.map(\.rawValue) == [
            "Normal", "Darken", "Multiply", "Color Burn", "Linear Burn",
            "Lighten", "Screen", "Color Dodge", "Linear Dodge (Add)",
            "Overlay", "Soft Light", "Hard Light", "Vivid Light", "Linear Light",
            "Pin Light", "Hard Mix", "Difference", "Exclusion", "Subtract", "Divide",
            "Hue", "Saturation", "Color", "Luminosity",
        ])
    }

    @Test("Adjustment kind raw values match the documented format")
    func adjustmentKindRawValues() {
        #expect(AdjustmentKind.allCases.map(\.rawValue) == [
            "Hue/Saturation", "Levels", "Curves", "Exposure", "Gradient Map", "Grain",
            "Add Noise", "Gaussian Blur", "Motion Blur", "Invert", "Black & White", "Color Balance",
        ])
    }

    /// `transform.sampling` in the manifest.
    @Test("Layer sampling raw values match the documented format")
    func layerSamplingRawValues() {
        #expect(LayerSampling.allCases.map(\.rawValue) == ["Nearest", "Smooth", "High quality"])
    }

    /// `shape.kind` in the manifest.
    @Test("Shape kind raw values match the documented format")
    func shapeKindRawValues() {
        #expect(ShapeKind.allCases.map(\.rawValue) == ["Rectangle", "Ellipse", "Line"])
    }

    /// `text.alignment` in the manifest. Easy to miss: it is not a blend mode and not an
    /// adjustment, but it is written and read exactly the same way.
    @Test("Text alignment raw values match the documented format")
    func textAlignmentRawValues() {
        #expect(TextAlignment.allCases.map(\.rawValue) == ["Left", "Center", "Right"])
    }

    /// The regression this whole file exists for: a display name must never become the
    /// value that goes to disk. Round-tripping through the wire format is the check —
    /// it fails the moment the two are conflated.
    @Test("A blend mode survives a round trip through the manifest")
    func blendModeRoundTrips() throws {
        for mode in LayerBlendMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let back = try JSONDecoder().decode(LayerBlendMode.self, from: data)
            #expect(back == mode)
            // And the encoded form is the raw value, never the shown one.
            #expect(String(decoding: data, as: UTF8.self) == "\"\(mode.rawValue)\"")
        }
    }

    @Test("An adjustment kind survives a round trip through the manifest")
    func adjustmentKindRoundTrips() throws {
        for kind in AdjustmentKind.allCases {
            let data = try JSONEncoder().encode(kind)
            #expect(try JSONDecoder().decode(AdjustmentKind.self, from: data) == kind)
        }
    }
}

@Suite("Display names are localized")
struct DisplayNameTests {

    /// Every value of every enum the interface shows must have a zh-Hans entry. Adding a
    /// case without translating it makes this fail, which is the point: a half-translated
    /// menu is a bug report waiting to happen, and it is invisible to an English reader.
    ///
    /// The list is explicit on purpose. There is no way to enumerate "every String-raw
    /// enum" at runtime, so this is the inventory — and updating it is the reminder that a
    /// newly displayed enum needs translating.
    @Test("Every displayed enum value has a translation")
    func everyDisplayedValueIsTranslated() throws {
        let catalog = try Self.catalog()
        var missing: [String] = []

        func check(_ values: [String]) {
            for value in values where catalog[value] == nil { missing.append(value) }
        }

        check(LayerBlendMode.allCases.map(\.rawValue))
        check(AdjustmentKind.allCases.map(\.rawValue))
        check(FilterKind.allCases.map(\.rawValue))
        check(LayerSampling.allCases.map(\.rawValue))
        check(ShapeKind.allCases.map(\.rawValue))
        check(TextAlignment.allCases.map(\.rawValue))
        check(LayerEffectKind.allCases.map(\.rawValue))
        check(GradientShape.allCases.map(\.rawValue))
        check(GradientStyle.allCases.map(\.rawValue))
        check(LassoKind.allCases.map(\.rawValue))
        check(SelectionMode.allCases.map(\.rawValue))
        check(WandMode.allCases.map(\.rawValue))
        check(BrushToolMode.allCases.map(\.rawValue))
        check(BlurToolMode.allCases.map(\.rawValue))
        check(SpotHealingMode.allCases.map(\.rawValue))
        check(CanvasUnit.allCases.map(\.rawValue))
        check(LevelsChannel.allCases.map(\.rawValue))
        check(ColorRange.allCases.map(\.rawValue))
        check(DitherStyle.allCases.map(\.rawValue))
        check(DitherColors.allCases.map(\.rawValue))
        check(DitherPixelShape.allCases.map(\.rawValue))
        check(GridAppearance.Preset.allCases.map(\.rawValue))
        check(GridAppearance.Style.allCases.map(\.rawValue))
        check(CameraRawWhiteBalance.allCases.map(\.rawValue))
        check(CameraRawCurvePage.allCases.map(\.rawValue))
        check(CameraRawGlowStyle.allCases.map(\.rawValue))
        check(CameraRawVignetteStyle.allCases.map(\.rawValue))
        check(CameraRawUprightMode.allCases.map(\.rawValue))
        check(CameraRawProjection.allCases.map(\.rawValue))
        check(CameraRawProcessVersion.allCases.map(\.rawValue))
        check(CameraRawMixerPage.allCases.map(\.rawValue))
        check(CameraRawMixerTab.allCases.map(\.rawValue))
        check(CameraRawGradePage.allCases.map(\.rawValue))
        check(CameraRawPointChannel.allCases.map(\.rawValue))

        #expect(missing.isEmpty, """
            \(missing.count) enum value(s) the interface shows have no zh-Hans translation:
            \(missing.sorted().joined(separator: "\n"))
            Add them to scripts/i18n/glossary.py and regenerate Localizable.xcstrings.
            """)
    }

    /// A translation that is byte-identical to the English is almost always an oversight
    /// rather than a deliberate choice — the handful that genuinely should not differ are
    /// listed here so the exception stays visible.
    @Test("No translation is accidentally left in English")
    func noUntranslatedLeftovers() throws {
        let catalog = try Self.catalog()
        // Symbols, units, format strings and proper nouns. Translating any of these would
        // be wrong: `%lld` must stay a format specifier, and `RGB` is `RGB`.
        let intentionallyIdentical: Set<String> = [
            "#", "%", "100%", "px",
            "%lld", "%lld%%", "%lld × %lld px", "%lld°  %lld", "%@ × %@ px · sRGB",
            "ASCII", "RGB", "HSL", "Floyd–Steinberg", "Compositor",
        ]
        var suspicious: [String] = []
        for (key, value) in catalog where key == value && !intentionallyIdentical.contains(key) {
            suspicious.append(key)
        }
        #expect(suspicious.isEmpty, """
            These entries read the same in zh-Hans as in English:
            \(suspicious.sorted().joined(separator: "\n"))
            Translate them, or add them to `intentionallyIdentical` with a reason.
            """)
    }

    /// Reads `Localizable.xcstrings` straight from the source tree, so a stale build
    /// product can never make this pass.
    private static func catalog() throws -> [String: String] {
        let root = URL(fileURLWithPath: #filePath)      // CompositorTests/LocalizationTests.swift
            .deletingLastPathComponent()                 // CompositorTests/
            .deletingLastPathComponent()                 // repository root
        let url = root.appendingPathComponent("Compositor/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var out: [String: String] = [:]
        for (key, entry) in strings {
            guard let entry = entry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let zh = localizations["zh-Hans"] as? [String: Any],
                  let unit = zh["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String else { continue }
            out[key] = value
        }
        return out
    }
}
