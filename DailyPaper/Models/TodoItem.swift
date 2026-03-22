import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var done: Bool
    var indent: Int
    var order: Int
    var carriedOver: Bool
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        text: String = "",
        done: Bool = false,
        indent: Int = 0,
        order: Int = 0,
        carriedOver: Bool = false,
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.done = done
        self.indent = indent
        self.order = order
        self.carriedOver = carriedOver
        self.modifiedAt = modifiedAt
    }

    mutating func markModified() {
        modifiedAt = Date()
    }
}
