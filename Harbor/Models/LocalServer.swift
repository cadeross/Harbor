import Foundation

/// A process owned by the current user that is listening on one or more TCP ports.
nonisolated struct LocalServer: Identifiable, Hashable, Sendable {
    let pid: pid_t
    let command: String
    let ports: [Int]
    let workingDirectory: String?

    var id: pid_t { pid }

    var folderName: String? {
        workingDirectory.map { ($0 as NSString).lastPathComponent }
    }

    func url(for port: Int) -> URL {
        URL(string: "http://localhost:\(port)")!
    }
}
