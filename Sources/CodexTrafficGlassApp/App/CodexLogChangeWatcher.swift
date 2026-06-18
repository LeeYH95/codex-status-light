import Darwin
import Dispatch
import Foundation
import CodexTrafficGlassCore

final class CodexLogChangeWatcher: @unchecked Sendable {
    private let logReader: CodexSessionLogReader
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "CodexTrafficGlass.log-change-watcher")

    private var watchedPaths: Set<String> = []
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pendingRefresh: DispatchWorkItem?

    init(logReader: CodexSessionLogReader, onChange: @escaping @Sendable () -> Void) {
        self.logReader = logReader
        self.onChange = onChange
    }

    func start() {
        refreshWatchedFiles()
    }

    func refreshWatchedFiles() {
        queue.async { [weak self] in
            self?.rebuildWatchList()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.cancelSources()
            self?.pendingRefresh?.cancel()
            self?.pendingRefresh = nil
        }
    }

    private func rebuildWatchList() {
        let nextPaths = watchablePaths()
        guard nextPaths != watchedPaths else {
            return
        }

        cancelSources()
        watchedPaths = nextPaths

        for path in nextPaths {
            let descriptor = open(path, O_EVTONLY)
            guard descriptor >= 0 else {
                continue
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .extend, .attrib, .delete, .rename],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                self?.handleLogChange()
            }
            source.setCancelHandler {
                close(descriptor)
            }
            sources.append(source)
            source.resume()
        }
    }

    private func handleLogChange() {
        rebuildWatchList()
        pendingRefresh?.cancel()

        let refresh = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        pendingRefresh = refresh
        queue.asyncAfter(deadline: .now() + .milliseconds(120), execute: refresh)
    }

    private func watchablePaths() -> Set<String> {
        var paths: Set<String> = []
        let fileManager = FileManager.default

        func addIfExists(_ url: URL) {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                paths.insert(url.standardizedFileURL.path)
            }
        }

        addIfExists(logReader.sessionsDirectory)

        for fileURL in logReader.latestSessionFiles(limit: 8) {
            addIfExists(fileURL)

            var directoryURL = fileURL.deletingLastPathComponent()
            while directoryURL.path.hasPrefix(logReader.sessionsDirectory.path) {
                addIfExists(directoryURL)
                if directoryURL.standardizedFileURL == logReader.sessionsDirectory.standardizedFileURL {
                    break
                }
                directoryURL.deleteLastPathComponent()
            }
        }

        return paths
    }

    private func cancelSources() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
    }
}
