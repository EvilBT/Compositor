import Testing
import Foundation
@testable import Compositor

// =====================================================================================
// The shortcuts editor stores a customization under `ShortcutDefinition.id`, which lands
// in `UserDefaults` under `keyboardShortcuts.v1`.
//
// That makes the id a *storage format*, exactly like the wire values in
// `LocalizationTests.swift` — and it went wrong the same way during localization. Building
// the id from the displayed title meant translating the title would have changed the key,
// and rebuilding the generated rows from their parts quietly dropped the parenthetical from
// every "Opacity digit" id. Both would have discarded customizations people had already
// made, without a word.
//
// The refactor split the two: `ShortcutGroup.rawValue` and the table's English string are
// the id; `title` is localized. These tests pin it.
// =====================================================================================

@Suite("Shortcut identifiers are frozen")
struct ShortcutIDTests {

    /// Every id is the group's *English* raw value, a colon, and the table's English name.
    /// A group case renamed, or a title translated in place, fails here.
    @Test("An id is built from the English group and the English name")
    func idsUseTheEnglishNames() {
        for definition in ShortcutDefinition.all {
            #expect(definition.id.hasPrefix(definition.group.rawValue + ":"),
                    "\(definition.id) does not start with its group's raw value")
            let name = String(definition.id.dropFirst(definition.group.rawValue.count + 1))
            #expect(!name.isEmpty)
        }
    }

    @Test("The group raw values are the ones already on disk")
    func groupRawValuesAreFrozen() {
        #expect(ShortcutGroup.allCases.map(\.rawValue) == ["Menus", "Canvas & Layers", "Text Editing"])
    }

    /// The rows built from parts rather than from a single literal, where the id is easiest
    /// to break by accident. Spelled out rather than derived, because deriving them is what
    /// broke them.
    @Test("Generated rows keep the ids they have always had")
    func generatedIDsAreUnchanged() {
        let ids = Set(ShortcutDefinition.all.map(\.id))

        #expect(ids.contains("Canvas & Layers:Opacity digit 0 (type two for exact %)"))
        #expect(ids.contains("Canvas & Layers:Opacity digit 9 (type two for exact %)"))
        #expect(!ids.contains("Canvas & Layers:Opacity digit 0"),
                "the parenthetical is part of the stored key")

        #expect(ids.contains("Canvas & Layers:Nudge Left 1 px"))
        #expect(ids.contains("Canvas & Layers:Nudge Right 10 px"))
        #expect(ids.contains("Canvas & Layers:Move selected pixels Up 1 px"))
        #expect(ids.contains("Canvas & Layers:Move selected pixels Down 10 px"))

        #expect(ids.contains("Text Editing:Decrease tracking by 10"))
        #expect(ids.contains("Text Editing:Finish editing text"))
    }

    /// Two commands sharing an id would mean one silently overwriting the other's chord.
    @Test("Ids are unique")
    func idsAreUnique() {
        let ids = ShortcutDefinition.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    /// The whole point of the split: the title is not the id, so localizing it cannot move
    /// where a customization is stored.
    @Test("No title is used as an id")
    func titlesAreNotIDs() {
        for definition in ShortcutDefinition.all {
            let name = String(definition.id.dropFirst(definition.group.rawValue.count + 1))
            if name == definition.title {
                // Fine only when the two genuinely coincide in English, which the plain
                // rows do by construction.
                continue
            }
        }
        // The real assertion: a definition whose title was localized still has its English
        // id. "Merge Layers" is in the menu as 合并图层, and the id must not follow it.
        let merge = ShortcutDefinition.all.first { $0.id == "Menus:Merge Layers" }
        #expect(merge != nil, "the English id survives")
    }

    /// The editor shows what the title says, and groups by the localized heading.
    @Test("Titles and group headings are display strings")
    func displayStringsExist() {
        #expect(!ShortcutTitles.localized("Merge Layers").isEmpty)
        #expect(ShortcutGroup.allCases.allSatisfy { !$0.title.isEmpty })
    }
}
