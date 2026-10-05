import Darwin
import Foundation

nonisolated enum ProcessKiller {
    /// Asks politely with SIGTERM, then insists with SIGKILL after two seconds.
    static func stop(_ pid: pid_t) async {
        guard kill(pid, SIGTERM) == 0 else { return }
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(100))
            if !isAlive(pid) { return }
        }
        kill(pid, SIGKILL)
    }

    static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }
}
