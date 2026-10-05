import SwiftUI

@main
struct HarborApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(AppModel.store)
                .environment(AppModel.monitor)
        } label: {
            MenuBarLabel()
                .environment(AppModel.store)
                .environment(AppModel.monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

enum AppModel {
    static let store = PinStore()
    static let monitor = ServerMonitor()
}

private struct MenuBarLabel: View {
    @Environment(PinStore.self) private var store
    @Environment(ServerMonitor.self) private var monitor

    var body: some View {
        let grouping = monitor.group(by: store.folders)
        let count = grouping.runningPinnedCount + grouping.others.count
        HStack(spacing: 3) {
            Image(systemName: count > 0 ? "sailboat.fill" : "sailboat")
            if count > 0 {
                Text(verbatim: "\(count)")
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(count > 0 ? "Harbor, \(count) running" : "Harbor")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var previewWindow: NSWindow?

    /// `open Harbor.app --args -HarborPreview YES` shows the panel in a normal window,
    /// which is handy for screenshots.
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard UserDefaults.standard.bool(forKey: "HarborPreview") else { return }
        let host = NSHostingController(
            rootView: PanelView()
                .environment(AppModel.store)
                .environment(AppModel.monitor)
        )
        let window = NSWindow(contentViewController: host)
        window.title = "Harbor"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        previewWindow = window
    }
}
