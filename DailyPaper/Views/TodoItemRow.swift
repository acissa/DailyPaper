import SwiftUI

struct TodoItemRow: View {
    let item: TodoItem
    let isReadOnly: Bool
    let isFocused: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onTextChange: (String) -> Void
    let onIndent: () -> Void
    let onOutdent: () -> Void
    let onClearCarriedOver: () -> Void
    let onSubmit: (String) -> Void

    @State private var editText: String
    @State private var isHovering = false
    @State private var textFlushTask: DispatchWorkItem?
    @FocusState private var fieldFocused: Bool

    init(
        item: TodoItem,
        isReadOnly: Bool,
        isFocused: Bool = false,
        onToggle: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onTextChange: @escaping (String) -> Void,
        onIndent: @escaping () -> Void,
        onOutdent: @escaping () -> Void,
        onClearCarriedOver: @escaping () -> Void,
        onSubmit: @escaping (String) -> Void
    ) {
        self.item = item
        self.isReadOnly = isReadOnly
        self.isFocused = isFocused
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.onTextChange = onTextChange
        self.onIndent = onIndent
        self.onOutdent = onOutdent
        self.onClearCarriedOver = onClearCarriedOver
        self.onSubmit = onSubmit
        self._editText = State(initialValue: item.text)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Indentation
            if item.indent > 0 {
                Spacer()
                    .frame(width: CGFloat(item.indent) * 24)
            }

            // Checkbox
            Button(action: {
                if !isReadOnly { onToggle() }
            }) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(item.done ? Color.secondary.opacity(0.5) : Color.primary.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Text
            if isReadOnly {
                Text(item.text.isEmpty ? " " : item.text)
                    .font(.system(size: 14, design: .monospaced))
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? Color.secondary.opacity(0.5) : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("New item...", text: $editText)
                    .font(.system(size: 14, design: .monospaced))
                    .textFieldStyle(.plain)
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? Color.secondary.opacity(0.5) : Color.primary)
                    .focused($fieldFocused)
                    .onSubmit {
                        // Single atomic operation: flush text + create next item
                        if !editText.trimmingCharacters(in: .whitespaces).isEmpty {
                            onSubmit(editText)
                        }
                    }
                    .onChange(of: fieldFocused) { _, focused in
                        if !focused {
                            // Flush text to model when focus leaves
                            onTextChange(editText)
                        }
                        if focused && item.carriedOver {
                            onClearCarriedOver()
                        }
                    }
                    .onKeyPress(.tab, phases: .down) { _ in
                        onIndent()
                        return .handled
                    }
            }

            Spacer()

            // Delete button (on hover)
            if isHovering && !isReadOnly {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onChange(of: editText) { _, newText in
            // Debounce flush to model — keeps the model in sync for save,
            // but doesn't trigger re-render since we ignore model→editText updates while focused
            textFlushTask?.cancel()
            let task = DispatchWorkItem { [onTextChange] in
                onTextChange(newText)
            }
            textFlushTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
        }
        .onChange(of: item.text) { _, newValue in
            // Only accept external model changes if we're NOT focused (i.e., not actively typing)
            if !fieldFocused && newValue != editText {
                editText = newValue
            }
        }
    }
}
