import AppKit
import SwiftUI

struct FolderRow: View {
    let folder: PinnedFolder
    let servers: [LocalServer]
    var isLifted = false

    @Environment(PinStore.self) private var store
    @Environment(ServerMonitor.self) private var monitor
    @State private var isHovering = false
    @State private var copiedPhrase: String?

    private var isRunning: Bool { !servers.isEmpty }
    private var isStopping: Bool { servers.contains { monitor.stopping.contains($0.pid) } }
    private var endpoints: [(server: LocalServer, port: Int)] {
        servers.flatMap { server in server.ports.map { (server, $0) } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                FolderIcon(path: folder.path)
                    .frame(width: 30, height: 30)
                    .saturation(folder.exists ? 1 : 0)

                VStack(alignment: .leading, spacing: 1) {
                    Text(folder.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Group {
                        if let copiedPhrase {
                            Text(copiedPhrase).foregroundStyle(.tint)
                        } else if !folder.exists {
                            Text("Missing · \(folder.displayPath)").foregroundStyle(.orange)
                        } else {
                            Text(folder.displayPath).foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .transition(.blurReplace)
                }

                Spacer(minLength: 6)

                Button(action: copy) {
                    Image(systemName: copiedPhrase == nil ? "doc.on.doc" : "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 16, height: 16)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .foregroundStyle(isHovering || copiedPhrase != nil ? .primary : .secondary)
                .help("Copy path")
            }

            if isRunning {
                HStack(spacing: 6) {
                    ForEach(endpoints.prefix(3), id: \.port) { endpoint in
                        ServerChip(server: endpoint.server, port: endpoint.port, compact: endpoints.count > 1)
                    }
                    if endpoints.count > 3 {
                        Text("+\(endpoints.count - 3)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 6)

                    StopButton(isStopping: isStopping) {
                        Task { await monitor.stopAll(servers) }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(12)
        .contentShape(.rect(cornerRadius: 16))
        .glassEffect(
            isRunning ? .regular.tint(.green.opacity(0.10)).interactive() : .regular.interactive(),
            in: .rect(cornerRadius: 16)
        )
        .opacity(folder.exists ? 1 : 0.7)
        .onTapGesture { if !isLifted { copy() } }
        .onHover { hovering in withAnimation(.snappy(duration: 0.18)) { isHovering = hovering } }
        .animation(.smooth(duration: 0.35), value: isRunning)
        .contextMenu { menu }
    }

    @ViewBuilder
    private var menu: some View {
        Button("Copy Path", systemImage: "doc.on.doc", action: copy)
        Button("Reveal in Finder", systemImage: "folder") { Launcher.reveal(folder.url) }
        if let editor = Launcher.editor {
            Button("Open in \(editor.name)", systemImage: "chevron.left.forwardslash.chevron.right") {
                Launcher.open(folder.url, in: editor)
            }
        }
        if let terminal = Launcher.terminal {
            Button("Open in \(terminal.name)", systemImage: "terminal") { Launcher.open(folder.url, in: terminal) }
        }
        Divider()
        Button("Move Up", systemImage: "arrow.up") { withAnimation(.smooth) { store.move(folder, by: -1) } }
            .disabled(!store.canMove(folder, by: -1))
        Button("Move Down", systemImage: "arrow.down") { withAnimation(.smooth) { store.move(folder, by: 1) } }
            .disabled(!store.canMove(folder, by: 1))
        Divider()
        Button("Unpin", systemImage: "pin.slash", role: .destructive) {
            withAnimation(.smooth) { store.unpin(folder) }
        }
    }

    private func copy() {
        Launcher.copy(folder.path)
        let phrase = CopyPhrases.next()
        withAnimation(.snappy) { copiedPhrase = phrase }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if copiedPhrase == phrase {
                withAnimation(.smooth) { copiedPhrase = nil }
            }
        }
    }
}

/// Mostly "Copied", occasionally something sillier.
enum CopyPhrases {
    private static let whimsical = ["Yoinked!", "Ahoy, copied!", "Stowed on the clipboard", "Path secured, captain", "Message in a bottle"]
    private static var count = 0

    static func next() -> String {
        count += 1
        return count % 4 == 0 ? whimsical.randomElement()! : "Copied to clipboard"
    }
}

struct FolderIcon: View {
    let path: String

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
    }
}
