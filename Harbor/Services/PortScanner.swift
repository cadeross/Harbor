import Darwin
import Foundation

/// Finds listening TCP servers with `lsof`, then resolves each process's
/// working directory natively through libproc.
nonisolated enum PortScanner {
    static func scan() -> [LocalServer] {
        guard let output = runLsof() else { return [] }

        var order: [pid_t] = []
        var commands: [pid_t: String] = [:]
        var ports: [pid_t: Set<Int>] = [:]
        var current: pid_t?

        for line in output.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = line.dropFirst()
            switch tag {
            case "p":
                current = pid_t(value)
                if let pid = current, ports[pid] == nil {
                    order.append(pid)
                    ports[pid] = []
                }
            case "c":
                if let pid = current { commands[pid] = String(value) }
            case "n":
                if let pid = current, let port = port(from: value) { ports[pid, default: []].insert(port) }
            default:
                break
            }
        }

        return order.compactMap { pid in
            guard let found = ports[pid], !found.isEmpty, pid != getpid() else { return nil }
            return LocalServer(
                pid: pid,
                command: commands[pid] ?? "process",
                ports: found.sorted(),
                workingDirectory: workingDirectory(of: pid)
            )
        }
    }

    /// Handles `*:3000`, `127.0.0.1:5173` and `[::1]:8080`.
    private static func port(from address: Substring) -> Int? {
        guard let colon = address.lastIndex(of: ":") else { return nil }
        return Int(address[address.index(after: colon)...])
    }

    private static func runLsof() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    static func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        return path.isEmpty ? nil : path
    }
}
