import SwiftUI

struct CarryOverSheet: View {
    @ObservedObject var viewModel: TodoViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Carry over incomplete items?")
                .font(.system(size: 16, weight: .medium, design: .monospaced))

            Text("You have \(viewModel.carryOverItems.count) incomplete item\(viewModel.carryOverItems.count == 1 ? "" : "s") from a previous day.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.carryOverItems) { item in
                        HStack(spacing: 10) {
                            Image(systemName: viewModel.carryOverSelections.contains(item.id)
                                  ? "checkmark.square.fill" : "square")
                                .foregroundStyle(viewModel.carryOverSelections.contains(item.id)
                                                 ? .primary : .secondary)
                                .onTapGesture {
                                    if viewModel.carryOverSelections.contains(item.id) {
                                        viewModel.carryOverSelections.remove(item.id)
                                    } else {
                                        viewModel.carryOverSelections.insert(item.id)
                                    }
                                }

                            Text(item.text)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(viewModel.carryOverSelections.contains(item.id)
                                                 ? .primary : .secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider()

            HStack {
                Button("Skip") {
                    viewModel.skipCarryOver()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Carry Over \(viewModel.carryOverSelections.count) Item\(viewModel.carryOverSelections.count == 1 ? "" : "s")") {
                    viewModel.confirmCarryOver()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.carryOverSelections.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
