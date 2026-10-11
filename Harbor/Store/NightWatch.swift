import Foundation
import Observation

/// The "Keep Mac awake" switch: while it's on, the Mac stays up so long-running work carries on.
@Observable
final class NightWatch {
    private(set) var isOn = false

    private let blocker = SleepBlocker()
    private let defaultsKey = "keepAwake"
    /// Preview mode (used for screenshots) never writes, same as pins.
    private let persists = !UserDefaults.standard.bool(forKey: "HarborPreview")

    init() {
        if UserDefaults.standard.bool(forKey: defaultsKey) {
            isOn = blocker.start()
        }
    }

    /// Returns whether the watch ended up in the requested state.
    @discardableResult
    func set(_ on: Bool) -> Bool {
        if on {
            guard blocker.start() else { return false }
        } else {
            blocker.stop()
        }
        isOn = on
        if persists { UserDefaults.standard.set(on, forKey: defaultsKey) }
        return true
    }

    /// Lets the Mac sleep normally once Harbor is gone. The preference is kept for next launch.
    func standDown() {
        blocker.stop()
    }
}
