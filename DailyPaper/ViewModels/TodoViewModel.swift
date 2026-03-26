import Foundation
import SwiftUI
import Combine

@MainActor
final class TodoViewModel: ObservableObject {

    // MARK: - Published

    @Published var data: DailyPaperData = DailyPaperData()
    @Published var selectedDate: Date = Date()
    @Published var showCarryOverSheet: Bool = false
    @Published var carryOverItems: [TodoItem] = []
    @Published var carryOverSelections: Set<UUID> = []
    @Published var focusedItemID: UUID? = nil

    // MARK: - Dependencies

    let storage: FileStorageManager
    private var dayChangeObservers: [Any] = []

    // MARK: - Computed

    var dateKey: String {
        DailyPaperData.dateKey(for: selectedDate)
    }

    var currentList: DailyList {
        get { data.days[dateKey] ?? DailyList() }
        set {
            var list = newValue
            list.reindex()
            data.days[dateKey] = list
            storage.save(data)
        }
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var isViewingPastDay: Bool {
        selectedDate < Calendar.current.startOfDay(for: Date()) && !isToday
    }

    var displayDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: selectedDate)
    }

    // MARK: - Init

    init(storage: FileStorageManager = FileStorageManager()) {
        self.storage = storage
        self.data = storage.load()

        // Strip any persisted empty items (e.g. app quit while an empty row was open)
        stripEmptyItemsFromAllDays()

        storage.onExternalChange = { [weak self] in
            self?.reloadFromDisk()
        }

        // Check if today needs to be created
        checkTodayList()

        // Watch for day changes (midnight rollover + app re-activation after sleep)
        setupDayChangeObservers()

        // Never auto-focus on launch — user must explicitly click Add Item or a row
        focusedItemID = nil
    }

    /// Remove empty items that were persisted (e.g. app quit mid-edit)
    private func stripEmptyItemsFromAllDays() {
        var changed = false
        for (key, day) in data.days {
            let cleaned = day.items.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            if cleaned.count != day.items.count {
                data.days[key]?.items = cleaned
                changed = true
            }
        }
        if changed {
            storage.save(data)
        }
    }

    private func setupDayChangeObservers() {
        let nc = NotificationCenter.default

        // Fires at midnight
        let dayChanged = nc.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.checkDayChange() }
        }

        // Fires when app comes to foreground (e.g. after sleep, switching apps)
        let becameActive = nc.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.checkDayChange() }
        }

        dayChangeObservers = [dayChanged, becameActive]
    }

    /// If the selected date is no longer today, automatically jump to the new day.
    func checkDayChange() {
        if !Calendar.current.isDateInToday(selectedDate) {
            selectedDate = Date()
            reloadFromDisk()
            checkTodayList()
        }
    }

    // MARK: - Navigation

    func goToPreviousDay() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = prev
    }

    func goToNextDay() {
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        // Don't go past today
        if next <= Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400) {
            selectedDate = next
        }
    }

    func goToToday() {
        selectedDate = Date()
        checkTodayList()
    }

    // MARK: - Item Operations

    /// Submit text for an item AND create a new item after it — single atomic update.
    func submitAndAddItem(id: UUID, text: String) {
        guard isToday else { return }
        var list = currentList

        // Update the text of the submitted item
        if let idx = list.items.firstIndex(where: { $0.id == id }) {
            list.items[idx].text = text
            list.items[idx].markModified()
        }

        // Remove any empty items (ghost cleanup)
        list.items.removeAll { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }

        // Create new item after the submitted one
        let newItem = TodoItem(order: list.items.count)
        if let idx = list.items.firstIndex(where: { $0.id == id }) {
            list.items.insert(newItem, at: idx + 1)
        } else {
            list.items.append(newItem)
        }

        // Single write
        currentList = list
        focusedItemID = newItem.id
    }

    func addItem(afterItemID: UUID? = nil) {
        guard isToday else { return }
        var list = currentList

        // Remove any existing empty items first (ghost cleanup)
        list.items.removeAll { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }

        let item = TodoItem(order: list.items.count)

        // Insert after the specified item, or append at end
        if let afterID = afterItemID,
           let idx = list.items.firstIndex(where: { $0.id == afterID }) {
            list.items.insert(item, at: idx + 1)
        } else {
            list.items.append(item)
        }

        currentList = list
        focusedItemID = item.id
    }

    /// Remove an item if its text is empty (called when focus leaves a row)
    func cleanupEmptyItem(_ id: UUID) {
        guard isToday else { return }
        var list = currentList
        guard let idx = list.items.firstIndex(where: { $0.id == id }) else { return }
        if list.items[idx].text.trimmingCharacters(in: .whitespaces).isEmpty {
            list.items.remove(at: idx)
            currentList = list
        }
    }

    func toggleItem(_ id: UUID) {
        guard isToday else { return }
        var list = currentList
        guard let idx = list.items.firstIndex(where: { $0.id == id }) else { return }
        list.items[idx].done.toggle()
        list.items[idx].carriedOver = false
        list.items[idx].markModified()
        currentList = list
    }

    func updateItemText(_ id: UUID, text: String) {
        guard isToday else { return }
        var list = currentList
        guard let idx = list.items.firstIndex(where: { $0.id == id }) else { return }
        list.items[idx].text = text
        list.items[idx].markModified()
        currentList = list
    }

    func deleteItem(_ id: UUID) {
        guard isToday else { return }
        var list = currentList
        list.markDeleted(id)
        currentList = list
    }

    func indentItem(_ id: UUID) {
        guard isToday else { return }
        var list = currentList
        guard let idx = list.items.firstIndex(where: { $0.id == id }) else { return }
        if list.items[idx].indent < 1 {
            list.items[idx].indent = 1
            list.items[idx].markModified()
            currentList = list
        }
    }

    func outdentItem(_ id: UUID) {
        guard isToday else { return }
        var list = currentList
        guard let idx = list.items.firstIndex(where: { $0.id == id }) else { return }
        if list.items[idx].indent > 0 {
            list.items[idx].indent = 0
            list.items[idx].markModified()
            currentList = list
        }
    }

    func clearAllItems() {
        guard isToday else { return }
        let existing = currentList
        let allIDs = Set(existing.items.map(\.id)).union(existing.deletedItemIDs)
        data.days[dateKey] = DailyList(deletedItemIDs: allIDs, clearedAt: Date())
        storage.saveAuthoritative(data)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        guard isToday else { return }
        var list = currentList
        list.items.move(fromOffsets: source, toOffset: destination)
        currentList = list
    }

    func clearCarriedOverFlag(_ id: UUID) {
        var list = currentList
        guard let idx = list.items.firstIndex(where: { $0.id == id }) else { return }
        if list.items[idx].carriedOver {
            list.items[idx].carriedOver = false
            list.items[idx].markModified()
            currentList = list
        }
    }

    // MARK: - Carry Over

    func checkTodayList() {
        let todayKey = DailyPaperData.dateKey(for: Date())

        // Re-read from disk first — another machine may have already created today's list
        let diskData = storage.load()
        if diskData.days[todayKey] != nil {
            // Another machine already set up today — use it, dismiss any sheet
            data = diskData
            showCarryOverSheet = false
            return
        }

        if data.days[todayKey] == nil {
            // Check for previous incomplete items
            if let (_, prevList) = data.mostRecentDay(before: Date()) {
                let incomplete = prevList.incompleteItems
                if !incomplete.isEmpty {
                    carryOverItems = incomplete
                    carryOverSelections = Set(incomplete.map(\.id))
                    showCarryOverSheet = true
                    return
                }
            }
            // Create empty list for today
            data.days[todayKey] = DailyList()
            storage.save(data)
        }
    }

    func confirmCarryOver() {
        let todayKey = DailyPaperData.dateKey(for: Date())

        // Re-check disk — another machine may have already handled carry-over
        let diskData = storage.load()
        if diskData.days[todayKey] != nil {
            data = diskData
            showCarryOverSheet = false
            return
        }

        var newItems: [TodoItem] = []

        for item in carryOverItems where carryOverSelections.contains(item.id) {
            var carried = TodoItem(
                text: item.text,
                indent: item.indent,
                order: newItems.count,
                carriedOver: true
            )
            carried.markModified()
            newItems.append(carried)
        }

        data.days[todayKey] = DailyList(items: newItems)
        storage.save(data)
        showCarryOverSheet = false
    }

    func skipCarryOver() {
        let todayKey = DailyPaperData.dateKey(for: Date())

        // Re-check disk — another machine may have already handled it
        let diskData = storage.load()
        if diskData.days[todayKey] != nil {
            data = diskData
            showCarryOverSheet = false
            return
        }

        data.days[todayKey] = DailyList()
        storage.save(data)
        showCarryOverSheet = false
    }

    // MARK: - Reload

    func reloadFromDisk() {
        let todayKey = DailyPaperData.dateKey(for: Date())
        data = storage.load()
        // If another machine created today's list while we had the carry-over sheet open, dismiss it
        if showCarryOverSheet && data.days[todayKey] != nil {
            showCarryOverSheet = false
        }
    }
}
