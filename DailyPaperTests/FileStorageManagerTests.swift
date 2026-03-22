import XCTest
@testable import DailyPaper

final class FileStorageManagerTests: XCTestCase {

    var tempDir: URL!
    var tempFileURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyPaperTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempFileURL = tempDir.appendingPathComponent("test-daily-paper.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testLoadReturnsEmptyDataWhenFileDoesNotExist() {
        let manager = FileStorageManager(fileURL: tempFileURL)
        let data = manager.load()
        XCTAssertEqual(data.version, 1)
        XCTAssertTrue(data.days.isEmpty)
    }

    func testSaveAndLoadRoundTrip() {
        let manager = FileStorageManager(fileURL: tempFileURL)

        var data = DailyPaperData()
        data.days["2026-03-17"] = DailyList(items: [
            TodoItem(text: "Test item", done: false, order: 0)
        ])

        // Use saveAuthoritative for immediate, non-debounced write
        manager.saveAuthoritative(data)

        // Wait for async write
        let expectation = expectation(description: "Write completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        let loaded = manager.load()
        XCTAssertEqual(loaded.days["2026-03-17"]?.items.count, 1)
        XCTAssertEqual(loaded.days["2026-03-17"]?.items.first?.text, "Test item")
    }

    func testSaveAuthoritativeOverwritesCompletely() {
        let manager = FileStorageManager(fileURL: tempFileURL)

        // Write initial data
        var data1 = DailyPaperData()
        data1.days["2026-03-17"] = DailyList(items: [
            TodoItem(text: "Item A", order: 0),
            TodoItem(text: "Item B", order: 1),
        ])
        manager.saveAuthoritative(data1)

        let exp1 = expectation(description: "First write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { exp1.fulfill() }
        wait(for: [exp1], timeout: 3.0)

        // Overwrite with empty list
        var data2 = DailyPaperData()
        data2.days["2026-03-17"] = DailyList()
        manager.saveAuthoritative(data2)

        let exp2 = expectation(description: "Second write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { exp2.fulfill() }
        wait(for: [exp2], timeout: 3.0)

        let loaded = manager.load()
        XCTAssertEqual(loaded.days["2026-03-17"]?.items.count, 0)
    }

    func testUpdateFileURL() {
        let manager = FileStorageManager(fileURL: tempFileURL)
        let newURL = tempDir.appendingPathComponent("other.json")
        manager.updateFileURL(newURL)
        XCTAssertEqual(manager.presentedItemURL, newURL)
    }

    func testSyncStatusStartsIdle() {
        let manager = FileStorageManager(fileURL: tempFileURL)
        XCTAssertEqual(manager.syncStatus, .idle)
    }
}
