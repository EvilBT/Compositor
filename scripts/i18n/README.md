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

## Regenerating

```sh
python3 scripts/i18n/build_catalog.py     # writes Compositor/Localizable.xcstrings
python3 scripts/i18n/missing.py           # lists displayed enum values with no translation
```

`build_catalog.py` merges `glossary.py` over `translations.py`; on a conflict the glossary
wins, because those are the reviewed domain terms.

## Finding strings still to translate

```sh
# Everything SwiftUI could localize, as potential keys
xcrun xcstringstool extract --all-potential-swift-keys \
  $(find Compositor -name '*.swift') -o /tmp/keys
```

`--all-potential-swift-keys` over-collects on purpose — it also returns PSD four-character
codes, UTIs and internal identifiers. **Do not translate those.** `"Layr"`, `"Btrn"`,
`"Rght"` and friends are binary format keys from the Photoshop spec; translating one breaks
PSD import in a way that looks like a corrupt file.

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
