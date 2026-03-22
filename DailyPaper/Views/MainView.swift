import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = TodoViewModel()
    @State private var showPreferences = false
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Date header
            dateHeader
                .padding(.top, 20)
                .padding(.bottom, 12)

            Divider()
                .opacity(0.3)

            // Todo list
            TodoListView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom bar
            bottomBar
        }
        .background(Color(nsColor: .textBackgroundColor))
        .sheet(isPresented: $viewModel.showCarryOverSheet) {
            CarryOverSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack {
            Button(action: { viewModel.goToPreviousDay() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.displayDate)
                    .font(.system(size: 20, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)

                if !viewModel.isToday {
                    Button("Go to Today") {
                        viewModel.goToToday()
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue.opacity(0.7))
                }

                if viewModel.isViewingPastDay {
                    Text("read only")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }

            Spacer()

            Button(action: { viewModel.goToNextDay() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(viewModel.isToday ? 0.2 : 1.0))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isToday)
            .keyboardShortcut(.rightArrow, modifiers: .command)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            SyncIndicator(status: viewModel.storage.syncStatus)

            Spacer()

            if viewModel.isToday {
                Button(action: { showClearConfirmation = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Clear All")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentList.items.isEmpty)
                .confirmationDialog(
                    "Clear all items?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear All", role: .destructive) {
                        viewModel.clearAllItems()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove all items from today's list.")
                }

                Button(action: { viewModel.addItem() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("Add Item")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: .command)
            }

            if !viewModel.isToday {
                Button(action: { viewModel.goToToday() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 11))
                        Text("Today")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("t", modifiers: .command)
            }

            Button(action: { showPreferences = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.5))
    }
}
