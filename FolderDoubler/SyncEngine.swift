// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import Foundation
import SwiftUI
import Combine

// MARK: - Data Models

/// Represents what happened to a file during sync
enum SyncAction: String {
    case copied  = "Copied"
    case updated = "Updated"
    case deleted = "Deleted"
    case error   = "Error"
}

/// Tracks the overall state of the sync engine
enum SyncStatus: String {
    case idle       = "Idle"
    case monitoring = "Monitoring"
    case syncing    = "Syncing"
    case error      = "Error"
}

/// A single logged sync operation — shown in the activity log
struct SyncEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let fileName: String
    let relativePath: String
    let action: SyncAction
    let fileSize: Int64
    var errorMessage: String?
}

// MARK: - SyncEngine

/// The core of FolderDoubler. This class:
/// 1. Watches a source folder for file changes using macOS FSEvents
/// 2. Compares files by modification date to find what's new or changed
/// 3. Copies changed files to a destination folder, preserving directory structure
/// 4. Mirrors deletions (if a file is removed from source, remove from destination)
/// 5. Publishes all state changes so the SwiftUI views update automatically
///
/// FSEvents is the macOS kernel-level file system notification system. It's the same
/// technology that powers Spotlight, Time Machine, and Finder's live updates. It's
/// efficient because the OS tells us exactly which files changed — we don't need to
/// poll or scan the whole directory tree repeatedly.
class SyncEngine: ObservableObject {

    // MARK: - Published Properties (drive the UI)

    /// The folder we're watching for changes
    @Published var sourcePath: URL?

    /// Where we copy changed files to (NAS, iCloud Drive, external drive, etc.)
    @Published var destinationPath: URL?

    /// Current state of the engine — idle, monitoring, syncing, or error
    @Published var status: SyncStatus = .idle

    /// Whether FSEvents monitoring is actively running
    @Published var isMonitoring = false

    /// Log of all sync operations, newest first
    @Published var events: [SyncEvent] = []

    /// When the last sync operation completed
    @Published var lastSyncDate: Date?

    /// Human-readable error message shown in the UI
    @Published var errorMessage: String?

    /// Running count of files synced this session
    @Published var totalFilesSynced: Int = 0

    /// File/directory name patterns to skip during sync.
    /// Supports simple wildcards: "*.ext" matches by extension, "name*" matches by prefix,
    /// plain names match exactly.
    @Published var excludePatterns: [String] = [
        ".DS_Store", ".git", ".svn", "*.swp", "*.tmp",
        ".Trash", "node_modules", ".build", "DerivedData",
        "xcuserdata", "*.xcuserdatad"
    ]

    // MARK: - Private State

    /// The active FSEvents stream (nil when not monitoring)
    private var eventStream: FSEventStreamRef?

    /// Background queue for all file I/O so we never block the main thread
    private let syncQueue = DispatchQueue(label: "com.kyleblizzard.folderDoubler.sync", qos: .utility)

    /// Collects changed paths during the debounce window before syncing
    private var pendingPaths: Set<String> = []

    /// Cancellable work item for debounce — gets replaced each time new events arrive
    private var debounceWorkItem: DispatchWorkItem?

    // UserDefaults keys for remembering settings between app launches
    private let sourcePathKey = "sourcePath"
    private let destPathKey = "destinationPath"
    private let excludePatternsKey = "excludePatterns"

    // MARK: - Lifecycle

    init() {
        loadSavedSettings()
    }

    deinit {
        // Clean up the FSEvents stream when the engine is deallocated
        stopFSEventsStream()
    }

    // MARK: - Folder Selection

    /// Opens a native macOS folder picker for the user to choose the source folder
    func selectSourceFolder() {
        chooseFolder(title: "Choose Source Folder", startAt: sourcePath) { [weak self] url in
            self?.sourcePath = url
            UserDefaults.standard.set(url.path, forKey: self?.sourcePathKey ?? "")
        }
    }

    /// Opens a native macOS folder picker for the user to choose the destination folder
    func selectDestinationFolder() {
        chooseFolder(title: "Choose Destination Folder", startAt: destinationPath) { [weak self] url in
            self?.destinationPath = url
            UserDefaults.standard.set(url.path, forKey: self?.destPathKey ?? "")
        }
    }

    /// Shared helper that presents an NSOpenPanel configured for directory selection.
    /// NSOpenPanel is the standard macOS "Open" dialog — here we restrict it to folders only.
    private func chooseFolder(title: String, startAt: URL?, completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        // Start the panel in the currently selected folder if we have one
        if let startAt = startAt {
            panel.directoryURL = startAt
        }

        // .runModal() blocks until the user picks a folder or cancels
        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }

    // MARK: - Sync Controls

    /// Called when the user presses "Start Monitoring".
    /// 1. Validates that source and destination are set
    /// 2. Runs a full initial sync (copies anything that's out of date)
    /// 3. Starts FSEvents monitoring for ongoing changes
    func startMonitoring() {
        guard let source = sourcePath, let dest = destinationPath else {
            errorMessage = "Select both source and destination folders first."
            return
        }

        guard FileManager.default.fileExists(atPath: source.path) else {
            errorMessage = "Source folder does not exist: \(source.path)"
            return
        }

        // Make sure the destination exists — create it if needed (e.g. first run)
        if !FileManager.default.fileExists(atPath: dest.path) {
            do {
                try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            } catch {
                errorMessage = "Cannot create destination folder: \(error.localizedDescription)"
                return
            }
        }

        errorMessage = nil
        status = .syncing

        // Run the initial sync on a background thread, then start real-time monitoring
        syncQueue.async { [weak self] in
            self?.performFullSync(source: source, destination: dest)
            DispatchQueue.main.async {
                self?.beginFSEventsMonitoring(path: source.path)
                self?.isMonitoring = true
                self?.status = .monitoring
            }
        }
    }

    /// Stops FSEvents monitoring and returns to idle state
    func stopMonitoring() {
        stopFSEventsStream()
        isMonitoring = false
        status = .idle
    }

    /// Manually triggers a full sync without starting/stopping monitoring.
    /// Useful for a one-time "catch up" sync.
    func runFullSync() {
        guard let source = sourcePath, let dest = destinationPath else {
            errorMessage = "Select both source and destination folders first."
            return
        }

        let wasMonitoring = isMonitoring
        status = .syncing

        syncQueue.async { [weak self] in
            self?.performFullSync(source: source, destination: dest)
            DispatchQueue.main.async {
                self?.status = wasMonitoring ? .monitoring : .idle
            }
        }
    }

    // MARK: - Full Sync

    /// Walks the entire source directory tree and copies any files that are
    /// newer than their destination counterpart (or missing from the destination).
    /// This is the "catch up" operation that ensures the destination matches the source.
    private func performFullSync(source: URL, destination: URL) {
        let fm = FileManager.default

        // FileManager.enumerator gives us every file and folder recursively.
        // We request modification date, size, and directory status upfront
        // so we don't have to ask for each file individually (much faster).
        guard let enumerator = fm.enumerator(
            at: source,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
            options: []
        ) else {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Cannot read source folder."
                self?.status = .error
            }
            return
        }

        var syncCount = 0

        while let fileURL = enumerator.nextObject() as? URL {
            // Build the relative path by stripping the source prefix.
            // e.g. /Users/bliz/Documents/Development/myProject/main.swift
            //   -> /myProject/main.swift
            let relativePath = fileURL.path.replacingOccurrences(of: source.path, with: "")
            let fileName = fileURL.lastPathComponent

            // Check if this file or directory matches any exclusion pattern.
            // If it's an excluded directory, skip its entire subtree.
            if shouldExclude(fileName: fileName, relativePath: relativePath) {
                if (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            do {
                let values = try fileURL.resourceValues(
                    forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
                )
                let destURL = destination.appendingPathComponent(relativePath)

                // For directories, just make sure they exist at the destination
                if values.isDirectory == true {
                    if !fm.fileExists(atPath: destURL.path) {
                        try fm.createDirectory(at: destURL, withIntermediateDirectories: true)
                    }
                    continue
                }

                // For files, compare modification dates to decide if we need to copy
                let sourceModDate = values.contentModificationDate ?? .distantPast
                var needsCopy = !fm.fileExists(atPath: destURL.path)

                if !needsCopy {
                    let destValues = try destURL.resourceValues(forKeys: [.contentModificationDateKey])
                    let destModDate = destValues.contentModificationDate ?? .distantPast
                    // Only copy if the source is newer than what's at the destination
                    needsCopy = sourceModDate > destModDate
                }

                if needsCopy {
                    try copyFile(
                        from: fileURL,
                        to: destURL,
                        fileSize: Int64(values.fileSize ?? 0),
                        relativePath: relativePath
                    )
                    syncCount += 1
                }

            } catch {
                logEvent(
                    fileName: fileName,
                    relativePath: relativePath,
                    action: .error,
                    size: 0,
                    errorMessage: error.localizedDescription
                )
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.lastSyncDate = Date()
            self?.totalFilesSynced += syncCount
        }
    }

    // MARK: - Single File Sync

    /// Syncs a single file that FSEvents told us about.
    /// Handles creation, modification, and deletion.
    private func syncFile(at path: String) {
        guard let source = sourcePath, let dest = destinationPath else { return }

        let fm = FileManager.default
        let fileURL = URL(fileURLWithPath: path)

        // Safety check: only sync files that are within our source directory
        guard path.hasPrefix(source.path) else { return }

        // Build the relative path and check exclusions
        let relativePath = String(path.dropFirst(source.path.count))
        let fileName = fileURL.lastPathComponent

        if shouldExclude(fileName: fileName, relativePath: relativePath) { return }

        let destURL = dest.appendingPathComponent(relativePath)

        do {
            // If the source file was deleted, mirror that deletion at the destination
            if !fm.fileExists(atPath: path) {
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                    logEvent(fileName: fileName, relativePath: relativePath, action: .deleted, size: 0)
                }
                return
            }

            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])

            // Create directories as needed
            if values.isDirectory == true {
                if !fm.fileExists(atPath: destURL.path) {
                    try fm.createDirectory(at: destURL, withIntermediateDirectories: true)
                }
                return
            }

            // Copy the changed file
            try copyFile(
                from: fileURL,
                to: destURL,
                fileSize: Int64(values.fileSize ?? 0),
                relativePath: relativePath
            )

            DispatchQueue.main.async { [weak self] in
                self?.lastSyncDate = Date()
                self?.totalFilesSynced += 1
            }

        } catch {
            logEvent(
                fileName: fileName,
                relativePath: relativePath,
                action: .error,
                size: 0,
                errorMessage: error.localizedDescription
            )
        }
    }

    // MARK: - File Copy Helper

    /// Copies a single file from source to destination, creating parent directories as needed.
    /// If the file already exists at the destination, it's replaced (logged as "Updated").
    /// If it's new, it's logged as "Copied".
    private func copyFile(from source: URL, to destination: URL, fileSize: Int64, relativePath: String) throws {
        let fm = FileManager.default

        // Make sure the parent directory exists at the destination
        // (e.g. if someone creates a new folder with files inside it)
        let parentDir = destination.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        let isUpdate = fm.fileExists(atPath: destination.path)

        // FileManager.copyItem won't overwrite, so we remove first if the file exists
        if isUpdate {
            try fm.removeItem(at: destination)
        }

        try fm.copyItem(at: source, to: destination)

        logEvent(
            fileName: source.lastPathComponent,
            relativePath: relativePath,
            action: isUpdate ? .updated : .copied,
            size: fileSize
        )
    }

    // MARK: - FSEvents Monitoring

    /// Sets up a macOS FSEvents stream to watch the source directory for changes.
    ///
    /// FSEvents is a kernel-level API — macOS tracks all file system changes and
    /// notifies us through a callback. Flags we use:
    /// - kFSEventStreamCreateFlagUseCFTypes: gives us paths as CFStrings (easier to use)
    /// - kFSEventStreamCreateFlagFileEvents: report individual file changes (not just directories)
    /// - kFSEventStreamCreateFlagNoDefer: deliver events immediately instead of batching
    private func beginFSEventsMonitoring(path: String) {
        let pathsToWatch = [path] as CFArray

        // The context lets us pass a reference to this SyncEngine instance into the
        // C-style callback function. We use Unmanaged to bridge Swift's reference
        // counting with C's raw pointer.
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        // Create the FSEvents stream with a 0.5 second latency.
        // This means macOS will batch events that happen within 500ms of each other.
        eventStream = FSEventStreamCreate(
            nil,                                                    // default allocator
            fsEventsCallback,                                       // our callback function
            &context,                                               // context with self reference
            pathsToWatch,                                           // directories to watch
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),    // start from now
            0.5,                                                    // latency in seconds
            flags
        )

        guard let stream = eventStream else { return }

        // Use a dispatch queue for event delivery (modern API, replaces the deprecated
        // FSEventStreamScheduleWithRunLoop). Events arrive on the main queue so we
        // can safely update published properties.
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    /// Cleans up the FSEvents stream. Must be called before releasing the stream reference.
    private func stopFSEventsStream() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }

    /// Called by the FSEvents callback when file changes are detected.
    /// Instead of syncing each file immediately, we collect changed paths for 1 second
    /// (debounce) and then sync them all at once. This prevents redundant work when
    /// many files change at once (e.g. during a git checkout or build).
    func handleFSEvents(paths: [String]) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // Add new paths to the pending set (Set automatically deduplicates)
            self.pendingPaths.formUnion(paths)

            // Cancel any previously scheduled sync
            self.debounceWorkItem?.cancel()

            // Schedule a new sync 1 second from now
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }

                // Grab all pending paths and clear the set
                let pathsToSync = self.pendingPaths
                self.pendingPaths.removeAll()

                DispatchQueue.main.async { self.status = .syncing }

                // Sync each changed file
                for path in pathsToSync {
                    self.syncFile(at: path)
                }

                DispatchQueue.main.async { self.status = .monitoring }
            }

            self.debounceWorkItem = workItem
            self.syncQueue.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        }
    }

    // MARK: - Exclusion Pattern Matching

    /// Checks if a file or directory should be skipped during sync.
    /// Supports three pattern types:
    /// - "*.ext" — matches files ending with .ext (e.g. "*.tmp" matches "notes.tmp")
    /// - "prefix*" — matches files starting with prefix (e.g. "._*" matches "._metadata")
    /// - "exactname" — matches the exact file/directory name (e.g. ".git", "node_modules")
    func shouldExclude(fileName: String, relativePath: String) -> Bool {
        for pattern in excludePatterns {
            if pattern.hasPrefix("*.") {
                // Wildcard suffix: *.ext
                let ext = String(pattern.dropFirst(1))  // keep the dot: ".ext"
                if fileName.hasSuffix(ext) { return true }
            } else if pattern.hasSuffix("*") {
                // Wildcard prefix: name*
                let prefix = String(pattern.dropLast())
                if fileName.hasPrefix(prefix) { return true }
            } else {
                // Exact match on the file/directory name
                if fileName == pattern { return true }
            }
        }
        return false
    }

    /// Adds a new exclusion pattern (no duplicates, no empties)
    func addExcludePattern(_ pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !excludePatterns.contains(trimmed) else { return }
        excludePatterns.append(trimmed)
        saveExcludePatterns()
    }

    /// Removes exclusion patterns at the given offsets (used by SwiftUI's onDelete)
    func removeExcludePattern(at offsets: IndexSet) {
        excludePatterns.remove(atOffsets: offsets)
        saveExcludePatterns()
    }

    // MARK: - Activity Log

    /// Records a sync event and adds it to the activity log (thread-safe).
    /// Keeps the log capped at 1000 entries to avoid unbounded memory growth.
    private func logEvent(
        fileName: String,
        relativePath: String,
        action: SyncAction,
        size: Int64,
        errorMessage: String? = nil
    ) {
        let event = SyncEvent(
            timestamp: Date(),
            fileName: fileName,
            relativePath: relativePath,
            action: action,
            fileSize: size,
            errorMessage: errorMessage
        )

        DispatchQueue.main.async { [weak self] in
            self?.events.insert(event, at: 0)
            if let count = self?.events.count, count > 1000 {
                self?.events = Array(self?.events.prefix(1000) ?? [])
            }
        }
    }

    /// Clears all entries from the activity log
    func clearLog() {
        events.removeAll()
    }

    // MARK: - Settings Persistence

    /// Loads source path, destination path, and exclude patterns from UserDefaults.
    /// Called once during init so the app remembers settings between launches.
    private func loadSavedSettings() {
        if let path = UserDefaults.standard.string(forKey: sourcePathKey) {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                sourcePath = url
            }
        }
        if let path = UserDefaults.standard.string(forKey: destPathKey) {
            destinationPath = URL(fileURLWithPath: path)
        }
        if let patterns = UserDefaults.standard.stringArray(forKey: excludePatternsKey) {
            excludePatterns = patterns
        }
    }

    /// Saves the current exclude patterns to UserDefaults
    private func saveExcludePatterns() {
        UserDefaults.standard.set(excludePatterns, forKey: excludePatternsKey)
    }
}

// MARK: - FSEvents C Callback

/// FSEvents requires a C-style function pointer as its callback. This free function
/// receives the raw pointer to our SyncEngine (from the context we set up) and
/// forwards the changed paths to handleFSEvents().
///
/// Parameters from FSEvents:
/// - streamRef: the stream that fired
/// - clientCallBackInfo: our context pointer (the SyncEngine instance)
/// - numEvents: how many events in this batch
/// - eventPaths: the file paths that changed (CFArray of CFStrings)
/// - eventFlags: what kind of change happened to each path
/// - eventIds: unique IDs for each event (for resuming later)
private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }

    // Convert the raw pointer back to our SyncEngine instance
    let engine = Unmanaged<SyncEngine>.fromOpaque(info).takeUnretainedValue()

    // Convert the CFArray of CFStrings to a Swift [String]
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

    engine.handleFSEvents(paths: paths)
}
