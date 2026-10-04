# Interface translations

The app ships English (source) and Simplified Chinese. Strings live in
`Compositor/Localizable.xcstrings`, which Xcode and `xcstringstool` both understand.

## Why scripts and not just the catalog

Most of the interface needs no Swift changes at all: SwiftUI resolves
`Text("Import Images…")` by looking up that literal, so translating is purely a matter of
adding an entry keyed by the English text. At ~800 strings, editing the catalog by hand is
the slow and error-prone part, so the English→Chinese pairs are kept as plain Python data
and the catalog is generated.

The one class of string that *does* need code is anything where the value shown and the
value saved are the same string — blend modes, adjustment kinds, sampling. See
`Compositor/Document/LocalizedDisplay.swift`: `rawValue` is the file format and never
changes; `displayName` is what people read.

## The one thing to understand before editing the catalog

**Xcode owns the catalog's key set, and it deletes what it did not put there.**

Every build runs a sync that removes any entry it cannot find in the source. An entry added
by hand is therefore gone by the next build — and worse, if the key *is* real but was
written by hand, the rebuild recreates it **without its translation**, so the work is lost
silently.

Two consequences:

- Never add a key to `Localizable.xcstrings` by hand. Make the source literal extractable
  and let Xcode find it.
- `build_catalog.py` only *fills in* values. It never invents keys, and it reports any
  translation it could not place.

The extractable forms are a **literal**:

```swift
Text("Import Images…")                       // SwiftUI looks the literal up
String(localized: "Crop (C)")                // extracted
NSLocalizedString("Add Mask", comment: "")   // extracted
```

and *not* a computed string or a variable key:

```swift
NSLocalizedString(someVariable, comment: "") // invisible to extraction
var label: String { "Crop (C)" }             // a String, not a key
```

That is why `NavigationTool.label` is a `switch` over literal `String(localized:)` calls
rather than a table of Strings, and why the same three literals are repeated in
`LocalizedDisplay.swift`'s doc comment as the reason `displayName` exists.

## Pipeline

```sh
# 1. Add newly extracted keys to the catalog (a plain build prunes but never adds)
xcodebuild -exportLocalizations -project Compositor.xcodeproj \
  -localizationPath /tmp/xcloc -exportLanguage zh-Hans

# 2. Fill in the translations
python3 scripts/i18n/build_catalog.py

# 3. Build and check
python3 scripts/i18n/missing.py
```

`build_catalog.py` merges `glossary.py` over `prose*.py` over `translations.py`; on a
conflict the glossary wins, because those are the reviewed domain terms.

`missing.py` lists enum values the interface shows that have no translation — the same
check `DisplayNameTests` makes, but faster to read.

## Do not translate these

`xcrun xcstringstool extract --all-potential-swift-keys` over-collects on purpose. Among
what it returns are **PSD four-character codes from the Photoshop binary format**:
`"Layr"`, `"Mtrn"`, `"Btrn"`, `"Rght"`, `"Btom"`, `"Rd  "`, `"Grn "`, `"Bl  "`, `"Txt "`,
`"Clss"`, `"Idnt"`, `"Ornt"`. Translating one makes PSD import fail in a way that looks
like a corrupt file.

UTIs (`com.compositor.project`), `sRGB`, and the enum raw values in
`LocalizedDisplay.swift` are the same category: they are identifiers, not copy.

## Terminology

`glossary.py` is the reference. Blend modes, adjustments and filters follow Adobe's
official Simplified Chinese for Photoshop, because that is the vocabulary a retoucher
already has. Where Photoshop has no equivalent, the term is chosen for what it does rather
than for the shape of the English.

Use it for the prose too: "blend mode" is 混合模式 everywhere, never 混合方式.

## What is enforced

`CompositorTests/LocalizationTests.swift` fails the build when:

- a wire value changes (that silently orphans saved projects), or
- a displayed enum value has no translation, or
- a translation is accidentally left in English.

Add a case to a displayed enum and the test names it.
