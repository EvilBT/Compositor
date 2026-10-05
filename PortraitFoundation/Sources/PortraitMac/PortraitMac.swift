#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import PortraitCore
import PortraitMCP

@main
struct PortraitMac: App {
    var body: some Scene {
        WindowGroup("人像修图 · 原型") { PortraitView() }
            .defaultSize(width: 1120, height: 760)
    }
}

@MainActor
final class PortraitModel: ObservableObject {
    @Published var original: CGImage?
    @Published var current: CGImage?
    @Published var candidate: PreviewTicket?
    @Published var busy = false
    @Published var message = "打开照片，查看磨皮预览，再决定是否应用。"
    @Published var error: String?
    @Published var undoCount = 0
    @Published var title = "尚未打开照片"
    private var session: PortraitSession?

    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url)
    }

    func load(_ url: URL) {
        run {
            let photo = try await Task.detached { try PhotoIO.load(url, maximumDimension: 2048) }.value
            // Keep review state in memory until the user explicitly chooses a saved document.
            let session = PortraitSession(photo: photo)
            self.session = session
            self.original = photo.image
            self.current = photo.image
            self.candidate = nil
            self.undoCount = 0
            self.title = url.lastPathComponent
            self.message = "照片已打开。原图保持不变；编辑暂存在本次会话。"
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
            self.message = "已撤销上一次应用。"
        }
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do { try await operation() }
            catch { self.error = String(describing: error) }
        }
    }
}

struct PortraitView: View {
    @StateObject private var model = PortraitModel()
    @State private var strength = 0.65
    @State private var texture = 0.30

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(model.title).font(.headline)
                Spacer()
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
        .padding(20)
        .frame(minWidth: 960, minHeight: 600)
        .disabled(model.busy)
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

#else
@main
struct PortraitMacUnavailable {
    static func main() {}
}
#endif
