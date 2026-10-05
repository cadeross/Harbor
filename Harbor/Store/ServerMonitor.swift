import Foundation
import Observation
import SwiftUI

@Observable
final class ServerMonitor {
    struct Grouping {
        var byFolder: [PinnedFolder.ID: [LocalServer]] = [:]
        var others: [LocalServer] = []
        var runningPinnedCount: Int { byFolder.values.filter { !$0.isEmpty }.count }
    }

    private(set) var servers: [LocalServer] = []
    private(set) var stopping: Set<pid_t> = []
    /// Lets the panel celebrate briefly after a server is stopped.
    private(set) var lastDocked: String?

    var isPanelVisible = false {
        didSet {
            if isPanelVisible && !oldValue { Task { await refresh() } }
        }
    }

    private var isScanning = false
    private var lastScan: ContinuousClock.Instant?
    private var loop: Task<Void, Never>?

    init() {
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval: Duration = isPanelVisible ? .seconds(2) : .seconds(10)
                if lastScan.map({ ContinuousClock.now - $0 >= interval }) ?? true {
                    await refresh()
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let result = await Task.detached(priority: .utility) { PortScanner.scan() }.value
        lastScan = .now
        if result != servers {
            withAnimation(.smooth(duration: 0.35)) { servers = result }
        }
    }

    func stop(_ server: LocalServer) async {
        withAnimation(.snappy) { _ = stopping.insert(server.pid) }
        await ProcessKiller.stop(server.pid)
        await refresh()
        withAnimation(.snappy) {
            _ = stopping.remove(server.pid)
            lastDocked = server.ports.first.map { "localhost:\($0)" } ?? server.command
        }
        let docked = lastDocked
        try? await Task.sleep(for: .seconds(2.4))
        if lastDocked == docked {
            withAnimation(.smooth) { lastDocked = nil }
        }
    }

    func stopAll(_ servers: [LocalServer]) async {
        await withTaskGroup(of: Void.self) { group in
            for server in servers {
                group.addTask { await self.stop(server) }
            }
        }
    }

    /// Assigns each server to the deepest pinned folder containing its working directory.
    func group(by folders: [PinnedFolder]) -> Grouping {
        var grouping = Grouping()
        for server in servers {
            guard let cwd = server.workingDirectory else { continue }
            let owner = folders
                .filter { $0.contains(cwd) }
                .max { $0.path.count < $1.path.count }
            if let owner {
                grouping.byFolder[owner.id, default: []].append(server)
            } else if cwd != "/" {
                grouping.others.append(server)
            }
        }
        return grouping
    }
}
