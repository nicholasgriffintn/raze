import ServiceManagement
import XCTest
@testable import Raze

final class LaunchAtLoginStatusTests: XCTestCase {
    func testStatusesHaveClearDisplayNames() {
        XCTAssertEqual(SMAppService.Status.enabled.displayName, "Enabled")
        XCTAssertEqual(SMAppService.Status.notRegistered.displayName, "Off")
        XCTAssertEqual(
            SMAppService.Status.requiresApproval.displayName,
            "Requires approval"
        )
        XCTAssertEqual(SMAppService.Status.notFound.displayName, "Unavailable")
    }
}
