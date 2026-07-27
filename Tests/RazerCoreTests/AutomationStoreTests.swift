import Foundation
import XCTest
@testable import RazerCore

final class AutomationStoreTests: XCTestCase {
    func testMissingStoreLoadsWithoutAssignments() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = AutomationStore(fileURL: fileURL)

        let assignments = try await store.load()
        XCTAssertEqual(assignments, [:])
    }

    func testRoundTripsEventAssignments() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = AutomationStore(fileURL: fileURL)
        let profileID = UUID()
        let assignments: [AutomationEvent: UUID] = [
            .appLaunch: profileID,
            .screenUnlock: profileID,
            .acPower: profileID
        ]

        try await store.save(assignments)

        let loaded = try await store.load()
        XCTAssertEqual(loaded, assignments)
    }

    func testRejectsUnsupportedSchema() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"schemaVersion":2,"assignments":[]}"#.utf8).write(to: fileURL)
        let store = AutomationStore(fileURL: fileURL)

        do {
            _ = try await store.load()
            XCTFail("Expected unsupported schema error")
        } catch {
            XCTAssertEqual(error as? ProfileStoreError, .unsupportedSchema(2))
        }
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("RazeAutomationTests-\(UUID().uuidString)")
            .appendingPathComponent("automation.json")
    }
}
