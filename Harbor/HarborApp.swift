import SwiftUI

@main
struct HarborApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(AppModel.store)
                .environment(AppModel.monitor)
                .environment(AppModel.watch)
        } label: {
            MenuBarLabel()
                .environment(AppModel.store)
                .environment(AppModel.monitor)
                .environment(AppModel.watch)
        }
        .menuBarExtraStyle(.window)
    }
}

enum AppModel {
    static let store = PinStore()
    static let monitor = ServerMonitor()
    static let watch = NightWatch()
}

private struct MenuBarLabel: View {
    @Environment(PinStore.self) private var store
    @Environment(ServerMonitor.self) private var monitor
    @Environment(NightWatch.self) private var watch

    var body: some View {
        let grouping = monitor.group(by: store.folders)
        let count = grouping.runningPinnedCount + grouping.others.count
        let sailboat = count > 0 ? "sailboat.fill" : "sailboat"
        HStack(spacing: 3) {
            if watch.isOn {
                Image(nsImage: .menuBarSailboat(sailboat, badge: "sun.max.fill"))
            } else {
                Image(systemName: sailboat)
            }
            if count > 0 {
                Text(verbatim: "\(count)")
                    .monospacedDigit()
            }
        }
        .accessibilityLabel([
            count > 0 ? "Harbor, \(count) running" : "Harbor",
            watch.isOn ? "keeping Mac awake" : nil,
        ].compactMap(\.self).joined(separator: ", "))
    }
}

private extension NSImage {
    /// The sailboat with a little sun out over the sail, drawn as one glyph the way the system's
    /// badged symbols are: the menu bar only shows a single image per item.
    static func menuBarSailboat(_ sailboat: String, badge: String) -> NSImage {
        func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight) -> NSImage {
            NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: size, weight: weight)) ?? NSImage()
        }
        let boat = symbol(sailboat, size: 13, weight: .regular)
        let badge = symbol(badge, size: 7.5, weight: .bold)
        let size = NSSize(width: boat.size.width + 3, height: boat.size.height + 1)
        let image = NSImage(size: size, flipped: false) { _ in
            boat.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
            let origin = NSPoint(x: size.width - badge.size.width, y: size.height - badge.size.height)
            // Clear a halo out of the sail so the badge reads as its own shape.
            let halo = NSRect(origin: origin, size: badge.size).insetBy(dx: -0.5, dy: -0.5)
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: halo).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            badge.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        image.isTemplate = true
        return image
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var previewWindow: NSWindow?

    /// `open Harbor.app --args -HarborPreview YES` shows the panel in a normal window,
    /// which is handy for screenshots. Add `-HarborAppearance light|dark` to force a theme.
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard UserDefaults.standard.bool(forKey: "HarborPreview") else { return }
        switch UserDefaults.standard.string(forKey: "HarborAppearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        let host = NSHostingView(
            rootView: PanelView()
                .environment(AppModel.store)
                .environment(AppModel.monitor)
                .environment(AppModel.watch)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(48)
                .background(PreviewBackdrop())
        )
        let window = PreviewWindow(
            contentRect: NSRect(origin: .zero, size: host.fittingSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        previewWindow = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.watch.standDown()
    }
}

/// Borderless windows can't become key by default; the preview should behave like the open panel.
private final class PreviewWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// A soft sea-colored backdrop so the glass has something to refract in screenshots.
private struct PreviewBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        ZStack {
            LinearGradient(
                colors: dark
                    ? [Color(red: 0.05, green: 0.12, blue: 0.28), Color(red: 0.02, green: 0.30, blue: 0.42)]
                    : [Color(red: 0.62, green: 0.84, blue: 0.98), Color(red: 0.30, green: 0.62, blue: 0.93)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color(red: 0.35, green: 0.85, blue: 0.80).opacity(dark ? 0.35 : 0.5))
                .frame(width: 320)
                .blur(radius: 70)
                .offset(x: -130, y: 170)
            Circle()
                .fill(Color(red: 0.55, green: 0.45, blue: 0.95).opacity(dark ? 0.3 : 0.35))
                .frame(width: 260)
                .blur(radius: 70)
                .offset(x: 150, y: -180)
        }
    }
}
