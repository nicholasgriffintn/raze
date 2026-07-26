import XCTest
@testable import RazerCore

final class DeviceCatalogTests: XCTestCase {
    func testCatalogRecognisesBroadDeviceSet() {
        XCTAssertEqual(DeviceCatalog.builtIns.count, 257)
        XCTAssertEqual(
            Set(DeviceCatalog.builtIns.map(\.productID)).count,
            DeviceCatalog.builtIns.count
        )
    }

    func testCorrectedProductMappings() {
        let catalog = DeviceCatalog()

        XCTAssertEqual(catalog.definition(for: 0x006E)?.name, "Razer DeathAdder Essential")
        XCTAssertEqual(catalog.definition(for: 0x0078)?.name, "Razer Viper")
        XCTAssertEqual(catalog.definition(for: 0x008A)?.name, "Razer Viper Mini")
        XCTAssertEqual(catalog.definition(for: 0x0216)?.name, "Razer BlackWidow X Chroma")
        XCTAssertEqual(catalog.definition(for: 0x0226)?.name, "Razer Huntsman Elite")
        XCTAssertEqual(catalog.definition(for: 0x0239)?.kind, .laptop)
        XCTAssertEqual(catalog.definition(for: 0x0269)?.name, "Razer Huntsman Mini JP")
    }

    func testDeathAdderEliteUsesItsObservedLightingCapabilities() throws {
        let definition = try XCTUnwrap(DeviceCatalog().definition(for: 0x005C))

        XCTAssertEqual(definition.name, "Razer DeathAdder Elite")
        XCTAssertEqual(definition.transactionID, 0x3F)
        XCTAssertEqual(definition.lightingProtocol, .extendedMatrix)
        XCTAssertEqual(Set(definition.targets), [.logo, .scrollWheel])
        XCTAssertEqual(
            definition.supportedEffects,
            [.off, .spectrum, .staticColor, .breathing, .reactive]
        )
        XCTAssertTrue(definition.supportsBrightness)
    }

    func testUnmappedProtocolsRemainDetectionOnly() {
        let definition = DeviceCatalog().definition(for: 0x0013)

        XCTAssertEqual(definition?.supportLevel, .detectionOnly)
        XCTAssertNil(definition?.lightingProtocol)
        XCTAssertEqual(definition?.targets, [])
    }

    func testMouseExtendedDefinitionsDoNotAdvertiseWave() {
        let definitions = DeviceCatalog.builtIns.filter {
            $0.lightingProtocol == .mouseExtendedMatrix
        }

        XCTAssertFalse(definitions.isEmpty)
        XCTAssertTrue(definitions.allSatisfy { !$0.supportedEffects.contains(.wave) })
    }

    func testBuiltInDefinitionsPreserveLightingSafetyInvariants() {
        for definition in DeviceCatalog.builtIns {
            switch definition.supportLevel {
            case .community:
                XCTAssertNotNil(
                    definition.lightingProtocol,
                    "Missing protocol for \(definition.name)"
                )
                XCTAssertFalse(
                    definition.targets.isEmpty,
                    "Missing lighting target for \(definition.name)"
                )
                XCTAssertEqual(
                    Set(definition.targets).count,
                    definition.targets.count,
                    "Duplicate lighting target for \(definition.name)"
                )
                XCTAssertFalse(
                    definition.supportedEffects.isEmpty,
                    "Missing supported effects for \(definition.name)"
                )
                XCTAssertNotEqual(
                    definition.transactionID,
                    0,
                    "Missing transaction ID for \(definition.name)"
                )
            case .detectionOnly:
                XCTAssertNil(
                    definition.lightingProtocol,
                    "Detection-only device has a protocol: \(definition.name)"
                )
                XCTAssertTrue(
                    definition.targets.isEmpty,
                    "Detection-only device has lighting targets: \(definition.name)"
                )
                XCTAssertTrue(
                    definition.supportedEffects.isEmpty,
                    "Detection-only device has supported effects: \(definition.name)"
                )
                XCTAssertFalse(
                    definition.supportsBrightness,
                    "Detection-only device supports brightness: \(definition.name)"
                )
            }
        }
    }

    func testDeviceRequiresProtocolAndTargetToSupportLighting() {
        let supported = device(protocol: .extendedMatrix, targets: [.all])
        let missingProtocol = device(protocol: nil, targets: [.all])
        let missingTarget = device(protocol: .extendedMatrix, targets: [])

        XCTAssertTrue(supported.supportsLighting)
        XCTAssertFalse(missingProtocol.supportsLighting)
        XCTAssertFalse(missingTarget.supportsLighting)
    }

    func testDuplicateDefinitionsResolveDeterministically() {
        let first = definition(name: "First")
        let second = definition(name: "Second")

        let catalog = DeviceCatalog(definitions: [first, second])

        XCTAssertEqual(catalog.definition(for: first.productID)?.name, "Second")
    }

    private func definition(name: String) -> DeviceDefinition {
        .init(
            productID: 0xFFFF,
            name: name,
            kind: .unknown,
            transactionID: 0,
            lightingProtocol: nil,
            supportLevel: .detectionOnly,
            targets: [],
            supportedEffects: [],
            supportsBrightness: false
        )
    }

    private func device(
        protocol lightingProtocol: LightingProtocol?,
        targets: [LightingTarget]
    ) -> RazerDevice {
        .init(
            id: "fixture",
            productID: 0xFFFF,
            productName: "Fixture",
            serialNumber: nil,
            kind: .unknown,
            transactionID: 0x1F,
            lightingProtocol: lightingProtocol,
            supportLevel: .community,
            targets: targets,
            supportedEffects: [.staticColor],
            supportsBrightness: true
        )
    }
}
