import XCTest
@testable import DailyPaper

final class DailyListTests: XCTestCase {

    // MARK: - DailyList

    func testIncompleteItems() {
        let list = DailyList(items: [
            TodoItem(text: "Done", done: true, order: 0),
            TodoItem(text: "Not done", done: false, order: 1),
            TodoItem(text: "Also not done", done: false, order: 2),
        ])
        let incomplete = list.incompleteItems
        XCTAssertEqual(incomplete.count, 2)
        XCTAssertTrue(incomplete.allSatisfy { !$0.done })
    }

    func testReindex() {
        var list = DailyList(items: [
            TodoItem(text: "A", order: 5),
            TodoItem(text: "B", order: 10),
            TodoItem(text: "C", order: 20),
        ])
        list.reindex()
        XCTAssertEqual(list.items[0].order, 0)
        XCTAssertEqual(list.items[1].order, 1)
        XCTAssertEqual(list.items[2].order, 2)
    }

    func testEmptyListIncompleteItems() {
        let list = DailyList()
        XCTAssertTrue(list.incompleteItems.isEmpty)
    }

    // MARK: - DailyPaperData

    func testDateKey() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let date = formatter.date(from: "2026-03-17")!
        XCTAssertEqual(DailyPaperData.dateKey(for: date), "2026-03-17")
    }

    func testListForDate() {
        var data = DailyPaperData()
        let date = makeDate("2026-03-17")
        let list = DailyList(items: [TodoItem(text: "Hello")])

        data.setList(list, for: date)
        let retrieved = data.list(for: date)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.items.count, 1)
        XCTAssertEqual(retrieved?.items.first?.text, "Hello")
    }

    func testListForDateReturnsNilWhenMissing() {
        let data = DailyPaperData()
        let date = makeDate("2026-01-01")
        XCTAssertNil(data.list(for: date))
    }

    func testMostRecentDayBefore() {
        var data = DailyPaperData()
        data.days["2026-03-15"] = DailyList(items: [TodoItem(text: "Old")])
        data.days["2026-03-16"] = DailyList(items: [TodoItem(text: "Yesterday")])
        data.days["2026-03-17"] = DailyList(items: [TodoItem(text: "Today")])

        let target = makeDate("2026-03-17")
        let result = data.mostRecentDay(before: target)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, "2026-03-16")
        XCTAssertEqual(result?.1.items.first?.text, "Yesterday")
    }

    func testMostRecentDayBeforeReturnsNilIfNone() {
        var data = DailyPaperData()
        data.days["2026-03-17"] = DailyList(items: [TodoItem(text: "Today")])

        let target = makeDate("2026-03-17")
        XCTAssertNil(data.mostRecentDay(before: target))
    }

    // MARK: - Merge

    func testMergeAddsNewDays() {
        var local = DailyPaperData()
        local.days["2026-03-17"] = DailyList(items: [TodoItem(text: "Local")])

        var remote = DailyPaperData()
        remote.days["2026-03-18"] = DailyList(items: [TodoItem(text: "Remote")])

        local.merge(with: remote)
        XCTAssertNotNil(local.days["2026-03-17"])
        XCTAssertNotNil(local.days["2026-03-18"])
    }

    func testMergeAddsNewItems() {
        let id1 = UUID()
        let id2 = UUID()

        var local = DailyPaperData()
        local.days["2026-03-17"] = DailyList(items: [
            TodoItem(id: id1, text: "Local item", order: 0)
        ])

        var remote = DailyPaperData()
        remote.days["2026-03-17"] = DailyList(items: [
            TodoItem(id: id2, text: "Remote item", order: 1)
        ])

        local.merge(with: remote)
        let merged = local.days["2026-03-17"]!
        XCTAssertEqual(merged.items.count, 2)
    }

    func testMergeLastWriteWins() {
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
        XCTAssertEqual(item.text, "New text")
        XCTAssertTrue(item.done)
    }

    func testMergeLocalWinsWhenNewer() {
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
        XCTAssertEqual(item.text, "Local newer")
        XCTAssertFalse(item.done)
    }

    // MARK: - Codable Round-Trip

    func testFullDataCodable() throws {
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

        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.days["2026-03-17"]?.items.count, 2)
        XCTAssertEqual(decoded.days["2026-03-17"]?.items[1].text, "Task 2")
        XCTAssertTrue(decoded.days["2026-03-17"]?.items[1].carriedOver ?? false)
    }

    // MARK: - Helpers

    private func makeDate(_ string: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: string)!
    }
}
