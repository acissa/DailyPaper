# Daily Paper

A native macOS app that replicates the experience of a paper daily todo list on your desktop. No chrome, no sidebar, no tabs — just today's list.

## Features

- **Daily lists** — each day gets its own list, keyed by date
- **Carry-over** — when starting a new day, choose which incomplete items to bring forward
- **Auto day change** — detects midnight rollover and app reactivation, prompts for a new day automatically
- **iCloud Drive sync** — single JSON file syncs across machines via iCloud Drive
- **Conflict-safe** — uses `NSFilePresenter`/`NSFileCoordinator` with UUID-based merge and deletion tracking
- **Drag to reorder** — rearrange items within a day
- **Indentation** — Tab/Shift-Tab for one level of sub-items
- **Dark mode** — works in both light and dark mode
- **Lightweight** — fast launch, ~300KB binary, no external dependencies

## Screenshots

The app is designed to feel like a clean sheet of paper with simple checkboxes. Minimalist, distraction-free.

## Building

**Requirements:**
- macOS 14+ (Sonoma)
- Swift 5.9+
- Xcode 15+

**From the command line:**

```bash
# Build the app
swiftc -sdk $(xcrun --show-sdk-path) -target arm64-apple-macosx14.0 -O \
  -o DailyPaper -parse-as-library \
  DailyPaper/Models/TodoItem.swift \
  DailyPaper/Models/DailyList.swift \
  DailyPaper/Storage/FileStorageManager.swift \
  DailyPaper/Storage/SyncMonitor.swift \
  DailyPaper/ViewModels/TodoViewModel.swift \
  DailyPaper/Views/TodoItemRow.swift \
  DailyPaper/Views/TodoListView.swift \
  DailyPaper/Views/CarryOverSheet.swift \
  DailyPaper/Views/PreferencesView.swift \
  DailyPaper/Views/MainView.swift \
  DailyPaper/DailyPaperApp.swift

# Run tests
swiftc -sdk $(xcrun --show-sdk-path) -target arm64-apple-macosx14.0 \
  -o DailyPaperTests -parse-as-library \
  DailyPaper/Models/TodoItem.swift \
  DailyPaper/Models/DailyList.swift \
  DailyPaper/Storage/FileStorageManager.swift \
  DailyPaper/Storage/SyncMonitor.swift \
  DailyPaper/ViewModels/TodoViewModel.swift \
  DailyPaperTests/TestRunner.swift && ./DailyPaperTests
```

Or open `DailyPaper.xcodeproj` in Xcode and build.

## Data Storage

All state lives in a single JSON file for iCloud Drive sync:

```
~/Library/Mobile Documents/com~apple~CloudDocs/DailyPaper/daily-paper.json
```

You can change the file location in Preferences. The file format:

```json
{
  "version": 1,
  "days": {
    "2026-03-21": {
      "items": [
        {
          "id": "uuid",
          "text": "Review PR for auth service",
          "done": false,
          "indent": 0,
          "order": 0,
          "carriedOver": false,
          "modifiedAt": "2026-03-21T12:00:00Z"
        }
      ],
      "deletedItemIDs": []
    }
  }
}
```

## Project Structure

```
DailyPaper/
├── DailyPaper.xcodeproj
├── DailyPaper/
│   ├── DailyPaperApp.swift          # App entry point
│   ├── Models/
│   │   ├── TodoItem.swift           # Item model
│   │   └── DailyList.swift          # Day model + full data model
│   ├── Storage/
│   │   ├── FileStorageManager.swift # NSFilePresenter/Coordinator, read/write/merge
│   │   └── SyncMonitor.swift        # File watcher, sync status
│   ├── ViewModels/
│   │   └── TodoViewModel.swift      # Main view model
│   ├── Views/
│   │   ├── MainView.swift           # Container with date nav
│   │   ├── TodoListView.swift       # The list itself
│   │   ├── TodoItemRow.swift        # Single item row
│   │   ├── CarryOverSheet.swift     # Day transition dialog
│   │   └── PreferencesView.swift    # File location setting
│   └── Assets.xcassets
└── DailyPaperTests/
    └── TestRunner.swift             # 63 unit tests
```

## Tests

63 tests covering models, merge logic, file storage, and the view model:

```
--- TodoItem Tests ---        5 tests
--- DailyList Tests ---       8 tests
--- Merge Tests ---          11 tests
--- FileStorageManager ---    5 tests
--- TodoViewModel ---        34 tests
```

## License

MIT
