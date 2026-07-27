import XCTest
@testable import RazerCore

final class DeviceCatalogTests: XCTestCase {
    func testCatalogRecognisesBroadDeviceSet() {
        XCTAssertEqual(DeviceCatalog.builtIns.count, 271)
        XCTAssertEqual(
            Set(DeviceCatalog.builtIns.map(\.productID)).count,
            DeviceCatalog.builtIns.count
        )
    }

    func testRecentDevicesFromComparisonCatalogRemainDetectionOnly() throws {
        let expectedDevices: [UInt16: String] = [
            0x00A4: "Razer Mouse Dock Pro",
            0x00BE: "Razer DeathAdder V4 Pro (Wired)",
            0x00BF: "Razer DeathAdder V4 Pro (Wireless)",
            0x00D3: "Razer Basilisk Mobile (Wired)",
            0x00D4: "Razer Basilisk Mobile (Receiver)",
            0x02B0: "Razer Huntsman V3 Pro Mini",
            0x02C5: "Razer Blade 14 (2025)",
            0x02C6: "Razer Blade 16 (2025)",
            0x02C7: "Razer Blade 18 (2025)",
            0x02CF: "Razer Huntsman V3 Pro 8KHz",
            0x02D5: "Razer BlackWidow V4 Tenkeyless HyperSpeed (Wireless)",
            0x02D7: "Razer BlackWidow V4 Tenkeyless HyperSpeed (Wired)",
            0x0520: "Razer Kraken Tournament Edition",
            0x0F13: "Razer Lian Li O11 Dynamic"
        ]
        let catalog = DeviceCatalog()

        for (productID, name) in expectedDevices {
            let definition = try XCTUnwrap(catalog.definition(for: productID))

            XCTAssertEqual(definition.name, name)
            XCTAssertEqual(definition.supportLevel, .detectionOnly)
        }
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
        let device = device(
            protocol: definition.lightingProtocol,
            targets: definition.targets,
            productID: definition.productID,
            kind: definition.kind
        )
        XCTAssertEqual(device.controlCapabilities.dpiRange, 100...16_000)
        XCTAssertEqual(device.controlCapabilities.pollingRates, PollingRate.allCases)
    }

    func testBasiliskXHyperSpeedAdvertisesBatteryStatus() throws {
        let definition = try XCTUnwrap(DeviceCatalog().definition(for: 0x0083))
        let device = device(
            protocol: definition.lightingProtocol,
            targets: definition.targets,
            productID: definition.productID,
            kind: definition.kind,
            productName: definition.name
        )

        XCTAssertTrue(device.controlCapabilities.supportsBattery)
    }

    func testNewerMouseCapabilitiesUseObservedDPIAndPollingOptions() throws {
        let definition = try XCTUnwrap(DeviceCatalog().definition(for: 0x00B7))
        let device = device(
            protocol: definition.lightingProtocol,
            targets: definition.targets,
            productID: definition.productID,
            kind: definition.kind,
            productName: definition.name
        )

        XCTAssertEqual(device.controlCapabilities.dpiRange, 100...35_000)
        XCTAssertEqual(
            device.controlCapabilities.pollingRates,
            [.hz125, .hz250, .hz500, .hz1000]
        )
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
        targets: [LightingTarget],
        productID: UInt16 = 0xFFFF,
        kind: DeviceKind = .unknown,
        productName: String = "Fixture"
    ) -> RazerDevice {
        .init(
            id: "fixture",
            productID: productID,
            productName: productName,
            serialNumber: nil,
            kind: kind,
            transactionID: 0x1F,
            lightingProtocol: lightingProtocol,
            supportLevel: .community,
            targets: targets,
            supportedEffects: [.staticColor],
            supportsBrightness: true
        )
    }
}
