import XCTest
@testable import RazerCore

final class MatrixAnimationsTests: XCTestCase {
    func testKnownAndFallbackMatrixDimensionsMatchDeviceFormFactors() {
        let tartarus = device(productID: 0x022B, name: "Razer Tartarus V2", kind: .keyboard)
        let newerLaptop = device(productID: 0xFFFF, name: "Razer Blade Future", kind: .laptop)
        let mouse = device(productID: 0x005C, name: "Razer DeathAdder Elite", kind: .mouse)

        XCTAssertEqual(
            DeviceMatrixLayout.dimensions(for: tartarus),
            .init(rows: 4, columns: 6)
        )
        XCTAssertEqual(
            DeviceMatrixLayout.dimensions(for: newerLaptop),
            .init(rows: 6, columns: 16)
        )
        XCTAssertNil(DeviceMatrixLayout.dimensions(for: mouse))
    }

    func testWheelAndRippleFramesHaveExpectedShapeAndColour() {
        let wheel = MatrixAnimations.wheelFrame(rows: 4, columns: 6, phase: 0)
        XCTAssertEqual(wheel.count, 4)
        XCTAssertTrue(wheel.allSatisfy { $0.count == 6 })
        XCTAssertTrue(wheel.flatMap { $0 }.contains { $0.red > 0 && $0.green > 0 })

        let colour = RazerCore.RGBColor(red: 255, green: 0, blue: 0)
        let ripple = MatrixAnimations.rippleFrame(
            rows: 4,
            columns: 6,
            ripples: [
                .init(origin: .init(row: 2, column: 3), progress: 0)
            ],
            colour: colour
        )
        XCTAssertEqual(ripple[2][3], colour)
        XCTAssertEqual(
            ripple[0][0],
            RazerCore.RGBColor(red: 0, green: 0, blue: 0)
        )
    }

    private func device(
        productID: UInt16,
        name: String,
        kind: DeviceKind
    ) -> RazerDevice {
        RazerDevice(
            id: name,
            productID: productID,
            productName: name,
            serialNumber: nil,
            kind: kind,
            transactionID: 0x3F,
            lightingProtocol: .extendedMatrix,
            supportLevel: .community,
            targets: [.backlight],
            supportedEffects: [],
            supportsBrightness: true
        )
    }
}
