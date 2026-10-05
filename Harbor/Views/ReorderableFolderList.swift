import AppKit
import SwiftUI

/// Pinned folder rows that can be picked up with a short press and dragged into a new order.
struct ReorderableFolderList: View {
    let spacing: CGFloat
    let grouping: ServerMonitor.Grouping

    @Environment(PinStore.self) private var store
    @State private var drag: DragState?
    @State private var rowHeights: [PinnedFolder.ID: CGFloat] = [:]

    private struct DragState {
        let id: PinnedFolder.ID
        var translation: CGFloat = 0
        /// How far the row's slot has moved since pickup, so it stays under the pointer.
        var slotShift: CGFloat = 0
        var offset: CGFloat { translation - slotShift }
    }

    var body: some View {
        ForEach(store.folders) { folder in
            let isDragging = drag?.id == folder.id

            FolderRow(folder: folder, servers: grouping.byFolder[folder.id] ?? [], isLifted: isDragging)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[folder.id] = $0 }
                .scaleEffect(isDragging ? 1.025 : 1)
                .shadow(color: .black.opacity(isDragging ? 0.22 : 0), radius: isDragging ? 14 : 0, y: isDragging ? 8 : 0)
                .offset(y: isDragging ? drag?.offset ?? 0 : 0)
                .zIndex(isDragging ? 1 : 0)
                // The lifted row's slot jumps with the data; its offset compensates in the same frame.
                .transaction(value: store.folders) { if isDragging { $0.animation = nil } }
                .gesture(reorderGesture(for: folder))
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .scale(scale: 0.96).combined(with: .opacity)
                ))
        }
    }

    private func reorderGesture(for folder: PinnedFolder) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let dragValue) = value else { return }
                if drag == nil {
                    withAnimation(.snappy(duration: 0.22)) { drag = DragState(id: folder.id) }
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                drag?.translation = dragValue?.translation.height ?? 0
                swapIfNeeded()
            }
            .onEnded { _ in
                withAnimation(.snappy(duration: 0.3)) { drag = nil }
            }
    }

    /// Swaps the lifted row with a neighbour once it's dragged past that neighbour's midpoint.
    private func swapIfNeeded() {
        guard var state = drag,
              let index = store.folders.firstIndex(where: { $0.id == state.id }) else { return }
        let folders = store.folders
        let folder = folders[index]

        if state.offset > 0, index + 1 < folders.count {
            let step = (rowHeights[folders[index + 1].id] ?? 60) + spacing
            guard state.offset > step / 2 else { return }
            state.slotShift += step
            commit(state) { store.move(folder, to: index + 1) }
        } else if state.offset < 0, index > 0 {
            let step = (rowHeights[folders[index - 1].id] ?? 60) + spacing
            guard -state.offset > step / 2 else { return }
            state.slotShift -= step
            commit(state) { store.move(folder, to: index - 1) }
        }
    }

    private func commit(_ state: DragState, move: () -> Void) {
        drag = state
        withAnimation(.snappy(duration: 0.28)) { move() }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
