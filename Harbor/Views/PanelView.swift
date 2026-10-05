import AppKit
import ServiceManagement
import SwiftUI

struct PanelView: View {
    @Environment(PinStore.self) private var store
    @Environment(ServerMonitor.self) private var monitor
    @State private var isDropTargeted = false

    var body: some View {
        let grouping = monitor.group(by: store.folders)

        VStack(spacing: 0) {
            HeaderView(
                runningCount: grouping.runningPinnedCount + grouping.others.count,
                onAdd: chooseFolders
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            if store.folders.isEmpty && grouping.others.isEmpty {
                EmptyHarborView(onAdd: chooseFolders)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.blurReplace)
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 10) {
                        VStack(spacing: 8) {
                            ForEach(store.folders) { folder in
                                FolderRow(folder: folder, servers: grouping.byFolder[folder.id] ?? [])
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                                        removal: .scale(scale: 0.96).combined(with: .opacity)
                                    ))
                            }

                            if !grouping.others.isEmpty {
                                OtherServersSection(servers: grouping.others)
                                    .padding(.top, store.folders.isEmpty ? 0 : 6)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
                .scrollIndicators(.automatic)
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 480)
                .fixedSize(horizontal: false, vertical: true)
            }

            FooterView()
        }
        .frame(width: 360)
        .overlay(alignment: .bottom) {
            if let docked = monitor.lastDocked {
                DockedToast(label: docked)
                    .padding(.bottom, 52)
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
            }
        }
        .overlay {
            if isDropTargeted {
                DropHint()
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            withAnimation(.bouncy) { store.pin(urls) }
            return true
        } isTargeted: { targeted in
            withAnimation(.snappy) { isDropTargeted = targeted }
        }
        .background(WindowVisibilityObserver { monitor.isPanelVisible = $0 })
        .animation(.smooth(duration: 0.35), value: store.folders)
    }

    private func chooseFolders() {
        let panel = NSOpenPanel()
        panel.title = "Pin Folders"
        panel.prompt = "Pin"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Projects")
        NSApp.activate()
        if panel.runModal() == .OK {
            withAnimation(.bouncy) { store.pin(panel.urls) }
        }
    }
}

// MARK: - Header

private struct HeaderView: View {
    let runningCount: Int
    let onAdd: () -> Void
    @State private var bob = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sailboat.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce.up, value: bob)
                .onTapGesture { bob += 1 }
                .help("Ahoy!")

            VStack(alignment: .leading, spacing: 0) {
                Text("Harbor")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(statusLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(runningCount)))
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Pin a folder")
        }
        .onChange(of: runningCount) { bob += 1 }
    }

    private var statusLine: String {
        switch runningCount {
        case 0: "All ships docked"
        case 1: "1 ship at sea"
        default: "\(runningCount) ships at sea"
        }
    }
}

// MARK: - Footer

private struct FooterView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.glass)
                .controlSize(.small)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Divider().padding(.horizontal, 16)
        }
    }
}

// MARK: - Empty state & overlays

private struct EmptyHarborView: View {
    let onAdd: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sailboat")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tint)
                .rotationEffect(.degrees(floating ? 4 : -4), anchor: .bottom)
                .offset(y: floating ? -2 : 2)
                .padding(.top, 8)

            Image(systemName: "water.waves")
                .font(.system(size: 18))
                .foregroundStyle(.tint.opacity(0.5))
                .offset(x: floating ? 3 : -3)
                .padding(.top, -10)

            Text("The harbor is quiet")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text("Pin your project folders to copy their paths in a click and keep an eye on their localhost servers.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onAdd) {
                Label("Pin a Folder", systemImage: "pin.fill")
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glassProminent)
            .padding(.top, 4)

            Text("or drop one right here")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { floating = true }
        }
    }
}

private struct DropHint: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(.tint, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            .background(.tint.opacity(0.08), in: .rect(cornerRadius: 18))
            .overlay {
                Label("Drop to moor it here", systemImage: "anchor")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.tint(.accentColor.opacity(0.2)), in: .capsule)
            }
            .allowsHitTesting(false)
    }
}

private struct DockedToast: View {
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "anchor")
                .symbolEffect(.bounce, options: .nonRepeating)
            Text("Docked \(label)")
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .allowsHitTesting(false)
    }
}
