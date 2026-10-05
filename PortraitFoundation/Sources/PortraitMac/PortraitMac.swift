#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import RetouchKit
import PortraitCore
import PortraitMCP

@main
struct PortraitMac: App {
    @NSApplicationDelegateAdaptor(PortraitAppDelegate.self) private var delegate
    @StateObject private var model = PortraitModel()
    var body: some Scene {
        Window("人像修图 · 原型", id: "portrait") {
            PortraitView(model: model).onAppear { delegate.model = model }
        }
            .defaultSize(width: 1120, height: 760)
    }
}

@MainActor
final class PortraitModel: ObservableObject {
    @Published var inspection: NativeInspection?
    @Published var showingInspection = false
    @Published var original: CGImage?
    @Published var current: CGImage?
    @Published var candidate: PreviewTicket?
    @Published var busy = false
    @Published var canCancel = false
    private var activeTask: Task<Void, Never>?
    @Published var message = "打开照片，查看磨皮预览，再决定是否应用。"
    @Published var error: String?
    @Published var undoCount = 0
    @Published var dirty = false
    private var documentURL: URL?
    private var sourceURL: URL?
    @Published var title = "尚未打开照片"
    private var session: PortraitSession?

    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { if await allowDiscard() { load(url) } }
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let documentURL = panel.url else { return }
        do {
            let document = try JSONDecoder().decode(PortraitDocument.self, from: Data(contentsOf: documentURL))
            guard case .file(let relativePath) = document.photo.source else { return }
            var photoURL = documentURL.deletingLastPathComponent().appendingPathComponent(relativePath)
            if !FileManager.default.fileExists(atPath: photoURL.path) {
                let source = NSOpenPanel()
                source.allowedContentTypes = [.image]
                source.message = "请选择这份编辑对应的原照片。"
                guard source.runModal() == .OK, let selected = source.url else { return }
                photoURL = selected
            }
            let selectedPhoto = photoURL
            Task { if await allowDiscard() { load(selectedPhoto, documentURL: documentURL) } }
        } catch { self.error = String(describing: error) }
    }

    func load(_ url: URL, documentURL: URL? = nil) {
        run {
            let photo = try await Task.detached { try PhotoIO.load(url, maximumDimension: 2048) }.value
            // Keep review state in memory until the user explicitly chooses a saved document.
            let saved = documentURL ?? url.appendingPathExtension("portrait.json")
            let exists = FileManager.default.fileExists(atPath: saved.path)
            let session = exists ? try PortraitSession.open(photo: photo, documentURL: saved) : PortraitSession(photo: photo)
            let image = exists ? try await session.renderCurrent(maximumDimension: 2048) : photo.image
            self.documentURL = exists ? saved : nil
            self.dirty = false
            self.session = session
            self.sourceURL = url
            self.original = photo.image
            self.current = image
            self.candidate = nil
            self.undoCount = 0
            self.title = url.lastPathComponent
            self.message = exists ? "已恢复保存的编辑。" : "照片已打开；批准后请保存编辑。"
        }
    }

    func preview(strength: Double, texture: Double) {
        guard let session else { return }
        run {
            var stack = await session.snapshot().document.ops
            var skin = SkinParams()
            skin.strength = strength
            skin.texturePreservation = texture
            if let index = stack.firstIndex(where: { if case .skin = $0.kind { return true }; return false }) {
                stack[index].kind = .skin(skin)
            } else { stack.append(RetouchOp(kind: .skin(skin))) }
            self.candidate = try await session.preview(stack: stack, maximumDimension: 2048)
            self.message = "正在查看候选效果，尚未应用。确认后可撤销。"
        }
    }

    func approve() {
        guard let session, let ticket = candidate else { return }
        run {
            _ = try await session.approvePreview(ticket)
            self.current = ticket.image
            self.candidate = nil
            self.undoCount += 1
            self.dirty = self.documentURL == nil
            self.message = "效果已应用到本次会话，原图保持不变。"
        }
    }

    func undo() {
        guard let session else { return }
        run {
            _ = try await session.undo()
            self.current = try await session.renderCurrent(maximumDimension: 2048)
            self.candidate = nil
            self.undoCount -= 1
            self.dirty = self.documentURL == nil
            self.message = "已撤销上一次应用。"
        }
    }

    func inspect() {
        guard let session, let sourceURL else { return }
        run(cancellable: true) {
            self.inspection = try await session.inspectNative(sourceURL: sourceURL, progress: self.reporter())
            self.showingInspection = true
        }
    }

    func export() {
        guard let session, let sourceURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-retouched.png"
        panel.message = "按原照片尺寸导出已批准效果（最多 4000 万像素）。候选不会导出；请选择新文件名。"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        run(cancellable: true) {
            try await session.exportPNG(sourceURL: sourceURL, destinationURL: destination, progress: self.reporter())
            self.message = "原尺寸 PNG 已导出：" + destination.lastPathComponent
        }
    }

    func save() {
        run { _ = try await self.saveDocument() }
    }

    private func saveDocument() async throws -> Bool {
        guard let session else { return false }
        var destination = documentURL
        if destination == nil {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = title + ".portrait.json"
            panel.message = "保存已批准的编辑；候选效果不会保存。请保存在原照片旁，以便打开照片时自动恢复。"
            guard panel.runModal() == .OK, let url = panel.url else { return false }
            destination = url
        }
        guard let destination else { return false }
        try await session.save(to: destination)
        documentURL = destination
        dirty = false
        message = "编辑已保存；后续应用与撤销将自动保存。"
        return true
    }

    func allowDiscard() async -> Bool {
        guard !busy else { return false }
        guard dirty || candidate != nil else { return true }
        let alert = NSAlert()
        alert.messageText = "离开当前照片？"
        alert.informativeText = "保存会保留已批准的编辑；尚未批准的候选会被放弃。"
        alert.addButton(withTitle: "保存并继续")
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "放弃并继续")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            busy = true
            defer { busy = false }
            do { return try await saveDocument() }
            catch { self.error = String(describing: error); return false }
        case .alertThirdButtonReturn: return true
        default: return false
        }
    }

    func cancel() {
        activeTask?.cancel()
        canCancel = false
        message = "正在取消，将在当前处理阶段结束后停止。"
    }

    private func reporter() -> @Sendable (String) -> Void {
        { [weak self] stage in
            Task { @MainActor in
                guard let self, self.busy, self.canCancel else { return }
                self.message = stage
            }
        }
    }

    private func run(cancellable: Bool = false, _ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        error = nil
        canCancel = cancellable
        activeTask = Task {
            defer { busy = false; canCancel = false; activeTask = nil }
            do { try await operation() }
            catch is CancellationError { message = "处理已取消，已批准编辑保持不变。" }
            catch { self.error = String(describing: error) }
        }
    }
}

struct PortraitView: View {
    @ObservedObject var model: PortraitModel
    @State private var strength = 0.65
    @State private var texture = 0.30

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(model.title).font(.headline)
                Spacer()
                Button("检查脸部细节") { model.inspect() }.disabled(model.original == nil)
                Button("导出原尺寸") { model.export() }.disabled(model.original == nil)
                Button("打开编辑") { model.openDocument() }
                Button("保存编辑") { model.save() }.disabled(model.original == nil)
                Button("打开照片") { model.open() }
            }
            HStack(spacing: 16) {
                panel("原图", image: model.original)
                panel(model.candidate == nil ? "当前效果" : "候选 · 尚未应用", image: model.candidate?.image ?? model.current)
            }
            HStack {
                Text("磨皮强度")
                Slider(value: $strength, in: 0...1).frame(maxWidth: 180)
                Text(strength, format: .number.precision(.fractionLength(2))).monospacedDigit()
                Text("纹理保留")
                Slider(value: $texture, in: 0...1).frame(maxWidth: 180)
                Text(texture, format: .number.precision(.fractionLength(2))).monospacedDigit()
                Button("生成预览") { model.preview(strength: strength, texture: texture) }
                    .disabled(model.original == nil)
            }
            HStack {
                if model.busy { ProgressView().controlSize(.small) }
                Text(model.error ?? model.message).foregroundStyle(model.error == nil ? Color.secondary : Color.red)
                Spacer()
                Button("放弃候选") { model.candidate = nil }.disabled(model.candidate == nil)
                Button("批准应用") { model.approve() }.disabled(model.candidate == nil)
                    .buttonStyle(.borderedProminent)
                Button("撤销") { model.undo() }.disabled(model.undoCount == 0)
            }
        }
        .sheet(isPresented: $model.showingInspection, onDismiss: { model.inspection = nil }) {
            if let inspection = model.inspection { NativeDetailView(inspection: inspection) }
        }
        .background(WindowCloseGuard(model: model))
        .onChange(of: strength) { model.candidate = nil }
        .onChange(of: texture) { model.candidate = nil }
        .padding(20)
        .frame(minWidth: 960, minHeight: 600)
        .disabled(model.busy)
        .overlay(alignment: .bottomTrailing) {
            if model.busy && model.canCancel {
                Button("取消处理") { model.cancel() }.padding(20)
            }
        }
        .onAppear {
            if model.original == nil, let path = CommandLine.arguments.dropFirst().first, path.hasPrefix("/") {
                model.load(URL(fileURLWithPath: path))
            }
        }
    }

    private func panel(_ title: String, image: CGImage?) -> some View {
        VStack {
            Text(title).font(.subheadline)
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.85))
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFit().padding(8)
                } else {
                    ContentUnavailableView("打开一张人像照片", systemImage: "photo")
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NativeDetailView: View {
    let inspection: NativeInspection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @State private var selectedFace = -1
    @State private var zoom = 1.0
    @State private var mode = ComparisonMode.split
    @State private var split = 0.5
    @State private var comparison: ImageComparison?
    @State private var comparisonError: String?

    private enum ComparisonMode: String, CaseIterable, Identifiable {
        case sideBySide, split, overlay, difference
        var id: Self { self }
        var title: String {
            switch self {
            case .sideBySide: "并排"
            case .split: "分割滑动"
            case .overlay: "修改区域"
            case .difference: "差值 ×4"
            }
        }
    }
    private struct ComparisonSource: @unchecked Sendable { let before: CGImage; let after: CGImage }

    init(inspection: NativeInspection) {
        self.inspection = inspection
        _selectedFace = State(initialValue: inspection.faces.isEmpty ? -1 : 0)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("原生像素检查 · 已批准效果").font(.headline)
                Spacer()
                Picker("区域", selection: $selectedFace) {
                    Text("整图").tag(-1)
                    ForEach(inspection.faces.indices, id: \.self) { i in Text("人脸 \(i + 1)").tag(i) }
                }.frame(width: 180)
                Picker("缩放", selection: $zoom) {
                    Text("50%").tag(0.5)
                    Text("100%").tag(1.0)
                    Text("200%").tag(2.0)
                }.frame(width: 150)
                Button("完成") { dismiss() }
            }
            Picker("比较方式", selection: $mode) {
                ForEach(ComparisonMode.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            Text(legend)
                .font(.caption).foregroundStyle(.secondary)
            Text("100% 时一张照片像素对应一个屏幕像素。这里显示已批准结果，未批准候选不参与。")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView([.horizontal, .vertical]) {
                Group {
                    switch mode {
                    case .sideBySide:
                        HStack(alignment: .top, spacing: 16) {
                            detail("原图", image: inspection.original)
                            detail("已批准效果", image: inspection.approved)
                        }
                    case .split: splitComparison
                    case .overlay, .difference:
                        if let comparison {
                            diagnosticImage(mode == .overlay ? comparison.changedOverlay : comparison.difference)
                        } else {
                            ProgressView(comparisonError ?? "正在计算像素差值…").padding(30)
                        }
                    }
                }.padding(8)
            }.background(Color.black.opacity(0.9))
        }
        .padding(20).frame(width: 1080, height: 720)
        .task(id: selectedFace) {
            comparison = nil
            comparisonError = nil
            let source = ComparisonSource(before: cropped(inspection.original), after: cropped(inspection.approved))
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try ImageComparison.make(original: source.before, processed: source.after)
                }.value
                guard !Task.isCancelled else { return }
                comparison = result
            } catch { if !Task.isCancelled { comparisonError = String(describing: error) } }
        }
    }

    private var legend: String {
        switch mode {
        case .sideBySide: return "左右为相同区域；可同时滚动检查。"
        case .split: return "拖动白色分割线：左侧原图，右侧已批准效果。"
        case .overlay:
            if let comparison {
                return "品红覆盖实际改变的像素（零阈值），不是皮肤遮罩。改动 \(comparison.changedPixels) / \(comparison.totalPixels) 像素。"
            }
            return "品红覆盖实际改变的像素，不改变成片。"
        case .difference: return "黑色代表未变化；逐通道绝对差值放大 4 倍，仅用于观察。"
        }
    }

    private func diagnosticImage(_ image: CGImage) -> some View {
        Image(decorative: image, scale: displayScale).resizable().interpolation(.none)
            .frame(width: Double(image.width) * zoom / displayScale,
                   height: Double(image.height) * zoom / displayScale)
    }

    private var splitComparison: some View {
        let before = cropped(inspection.original), after = cropped(inspection.approved)
        let width = Double(before.width) * zoom / displayScale
        let height = Double(before.height) * zoom / displayScale
        return ZStack(alignment: .leading) {
            diagnosticImage(after)
            diagnosticImage(before).mask(alignment: .leading) {
                Rectangle().frame(width: width * split, height: height)
            }
            Rectangle().fill(.white).frame(width: 2).offset(x: width * split - 1)
            Image(systemName: "arrow.left.and.right").padding(8)
                .background(.black.opacity(0.7), in: Circle()).foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .offset(x: width * split - 18)
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            split = min(1, max(0, value.location.x / width))
        })
        .accessibilityLabel("原图与已批准效果分割位置")
        .accessibilityValue("\(Int(split * 100))%")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: split = min(1, split + 0.05)
            case .decrement: split = max(0, split - 0.05)
            @unknown default: break
            }
        }
    }

    private func detail(_ title: String, image: CGImage) -> some View {
        let crop = cropped(image)
        return VStack {
            Text(title).foregroundStyle(.white)
            Image(decorative: crop, scale: displayScale).resizable().interpolation(.none)
                .frame(width: Double(crop.width) * zoom / displayScale,
                       height: Double(crop.height) * zoom / displayScale)
        }
    }

    private func cropped(_ image: CGImage) -> CGImage {
        guard inspection.faces.indices.contains(selectedFace) else { return image }
        let bounds = inspection.faces[selectedFace].boundingBox
        let rect = CGRect(x: bounds.origin.x * Double(image.width), y: bounds.origin.y * Double(image.height),
                          width: bounds.size.x * Double(image.width), height: bounds.size.y * Double(image.height)).integral
        return image.cropping(to: rect) ?? image
    }
}

@MainActor
final class PortraitAppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // SwiftPM launches without a bundle's LSUIElement/activation defaults.
        // Establish a regular application before SwiftUI creates its window scene.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if ProcessInfo.processInfo.environment["PORTRAIT_STARTUP_DIAGNOSTICS"] == "1" {
            DispatchQueue.main.async {
                let windows = NSApplication.shared.windows.filter { $0.isVisible }
                let report = "visibleWindows=\(windows.count); titles=\(windows.map(\.title))\n"
                FileHandle.standardError.write(Data(report.utf8))
            }
        }
    }

    weak var model: PortraitModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        Task { sender.reply(toApplicationShouldTerminate: await model.allowDiscard()) }
        return .terminateLater
    }
}

struct WindowCloseGuard: NSViewRepresentable {
    let model: PortraitModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        let coordinator = context.coordinator
        DispatchQueue.main.async { view.window?.delegate = coordinator }
    }
    @MainActor final class Coordinator: NSObject, NSWindowDelegate {
        let model: PortraitModel
        private var closing = false
        init(model: PortraitModel) { self.model = model }
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if closing { return true }
            Task {
                if await model.allowDiscard() { closing = true; sender.performClose(nil) }
            }
            return false
        }
    }
}

#else
@main
struct PortraitMacUnavailable {
    static func main() {}
}
#endif
