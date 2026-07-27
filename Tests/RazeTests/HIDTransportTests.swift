#if os(macOS)
import IOKit
import RazerCore
import XCTest
@testable import Raze

final class HIDTransportTests: XCTestCase {
    func testInputMonitoringDenialStillPermitsReadOnlyEnumeration() {
        XCTAssertTrue(HIDManagerOpenPolicy.permitsEnumeration(kIOReturnSuccess))
        XCTAssertTrue(HIDManagerOpenPolicy.permitsEnumeration(kIOReturnNotPermitted))
        XCTAssertFalse(HIDManagerOpenPolicy.permitsEnumeration(kIOReturnError))
    }

    func testNotPermittedHIDErrorsRequireInputMonitoring() {
        XCTAssertTrue(HIDError.managerOpen(kIOReturnNotPermitted).requiresInputMonitoring)
        XCTAssertTrue(HIDError.open(kIOReturnNotPermitted).requiresInputMonitoring)
        XCTAssertTrue(HIDError.write(kIOReturnNotPermitted).requiresInputMonitoring)
        XCTAssertTrue(HIDError.read(kIOReturnNotPermitted).requiresInputMonitoring)
        XCTAssertFalse(HIDError.open(kIOReturnError).requiresInputMonitoring)
        XCTAssertFalse(HIDError.noControlInterface.requiresInputMonitoring)
    }

    func testConnectedDeathAdderEliteIsDiscoveredWhenHardwareTestingIsEnabled() async throws {
        guard ProcessInfo.processInfo.environment["RAZE_HARDWARE_TEST"] == "1" else {
            throw XCTSkip("Set RAZE_HARDWARE_TEST=1 with the device connected.")
        }

        let transport = HIDTransport()
        let devices = try await transport.scan()
        let deathAdderElite = devices.first { $0.productID == 0x005C }

        XCTAssertEqual(deathAdderElite?.productName, "Razer DeathAdder Elite")
        XCTAssertTrue(deathAdderElite?.supportsLighting == true)
        if let deathAdderElite {
            let hasControlInterface = await transport.hasControlInterface(
                for: deathAdderElite
            )
            XCTAssertTrue(hasControlInterface)

            let dpiResponse = try await transport.send(
                RazerCommands.getDPI(
                    transactionID: deathAdderElite.transactionID
                ),
                to: deathAdderElite
            )
            let pollingResponse = try await transport.send(
                RazerCommands.getPollingRate(
                    transactionID: deathAdderElite.transactionID
                ),
                to: deathAdderElite
            )
            let currentDPI = try XCTUnwrap(
                dpiResponse.flatMap(DeviceResponseDecoder.dpi(from:))
            )
            let currentPollingRate = try XCTUnwrap(
                pollingResponse.flatMap(
                    DeviceResponseDecoder.pollingRate(from:)
                )
            )
            XCTAssertTrue(100...16_000 ~= currentDPI)
            let requestedDPI = ProcessInfo.processInfo.environment["RAZE_SET_DPI"]
                .flatMap(Int.init) ?? currentDPI
            let requestedPollingRate = ProcessInfo.processInfo
                .environment["RAZE_SET_POLL_RATE"]
                .flatMap(Int.init)
                .flatMap(PollingRate.init(rawValue:)) ?? currentPollingRate

            _ = try await transport.send(
                RazerCommands.setDPI(
                    requestedDPI,
                    transactionID: deathAdderElite.transactionID
                ),
                to: deathAdderElite
            )
            _ = try await transport.send(
                RazerCommands.setPollingRate(
                    requestedPollingRate,
                    transactionID: deathAdderElite.transactionID
                ),
                to: deathAdderElite
            )

            let updatedDPIResponse = try await transport.send(
                RazerCommands.getDPI(
                    transactionID: deathAdderElite.transactionID
                ),
                to: deathAdderElite
            )
            let updatedPollingResponse = try await transport.send(
                RazerCommands.getPollingRate(
                    transactionID: deathAdderElite.transactionID
                ),
                to: deathAdderElite
            )
            XCTAssertEqual(
                updatedDPIResponse.flatMap(DeviceResponseDecoder.dpi(from:)),
                requestedDPI
            )
            XCTAssertEqual(
                updatedPollingResponse.flatMap(
                    DeviceResponseDecoder.pollingRate(from:)
                ),
                requestedPollingRate
            )
        }
    }

    func testConnectedBasiliskXReportsBatteryWhenHardwareTestingIsEnabled() async throws {
        guard ProcessInfo.processInfo.environment["RAZE_HARDWARE_TEST"] == "1" else {
            throw XCTSkip("Set RAZE_HARDWARE_TEST=1 with the device connected.")
        }

        let transport = HIDTransport()
        let devices = try await transport.scan()
        let basilisk = try XCTUnwrap(
            devices.first { $0.productID == 0x0083 },
            "Connect a Razer Basilisk X HyperSpeed."
        )
        let response = try await transport.send(
            RazerCommands.getBatteryLevel(transactionID: basilisk.transactionID),
            to: basilisk
        )
        let percentage = try XCTUnwrap(
            response.flatMap(DeviceResponseDecoder.batteryPercentage(from:))
        )

        XCTAssertTrue(0...100 ~= percentage)
    }
}
#endif
