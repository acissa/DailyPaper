import XCTest
@testable import DailyPaper

final class TodoItemTests: XCTestCase {

    func testDefaultInit() {
        let item = TodoItem()
        XCTAssertFalse(item.done)
        XCTAssertEqual(item.text, "")
        XCTAssertEqual(item.indent, 0)
        XCTAssertEqual(item.order, 0)
        XCTAssertFalse(item.carriedOver)
    }

    func testCustomInit() {
        let item = TodoItem(text: "Buy milk", done: true, indent: 1, order: 3, carriedOver: true)
        XCTAssertEqual(item.text, "Buy milk")
        XCTAssertTrue(item.done)
        XCTAssertEqual(item.indent, 1)
        XCTAssertEqual(item.order, 3)
        XCTAssertTrue(item.carriedOver)
    }

    func testMarkModified() {
        var item = TodoItem()
        let before = item.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        item.markModified()
        XCTAssertGreaterThan(item.modifiedAt, before)
    }

    func testCodable() throws {
        let item = TodoItem(text: "Test", done: true, indent: 1, order: 2, carriedOver: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TodoItem.self, from: data)

        XCTAssertEqual(item, decoded)
    }

    func testEquatable() {
        let id = UUID()
        let a = TodoItem(id: id, text: "Same", done: false, indent: 0, order: 0)
        let b = TodoItem(id: id, text: "Same", done: false, indent: 0, order: 0)
        XCTAssertEqual(a, b)

        let c = TodoItem(text: "Different")
        XCTAssertNotEqual(a, c)
    }
}
