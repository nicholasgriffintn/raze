#if os(macOS)
import IOKit
import XCTest
@testable import Raze

final class HIDTransportTests: XCTestCase {
    func testInputMonitoringDenialStillPermitsReadOnlyEnumeration() {
        XCTAssertTrue(HIDManagerOpenPolicy.permitsEnumeration(kIOReturnSuccess))
        XCTAssertTrue(HIDManagerOpenPolicy.permitsEnumeration(kIOReturnNotPermitted))
        XCTAssertFalse(HIDManagerOpenPolicy.permitsEnumeration(kIOReturnError))
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
        }
    }
}
#endif
