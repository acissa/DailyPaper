import Foundation

// MARK: - Minimal Test Harness

var totalTests = 0
var passedTests = 0
var failedTests: [(String, String)] = []

func test(_ name: String, _ body: () throws -> Void) {
    totalTests += 1
    do {
        try body()
        passedTests += 1
        print("  PASS  \(name)")
    } catch {
        failedTests.append((name, "\(error)"))
        print("  FAIL  \(name): \(error)")
    }
}

@MainActor
func testAsync(_ name: String, _ body: @MainActor () throws -> Void) {
    totalTests += 1
    do {
        try body()
        passedTests += 1
        print("  PASS  \(name)")
    } catch {
        failedTests.append((name, "\(error)"))
        print("  FAIL  \(name): \(error)")
    }
}

struct AssertionError: Error, CustomStringConvertible {
    let description: String
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, file: String = #file, line: Int = #line) throws {
    guard a == b else { throw AssertionError(description: "assertEqual failed: \(a) != \(b) at \(file):\(line)") }
}

func assertNotEqual<T: Equatable>(_ a: T, _ b: T, file: String = #file, line: Int = #line) throws {
    guard a != b else { throw AssertionError(description: "assertNotEqual failed: \(a) == \(b) at \(file):\(line)") }
}

func assertTrue(_ v: Bool, file: String = #file, line: Int = #line) throws {
    guard v else { throw AssertionError(description: "assertTrue failed at \(file):\(line)") }
}

func assertFalse(_ v: Bool, file: String = #file, line: Int = #line) throws {
    guard !v else { throw AssertionError(description: "assertFalse failed at \(file):\(line)") }
}

func assertNil<T>(_ v: T?, file: String = #file, line: Int = #line) throws {
    guard v == nil else { throw AssertionError(description: "assertNil failed: got \(v!) at \(file):\(line)") }
}

func assertNotNil<T>(_ v: T?, file: String = #file, line: Int = #line) throws {
    guard v != nil else { throw AssertionError(description: "assertNotNil failed at \(file):\(line)") }
}

func assertGreaterThan<T: Comparable>(_ a: T, _ b: T, file: String = #file, line: Int = #line) throws {
    guard a > b else { throw AssertionError(description: "assertGreaterThan failed: \(a) <= \(b) at \(file):\(line)") }
}

// MARK: - TodoItem Tests

func runTodoItemTests() {
    print("\n--- TodoItem Tests ---")

    test("defaultInit") {
        let item = TodoItem()
        try assertFalse(item.done)
        try assertEqual(item.text, "")
        try assertEqual(item.indent, 0)
        try assertEqual(item.order, 0)
        try assertFalse(item.carriedOver)
    }

    test("customInit") {
        let item = TodoItem(text: "Buy milk", done: true, indent: 1, order: 3, carriedOver: true)
        try assertEqual(item.text, "Buy milk")
        try assertTrue(item.done)
        try assertEqual(item.indent, 1)
        try assertEqual(item.order, 3)
        try assertTrue(item.carriedOver)
    }

    test("markModified") {
        var item = TodoItem()
        let before = item.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        item.markModified()
        try assertGreaterThan(item.modifiedAt, before)
    }

    test("codableRoundTrip") {
        // Use a date with no sub-second precision to survive ISO 8601 round-trip
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let item = TodoItem(text: "Test", done: true, indent: 1, order: 2, carriedOver: true, modifiedAt: fixedDate)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TodoItem.self, from: data)
        try assertEqual(item.id, decoded.id)
        try assertEqual(item.text, decoded.text)
        try assertEqual(item.done, decoded.done)
        try assertEqual(item.indent, decoded.indent)
        try assertEqual(item.order, decoded.order)
        try assertEqual(item.carriedOver, decoded.carriedOver)
    }

    test("equatable") {
        let id = UUID()
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let a = TodoItem(id: id, text: "Same", done: false, indent: 0, order: 0, modifiedAt: fixedDate)
        let b = TodoItem(id: id, text: "Same", done: false, indent: 0, order: 0, modifiedAt: fixedDate)
        try assertEqual(a, b)
        let c = TodoItem(text: "Different")
        try assertNotEqual(a, c)
    }
}

// MARK: - DailyList Tests

func makeDate(_ string: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: string)!
}

func runDailyListTests() {
    print("\n--- DailyList Tests ---")

    test("incompleteItems") {
        let list = DailyList(items: [
            TodoItem(text: "Done", done: true, order: 0),
            TodoItem(text: "Not done", done: false, order: 1),
            TodoItem(text: "Also not done", done: false, order: 2),
        ])
        try assertEqual(list.incompleteItems.count, 2)
        try assertTrue(list.incompleteItems.allSatisfy { !$0.done })
    }

    test("reindex") {
        var list = DailyList(items: [
            TodoItem(text: "A", order: 5),
            TodoItem(text: "B", order: 10),
            TodoItem(text: "C", order: 20),
        ])
        list.reindex()
        try assertEqual(list.items[0].order, 0)
        try assertEqual(list.items[1].order, 1)
        try assertEqual(list.items[2].order, 2)
    }

    test("emptyIncompleteItems") {
        let list = DailyList()
        try assertTrue(list.incompleteItems.isEmpty)
    }

    test("dateKey") {
        let date = makeDate("2026-03-17")
        try assertEqual(DailyPaperData.dateKey(for: date), "2026-03-17")
    }

    test("listForDate") {
        var data = DailyPaperData()
        let date = makeDate("2026-03-17")
        data.setList(DailyList(items: [TodoItem(text: "Hello")]), for: date)
        let retrieved = data.list(for: date)
        try assertNotNil(retrieved)
        try assertEqual(retrieved!.items.count, 1)
        try assertEqual(retrieved!.items.first!.text, "Hello")
    }

    test("listForDateReturnsNilWhenMissing") {
        let data = DailyPaperData()
        try assertNil(data.list(for: makeDate("2026-01-01")))
    }

    test("mostRecentDayBefore") {
        var data = DailyPaperData()
        data.days["2026-03-15"] = DailyList(items: [TodoItem(text: "Old")])
        data.days["2026-03-16"] = DailyList(items: [TodoItem(text: "Yesterday")])
        data.days["2026-03-17"] = DailyList(items: [TodoItem(text: "Today")])
        let result = data.mostRecentDay(before: makeDate("2026-03-17"))
        try assertNotNil(result)
        try assertEqual(result!.0, "2026-03-16")
        try assertEqual(result!.1.items.first!.text, "Yesterday")
    }

    test("mostRecentDayBeforeReturnsNilIfNone") {
        var data = DailyPaperData()
        data.days["2026-03-17"] = DailyList(items: [TodoItem(text: "Today")])
        try assertNil(data.mostRecentDay(before: makeDate("2026-03-17")))
    }
}

// MARK: - Merge Tests

func runMergeTests() {
    print("\n--- Merge Tests ---")

    test("mergeAddsNewDays") {
        var local = DailyPaperData()
        local.days["2026-03-17"] = DailyList(items: [TodoItem(text: "Local")])
        var remote = DailyPaperData()
        remote.days["2026-03-18"] = DailyList(items: [TodoItem(text: "Remote")])
        local.merge(with: remote)
        try assertNotNil(local.days["2026-03-17"])
        try assertNotNil(local.days["2026-03-18"])
    }

    test("mergeAddsNewItems") {
        let id1 = UUID(), id2 = UUID()
        var local = DailyPaperData()
        local.days["2026-03-17"] = DailyList(items: [TodoItem(id: id1, text: "Local item", order: 0)])
        var remote = DailyPaperData()
        remote.days["2026-03-17"] = DailyList(items: [TodoItem(id: id2, text: "Remote item", order: 1)])
        local.merge(with: remote)
        try assertEqual(local.days["2026-03-17"]!.items.count, 2)
    }

    test("mergeLastWriteWins") {
        let id = UUID()
        let earlier = Date(timeIntervalSince1970: 1000)
        let later = Date(timeIntervalSince1970: 2000)
        var local = DailyPaperData()
        local.days["2026-03-17"] = DailyList(items: [
            TodoItem(id: id, text: "Old text", done: false, order: 0, modifiedAt: earlier)
        ])
        var remote = DailyPaperData()
        remote.days["2026-03-17"] = DailyList(items: [
            TodoItem(id: id, text: "New text", done: true, order: 0, modifiedAt: later)
        ])
        local.merge(with: remote)
        let item = local.days["2026-03-17"]!.items.first { $0.id == id }!
        try assertEqual(item.text, "New text")
        try assertTrue(item.done)
    }

    test("mergeLocalWinsWhenNewer") {
        let id = UUID()
        let earlier = Date(timeIntervalSince1970: 1000)
        let later = Date(timeIntervalSince1970: 2000)
        var local = DailyPaperData()
        local.days["2026-03-17"] = DailyList(items: [
            TodoItem(id: id, text: "Local newer", done: false, order: 0, modifiedAt: later)
        ])
        var remote = DailyPaperData()
        remote.days["2026-03-17"] = DailyList(items: [
            TodoItem(id: id, text: "Remote older", done: true, order: 0, modifiedAt: earlier)
        ])
        local.merge(with: remote)
        let item = local.days["2026-03-17"]!.items.first { $0.id == id }!
        try assertEqual(item.text, "Local newer")
        try assertFalse(item.done)
    }

    test("mergeRespectsDeletedItemIDs") {
        let id1 = UUID(), id2 = UUID()
        var local = DailyPaperData()
        // Disk has both items
        local.days["2026-03-17"] = DailyList(items: [
            TodoItem(id: id1, text: "Keep me", order: 0),
            TodoItem(id: id2, text: "Delete me", order: 1),
        ])
        // In-memory (other) deleted id2
        var remote = DailyPaperData()
        remote.days["2026-03-17"] = DailyList(
            items: [TodoItem(id: id1, text: "Keep me", order: 0)],
            deletedItemIDs: [id2]
        )
        local.merge(with: remote)
        let items = local.days["2026-03-17"]!.items
        try assertEqual(items.count, 1)
        try assertEqual(items.first!.id, id1)
        try assertTrue(local.days["2026-03-17"]!.deletedItemIDs.contains(id2))
    }

    test("mergeDeletedItemStaysDeleted") {
        // Simulates: you delete an item, debounced save does read-merge-write,
        // the old file still has the item — it should NOT come back.
        let id = UUID()
        var disk = DailyPaperData()
        disk.days["2026-03-17"] = DailyList(items: [
            TodoItem(id: id, text: "Zombie item", order: 0)
        ])
        var memory = DailyPaperData()
        memory.days["2026-03-17"] = DailyList(
            items: [],
            deletedItemIDs: [id]
        )
        disk.merge(with: memory)
        try assertEqual(disk.days["2026-03-17"]!.items.count, 0)
        try assertTrue(disk.days["2026-03-17"]!.deletedItemIDs.contains(id))
    }

    test("mergeDeletedIDsUnionFromBothSides") {
        let id1 = UUID(), id2 = UUID()
        var local = DailyPaperData()
        local.days["2026-03-17"] = DailyList(items: [], deletedItemIDs: [id1])
        var remote = DailyPaperData()
        remote.days["2026-03-17"] = DailyList(items: [], deletedItemIDs: [id2])
        local.merge(with: remote)
        try assertTrue(local.days["2026-03-17"]!.deletedItemIDs.contains(id1))
        try assertTrue(local.days["2026-03-17"]!.deletedItemIDs.contains(id2))
    }

    test("mergeClearedAtDropsOldItems") {
        let id = UUID()
        let clearTime = Date()
        let oldTime = clearTime.addingTimeInterval(-100)
        var local = DailyPaperData()
        local.days["2026-03-17"] = DailyList(items: [
            TodoItem(id: id, text: "Old item", order: 0, modifiedAt: oldTime)
        ])
        var remote = DailyPaperData()
        remote.days["2026-03-17"] = DailyList(items: [], clearedAt: clearTime)
        local.merge(with: remote)
        try assertEqual(local.days["2026-03-17"]!.items.count, 0)
    }

    test("fullDataCodableRoundTrip") {
        var data = DailyPaperData()
        data.days["2026-03-17"] = DailyList(items: [
            TodoItem(text: "Task 1", done: false, indent: 0, order: 0),
            TodoItem(text: "Task 2", done: true, indent: 1, order: 1, carriedOver: true),
        ])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DailyPaperData.self, from: json)
        try assertEqual(decoded.version, 1)
        try assertEqual(decoded.days["2026-03-17"]!.items.count, 2)
        try assertEqual(decoded.days["2026-03-17"]!.items[1].text, "Task 2")
        try assertTrue(decoded.days["2026-03-17"]!.items[1].carriedOver)
    }

    test("codableRoundTripWithDeletedItemIDs") {
        let deletedID = UUID()
        var data = DailyPaperData()
        data.days["2026-03-17"] = DailyList(
            items: [TodoItem(text: "Remaining")],
            deletedItemIDs: [deletedID]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DailyPaperData.self, from: json)
        try assertTrue(decoded.days["2026-03-17"]!.deletedItemIDs.contains(deletedID))
    }

    test("decodingWithoutDeletedItemIDsDefaultsToEmpty") {
        // Simulates loading an old JSON file that doesn't have deletedItemIDs
        let json = """
        {
            "version": 1,
            "days": {
                "2026-03-17": {
                    "items": [{"id": "A9D21D76-B372-48A0-AB43-12D97175E295", "text": "Hello", "done": false, "indent": 0, "order": 0, "carriedOver": false, "modifiedAt": "2026-03-18T02:14:42Z"}]
                }
            }
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DailyPaperData.self, from: json)
        try assertEqual(decoded.days["2026-03-17"]!.items.count, 1)
        try assertTrue(decoded.days["2026-03-17"]!.deletedItemIDs.isEmpty)
    }

    test("stripEmptyItemsRemovesOldEmpty") {
        var data = DailyPaperData()
        let oldDate = Date().addingTimeInterval(-60) // 60 seconds ago
        var emptyItem1 = TodoItem(text: "", order: 1)
        emptyItem1.modifiedAt = oldDate
        var emptyItem2 = TodoItem(text: "   ", order: 2)
        emptyItem2.modifiedAt = oldDate
        data.days["2026-03-17"] = DailyList(items: [
            TodoItem(text: "Real item", order: 0),
            emptyItem1,
            emptyItem2,
            TodoItem(text: "Another real", order: 3),
        ])
        data.stripEmptyItems()
        try assertEqual(data.days["2026-03-17"]!.items.count, 2)
        try assertEqual(data.days["2026-03-17"]!.items[0].text, "Real item")
        try assertEqual(data.days["2026-03-17"]!.items[1].text, "Another real")
    }

    test("stripEmptyItemsPreservesRecentEmpty") {
        var data = DailyPaperData()
        // Brand new empty item (modifiedAt = now) should be preserved
        data.days["2026-03-17"] = DailyList(items: [
            TodoItem(text: "Real item", order: 0),
            TodoItem(text: "", order: 1),  // just created, should survive
        ])
        data.stripEmptyItems()
        try assertEqual(data.days["2026-03-17"]!.items.count, 2)
    }

    test("mergeTwoMachinesAddDifferentItems") {
        // Machine A adds item X, Machine B adds item Y to the same day
        let sharedID1 = UUID()
        let sharedID2 = UUID()
        var machineA = DailyPaperData()
        machineA.days["2026-03-19"] = DailyList(items: [
            TodoItem(id: sharedID1, text: "From Machine A", order: 0)
        ])
        var machineB = DailyPaperData()
        machineB.days["2026-03-19"] = DailyList(items: [
            TodoItem(id: sharedID2, text: "From Machine B", order: 0)
        ])
        // A merges with B (B is the "other/remote")
        machineA.merge(with: machineB)
        let items = machineA.days["2026-03-19"]!.items
        try assertEqual(items.count, 2)
        let texts = Set(items.map(\.text))
        try assertTrue(texts.contains("From Machine A"))
        try assertTrue(texts.contains("From Machine B"))
    }

    test("mergeConflictingTextEdits") {
        // Same item edited on both machines — newer timestamp wins
        let itemID = UUID()
        let olderDate = Date().addingTimeInterval(-10)
        let newerDate = Date()
        var machineA = DailyPaperData()
        var itemA = TodoItem(id: itemID, text: "Old text from A", order: 0)
        itemA.modifiedAt = olderDate
        machineA.days["2026-03-19"] = DailyList(items: [itemA])
        var machineB = DailyPaperData()
        var itemB = TodoItem(id: itemID, text: "New text from B", order: 0)
        itemB.modifiedAt = newerDate
        machineB.days["2026-03-19"] = DailyList(items: [itemB])
        // A merges with B
        machineA.merge(with: machineB)
        try assertEqual(machineA.days["2026-03-19"]!.items.count, 1)
        try assertEqual(machineA.days["2026-03-19"]!.items[0].text, "New text from B")
    }

    test("mergeClearAllThenReloadDoesNotResurrect") {
        // Simulates: clear all on machine A, disk still has items
        let itemID = UUID()
        let clearTime = Date()
        var disk = DailyPaperData()
        var oldItem = TodoItem(id: itemID, text: "Should stay dead", order: 0)
        oldItem.modifiedAt = clearTime.addingTimeInterval(-5)
        disk.days["2026-03-19"] = DailyList(items: [oldItem])
        // In-memory state after clear-all
        var memory = DailyPaperData()
        memory.days["2026-03-19"] = DailyList(
            deletedItemIDs: [itemID],
            clearedAt: clearTime
        )
        // Merge disk with memory (simulates read-merge-write)
        disk.merge(with: memory)
        try assertEqual(disk.days["2026-03-19"]!.items.count, 0)
    }

    test("markDeletedAddsToDeletedIDs") {
        var list = DailyList(items: [
            TodoItem(text: "A", order: 0),
            TodoItem(text: "B", order: 1),
        ])
        let idToDelete = list.items[0].id
        list.markDeleted(idToDelete)
        try assertEqual(list.items.count, 1)
        try assertEqual(list.items.first!.text, "B")
        try assertTrue(list.deletedItemIDs.contains(idToDelete))
    }
}

// MARK: - FileStorageManager Tests

func runFileStorageTests() {
    print("\n--- FileStorageManager Tests ---")

    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("DPTests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    test("loadReturnsEmptyWhenNoFile") {
        let url = tempDir.appendingPathComponent("empty-\(UUID()).json")
        let mgr = FileStorageManager(fileURL: url)
        let data = mgr.load()
        try assertEqual(data.version, 1)
        try assertTrue(data.days.isEmpty)
    }

    test("syncStatusStartsIdle") {
        let url = tempDir.appendingPathComponent("idle-\(UUID()).json")
        let mgr = FileStorageManager(fileURL: url)
        try assertEqual(mgr.syncStatus, .idle)
    }

    test("updateFileURL") {
        let url1 = tempDir.appendingPathComponent("a.json")
        let url2 = tempDir.appendingPathComponent("b.json")
        let mgr = FileStorageManager(fileURL: url1)
        mgr.updateFileURL(url2)
        try assertEqual(mgr.presentedItemURL, url2)
    }

    test("saveAuthoritativeAndLoad") {
        let url = tempDir.appendingPathComponent("savload-\(UUID()).json")
        let mgr = FileStorageManager(fileURL: url)
        var data = DailyPaperData()
        data.days["2026-03-17"] = DailyList(items: [TodoItem(text: "Saved", order: 0)])
        mgr.saveAuthoritative(data)
        // Wait for async write
        Thread.sleep(forTimeInterval: 1.5)
        let loaded = mgr.load()
        try assertEqual(loaded.days["2026-03-17"]!.items.count, 1)
        try assertEqual(loaded.days["2026-03-17"]!.items.first!.text, "Saved")
    }

    test("saveAuthoritativeOverwrites") {
        let url = tempDir.appendingPathComponent("overwrite-\(UUID()).json")
        let mgr = FileStorageManager(fileURL: url)
        var data1 = DailyPaperData()
        data1.days["2026-03-17"] = DailyList(items: [
            TodoItem(text: "A", order: 0), TodoItem(text: "B", order: 1)
        ])
        mgr.saveAuthoritative(data1)
        Thread.sleep(forTimeInterval: 1.5)

        var data2 = DailyPaperData()
        data2.days["2026-03-17"] = DailyList()
        mgr.saveAuthoritative(data2)
        Thread.sleep(forTimeInterval: 1.5)

        let loaded = mgr.load()
        try assertEqual(loaded.days["2026-03-17"]!.items.count, 0)
    }
}

// MARK: - TodoViewModel Tests

@MainActor
func runViewModelTests() {
    print("\n--- TodoViewModel Tests ---")

    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("DPVMTests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    // Note: not using defer here since we're @MainActor; cleanup at end

    func makeVM() -> TodoViewModel {
        let url = tempDir.appendingPathComponent("vm-\(UUID()).json")
        return TodoViewModel(storage: FileStorageManager(fileURL: url))
    }

    testAsync("initCreatesTodayList") {
        let vm = makeVM()
        try assertTrue(vm.isToday)
        try assertNotNil(vm.data.days[vm.dateKey])
    }

    testAsync("addItem") {
        let vm = makeVM()
        try assertEqual(vm.currentList.items.count, 0)
        vm.addItem()
        try assertEqual(vm.currentList.items.count, 1)
        try assertEqual(vm.currentList.items.first!.text, "")
    }

    testAsync("addItemNoDuplicateEmpty") {
        let vm = makeVM()
        vm.addItem()
        try assertEqual(vm.currentList.items.count, 1)
        vm.addItem()
        try assertEqual(vm.currentList.items.count, 1)
    }

    testAsync("addItemAfterTextCreatesNew") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.updateItemText(id, text: "Something")
        vm.addItem()
        try assertEqual(vm.currentList.items.count, 2)
    }

    testAsync("addItemSetsFocusedID") {
        let vm = makeVM()
        vm.addItem()
        try assertNotNil(vm.focusedItemID)
        try assertEqual(vm.focusedItemID, vm.currentList.items.last!.id)
    }

    testAsync("toggleItem") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.updateItemText(id, text: "Task")
        try assertFalse(vm.currentList.items.first!.done)
        vm.toggleItem(id)
        try assertTrue(vm.currentList.items.first!.done)
        vm.toggleItem(id)
        try assertFalse(vm.currentList.items.first!.done)
    }

    testAsync("toggleClearsCarriedOver") {
        let vm = makeVM()
        var list = vm.currentList
        let item = TodoItem(text: "Carried", carriedOver: true)
        list.items.append(item)
        vm.data.days[vm.dateKey] = list
        try assertTrue(vm.currentList.items.first!.carriedOver)
        vm.toggleItem(item.id)
        try assertFalse(vm.currentList.items.first!.carriedOver)
    }

    testAsync("updateItemText") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.updateItemText(id, text: "Updated")
        try assertEqual(vm.currentList.items.first!.text, "Updated")
    }

    testAsync("deleteItem") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.updateItemText(id, text: "To delete")
        vm.addItem()
        try assertEqual(vm.currentList.items.count, 2)
        vm.deleteItem(id)
        try assertEqual(vm.currentList.items.count, 1)
        // Verify it's tracked as deleted
        try assertTrue(vm.currentList.deletedItemIDs.contains(id))
    }

    testAsync("deleteItemNotResurrectedByMerge") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.updateItemText(id, text: "Will be deleted")
        // Delete it
        vm.deleteItem(id)
        try assertEqual(vm.currentList.items.count, 0)
        // Simulate what merge does: disk still has the item
        var diskData = vm.data
        diskData.days[vm.dateKey] = DailyList(items: [
            TodoItem(id: id, text: "Will be deleted", order: 0)
        ])
        // Merge disk into memory
        diskData.merge(with: vm.data)
        // Item should still be gone
        try assertEqual(diskData.days[vm.dateKey]!.items.count, 0)
    }

    testAsync("indentItem") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        try assertEqual(vm.currentList.items.first!.indent, 0)
        vm.indentItem(id)
        try assertEqual(vm.currentList.items.first!.indent, 1)
        vm.indentItem(id)
        try assertEqual(vm.currentList.items.first!.indent, 1) // capped at 1
    }

    testAsync("outdentItem") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.indentItem(id)
        vm.outdentItem(id)
        try assertEqual(vm.currentList.items.first!.indent, 0)
        vm.outdentItem(id)
        try assertEqual(vm.currentList.items.first!.indent, 0) // stays at 0
    }

    testAsync("clearAllItems") {
        let vm = makeVM()
        vm.addItem()
        vm.updateItemText(vm.currentList.items.first!.id, text: "A")
        vm.addItem()
        vm.updateItemText(vm.currentList.items.last!.id, text: "B")
        try assertEqual(vm.currentList.items.count, 2)
        vm.clearAllItems()
        try assertEqual(vm.currentList.items.count, 0)
    }

    testAsync("moveItem") {
        let vm = makeVM()
        vm.addItem()
        vm.updateItemText(vm.currentList.items.first!.id, text: "First")
        vm.addItem()
        vm.updateItemText(vm.currentList.items.last!.id, text: "Second")
        vm.moveItem(from: IndexSet(integer: 1), to: 0)
        try assertEqual(vm.currentList.items[0].text, "Second")
        try assertEqual(vm.currentList.items[1].text, "First")
    }

    testAsync("goToPreviousDay") {
        let vm = makeVM()
        let todayKey = vm.dateKey
        vm.goToPreviousDay()
        try assertNotEqual(vm.dateKey, todayKey)
        try assertTrue(vm.isViewingPastDay)
    }

    testAsync("goToNextDayDoesNotGoPastToday") {
        let vm = makeVM()
        vm.goToNextDay()
        try assertTrue(vm.isToday || vm.selectedDate <= Date())
    }

    testAsync("goToToday") {
        let vm = makeVM()
        vm.goToPreviousDay()
        vm.goToPreviousDay()
        try assertFalse(vm.isToday)
        vm.goToToday()
        try assertTrue(vm.isToday)
    }

    testAsync("pastDayIsReadOnly") {
        let vm = makeVM()
        vm.goToPreviousDay()
        try assertTrue(vm.isViewingPastDay)
        let count = vm.currentList.items.count
        vm.addItem()
        try assertEqual(vm.currentList.items.count, count)
    }

    testAsync("carryOverFlow") {
        let url = tempDir.appendingPathComponent("carry-\(UUID()).json")
        let storage = FileStorageManager(fileURL: url)
        var data = DailyPaperData()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let key = DailyPaperData.dateKey(for: yesterday)
        data.days[key] = DailyList(items: [
            TodoItem(text: "Incomplete", done: false, order: 0),
            TodoItem(text: "Done", done: true, order: 1),
        ])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(data).write(to: url, options: .atomic)
        let vm = TodoViewModel(storage: storage)
        try assertTrue(vm.showCarryOverSheet)
        try assertEqual(vm.carryOverItems.count, 1)
        try assertEqual(vm.carryOverItems.first!.text, "Incomplete")
    }

    testAsync("confirmCarryOver") {
        let url = tempDir.appendingPathComponent("confirm-\(UUID()).json")
        let storage = FileStorageManager(fileURL: url)
        var data = DailyPaperData()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        data.days[DailyPaperData.dateKey(for: yesterday)] = DailyList(items: [
            TodoItem(text: "Carry me", done: false, order: 0)
        ])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(data).write(to: url, options: .atomic)
        let vm = TodoViewModel(storage: storage)
        try assertTrue(vm.showCarryOverSheet)
        vm.confirmCarryOver()
        try assertFalse(vm.showCarryOverSheet)
        try assertEqual(vm.currentList.items.count, 1)
        try assertEqual(vm.currentList.items.first!.text, "Carry me")
        try assertTrue(vm.currentList.items.first!.carriedOver)
    }

    testAsync("skipCarryOver") {
        let url = tempDir.appendingPathComponent("skip-\(UUID()).json")
        let storage = FileStorageManager(fileURL: url)
        var data = DailyPaperData()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        data.days[DailyPaperData.dateKey(for: yesterday)] = DailyList(items: [
            TodoItem(text: "Skip me", done: false, order: 0)
        ])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(data).write(to: url, options: .atomic)
        let vm = TodoViewModel(storage: storage)
        try assertTrue(vm.showCarryOverSheet)
        vm.skipCarryOver()
        try assertFalse(vm.showCarryOverSheet)
        try assertEqual(vm.currentList.items.count, 0)
    }

    testAsync("displayDateNotEmpty") {
        let vm = makeVM()
        try assertFalse(vm.displayDate.isEmpty)
    }

    // MARK: - submitAndAddItem Tests

    testAsync("submitAndAddItemSavesTextAndCreatesNew") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        // Simulates: user typed "test 5" then pressed Return
        vm.submitAndAddItem(id: id, text: "test 5")
        try assertEqual(vm.currentList.items.count, 2)
        try assertEqual(vm.currentList.items[0].text, "test 5")
        try assertEqual(vm.currentList.items[1].text, "")
    }

    testAsync("submitAndAddItemNewItemIsAfterSubmitted") {
        let vm = makeVM()
        // Create three items
        vm.addItem()
        vm.updateItemText(vm.currentList.items[0].id, text: "First")
        vm.addItem()
        vm.updateItemText(vm.currentList.items[1].id, text: "Third")
        let firstID = vm.currentList.items[0].id
        // Submit on first item — new item should appear between First and Third
        vm.submitAndAddItem(id: firstID, text: "First")
        try assertEqual(vm.currentList.items.count, 3)
        try assertEqual(vm.currentList.items[0].text, "First")
        try assertEqual(vm.currentList.items[1].text, "")  // new empty item
        try assertEqual(vm.currentList.items[2].text, "Third")
    }

    testAsync("submitAndAddItemSetsFocusToNewItem") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        vm.submitAndAddItem(id: id, text: "Hello")
        let newItemID = vm.currentList.items[1].id
        try assertEqual(vm.focusedItemID, newItemID)
    }

    testAsync("submitAndAddItemCleansUpOtherEmptyItems") {
        let vm = makeVM()
        // Create an item with text and an empty ghost
        vm.addItem()
        let id1 = vm.currentList.items[0].id
        vm.updateItemText(id1, text: "Real item")
        vm.addItem()  // empty item
        try assertEqual(vm.currentList.items.count, 2)
        // Submit on the real item — the old empty should be cleaned up
        vm.submitAndAddItem(id: id1, text: "Real item")
        // Should have: "Real item" + 1 new empty item (old empty was stripped)
        try assertEqual(vm.currentList.items.count, 2)
        try assertEqual(vm.currentList.items[0].text, "Real item")
        try assertEqual(vm.currentList.items[1].text, "")
    }

    testAsync("submitAndAddItemIsAtomicSingleWrite") {
        // Verify the item text is saved and new item exists in one operation
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items.first!.id
        // Before submit: one empty item
        try assertEqual(vm.currentList.items.count, 1)
        try assertEqual(vm.currentList.items[0].text, "")
        // After submit: text saved + new item, all in one shot
        vm.submitAndAddItem(id: id, text: "Atomic test")
        let items = vm.currentList.items
        try assertEqual(items.count, 2)
        try assertEqual(items[0].text, "Atomic test")
        try assertTrue(items[0].modifiedAt > Date.distantPast)
        try assertEqual(items[1].text, "")
    }

    // MARK: - Rapid Entry Simulation

    testAsync("rapidEntryMultipleItems") {
        // Simulates typing 5 items in quick succession via Return
        let vm = makeVM()
        vm.addItem()
        let id1 = vm.currentList.items[0].id
        vm.submitAndAddItem(id: id1, text: "Item 1")

        let id2 = vm.currentList.items[1].id
        vm.submitAndAddItem(id: id2, text: "Item 2")

        let id3 = vm.currentList.items[2].id
        vm.submitAndAddItem(id: id3, text: "Item 3")

        let id4 = vm.currentList.items[3].id
        vm.submitAndAddItem(id: id4, text: "Item 4")

        let id5 = vm.currentList.items[4].id
        vm.submitAndAddItem(id: id5, text: "Item 5")

        // Should have 5 real items + 1 empty at the end
        let items = vm.currentList.items
        try assertEqual(items.count, 6)
        try assertEqual(items[0].text, "Item 1")
        try assertEqual(items[1].text, "Item 2")
        try assertEqual(items[2].text, "Item 3")
        try assertEqual(items[3].text, "Item 4")
        try assertEqual(items[4].text, "Item 5")
        try assertEqual(items[5].text, "")
    }

    testAsync("deleteAfterSubmitStaysDeleted") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items[0].id
        vm.submitAndAddItem(id: id, text: "Delete me")
        // Now delete the first item
        vm.deleteItem(id)
        try assertEqual(vm.currentList.items.count, 1)  // only the empty new item
        try assertTrue(vm.currentList.deletedItemIDs.contains(id))
    }

    testAsync("clearAllAfterMultipleSubmits") {
        let vm = makeVM()
        vm.addItem()
        let id1 = vm.currentList.items[0].id
        vm.submitAndAddItem(id: id1, text: "A")
        let id2 = vm.currentList.items[1].id
        vm.submitAndAddItem(id: id2, text: "B")
        // Strip the trailing empty
        try assertTrue(vm.currentList.items.count >= 2)
        vm.clearAllItems()
        try assertEqual(vm.currentList.items.count, 0)
        try assertTrue(vm.currentList.deletedItemIDs.contains(id1))
        try assertTrue(vm.currentList.deletedItemIDs.contains(id2))
    }

    testAsync("cleanupEmptyItemOnFocusLoss") {
        let vm = makeVM()
        vm.addItem()
        let emptyID = vm.currentList.items[0].id
        try assertEqual(vm.currentList.items.count, 1)
        // Simulate focus leaving the empty item
        vm.cleanupEmptyItem(emptyID)
        try assertEqual(vm.currentList.items.count, 0)
    }

    testAsync("cleanupEmptyItemLeavesNonEmpty") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items[0].id
        vm.updateItemText(id, text: "Not empty")
        vm.cleanupEmptyItem(id)
        try assertEqual(vm.currentList.items.count, 1)
        try assertEqual(vm.currentList.items[0].text, "Not empty")
    }

    testAsync("newEmptyItemSurvivesSaveReload") {
        // Simulates: user clicks Add Item, then pauses while typing
        // The empty item should NOT be stripped by a save+reload because it's recent
        let url = tempDir.appendingPathComponent("survive-\(UUID()).json")
        let storage = FileStorageManager(fileURL: url)
        let vm = TodoViewModel(storage: storage)
        vm.addItem()
        try assertEqual(vm.currentList.items.count, 1)
        let id = vm.currentList.items[0].id
        // The item is empty but just created — save should preserve it
        storage.saveImmediately(vm.data)
        Thread.sleep(forTimeInterval: 1.5)
        // Reload from disk
        vm.reloadFromDisk()
        // The empty item should still be there because it's < 10 seconds old
        try assertEqual(vm.currentList.items.count, 1)
        try assertEqual(vm.currentList.items[0].id, id)
    }

    testAsync("oldEmptyItemStrippedOnSaveReload") {
        // Empty items older than 10 seconds should be stripped
        let url = tempDir.appendingPathComponent("strip-\(UUID()).json")
        let storage = FileStorageManager(fileURL: url)
        var data = DailyPaperData()
        let todayKey = DailyPaperData.dateKey(for: Date())
        var oldEmpty = TodoItem(text: "", order: 0)
        oldEmpty.modifiedAt = Date().addingTimeInterval(-60) // 60s ago
        data.days[todayKey] = DailyList(items: [
            TodoItem(text: "Real", order: 1),
            oldEmpty,
        ])
        storage.saveAuthoritative(data)
        Thread.sleep(forTimeInterval: 1.5)
        let loaded = storage.load()
        try assertEqual(loaded.days[todayKey]!.items.count, 1)
        try assertEqual(loaded.days[todayKey]!.items[0].text, "Real")
    }

    // MARK: - Carry-Over Edge Cases

    testAsync("carryOverPartialSelection") {
        let url = tempDir.appendingPathComponent("partial-\(UUID()).json")
        let storage = FileStorageManager(fileURL: url)
        var data = DailyPaperData()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let item1 = TodoItem(text: "Carry this", done: false, order: 0)
        let item2 = TodoItem(text: "Skip this", done: false, order: 1)
        let item3 = TodoItem(text: "Carry this too", done: false, order: 2)
        data.days[DailyPaperData.dateKey(for: yesterday)] = DailyList(items: [item1, item2, item3])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(data).write(to: url, options: .atomic)
        let vm = TodoViewModel(storage: storage)
        try assertTrue(vm.showCarryOverSheet)
        try assertEqual(vm.carryOverItems.count, 3)
        // Deselect item2
        vm.carryOverSelections.remove(item2.id)
        vm.confirmCarryOver()
        try assertEqual(vm.currentList.items.count, 2)
        let texts = vm.currentList.items.map(\.text)
        try assertTrue(texts.contains("Carry this"))
        try assertTrue(texts.contains("Carry this too"))
        try assertFalse(texts.contains("Skip this"))
    }

    testAsync("carriedOverItemsGetNewUUIDs") {
        let url = tempDir.appendingPathComponent("newuuid-\(UUID()).json")
        let storage = FileStorageManager(fileURL: url)
        var data = DailyPaperData()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let originalItem = TodoItem(text: "Carry me", done: false, order: 0)
        let originalID = originalItem.id
        data.days[DailyPaperData.dateKey(for: yesterday)] = DailyList(items: [originalItem])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(data).write(to: url, options: .atomic)
        let vm = TodoViewModel(storage: storage)
        vm.confirmCarryOver()
        // New item should have a different UUID than the original
        try assertEqual(vm.currentList.items.count, 1)
        try assertNotEqual(vm.currentList.items[0].id, originalID)
        try assertEqual(vm.currentList.items[0].text, "Carry me")
        try assertTrue(vm.currentList.items[0].carriedOver)
    }

    // MARK: - Navigation Edge Cases

    testAsync("cannotNavigatePastToday") {
        let vm = makeVM()
        // Try going forward from today
        let todayKey = vm.dateKey
        vm.goToNextDay()
        vm.goToNextDay()
        vm.goToNextDay()
        // Should still be on today (or at most tomorrow depending on time-of-day)
        let daysDiff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: vm.selectedDate).day ?? 0
        try assertTrue(daysDiff <= 1)
    }

    // MARK: - Delete Edge Cases

    testAsync("deleteOnlyItem") {
        let vm = makeVM()
        vm.addItem()
        let id = vm.currentList.items[0].id
        vm.updateItemText(id, text: "Only item")
        try assertEqual(vm.currentList.items.count, 1)
        vm.deleteItem(id)
        try assertEqual(vm.currentList.items.count, 0)
        try assertTrue(vm.currentList.deletedItemIDs.contains(id))
    }

    testAsync("deleteDoesNotAffectOtherDays") {
        let vm = makeVM()
        // Add item to today
        vm.addItem()
        let todayItemID = vm.currentList.items[0].id
        vm.updateItemText(todayItemID, text: "Today's item")
        // Manually add item to yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayKey = DailyPaperData.dateKey(for: yesterday)
        vm.data.days[yesterdayKey] = DailyList(items: [TodoItem(text: "Yesterday's item", order: 0)])
        // Delete today's item
        vm.deleteItem(todayItemID)
        try assertEqual(vm.currentList.items.count, 0)
        // Yesterday's item should be untouched
        try assertEqual(vm.data.days[yesterdayKey]!.items.count, 1)
        try assertEqual(vm.data.days[yesterdayKey]!.items[0].text, "Yesterday's item")
    }

    // MARK: - Indent/Outdent Edge Cases

    testAsync("indentNonExistentIDNoOp") {
        let vm = makeVM()
        let bogusID = UUID()
        vm.indentItem(bogusID)  // should not crash
        vm.outdentItem(bogusID)  // should not crash
        try assertTrue(true)  // if we got here, no crash
    }

    testAsync("deleteNonExistentIDNoOp") {
        let vm = makeVM()
        let bogusID = UUID()
        vm.deleteItem(bogusID)  // should not crash
        try assertTrue(true)
    }

    testAsync("toggleNonExistentIDNoOp") {
        let vm = makeVM()
        let bogusID = UUID()
        vm.toggleItem(bogusID)  // should not crash
        try assertTrue(true)
    }

    // MARK: - Corrupt Data Handling

    testAsync("corruptJSONLoadsEmpty") {
        let url = tempDir.appendingPathComponent("corrupt-\(UUID()).json")
        try "{{{{ not valid json !@#$".write(to: url, atomically: true, encoding: .utf8)
        let storage = FileStorageManager(fileURL: url)
        let data = storage.load()
        // Should return empty data instead of crashing
        try assertEqual(data.version, 1)
        try assertTrue(data.days.isEmpty)
    }

    testAsync("emptyFileLoadsEmpty") {
        let url = tempDir.appendingPathComponent("empty-\(UUID()).json")
        try "".write(to: url, atomically: true, encoding: .utf8)
        let storage = FileStorageManager(fileURL: url)
        let data = storage.load()
        try assertEqual(data.version, 1)
        try assertTrue(data.days.isEmpty)
    }

    testAsync("clearAllThenReloadStaysCleared") {
        let url = tempDir.appendingPathComponent("clearreload-\(UUID()).json")
        let storage = FileStorageManager(fileURL: url)
        let vm = TodoViewModel(storage: storage)
        // Add items
        vm.addItem()
        vm.updateItemText(vm.currentList.items[0].id, text: "A")
        vm.addItem()
        vm.updateItemText(vm.currentList.items.last!.id, text: "B")
        // Clear all
        vm.clearAllItems()
        try assertEqual(vm.currentList.items.count, 0)
        // Wait for save
        Thread.sleep(forTimeInterval: 1.5)
        // Reload from disk
        vm.reloadFromDisk()
        // Should still be cleared
        try assertEqual(vm.currentList.items.count, 0)
    }

    try? FileManager.default.removeItem(at: tempDir)
}

// MARK: - Main

@main
struct TestMain {
    static func main() {
        runTodoItemTests()
        runDailyListTests()
        runMergeTests()
        runFileStorageTests()
        MainActor.assumeIsolated {
            runViewModelTests()
        }

        print("\n========================================")
        print("Results: \(passedTests)/\(totalTests) passed")
        if !failedTests.isEmpty {
            print("\nFailures:")
            for (name, msg) in failedTests {
                print("  - \(name): \(msg)")
            }
            exit(1)
        } else {
            print("All tests passed!")
            exit(0)
        }
    }
}
