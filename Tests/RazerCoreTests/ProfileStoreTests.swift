import Foundation
import XCTest
@testable import RazerCore

final class ProfileStoreTests: XCTestCase {
    func testMissingStoreLoadsAsEmptyOnFirstLaunch() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = ProfileStore(fileURL: fileURL)

        let loaded = try await store.load()

        XCTAssertEqual(loaded, [])
    }

    func testRoundTripsVersionedProfiles() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = ProfileStore(fileURL: fileURL)
        let profiles = [
            DeviceProfile(
                name: "Work",
                productID: 0x0226,
                target: .backlight,
                effect: .staticColor(.init(red: 10, green: 20, blue: 30)),
                brightness: 75
            )
        ]

        try await store.save(profiles)
        let loaded = try await store.load()

        XCTAssertEqual(loaded, profiles)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
    }

    func testRejectsUnsupportedSchema() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"schemaVersion":2,"profiles":[]}"#.utf8).write(to: fileURL)
        let store = ProfileStore(fileURL: fileURL)

        do {
            _ = try await store.load()
            XCTFail("Expected unsupported schema error")
        } catch {
            XCTAssertEqual(error as? ProfileStoreError, .unsupportedSchema(2))
        }
    }

    func testSurfacesCorruptJSON() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: fileURL)
        let store = ProfileStore(fileURL: fileURL)

        do {
            _ = try await store.load()
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testRejectsMalformedProfileValuesInValidJSON() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(
            """
            {
              "schemaVersion": 1,
              "profiles": [{
                "id": "D2290506-1EF8-46B1-BDE2-B71E74FC39C6",
                "name": "Invalid",
                "productID": 550,
                "target": 5,
                "effect": {"wave": {"_0": 255}},
                "brightness": 75
              }]
            }
            """.utf8
        ).write(to: fileURL)
        let store = ProfileStore(fileURL: fileURL)

        do {
            _ = try await store.load()
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testSaveSurfacesDirectoryCreationFailure() async throws {
        let rootURL = temporaryFileURL().deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let blockingFileURL = rootURL.appendingPathComponent("not-a-directory")
        try Data().write(to: blockingFileURL)
        let store = ProfileStore(
            fileURL: blockingFileURL.appendingPathComponent("profiles.json")
        )

        do {
            try await store.save([])
            XCTFail("Expected persistence error")
        } catch {
            XCTAssertNotNil(error as? CocoaError)
        }
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("RazeTests-\(UUID().uuidString)")
            .appendingPathComponent("profiles.json")
    }
}
