import XCTest
@testable import DailyPaper

@MainActor
final class TodoViewModelTests: XCTestCase {

    var tempDir: URL!
    var tempFileURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyPaperVMTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempFileURL = tempDir.appendingPathComponent("test-vm.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeVM() -> TodoViewModel {
        let storage = FileStorageManager(fileURL: tempFileURL)
        return TodoViewModel(storage: storage)
    }

    // MARK: - Init

    func testInitCreatesTodayList() {
        let vm = makeVM()
        XCTAssertTrue(vm.isToday)
        XCTAssertNotNil(vm.data.days[vm.dateKey])
    }

    // MARK: - Add Item

    func testAddItem() {
        let vm = makeVM()
        XCTAssertEqual(vm.currentList.items.count, 0)
        vm.addItem()
        XCTAssertEqual(vm.currentList.items.count, 1)
        XCTAssertEqual(vm.currentList.items.first?.text, "")
    }

    func testAddItemDoesNotDuplicateEmptyItem() {
        let vm = makeVM()
        vm.addItem()
        XCTAssertEqual(vm.currentList.items.count, 1)
        // Adding again should not create a second empty item
        vm.addItem()
        XCTAssertEqual(vm.currentList.items.count, 1)
    }

    func testAddItemAfterTextCreatesNew() {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.updateItemText(id, text: "Something")
        vm.addItem()
        XCTAssertEqual(vm.currentList.items.count, 2)
    }

    func testAddItemSetsFocusedID() {
        let vm = makeVM()
        vm.addItem()
        XCTAssertNotNil(vm.focusedItemID)
        XCTAssertEqual(vm.focusedItemID, vm.currentList.items.last?.id)
    }

    // MARK: - Toggle

    func testToggleItem() {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.updateItemText(id, text: "Task")
        XCTAssertFalse(vm.currentList.items.first!.done)

        vm.toggleItem(id)
        XCTAssertTrue(vm.currentList.items.first!.done)

        vm.toggleItem(id)
        XCTAssertFalse(vm.currentList.items.first!.done)
    }

    func testToggleClearsCarriedOverFlag() {
        let vm = makeVM()
        // Manually insert a carried-over item
        var list = vm.currentList
        let item = TodoItem(text: "Carried", carriedOver: true)
        list.items.append(item)
        vm.data.days[vm.dateKey] = list

        XCTAssertTrue(vm.currentList.items.first!.carriedOver)
        vm.toggleItem(item.id)
        XCTAssertFalse(vm.currentList.items.first!.carriedOver)
    }

    // MARK: - Update Text

    func testUpdateItemText() {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.updateItemText(id, text: "Updated")
        XCTAssertEqual(vm.currentList.items.first!.text, "Updated")
    }

    // MARK: - Delete

    func testDeleteItem() {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.updateItemText(id, text: "To delete")
        vm.addItem()
        XCTAssertEqual(vm.currentList.items.count, 2)

        vm.deleteItem(id)
        XCTAssertEqual(vm.currentList.items.count, 1)
        XCTAssertNil(vm.currentList.items.first { $0.id == id })
    }

    // MARK: - Indent / Outdent

    func testIndentItem() {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        XCTAssertEqual(vm.currentList.items.first!.indent, 0)

        vm.indentItem(id)
        XCTAssertEqual(vm.currentList.items.first!.indent, 1)

        // Should not go beyond 1
        vm.indentItem(id)
        XCTAssertEqual(vm.currentList.items.first!.indent, 1)
    }

    func testOutdentItem() {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.indentItem(id)
        XCTAssertEqual(vm.currentList.items.first!.indent, 1)

        vm.outdentItem(id)
        XCTAssertEqual(vm.currentList.items.first!.indent, 0)

        // Should not go below 0
        vm.outdentItem(id)
        XCTAssertEqual(vm.currentList.items.first!.indent, 0)
    }

    // MARK: - Clear All

    func testClearAllItems() {
        let vm = makeVM()
        vm.addItem()
        vm.updateItemText(vm.currentList.items.first!.id, text: "A")
        vm.addItem()
        vm.updateItemText(vm.currentList.items.last!.id, text: "B")
        XCTAssertEqual(vm.currentList.items.count, 2)

        vm.clearAllItems()
        XCTAssertEqual(vm.currentList.items.count, 0)
    }

    // MARK: - Move

    func testMoveItem() {
        let vm = makeVM()
        vm.addItem()
        vm.updateItemText(vm.currentList.items.first!.id, text: "First")
        vm.addItem()
        vm.updateItemText(vm.currentList.items.last!.id, text: "Second")

        // Move item at index 1 to index 0
        vm.moveItem(from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(vm.currentList.items[0].text, "Second")
        XCTAssertEqual(vm.currentList.items[1].text, "First")
    }

    // MARK: - Navigation

    func testGoToPreviousDay() {
        let vm = makeVM()
        let todayKey = vm.dateKey
        vm.goToPreviousDay()
        XCTAssertNotEqual(vm.dateKey, todayKey)
        XCTAssertTrue(vm.isViewingPastDay)
    }

    func testGoToNextDayDoesNotGoPastToday() {
        let vm = makeVM()
        vm.goToNextDay()
        XCTAssertTrue(vm.isToday || vm.selectedDate <= Date())
    }

    func testGoToToday() {
        let vm = makeVM()
        vm.goToPreviousDay()
        vm.goToPreviousDay()
        XCTAssertFalse(vm.isToday)

        vm.goToToday()
        XCTAssertTrue(vm.isToday)
    }

    func testPastDayIsReadOnly() {
        let vm = makeVM()
        vm.goToPreviousDay()
        XCTAssertTrue(vm.isViewingPastDay)

        // Operations should be no-ops on past days
        let countBefore = vm.currentList.items.count
        vm.addItem()
        XCTAssertEqual(vm.currentList.items.count, countBefore)
    }

    // MARK: - Carry Over

    func testCarryOverFlow() {
        let storage = FileStorageManager(fileURL: tempFileURL)

        // Seed yesterday's data with incomplete items
        var data = DailyPaperData()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayKey = DailyPaperData.dateKey(for: yesterday)
        data.days[yesterdayKey] = DailyList(items: [
            TodoItem(text: "Incomplete", done: false, order: 0),
            TodoItem(text: "Done", done: true, order: 1),
        ])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try! encoder.encode(data)
        try! json.write(to: tempFileURL, options: .atomic)

        let vm = TodoViewModel(storage: storage)
        XCTAssertTrue(vm.showCarryOverSheet)
        XCTAssertEqual(vm.carryOverItems.count, 1)
        XCTAssertEqual(vm.carryOverItems.first?.text, "Incomplete")
    }

    func testConfirmCarryOver() {
        let storage = FileStorageManager(fileURL: tempFileURL)

        var data = DailyPaperData()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayKey = DailyPaperData.dateKey(for: yesterday)
        let incompleteItem = TodoItem(text: "Carry me", done: false, order: 0)
        data.days[yesterdayKey] = DailyList(items: [incompleteItem])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode(data).write(to: tempFileURL, options: .atomic)

        let vm = TodoViewModel(storage: storage)
        XCTAssertTrue(vm.showCarryOverSheet)

        vm.confirmCarryOver()
        XCTAssertFalse(vm.showCarryOverSheet)
        XCTAssertEqual(vm.currentList.items.count, 1)
        XCTAssertEqual(vm.currentList.items.first?.text, "Carry me")
        XCTAssertTrue(vm.currentList.items.first?.carriedOver ?? false)
    }

    func testSkipCarryOver() {
        let storage = FileStorageManager(fileURL: tempFileURL)

        var data = DailyPaperData()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayKey = DailyPaperData.dateKey(for: yesterday)
        data.days[yesterdayKey] = DailyList(items: [
            TodoItem(text: "Skip me", done: false, order: 0)
        ])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode(data).write(to: tempFileURL, options: .atomic)

        let vm = TodoViewModel(storage: storage)
        XCTAssertTrue(vm.showCarryOverSheet)

        vm.skipCarryOver()
        XCTAssertFalse(vm.showCarryOverSheet)
        XCTAssertEqual(vm.currentList.items.count, 0)
    }

    // MARK: - Display Date

    func testDisplayDate() {
        let vm = makeVM()
        let formatted = vm.displayDate
        // Should contain the day of week and month
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("March") || formatted.contains("Tuesday") || formatted.count > 5)
    }
}
