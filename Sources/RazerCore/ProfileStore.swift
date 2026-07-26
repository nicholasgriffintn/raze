import Foundation

public enum ProfileStoreError: Error, Equatable, LocalizedError {
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            "Profiles use unsupported schema version \(version)."
        }
    }
}

public actor ProfileStore {
    private struct Envelope: Codable {
        let schemaVersion: Int
        let profiles: [DeviceProfile]
    }

    private static let currentSchemaVersion = 1
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> [DeviceProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let envelope = try JSONDecoder().decode(
            Envelope.self,
            from: Data(contentsOf: fileURL)
        )
        guard envelope.schemaVersion == Self.currentSchemaVersion else {
            throw ProfileStoreError.unsupportedSchema(envelope.schemaVersion)
        }
        return envelope.profiles
    }

    public func save(_ profiles: [DeviceProfile]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let envelope = Envelope(
            schemaVersion: Self.currentSchemaVersion,
            profiles: profiles
        )
        let data = try JSONEncoder.profileEncoder.encode(envelope)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var profileEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
