import Foundation
import Observation

@Observable
final class PinStore {
    private(set) var folders: [PinnedFolder] = [] {
        didSet { save() }
    }

    private let defaultsKey = "pinnedFolders"
    /// Preview mode (used for screenshots, often with demo pins passed as launch arguments) never writes.
    private let persists = !UserDefaults.standard.bool(forKey: "HarborPreview")
    private var isLoading = true

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([PinnedFolder].self, from: data) {
            folders = decoded
        }
        isLoading = false
    }

    func pin(_ urls: [URL]) {
        for url in urls {
            var isDirectory: ObjCBool = false
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  !isPinned(path) else { continue }
            folders.append(PinnedFolder(path: path))
        }
    }

    func isPinned(_ path: String) -> Bool {
        folders.contains { $0.path == path }
    }

    func unpin(_ folder: PinnedFolder) {
        folders.removeAll { $0.id == folder.id }
    }

    func move(_ folder: PinnedFolder, by offset: Int) {
        guard let index = folders.firstIndex(of: folder) else { return }
        let target = index + offset
        guard folders.indices.contains(target) else { return }
        folders.swapAt(index, target)
    }

    func move(_ folder: PinnedFolder, to target: Int) {
        guard let index = folders.firstIndex(of: folder), folders.indices.contains(target), index != target else { return }
        var reordered = folders
        reordered.insert(reordered.remove(at: index), at: target)
        folders = reordered
    }

    func canMove(_ folder: PinnedFolder, by offset: Int) -> Bool {
        guard let index = folders.firstIndex(of: folder) else { return false }
        return folders.indices.contains(index + offset)
    }

    private func save() {
        guard persists, !isLoading else { return }
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
