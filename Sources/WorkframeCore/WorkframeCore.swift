import Foundation

public struct Workspace: Identifiable, Equatable, Sendable {
    public let agent: String
    public let repository: String
    public let city: String
    public let path: String
    public let branch: String

    public init(agent: String, repository: String, city: String, path: String, branch: String) {
        self.agent = agent
        self.repository = repository
        self.city = city
        self.path = path
        self.branch = branch
    }

    public var id: String { path }
    public var feature: String {
        agent == "task" ? branch : branch.split(separator: "/", maxSplits: 1).last.map(String.init) ?? branch
    }
    public var title: String { "\(repository) / \(feature)" }
    /// New task-owned workspaces use `task` as a layout marker. Keep a legacy
    /// agent prefix visible only for stores that still carry one.
    public var location: String { agent == "task" ? city : "\(agent) · \(city)" }
}

public struct ArchivedWorkspace: Identifiable, Equatable, Sendable {
    public let agent: String
    public let repository: String
    public let branch: String
    public let lastUpdated: String

    public init(agent: String, repository: String, branch: String, lastUpdated: String) {
        self.agent = agent
        self.repository = repository
        self.branch = branch
        self.lastUpdated = lastUpdated
    }

    public var id: String { "\(repository):\(branch)" }
    /// Archived output cannot distinguish a legacy agent prefix from a task
    /// containing a slash, so retain the full branch name rather than hiding
    /// part of a task.
    public var feature: String { branch }
}

public struct CommandResult: Sendable {
    public let output: String
    public let error: String
    public let status: Int32

    public init(output: String, error: String, status: Int32) {
        self.output = output
        self.error = error
        self.status = status
    }
}

public enum WorkframeOutput {
    public static func workspaces(_ output: String) -> [Workspace] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 5 else { return nil }
            return Workspace(agent: fields[0], repository: fields[1], city: fields[2], path: fields[3], branch: fields[4])
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public static func archived(_ output: String) -> [ArchivedWorkspace] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 4 else { return nil }
            return ArchivedWorkspace(agent: fields[0], repository: fields[1], branch: fields[2], lastUpdated: fields[3])
        }.sorted { $0.lastUpdated.localizedStandardCompare($1.lastUpdated) == .orderedAscending }
    }

    public static func lines(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
    }
}

public struct WorkframeCommand: Sendable {
    public let executable: String

    public static func resolve() -> WorkframeCommand? {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            environment["WORKFRAME_EXECUTABLE"],
            "\(NSHomeDirectory())/.local/bin/workframe",
            "/opt/homebrew/bin/workframe",
            "/usr/local/bin/workframe",
            FileManager.default.currentDirectoryPath + "/bin/workframe",
        ].compactMap { $0 }

        guard let executable = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else {
            return nil
        }
        return WorkframeCommand(executable: executable)
    }

    public func run(_ arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging([
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
            "WORKFRAME_COLOR": "0",
        ], uniquingKeysWith: { _, new in new })

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        return CommandResult(
            output: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            error: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            status: process.terminationStatus
        )
    }
}
