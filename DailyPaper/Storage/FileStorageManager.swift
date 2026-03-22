import Foundation
import Combine

final class FileStorageManager: NSObject, NSFilePresenter, ObservableObject {

    // MARK: - Published State

    @Published private(set) var syncStatus: SyncStatus = .idle

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case error(String)
    }

    // MARK: - File Presenter

    var presentedItemURL: URL? { fileURL }
    let presentedItemOperationQueue = OperationQueue()

    // MARK: - Private

    private var fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var writeDebounceTask: DispatchWorkItem?
    private let writeQueue = DispatchQueue(label: "com.dailypaper.filewrite", qos: .userInitiated)
    /// Timestamp of our last write — ignore external change notifications within 1 second of our own writes.
    private var lastWriteTime: Date = .distantPast

    /// Called on the main queue when external changes are detected.
    var onExternalChange: (() -> Void)?

    // MARK: - Init

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        super.init()
        ensureDirectory()
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }

    // MARK: - Default Path

    static func defaultFileURL() -> URL {
        let iCloudDocs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/DailyPaper")
        return iCloudDocs.appendingPathComponent("daily-paper.json")
    }

    func updateFileURL(_ newURL: URL) {
        NSFileCoordinator.removeFilePresenter(self)
        fileURL = newURL
        ensureDirectory()
        NSFileCoordinator.addFilePresenter(self)
    }

    // MARK: - Read

    func load() -> DailyPaperData {
        var result = DailyPaperData()
        let coordinator = NSFileCoordinator(filePresenter: self)
        var coordError: NSError?

        coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordError) { url in
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            do {
                let data = try Data(contentsOf: url)
                result = try self.decoder.decode(DailyPaperData.self, from: data)
                result.stripEmptyItems()
            } catch {
                DispatchQueue.main.async {
                    self.syncStatus = .error("Read failed: \(error.localizedDescription)")
                }
            }
        }

        if let err = coordError {
            DispatchQueue.main.async {
                self.syncStatus = .error("Coordination error: \(err.localizedDescription)")
            }
        }

        return result
    }

    // MARK: - Write (debounced, read-merge-write)

    func save(_ data: DailyPaperData) {
        writeDebounceTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.performSave(data)
        }
        writeDebounceTask = task
        writeQueue.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    /// Immediately save without debounce.
    func saveImmediately(_ data: DailyPaperData) {
        writeQueue.async { [weak self] in
            self?.performSave(data)
        }
    }

    /// Overwrite the file without merging. Use for destructive operations like clear-all.
    func saveAuthoritative(_ data: DailyPaperData) {
        writeDebounceTask?.cancel()
        writeQueue.async { [weak self] in
            self?.performSave(data, merge: false)
        }
    }

    private func performSave(_ data: DailyPaperData, merge: Bool = true) {
        DispatchQueue.main.async { self.syncStatus = .syncing }

        let coordinator = NSFileCoordinator(filePresenter: self)
        var coordError: NSError?

        coordinator.coordinate(
            writingItemAt: fileURL,
            options: .forMerging,
            error: &coordError
        ) { url in
            do {
                // Read-merge-write (or direct overwrite if merge == false)
                var merged = data
                if merge, FileManager.default.fileExists(atPath: url.path) {
                    let existingData = try Data(contentsOf: url)
                    var existing = try self.decoder.decode(DailyPaperData.self, from: existingData)
                    existing.merge(with: data)
                    merged = existing
                }

                // Strip out empty items before writing — they're transient UI state, not data
                merged.stripEmptyItems()

                let jsonData = try self.encoder.encode(merged)
                try jsonData.write(to: url, options: .atomic)
                self.lastWriteTime = Date()

                DispatchQueue.main.async { self.syncStatus = .idle }
            } catch {
                DispatchQueue.main.async {
                    self.syncStatus = .error("Write failed: \(error.localizedDescription)")
                }
            }
        }

        if let err = coordError {
            DispatchQueue.main.async {
                self.syncStatus = .error("Coordination error: \(err.localizedDescription)")
            }
        }
    }

    // MARK: - File Presenter Callbacks

    func presentedItemDidChange() {
        // Ignore change notifications that are echoes of our own writes
        if Date().timeIntervalSince(lastWriteTime) < 1.5 {
            return
        }
        DispatchQueue.main.async {
            self.onExternalChange?()
        }
    }

    // MARK: - Helpers

    private func ensureDirectory() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
