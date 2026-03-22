import Foundation

struct DailyList: Codable, Equatable {
    var items: [TodoItem]
    /// UUIDs of items that were explicitly deleted — prevents merge from resurrecting them.
    var deletedItemIDs: Set<UUID>
    /// When set, items with modifiedAt before this date are considered deleted by a clear-all.
    var clearedAt: Date?

    init(items: [TodoItem] = [], deletedItemIDs: Set<UUID> = [], clearedAt: Date? = nil) {
        self.items = items
        self.deletedItemIDs = deletedItemIDs
        self.clearedAt = clearedAt
    }

    // Custom decoder to handle JSON files that don't have deletedItemIDs yet
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([TodoItem].self, forKey: .items) ?? []
        deletedItemIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .deletedItemIDs) ?? []
        clearedAt = try container.decodeIfPresent(Date.self, forKey: .clearedAt)
    }

    var incompleteItems: [TodoItem] {
        items.filter { !$0.done }
    }

    mutating func reindex() {
        for i in items.indices {
            items[i].order = i
        }
    }

    /// Record an item as deleted so merge won't bring it back.
    mutating func markDeleted(_ id: UUID) {
        items.removeAll { $0.id == id }
        deletedItemIDs.insert(id)
    }
}

struct DailyPaperData: Codable, Equatable {
    var version: Int = 1
    var days: [String: DailyList]

    init(version: Int = 1, days: [String: DailyList] = [:]) {
        self.version = version
        self.days = days
    }

    static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func dateKey(for date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    func list(for date: Date) -> DailyList? {
        days[Self.dateKey(for: date)]
    }

    mutating func setList(_ list: DailyList, for date: Date) {
        days[Self.dateKey(for: date)] = list
    }

    /// Returns the most recent day before the given date that has a list.
    func mostRecentDay(before date: Date) -> (String, DailyList)? {
        let key = Self.dateKey(for: date)
        let sorted = days.keys.sorted().reversed()
        for dayKey in sorted {
            if dayKey < key, let list = days[dayKey] {
                return (dayKey, list)
            }
        }
        return nil
    }

    /// Remove items with empty text from all days — these are transient UI placeholders.
    /// Preserves recently-created items (< 10 seconds old) so the user can finish typing.
    mutating func stripEmptyItems() {
        let now = Date()
        for key in days.keys {
            days[key]?.items.removeAll {
                $0.text.trimmingCharacters(in: .whitespaces).isEmpty
                && now.timeIntervalSince($0.modifiedAt) > 10
            }
        }
    }

    /// Merge another copy of the data, preferring items with later modifiedAt timestamps.
    /// Respects `deletedItemIDs` and `clearedAt` to prevent resurrection of deleted items.
    mutating func merge(with other: DailyPaperData) {
        for (dayKey, otherList) in other.days {
            guard var localList = days[dayKey] else {
                days[dayKey] = otherList
                continue
            }

            // Use the most recent clearedAt from either side
            let effectiveClearedAt: Date? = {
                switch (localList.clearedAt, otherList.clearedAt) {
                case let (a?, b?): return max(a, b)
                case let (a?, nil): return a
                case let (nil, b?): return b
                case (nil, nil): return nil
                }
            }()

            // Union of deleted IDs from both sides — once deleted, stays deleted
            let allDeletedIDs = localList.deletedItemIDs.union(otherList.deletedItemIDs)

            // Start with the "other" (in-memory) items as the base — these represent current intent
            var merged: [UUID: TodoItem] = [:]
            for item in otherList.items {
                merged[item.id] = item
            }

            // Layer in disk items only if they're newer AND not deleted
            for localItem in localList.items {
                if allDeletedIDs.contains(localItem.id) {
                    continue  // Explicitly deleted — don't resurrect
                }
                if let existing = merged[localItem.id] {
                    // In-memory version exists — keep whichever is newer
                    if localItem.modifiedAt > existing.modifiedAt {
                        merged[localItem.id] = localItem
                    }
                } else {
                    // Item exists on disk but not in memory — it was deleted in memory
                    // Only bring it back if it's NOT in the deletedItemIDs
                    if !allDeletedIDs.contains(localItem.id) {
                        // This is a genuinely new item from another machine — keep it
                        // But only if the other side doesn't have deletedItemIDs tracking
                        // (i.e., it was added on another machine after our last sync)
                        if localItem.modifiedAt > (otherList.clearedAt ?? .distantPast) {
                            merged[localItem.id] = localItem
                        }
                    }
                }
            }

            // Drop items that predate the clear
            if let cleared = effectiveClearedAt {
                merged = merged.filter { $0.value.modifiedAt > cleared }
            }

            // Remove any explicitly deleted items
            for deletedID in allDeletedIDs {
                merged.removeValue(forKey: deletedID)
            }

            localList.items = merged.values.sorted { $0.order < $1.order }
            localList.clearedAt = effectiveClearedAt
            localList.deletedItemIDs = allDeletedIDs
            days[dayKey] = localList
        }
    }
}
