import Foundation

struct PinnedFolder: Identifiable, Codable, Hashable {
    var id = UUID()
    var path: String

    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
    var name: String { FileManager.default.displayName(atPath: path) }
    var displayPath: String { (path as NSString).abbreviatingWithTildeInPath }

    var exists: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// True when `otherPath` is this folder or lives somewhere inside it.
    func contains(_ otherPath: String) -> Bool {
        otherPath == path || otherPath.hasPrefix(path.hasSuffix("/") ? path : path + "/")
    }
}
