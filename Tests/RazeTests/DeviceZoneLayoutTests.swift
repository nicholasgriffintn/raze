#if os(macOS)
import RazerCore
import XCTest
@testable import Raze

final class DeviceZoneLayoutTests: XCTestCase {
    func testDeathAdderZonesMapToDistinctVisibleLocations() {
        let size = CGSize(width: 330, height: 200)

        let logo = DeviceZoneLayout.position(for: .logo, kind: .mouse, in: size)
        let scrollWheel = DeviceZoneLayout.position(
            for: .scrollWheel,
            kind: .mouse,
            in: size
        )

        XCTAssertEqual(logo.x, scrollWheel.x)
        XCTAssertGreaterThan(logo.y, scrollWheel.y)
        XCTAssertTrue(size.contains(logo))
        XCTAssertTrue(size.contains(scrollWheel))
    }

    func testEveryTargetRemainsInsideEveryDeviceSchematic() {
        let size = CGSize(width: 330, height: 200)
        let kinds: [DeviceKind] = [.mouse, .keyboard, .laptop, .headset, .accessory, .unknown]
        let targets: [LightingTarget] = [.all, .scrollWheel, .battery, .logo, .backlight]

        for kind in kinds {
            for target in targets {
                let point = DeviceZoneLayout.position(for: target, kind: kind, in: size)
                XCTAssertTrue(size.contains(point), "\(target) is outside the \(kind) schematic")
            }
        }
    }
}

private extension CGSize {
    func contains(_ point: CGPoint) -> Bool {
        (0...width).contains(point.x) && (0...height).contains(point.y)
    }
}
#endif
