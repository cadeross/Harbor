import AppKit
import SwiftUI

/// Listening servers whose working directory isn't inside any pinned folder.
struct OtherServersSection: View {
    let servers: [LocalServer]
    @AppStorage("showOtherServers") private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.smooth(duration: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text("Elsewhere on localhost")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(servers.count)")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: .capsule)
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                        if index > 0 { Divider().padding(.leading, 40) }
                        OtherServerRow(server: server)
                    }
                }
                .padding(.vertical, 4)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
    }
}

private struct OtherServerRow: View {
    let server: LocalServer
    @Environment(PinStore.self) private var store
    @Environment(ServerMonitor.self) private var monitor
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(server.folderName ?? server.command)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            if let port = server.ports.first {
                ServerChip(server: server, port: port, compact: true)
            }

            if isHovering, let cwd = server.workingDirectory, !store.isPinned(cwd) {
                Button {
                    withAnimation(.bouncy) { store.pin([URL(fileURLWithPath: cwd)]) }
                } label: {
                    Image(systemName: "pin.fill").font(.system(size: 10, weight: .semibold))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .help("Pin \(server.folderName ?? "this folder")")
                .transition(.scale.combined(with: .opacity))
            }

            StopButton(isStopping: monitor.stopping.contains(server.pid), iconOnly: true) {
                Task { await monitor.stop(server) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(.rect)
        .onHover { hovering in withAnimation(.snappy(duration: 0.18)) { isHovering = hovering } }
        .contextMenu {
            if let cwd = server.workingDirectory {
                Button("Copy Path", systemImage: "doc.on.doc") { Launcher.copy(cwd) }
                Button("Reveal in Finder", systemImage: "folder") { Launcher.reveal(URL(fileURLWithPath: cwd)) }
                Button("Pin Folder", systemImage: "pin") { store.pin([URL(fileURLWithPath: cwd)]) }
                    .disabled(store.isPinned(cwd))
            }
            Button("Copy PID \(String(server.pid))", systemImage: "number") { Launcher.copy("\(server.pid)") }
        }
    }

    private var subtitle: String {
        guard let cwd = server.workingDirectory else { return server.command }
        return server.command + " · " + (cwd as NSString).abbreviatingWithTildeInPath
    }

    private var icon: NSImage {
        if let app = NSRunningApplication(processIdentifier: server.pid), let icon = app.icon { return icon }
        if let cwd = server.workingDirectory { return NSWorkspace.shared.icon(forFile: cwd) }
        return NSImage(systemSymbolName: "terminal", accessibilityDescription: nil) ?? NSImage()
    }
}
