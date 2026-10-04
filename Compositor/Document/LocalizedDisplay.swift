import Foundation

// =====================================================================================
// Wire values vs. display names
// =====================================================================================
//
// Several enums here serve two masters. `LayerBlendMode.normal` is `"Normal"` — in the
// `.comp` manifest *and* in the blend mode menu. Same for `AdjustmentKind` ("Levels"),
// `LayerSampling` ("High quality") and the shape kinds.
//
// That is a trap, because the obvious way to localize a menu is to translate the string
// you are already showing. Doing that would change what Compositor reads and writes:
//
//   • A project saved before the change stops loading. `LayerBlendMode(rawValue: "正常")`
//     returns nil, so `ProjectStore.validate` rejects the entire package.
//   • In the live-reload path that rejection is silent by design (see
//     `ProjectController+ExternalChanges`), so the person just sees the canvas stop
//     updating — the worst possible failure mode.
//   • `docs/writing-comp-files.md` documents these exact spellings as the format, so
//     agents and scripts writing projects would break too.
//
// So the two are kept apart, permanently:
//
//   rawValue      frozen. It *is* the file format. Never translate it, never rename it.
//   displayName   what the interface shows. Localized via `Localizable.xcstrings`.
//
// `WireValueTests` pins every rawValue that reaches the manifest, so an accidental rename
// fails a test instead of silently orphaning someone's saved work.
//
// The extension is deliberately broad — every `String`-raw enum gets a `displayName` —
// because the rule is "show `displayName`, never `rawValue`", and a rule with exceptions
// is a rule that gets broken. Enums whose raw value is only an internal identifier
// (`NavigationTool.rawValue == "brush"`) simply never have it read.

extension RawRepresentable where RawValue == String {
    /// The string to show for this value, localized. `rawValue` stays the wire value.
    ///
    /// Because the key is a variable, `xcstringstool extract` cannot find these entries;
    /// they are maintained by hand in the catalog.
    nonisolated var displayName: String {
        NSLocalizedString(rawValue, comment: "Display name for \(Self.self)")
    }
}
