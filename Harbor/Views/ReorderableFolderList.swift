import AppKit
import SwiftUI

/// Pinned folder rows that can be dragged into a new order.
///
/// The data never changes mid-drag: the lifted row follows the pointer 1:1 while its
/// neighbours spring aside to preview the drop. On release the row settles into its
/// slot, and only then is the new order committed (without animation, so nothing jumps).
struct ReorderableFolderList: View {
    let spacing: CGFloat
    let grouping: ServerMonitor.Grouping

    @Environment(PinStore.self) private var store
    @State private var rowHeights: [PinnedFolder.ID: CGFloat] = [:]
    @State private var draggingID: PinnedFolder.ID?
    @State private var targetIndex: Int?
    @State private var dragOffset: CGFloat = 0
    @State private var isLifted = false
    @State private var isSettling = false

    private let liftSpring = Animation.spring(response: 0.28, dampingFraction: 0.72)
    private let makeRoomSpring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    private let settleSpring = Animation.spring(response: 0.34, dampingFraction: 0.84)

    var body: some View {
        let folders = store.folders
        let sourceIndex = draggingID.flatMap { id in folders.firstIndex { $0.id == id } }

        ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
            let isDragging = folder.id == draggingID
            let lifted = isDragging && isLifted

            FolderRow(folder: folder, servers: grouping.byFolder[folder.id] ?? [], isLifted: isDragging)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[folder.id] = $0 }
                .scaleEffect(lifted ? 1.03 : 1)
                .shadow(color: .black.opacity(lifted ? 0.25 : 0), radius: lifted ? 18 : 0, y: lifted ? 10 : 0)
                .offset(y: isDragging ? dragOffset : makeRoomOffset(for: index, source: sourceIndex))
                .zIndex(isDragging ? 1 : 0)
                .gesture(dragGesture(for: folder))
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .scale(scale: 0.96).combined(with: .opacity)
                ))
        }
    }

    // MARK: - Gesture

    private func dragGesture(for folder: PinnedFolder) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                if draggingID == nil {
                    guard !isSettling, let index = store.folders.firstIndex(of: folder) else { return }
                    draggingID = folder.id
                    targetIndex = index
                    withAnimation(liftSpring) { isLifted = true }
                    haptic()
                }
                guard draggingID == folder.id, !isSettling,
                      let source = store.folders.firstIndex(of: folder) else { return }

                dragOffset = rubberBanded(value.translation.height, source: source)

                let proposed = proposedIndex(source: source, offset: dragOffset)
                if proposed != targetIndex {
                    withAnimation(makeRoomSpring) { targetIndex = proposed }
                    haptic()
                }
            }
            .onEnded { _ in
                guard draggingID == folder.id, !isSettling else { return }
                drop(folder)
            }
    }

    private func drop(_ folder: PinnedFolder) {
        guard let source = store.folders.firstIndex(of: folder) else { return reset() }
        let target = targetIndex ?? source
        isSettling = true

        withAnimation(settleSpring, completionCriteria: .logicallyComplete) {
            dragOffset = slotOffset(from: source, to: target)
            isLifted = false
        } completion: {
            // Every row is already drawn where it will end up, so swap in the new order invisibly.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                store.move(folder, to: target)
                reset()
            }
        }
    }

    private func reset() {
        draggingID = nil
        targetIndex = nil
        dragOffset = 0
        isLifted = false
        isSettling = false
    }

    // MARK: - Geometry

    private func height(at index: Int) -> CGFloat {
        (rowHeights[store.folders[index].id] ?? 60) + spacing
    }

    /// How far a non-dragged row moves to make room for the lifted one at its proposed slot.
    private func makeRoomOffset(for index: Int, source: Int?) -> CGFloat {
        guard let source, let target = targetIndex, index != source else { return 0 }
        let room = height(at: source)
        if source < target, index > source, index <= target { return -room }
        if source > target, index >= target, index < source { return room }
        return 0
    }

    /// The offset that places the dragged row exactly in slot `target`.
    private func slotOffset(from source: Int, to target: Int) -> CGFloat {
        if target > source { return (source + 1...target).reduce(0) { $0 + height(at: $1) } }
        if target < source { return -(target..<source).reduce(0) { $0 + height(at: $1) } }
        return 0
    }

    /// The slot whose neighbour midpoint the dragged row has crossed.
    private func proposedIndex(source: Int, offset: CGFloat) -> Int {
        var target = source
        var remaining = offset
        if offset > 0 {
            for index in (source + 1)..<store.folders.count {
                let step = height(at: index)
                guard remaining > step / 2 else { break }
                target = index
                remaining -= step
            }
        } else if offset < 0 {
            for index in stride(from: source - 1, through: 0, by: -1) {
                let step = height(at: index)
                guard -remaining > step / 2 else { break }
                target = index
                remaining += step
            }
        }
        return target
    }

    /// Follows the pointer 1:1 within the list, with soft resistance past either end.
    private func rubberBanded(_ translation: CGFloat, source: Int) -> CGFloat {
        let minimum = slotOffset(from: source, to: 0)
        let maximum = slotOffset(from: source, to: store.folders.count - 1)
        func resist(_ overshoot: CGFloat) -> CGFloat { 24 * (1 - 1 / (overshoot / 80 + 1)) }
        if translation < minimum { return minimum - resist(minimum - translation) }
        if translation > maximum { return maximum + resist(translation - maximum) }
        return translation
    }

    private func haptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
