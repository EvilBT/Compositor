import SwiftUI
import AppKit

struct BlendModePicker: NSViewRepresentable {
    let session: EditorSession
    func makeCoordinator() -> Coordinator { Coordinator(session: session) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        // Grouped as Photoshop groups them — darkening, lightening, contrast, comparative, component —
        // with a line between, so a long list stays readable.
        for (index, group) in LayerBlendMode.groups.enumerated() {
            if index > 0 { button.menu?.addItem(.separator()) }
            for mode in group {
                button.addItem(withTitle: mode.displayName)
                // The item carries the mode; the title is only ever shown. This used to
                // parse `item.title` back into the enum, which works only while the title
                // is the untranslated raw value — localizing it would have made every
                // lookup return nil and broken blend modes entirely. See
                // `LocalizedDisplay.swift`.
                button.lastItem?.representedObject = mode.rawValue
            }
        }
        button.menu?.delegate = context.coordinator
        button.target = context.coordinator
        button.action = #selector(Coordinator.choose(_:))
        button.setAccessibilityLabel("Blend mode")
        // A capsule like the SwiftUI buttons and menus (`roundedControls`), which don't reach this AppKit pop-up.
        button.borderShape = .capsule
        return button
    }
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        button.isEnabled = session.canEditAppearance
        if !context.coordinator.tracking {
            select(session.activeLayer?.blendMode ?? .normal, in: button)
        }
    }

    /// Selects by the mode an item carries, never by its title — the title is localized.
    private func select(_ mode: LayerBlendMode, in button: NSPopUpButton) {
        guard let index = button.itemArray.firstIndex(where: { $0.representedObject as? String == mode.rawValue })
        else { return }
        button.selectItem(at: index)
    }
    static func dismantleNSView(_ button: NSPopUpButton, coordinator: Coordinator) {
        if coordinator.tracking { coordinator.session.previewBlendMode(nil, for: nil) }
        button.menu?.delegate = nil
    }
    final class Coordinator: NSObject, NSMenuDelegate {
        let session: EditorSession
        var tracking = false
        private var layerID: UUID?
        private var highlightedMode: LayerBlendMode?
        init(session: EditorSession) { self.session = session }
        func menuWillOpen(_ menu: NSMenu) {
            tracking = true
            layerID = session.activeLayerID
            highlightedMode = nil
        }
        func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
            // AppKit briefly reports no highlighted item while dismissing the menu.
            // Keep the last preview alive until the selection action has committed so
            // the canvas never flashes back to the layer's previous mode.
            guard let mode = Self.mode(of: item) else { return }
            highlightedMode = mode
            session.previewBlendMode(mode, for: layerID)
        }
        func menuDidClose(_ menu: NSMenu) {
            tracking = false
            // A chosen item's action runs as the menu finishes closing. Clearing on the
            // next turn lets that action replace the preview with the committed mode;
            // when the menu was cancelled, this simply restores the original mode.
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.tracking else { return }
                self.session.previewBlendMode(nil, for: nil)
            }
        }
        @objc func choose(_ button: NSPopUpButton) {
            guard session.activeLayerID == layerID,
                  let mode = highlightedMode ?? Self.mode(of: button.selectedItem) else { return }
            session.setLayerBlendMode(mode)
            if let index = button.itemArray.firstIndex(where: { $0.representedObject as? String == mode.rawValue }) {
                button.selectItem(at: index)
            }
            highlightedMode = nil
            session.refreshCanvasPreview?()
        }

        /// The mode an item stands for. Read from `representedObject`, so a translated
        /// title can never be mistaken for a format value.
        static func mode(of item: NSMenuItem?) -> LayerBlendMode? {
            guard let raw = item?.representedObject as? String else { return nil }
            return LayerBlendMode(rawValue: raw)
        }
    }
}
