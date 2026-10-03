import Foundation

public enum CodexExecutableLocator {
    public static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory(),
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> URL? {
        let candidates = [
            environment["CODEX_EXECUTABLE"],
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(homeDirectory)/.local/bin/codex"
        ].compactMap { $0 }

        return candidates.first(where: isExecutable).map { URL(fileURLWithPath: $0) }
    }
}
