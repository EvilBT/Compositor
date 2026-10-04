import AppKit
import SwiftUI

struct ShortcutChord: Codable, Equatable, Hashable {
    var key: String
    var modifiers: Int
    init(_ key: String, _ modifiers: Int = 0) { self.key = key; self.modifiers = modifiers }
    // Stable stored bits: Command, Option, Control, Shift.
    init(_ event: NSEvent) {
        let flags = event.modifierFlags
        modifiers = (flags.contains(.command) ? 1 : 0) | (flags.contains(.option) ? 2 : 0)
            | (flags.contains(.control) ? 4 : 0) | (flags.contains(.shift) ? 8 : 0)
        switch event.keyCode {
        case 51, 117: key = "\u{7f}"
        case 36, 76: key = "\r"
        case 53: key = "\u{1b}"
        case 48: key = "\t"
        case 49: key = " "
        case 123: key = "\u{f702}"
        case 124: key = "\u{f703}"
        case 125: key = "\u{f701}"
        case 126: key = "\u{f700}"
        default:
            let typed = event.charactersIgnoringModifiers?.lowercased() ?? ""
            key = ["{": "[", "}": "]", "+": "=", "_": "-" ][typed] ?? typed
        }
    }
    var eventModifiers: EventModifiers {
        var flags: EventModifiers = []
        if modifiers & 1 != 0 { flags.insert(.command) }
        if modifiers & 2 != 0 { flags.insert(.option) }
        if modifiers & 4 != 0 { flags.insert(.control) }
        if modifiers & 8 != 0 { flags.insert(.shift) }
        return flags
    }
    var cocoaModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & 1 != 0 { flags.insert(.command) }
        if modifiers & 2 != 0 { flags.insert(.option) }
        if modifiers & 4 != 0 { flags.insert(.control) }
        if modifiers & 8 != 0 { flags.insert(.shift) }
        return flags
    }
    var label: String {
        let special = ["\u{7f}": "Delete", "\r": "Return", "\u{1b}": "Esc", "\t": "Tab", " ": "Space",
                       "\u{f702}": "←", "\u{f703}": "→", "\u{f701}": "↓", "\u{f700}": "↑"]
        return (modifiers & 4 != 0 ? "⌃" : "") + (modifiers & 2 != 0 ? "⌥" : "")
            + (modifiers & 8 != 0 ? "⇧" : "") + (modifiers & 1 != 0 ? "⌘" : "")
            + (special[key] ?? key.uppercased())
    }
    func event(like event: NSEvent) -> NSEvent? {
        let codes: [String: UInt16] = ["\u{7f}": 51, "\r": 36, "\u{1b}": 53, "\t": 48, " ": 49,
                                       "\u{f702}": 123, "\u{f703}": 124, "\u{f701}": 125, "\u{f700}": 126,
                                       "=": 24, "-": 27]
        let shifted = modifiers & 8 != 0 ? (["[": "{", "]": "}", "=": "+", "-": "_"][key] ?? key) : key
        return NSEvent.keyEvent(with: event.type, location: event.locationInWindow, modifierFlags: cocoaModifiers,
            timestamp: event.timestamp, windowNumber: event.windowNumber, context: nil,
            characters: shifted, charactersIgnoringModifiers: shifted, isARepeat: event.isARepeat,
            keyCode: codes[key] ?? 0xffff)
    }
}

/// Which section of the shortcuts editor a command appears under.
///
/// The `rawValue` is part of every definition's `id`, which is the key a customized
/// shortcut is stored under in `UserDefaults`. Renaming a case would orphan every
/// customization already made, so the raw values stay the English they have always been
/// and `title` carries the localized one. The same split as `LocalizedDisplay.swift`.
enum ShortcutGroup: String, CaseIterable, Identifiable {
    case menus = "Menus"
    case canvas = "Canvas & Layers"
    case text = "Text Editing"

    var id: Self { self }

    var title: String {
        switch self {
        case .menus:  String(localized: "Menus")
        case .canvas: String(localized: "Canvas & Layers")
        case .text:   String(localized: "Text Editing")
        }
    }
}

/// Localized names for the shortcut table.
///
/// The table keeps English strings because they are also the stable half of each `id`. The
/// literals have to appear somewhere for Xcode to extract them — `NSLocalizedString` on a
/// variable is invisible to extraction, and a catalog entry written by hand is deleted by
/// the next build — so this is that somewhere.
enum ShortcutTitles {
    static func localized(_ english: String) -> String {
        switch english {
        case "Actual Pixels": String(localized: "Actual Pixels")
        case "Apply current canvas operation": String(localized: "Apply current canvas operation")
        case "Blur / Smudge / Liquify": String(localized: "Blur / Smudge / Liquify")
        case "Brush tool": String(localized: "Brush tool")
        case "Cancel current canvas operation": String(localized: "Cancel current canvas operation")
        case "Canvas Size": String(localized: "Canvas Size")
        case "Clone Stamp": String(localized: "Clone Stamp")
        case "Close Project": String(localized: "Close Project")
        case "Content-Aware Fill": String(localized: "Content-Aware Fill")
        case "Copy": String(localized: "Copy")
        case "Copy Merged": String(localized: "Copy Merged")
        case "Crop tool": String(localized: "Crop tool")
        case "Curves": String(localized: "Curves")
        case "Cut": String(localized: "Cut")
        case "Cycle shape kind": String(localized: "Cycle shape kind")
        case "Cycle tool mode": String(localized: "Cycle tool mode")
        case "Decrease brush hardness": String(localized: "Decrease brush hardness")
        case "Decrease brush size": String(localized: "Decrease brush size")
        case "Decrease leading": String(localized: "Decrease leading")
        case "Decrease tracking": String(localized: "Decrease tracking")
        case "Delete selection / layer / effect / lasso point": String(localized: "Delete selection / layer / effect / lasso point")
        case "Deselect": String(localized: "Deselect")
        case "Down": String(localized: "Down")
        case "Duplicate / Layer via Copy": String(localized: "Duplicate / Layer via Copy")
        case "Eraser": String(localized: "Eraser")
        case "Export JPEG": String(localized: "Export JPEG")
        case "Export PNG": String(localized: "Export PNG")
        case "Eyedropper tool": String(localized: "Eyedropper tool")
        case "Fill with Background": String(localized: "Fill with Background")
        case "Fill with Foreground": String(localized: "Fill with Foreground")
        case "Finish editing text": String(localized: "Finish editing text")
        case "Fit Canvas": String(localized: "Fit Canvas")
        case "Gradient tool": String(localized: "Gradient tool")
        case "Group Layers": String(localized: "Group Layers")
        case "Hand tool": String(localized: "Hand tool")
        case "Hide Compositor": String(localized: "Hide Compositor")
        case "Hue/Saturation": String(localized: "Hue/Saturation")
        case "Image Size": String(localized: "Image Size")
        case "Increase brush hardness": String(localized: "Increase brush hardness")
        case "Increase brush size": String(localized: "Increase brush size")
        case "Increase leading": String(localized: "Increase leading")
        case "Increase tracking": String(localized: "Increase tracking")
        case "Inverse Selection": String(localized: "Inverse Selection")
        case "Invert Pixels / Mask": String(localized: "Invert Pixels / Mask")
        case "Lasso / cycle mode": String(localized: "Lasso / cycle mode")
        case "Left": String(localized: "Left")
        case "Levels": String(localized: "Levels")
        case "Lock Guides": String(localized: "Lock Guides")
        case "Magic": String(localized: "Magic")
        case "Marquee / cycle shape": String(localized: "Marquee / cycle shape")
        case "Merge Layers": String(localized: "Merge Layers")
        case "Move / Transform tool": String(localized: "Move / Transform tool")
        case "Move Layer Down": String(localized: "Move Layer Down")
        case "Move Layer Up": String(localized: "Move Layer Up")
        case "New Blank Layer": String(localized: "New Blank Layer")
        case "New Canvas": String(localized: "New Canvas")
        case "Next blend mode": String(localized: "Next blend mode")
        case "Open Project": String(localized: "Open Project")
        case "Paste": String(localized: "Paste")
        case "Previous blend mode": String(localized: "Previous blend mode")
        case "Redo": String(localized: "Redo")
        case "Reset colors": String(localized: "Reset colors")
        case "Right": String(localized: "Right")
        case "Save": String(localized: "Save")
        case "Save As": String(localized: "Save As")
        case "Select All": String(localized: "Select All")
        case "Select Subject": String(localized: "Select Subject")
        case "Select tool": String(localized: "Select tool")
        case "Shape tool": String(localized: "Shape tool")
        case "Show Grid": String(localized: "Show Grid")
        case "Show Guides": String(localized: "Show Guides")
        case "Show Rulers": String(localized: "Show Rulers")
        case "Show Transform Controls": String(localized: "Show Transform Controls")
        case "Snap": String(localized: "Snap")
        case "Spot Healing": String(localized: "Spot Healing")
        case "Swap foreground/background": String(localized: "Swap foreground/background")
        case "Temporary Hand tool (hold)": String(localized: "Temporary Hand tool (hold)")
        case "Toggle Clipping Mask": String(localized: "Toggle Clipping Mask")
        case "Toggle Levels preview": String(localized: "Toggle Levels preview")
        case "Transform Layer / Selection": String(localized: "Transform Layer / Selection")
        case "Type tool": String(localized: "Type tool")
        case "Undo": String(localized: "Undo")
        case "Ungroup Layers": String(localized: "Ungroup Layers")
        case "Up": String(localized: "Up")
        case "Zoom In": String(localized: "Zoom In")
        case "Zoom Out": String(localized: "Zoom Out")
        case "Zoom tool": String(localized: "Zoom tool")
        default: english
        }
    }

    /// Text-editing commands come in pairs, a normal step and a tenfold one.
    static func byTen(_ english: String) -> String {
        String(format: String(localized: "%@ by 10"), localized(english))
    }

    static func opacityDigit(_ digit: Int) -> String {
        String(format: String(localized: "Opacity digit %lld (type two for exact %%)"), digit)
    }

    static func nudge(_ direction: String, _ pixels: Int, selected: Bool) -> String {
        let dir = localized(direction)
        return selected
            ? String(format: String(localized: "Move selected pixels %@ %lld px"), dir, pixels)
            : String(format: String(localized: "Nudge %@ %lld px"), dir, pixels)
    }
}

struct ShortcutDefinition: Identifiable {
    /// Stable across languages and across releases. It is the dictionary key a saved
    /// override is stored under, so it is a storage format rather than a label — never
    /// translate it, never rename it.
    let id: String
    /// Localized, for display and for the conflict message.
    let title: String
    let group: ShortcutGroup
    let original: ShortcutChord

    var isMenu: Bool { group == .menus }

    static let all: [ShortcutDefinition] = {
        func entry(_ english: String, _ key: String, _ modifiers: Int = 0, menu: Bool = false) -> ShortcutDefinition {
            let group: ShortcutGroup = menu ? .menus : .canvas
            return ShortcutDefinition(id: "\(group.rawValue):\(english)",
                                      title: ShortcutTitles.localized(english),
                                      group: group,
                                      original: ShortcutChord(key, modifiers))
        }
        func textEntry(_ english: String, _ key: String, _ modifiers: Int) -> ShortcutDefinition {
            ShortcutDefinition(id: "\(ShortcutGroup.text.rawValue):\(english)",
                               title: ShortcutTitles.localized(english),
                               group: .text,
                               original: ShortcutChord(key, modifiers))
        }
        var result: [ShortcutDefinition] = [
            entry("Undo", "z", 1, menu: true), entry("Redo", "z", 9, menu: true),
            entry("New Canvas", "n", 1, menu: true), entry("Open Project", "o", 1, menu: true),
            entry("Save", "s", 1, menu: true), entry("Save As", "s", 9, menu: true),
            entry("Export PNG", "e", 9, menu: true), entry("Export JPEG", "s", 11, menu: true),
            entry("Close Project", "w", 1, menu: true), entry("Fit Canvas", "0", 1, menu: true),
            entry("Actual Pixels", "1", 1, menu: true), entry("Zoom In", "=", 1, menu: true),
            entry("Zoom Out", "-", 1, menu: true), entry("Show Transform Controls", "h", 1, menu: true),
            entry("Hide Compositor", "h", 3, menu: true), entry("Cut", "x", 1, menu: true),
            entry("Copy", "c", 1, menu: true), entry("Copy Merged", "c", 9, menu: true),
            entry("Paste", "v", 1, menu: true), entry("Fill with Foreground", "\u{7f}", 2, menu: true),
            entry("Fill with Background", "\u{7f}", 1, menu: true), entry("Content-Aware Fill", "\u{7f}", 8, menu: true),
            entry("Select All", "a", 1, menu: true), entry("Deselect", "d", 1, menu: true),
            entry("Inverse Selection", "i", 9, menu: true), entry("Select Subject", "a", 3, menu: true),
            entry("Curves", "m", 1, menu: true), entry("Levels", "l", 1, menu: true),
            entry("Hue/Saturation", "u", 1, menu: true), entry("Invert Pixels / Mask", "i", 1, menu: true),
            entry("Canvas Size", "c", 3, menu: true), entry("Image Size", "i", 3, menu: true),
            entry("Transform Layer / Selection", "t", 1, menu: true), entry("Duplicate / Layer via Copy", "j", 1, menu: true),
            entry("Toggle Clipping Mask", "g", 3, menu: true), entry("Group Layers", "g", 1, menu: true),
            entry("Ungroup Layers", "g", 9, menu: true),
            entry("New Blank Layer", "n", 9, menu: true), entry("Move Layer Up", "]", 1, menu: true),
            entry("Move Layer Down", "[", 1, menu: true), entry("Merge Layers", "e", 1, menu: true),
            entry("Show Grid", "'", 1, menu: true), entry("Show Guides", ";", 1, menu: true),
            entry("Show Rulers", "r", 1, menu: true), entry("Snap", ";", 9, menu: true),
            entry("Lock Guides", ";", 3, menu: true)
        ]
        for (title, key) in [("Select tool", "a"), ("Move / Transform tool", "v"), ("Hand tool", "h"),
            ("Zoom tool", "z"), ("Brush tool", "b"), ("Eraser", "e"), ("Spot Healing", "j"),
            ("Clone Stamp", "s"), ("Type tool", "t"), ("Gradient tool", "g"), ("Shape tool", "u"),
            ("Eyedropper tool", "i"), ("Marquee / cycle shape", "m"), ("Magic", "w"),
            ("Lasso / cycle mode", "l"), ("Blur / Smudge / Liquify", "r"), ("Crop tool", "c"),
            ("Swap foreground/background", "x"), ("Reset colors", "d"), ("Cycle tool mode", "\t"),
            ("Temporary Hand tool (hold)", " "), ("Delete selection / layer / effect / lasso point", "\u{7f}"),
            ("Apply current canvas operation", "\r"), ("Cancel current canvas operation", "\u{1b}"),
            ("Decrease brush size", "["), ("Increase brush size", "]")] {
            result.append(entry(title, key))
        }
        result += [entry("Decrease brush hardness", "[", 8), entry("Increase brush hardness", "]", 8),
                   entry("Previous blend mode", "-", 8), entry("Next blend mode", "=", 8),
                   entry("Cycle shape kind", "u", 8)]
        for digit in 0...9 {
            result.append(ShortcutDefinition(
                // The id keeps the whole original English title, parentheses and all. It is
                // the dictionary key an existing customization is stored under, so it looks
                // like it wants tidying and must not be touched.
                id: "\(ShortcutGroup.canvas.rawValue):Opacity digit \(digit) (type two for exact %)",

                title: ShortcutTitles.opacityDigit(digit),
                group: .canvas,
                original: ShortcutChord(String(digit))))
        }
        for (direction, key) in [("Left", "\u{f702}"), ("Right", "\u{f703}"), ("Up", "\u{f700}"), ("Down", "\u{f701}")] {
            // Built from one format string each rather than from a String that already has
            // the direction baked in: Xcode can only extract the literal.
            func nudge(_ pixels: Int, _ modifiers: Int, selected: Bool) -> ShortcutDefinition {
                let english = selected ? "Move selected pixels" : "Nudge"
                let group: ShortcutGroup = .canvas
                return ShortcutDefinition(
                    id: "\(group.rawValue):\(english) \(direction) \(pixels) px",
                    title: ShortcutTitles.nudge(direction, pixels, selected: selected),
                    group: group,
                    original: ShortcutChord(key, modifiers))
            }
            result += [nudge(1, 0, selected: false), nudge(10, 8, selected: false),
                       nudge(1, 1, selected: true), nudge(10, 9, selected: true)]
        }
        result.append(textEntry("Finish editing text", "\r", 1))
        for (title, key) in [("Decrease tracking", "\u{f702}"), ("Increase tracking", "\u{f703}"),
                             ("Decrease leading", "\u{f700}"), ("Increase leading", "\u{f701}")] {
            result.append(textEntry(title, key, 2))
            result.append(ShortcutDefinition(id: "\(ShortcutGroup.text.rawValue):\(title) by 10",
                                             title: ShortcutTitles.byTen(title),
                                             group: .text,
                                             original: ShortcutChord(key, 10)))
        }
        result.append(entry("Toggle Levels preview", "p", 2))
        return result
    }()
}

@MainActor @Observable
final class ShortcutSettings {
    static let shared = ShortcutSettings()
    private(set) var overrides: [String: ShortcutChord] = [:]
    @ObservationIgnored private let panel = FloatingPanelController(name: "keyboardShortcuts")
    private static let storageKey = "keyboardShortcuts.v1"
    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([String: ShortcutChord].self, from: data),
           Self.problem(in: saved) == nil { overrides = saved }
    }
    func chord(_ definition: ShortcutDefinition) -> ShortcutChord { overrides[definition.id] ?? definition.original }
    func menu(_ key: KeyEquivalent, modifiers: EventModifiers) -> ShortcutChord {
        let bits = (modifiers.contains(.command) ? 1 : 0) | (modifiers.contains(.option) ? 2 : 0)
            | (modifiers.contains(.control) ? 4 : 0) | (modifiers.contains(.shift) ? 8 : 0)
        let original = ShortcutChord(String(key.character), bits)
        guard let definition = ShortcutDefinition.all.first(where: { $0.isMenu && $0.original == original }) else { return original }
        return chord(definition)
    }
    func native(_ key: KeyEquivalent, modifiers: EventModifiers = []) -> ShortcutChord {
        let bits = (modifiers.contains(.command) ? 1 : 0) | (modifiers.contains(.option) ? 2 : 0)
            | (modifiers.contains(.control) ? 4 : 0) | (modifiers.contains(.shift) ? 8 : 0)
        let original = ShortcutChord(String(key.character), bits)
        guard let definition = ShortcutDefinition.all.first(where: { !$0.isMenu && $0.original == original }) else { return original }
        return chord(definition)
    }
    func show() {
        panel.show(title: "Keyboard Shortcuts", content: KeyboardShortcutsSheet(settings: self))
    }
    func close() { panel.close() }
    func save(_ values: [String: ShortcutChord]) {
        guard Self.problem(in: values) == nil, let data = try? JSONEncoder().encode(values) else { return }
        overrides = values
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        close()
    }
    static func problem(in values: [String: ShortcutChord]) -> String? {
        var assigned: [ShortcutChord: String] = [:]
        for definition in ShortcutDefinition.all {
            let chord = values[definition.id] ?? definition.original
            guard chord.key.count == 1, (0...15).contains(chord.modifiers) else { return "Choose a single key with optional modifiers." }
            if definition.group == .text, chord.modifiers & 7 == 0 {
                return "Text-editing shortcuts need Command, Option, or Control so they do not replace normal typing."
            }
            if [ShortcutChord("q", 1), ShortcutChord(",", 1), ShortcutChord("m", 3)].contains(chord) {
                return "\(chord.label) is reserved by macOS."
            }
            if let other = assigned[chord] { return "\(chord.label) is assigned to both \(other) and \(definition.title)." }
            assigned[chord] = definition.title
        }
        return nil
    }

    /// Translate only at the existing canvas/layer responder boundary. Native text
    /// fields and dialog controls retain their normal typing and navigation behavior.
    func canvasEvent(_ event: NSEvent) -> NSEvent? {
        guard !overrides.isEmpty else { return event }
        let input = ShortcutChord(event)
        if let definition = ShortcutDefinition.all.first(where: { $0.group == .canvas && chord($0) == input }) {
            return definition.original == input ? event : definition.original.event(like: event)
        }
        if ShortcutDefinition.all.contains(where: { $0.group != .text && $0.original == input && chord($0) != input }) { return nil }
        // Letter tool shortcuts traditionally also accept Shift. Follow the base
        // assignment unless Shift has its own explicit command (e.g. cycle shape).
        if input.modifiers == 8 {
            let plain = ShortcutChord(input.key)
            if let definition = ShortcutDefinition.all.first(where: { !$0.isMenu && $0.original.modifiers == 0 && chord($0) == plain }) {
                return ShortcutChord(definition.original.key, 8).event(like: event)
            }
            if ShortcutDefinition.all.contains(where: { !$0.isMenu && $0.original == plain && chord($0) != plain }) { return nil }
        }
        return event
    }

    func textEvent(_ event: NSEvent) -> NSEvent? {
        guard !overrides.isEmpty else { return event }
        let definitions = ShortcutDefinition.all.filter { $0.group == .text || $0.original == ShortcutChord("\u{1b}") }
        let input = ShortcutChord(event)
        if let definition = definitions.first(where: { chord($0) == input }) {
            return definition.original == input ? event : definition.original.event(like: event)
        }
        if definitions.contains(where: { $0.original == input && chord($0) != input }) { return nil }
        return event
    }
}

extension View {
    func configuredNativeShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = []) -> some View {
        let chord = ShortcutSettings.shared.native(key, modifiers: modifiers)
        guard let first = chord.key.first else { return keyboardShortcut(key, modifiers: modifiers) }
        return keyboardShortcut(KeyEquivalent(first), modifiers: chord.eventModifiers)
    }
    func configuredKeyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View {
        let chord = ShortcutSettings.shared.menu(key, modifiers: modifiers)
        guard let first = chord.key.first else { return keyboardShortcut(key, modifiers: modifiers) }
        return keyboardShortcut(KeyEquivalent(first), modifiers: chord.eventModifiers)
    }
}

private struct KeyboardShortcutsSheet: View {
    let settings: ShortcutSettings
    @State private var draft: [String: ShortcutChord]
    @State private var search = ""
    @State private var recording: String?
    init(settings: ShortcutSettings) { self.settings = settings; _draft = State(initialValue: settings.overrides) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Click a shortcut, then press its new key combination. Changes apply when you save.")
                .foregroundStyle(.secondary)
            TextField("Search shortcuts", text: $search).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(ShortcutGroup.allCases) { group in
                        Text(group.title).font(.headline).padding(.top, 8)
                        ForEach(ShortcutDefinition.all.filter { $0.group == group && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) }) { definition in
                            HStack {
                                Text(definition.title)
                                Spacer()
                                ShortcutRecorder(chord: draft[definition.id] ?? definition.original,
                                    recording: recording == definition.id,
                                    start: { recording = definition.id },
                                    finish: { chord in
                                        if let chord { draft[definition.id] = chord }
                                        recording = nil
                                    })
                                    .frame(width: 150, height: 26)
                            }
                        }
                    }
                    Divider().padding(.vertical, 8)
                    Text("Contextual keys & mouse gestures").font(.headline)
                    Text("Text fields keep standard macOS editing keys. Dialogs share the Apply/Cancel assignments above. Numeric fields use Up/Down, with Shift for larger steps. Standard macOS commands include ⌘Q to quit and ⌃⌘F for full screen. The shortcut editor itself always uses Return to save and Esc to cancel when not recording.")
                    Text("Option temporarily selects the eyedropper in painting tools. Shift constrains shapes/movement or adds to a selection; Option subtracts from selections or draws from center. Command-drag moves selected pixels; Command-Option-drag copies them. Option-drag duplicates layers/folders/effects; Option-click at a layer boundary toggles clipping. Command-click a thumbnail loads its selection. Control bypasses snapping. Right-drag adjusts brush size. Modifier-and-mouse gestures are fixed.")
                }.padding(.trailing, 8)
            }.frame(height: 465)
            // Only a conflict takes room here; an empty line left a wide gap above the buttons.
            if let problem = ShortcutSettings.problem(in: draft) {
                Text(problem)
                    .foregroundStyle(.orange).font(.callout).lineLimit(2)
                    .frame(height: 22, alignment: .topLeading)
            }
            Divider()
            HStack {
                Button("Restore Defaults") { recording = nil; draft = [:] }
                Spacer()
                Button("Cancel") { settings.close() }.keyboardShortcut(.cancelAction)
                Button("Save") { settings.save(draft) }.keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(recording != nil || ShortcutSettings.problem(in: draft) != nil)
            }
        }.padding(24).frame(width: 660).fixedSize()
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let chord: ShortcutChord
    let recording: Bool
    let start: () -> Void
    let finish: (ShortcutChord?) -> Void
    func makeNSView(context: Context) -> RecorderButton { RecorderButton() }
    func updateNSView(_ button: RecorderButton, context: Context) {
        button.start = start; button.finish = finish; button.recording = recording
        button.title = recording ? "Press keys…" : chord.label
        button.setAccessibilityLabel(recording ? "Press a shortcut" : chord.label)
        if recording, button.window?.firstResponder !== button { button.window?.makeFirstResponder(button) }
    }
    final class RecorderButton: NSButton {
        var start: (() -> Void)?
        var finish: ((ShortcutChord?) -> Void)?
        var recording = false
        override var acceptsFirstResponder: Bool { true }
        init() {
            super.init(frame: .zero)
            bezelStyle = .rounded; target = self; action = #selector(beginRecording)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        @objc private func beginRecording() { window?.makeFirstResponder(self); recording = true; start?() }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard recording, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
            keyDown(with: event); return true
        }
        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            let chord = ShortcutChord(event)
            guard chord.key.count == 1 else { NSSound.beep(); return }
            recording = false
            finish?(chord)
            window?.makeFirstResponder(nil)
        }
    }
}
