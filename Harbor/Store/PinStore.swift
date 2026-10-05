import Foundation
import Observation

@Observable
final class PinStore {
    private(set) var folders: [PinnedFolder] = [] {
        didSet { save() }
    }

    private let defaultsKey = "pinnedFolders"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([PinnedFolder].self, from: data) {
            folders = decoded
        }
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

    func canMove(_ folder: PinnedFolder, by offset: Int) -> Bool {
        guard let index = folders.firstIndex(of: folder) else { return false }
        return folders.indices.contains(index + offset)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
