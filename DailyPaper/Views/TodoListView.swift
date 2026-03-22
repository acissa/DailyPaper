import SwiftUI
import UniformTypeIdentifiers

struct TodoListView: View {
    @ObservedObject var viewModel: TodoViewModel
    @FocusState private var focusedItemID: UUID?
    @State private var draggingItemID: UUID?

    var body: some View {
        let items = viewModel.currentList.items

        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    TodoItemRow(
                        item: item,
                        isReadOnly: viewModel.isViewingPastDay,
                        isFocused: focusedItemID == item.id,
                        isDragging: draggingItemID == item.id,
                        onToggle: { viewModel.toggleItem(item.id) },
                        onDelete: { viewModel.deleteItem(item.id) },
                        onTextChange: { viewModel.updateItemText(item.id, text: $0) },
                        onIndent: { viewModel.indentItem(item.id) },
                        onOutdent: { viewModel.outdentItem(item.id) },
                        onClearCarriedOver: { viewModel.clearCarriedOverFlag(item.id) },
                        onSubmit: { text in viewModel.submitAndAddItem(id: item.id, text: text) }
                    )
                    .focused($focusedItemID, equals: item.id)
                    .onDrag {
                        guard !viewModel.isViewingPastDay else { return NSItemProvider() }
                        draggingItemID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TodoDropDelegate(
                        targetID: item.id,
                        draggingID: $draggingItemID,
                        viewModel: viewModel
                    ))

                    Divider()
                        .padding(.leading, 40)
                        .opacity(0.3)
                }
            }
            .padding(.vertical, 8)
        }
        .onChange(of: viewModel.focusedItemID) { _, newValue in
            if let id = newValue {
                focusedItemID = id
                viewModel.focusedItemID = nil
            }
        }
        .onChange(of: focusedItemID) { oldValue, _ in
            // Clean up empty items when focus leaves them
            if let oldID = oldValue {
                viewModel.cleanupEmptyItem(oldID)
            }
        }
    }
}

// MARK: - Drop Delegate

struct TodoDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingID: UUID?
    let viewModel: TodoViewModel

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragID = draggingID, dragID != targetID else { return }
        let items = viewModel.currentList.items
        guard let fromIndex = items.firstIndex(where: { $0.id == dragID }),
              let toIndex = items.firstIndex(where: { $0.id == targetID }) else { return }
        if fromIndex != toIndex {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.moveItem(from: IndexSet(integer: fromIndex), to: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingID != nil
    }
}
