import AppKit
import SwiftUI

struct ServerChip: View {
    let server: LocalServer
    let port: Int
    var compact = false

    @State private var isHovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(server.url(for: port))
        } label: {
            HStack(spacing: 6) {
                PulsingDot()
                Text(verbatim: compact ? ":\(port)" : "localhost:\(port)")
                    .foregroundStyle(.primary)
                    .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .offset(x: isHovering ? 1 : 0, y: isHovering ? -1 : 0)
            }
        }
        .buttonStyle(.glass)
        .controlSize(.small)
        .onHover { hovering in withAnimation(.snappy(duration: 0.2)) { isHovering = hovering } }
        .help(Text(verbatim: "Open http://localhost:\(port) · \(server.command) (pid \(server.pid))"))
    }
}

struct PulsingDot: View {
    var color: Color = .green
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .background {
                Circle()
                    .fill(color.opacity(0.5))
                    .scaleEffect(pulse ? 2.6 : 1)
                    .opacity(pulse ? 0 : 0.9)
            }
            .shadow(color: color.opacity(0.6), radius: 3)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
            }
    }
}

struct StopButton: View {
    let isStopping: Bool
    var iconOnly = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isStopping {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "stop.fill").font(.system(size: 9, weight: .bold))
                }
                if !iconOnly {
                    Text(isStopping ? "Docking…" : "Stop")
                        .font(.system(size: 11.5, weight: .semibold))
                }
            }
            .foregroundStyle(.red)
            .frame(minWidth: iconOnly ? 14 : nil, minHeight: 14)
        }
        .buttonStyle(.glass)
        .tint(.red)
        .controlSize(.small)
        .disabled(isStopping)
        .help("Stop this server")
    }
}
