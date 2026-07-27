import Foundation

public enum AutomationEvent: String, Codable, CaseIterable, Sendable {
    case appLaunch
    case wake
    case sleep
    case acPower
    case batteryPower
    case screenLock
    case screenUnlock
}

public actor AutomationStore {
    private struct Envelope: Codable {
        let schemaVersion: Int
        let assignments: [AutomationEvent: UUID]
    }

    private static let currentSchemaVersion = 1
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> [AutomationEvent: UUID] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        let envelope = try JSONDecoder().decode(
            Envelope.self,
            from: Data(contentsOf: fileURL)
        )
        guard envelope.schemaVersion == Self.currentSchemaVersion else {
            throw ProfileStoreError.unsupportedSchema(envelope.schemaVersion)
        }
        return envelope.assignments
    }

    public func save(_ assignments: [AutomationEvent: UUID]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let envelope = Envelope(
            schemaVersion: Self.currentSchemaVersion,
            assignments: assignments
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(envelope).write(to: fileURL, options: .atomic)
    }
}
