import AppKit

/// Opens folders in the apps you actually use, falling back to Apple's.
enum Launcher {
    struct App {
        let name: String
        let url: URL
    }

    static let terminal = firstInstalled(["com.mitchellh.ghostty", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.apple.Terminal"])
    static let editor = firstInstalled(["com.todesktop.230313mzl4w4u92", "dev.zed.Zed", "com.microsoft.VSCode"])

    static func open(_ folder: URL, in app: App) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([folder], withApplicationAt: app.url, configuration: configuration)
    }

    static func reveal(_ folder: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private static func firstInstalled(_ bundleIDs: [String]) -> App? {
        for id in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                let name = FileManager.default.displayName(atPath: url.path)
                return App(name: (name as NSString).deletingPathExtension, url: url)
            }
        }
        return nil
    }
}
