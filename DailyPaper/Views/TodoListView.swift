import SwiftUI

struct TodoListView: View {
    @ObservedObject var viewModel: TodoViewModel
    @FocusState private var focusedItemID: UUID?

    var body: some View {
        let items = viewModel.currentList.items

        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    TodoItemRow(
                        item: item,
                        isReadOnly: viewModel.isViewingPastDay,
                        isFocused: focusedItemID == item.id,
                        onToggle: { viewModel.toggleItem(item.id) },
                        onDelete: { viewModel.deleteItem(item.id) },
                        onTextChange: { viewModel.updateItemText(item.id, text: $0) },
                        onIndent: { viewModel.indentItem(item.id) },
                        onOutdent: { viewModel.outdentItem(item.id) },
                        onClearCarriedOver: { viewModel.clearCarriedOverFlag(item.id) },
                        onSubmit: { text in viewModel.submitAndAddItem(id: item.id, text: text) }
                    )
                    .focused($focusedItemID, equals: item.id)
                    .moveDisabled(viewModel.isViewingPastDay)

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
