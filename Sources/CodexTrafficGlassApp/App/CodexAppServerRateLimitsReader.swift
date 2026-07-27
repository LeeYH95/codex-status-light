import Foundation
import CodexTrafficGlassCore

struct CodexAppServerRateLimitsReader: Sendable {
    private let parser: CodexAppServerRateLimitsParser

    init(parser: CodexAppServerRateLimitsParser = CodexAppServerRateLimitsParser()) {
        self.parser = parser
    }

    func readQuota(timeout: TimeInterval = 8) -> CodexQuota? {
        let process = Process()
        configure(process)

        let standardInput = Pipe()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let jsonLines = JSONLineBuffer()

        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError

        standardOutput.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            jsonLines.append(data)
        }

        do {
            try process.run()
            defer {
                standardOutput.fileHandleForReading.readabilityHandler = nil
                if process.isRunning {
                    process.terminate()
                }
            }

            guard writeJSON(
                [
                    "id": 1,
                    "method": "initialize",
                    "params": [
                        "clientInfo": [
                            "name": "codex-traffic-glass",
                            "title": "Codex Traffic Glass",
                            "version": "0"
                        ],
                        "capabilities": [
                            "experimentalApi": true,
                            "requestAttestation": false
                        ]
                    ]
                ],
                to: standardInput.fileHandleForWriting
            ) else {
                return nil
            }
            _ = jsonLines.waitForLine(withID: 1, timeout: timeout)

            guard writeJSON(["method": "initialized"], to: standardInput.fileHandleForWriting),
                  writeJSON(
                [
                    "id": 2,
                    "method": "account/rateLimits/read"
                ],
                to: standardInput.fileHandleForWriting
                  ) else {
                return nil
            }

            guard let line = jsonLines.waitForLine(withID: 2, timeout: timeout) else {
                return nil
            }

            return try parser.parseQuota(from: line)
        } catch {
            return nil
        }
    }

    private func configure(_ process: Process) {
        if let codexExecutableURL {
            process.executableURL = codexExecutableURL
            process.arguments = ["app-server", "--stdio"]
            return
        }

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "codex app-server --stdio"]
    }

    private var codexExecutableURL: URL? {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            environment["CODEX_EXECUTABLE"],
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(NSHomeDirectory())/.local/bin/codex"
        ].compactMap { $0 }

        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func writeJSON(_ object: [String: Any], to handle: FileHandle) -> Bool {
        do {
            var data = try JSONSerialization.data(withJSONObject: object)
            data.append(Data("\n".utf8))
            try handle.write(contentsOf: data)
            return true
        } catch {
            return false
        }
    }

    private final class JSONLineBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = ""
        private var lines: [Data] = []

        func append(_ data: Data) {
            guard let string = String(data: data, encoding: .utf8) else {
                return
            }

            lock.lock()
            defer {
                lock.unlock()
            }

            buffer += string
            while let newline = buffer.firstIndex(of: "\n") {
                let line = String(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                lines.append(Data(line.utf8))
            }
        }

        func waitForLine(withID id: Int, timeout: TimeInterval) -> Data? {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if let line = takeLine(withID: id) {
                    return line
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
            return nil
        }

        private func takeLine(withID id: Int) -> Data? {
            lock.lock()
            defer {
                lock.unlock()
            }

            guard let index = lines.firstIndex(where: { data in
                guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return false
                }
                return object["id"] as? Int == id
            }) else {
                return nil
            }

            return lines.remove(at: index)
        }
    }
}
