import Foundation
import XCTest
@testable import RazerCore

final class RazerProtocolTests: XCTestCase {
    func testChangingEffectKindPreservesThePrimaryColour() {
        let colour = RazerCore.RGBColor(red: 10, green: 20, blue: 30)
        let effect = LightingEffect.staticColor(colour)

        XCTAssertEqual(
            effect.changingKind(to: LightingEffectKind.breathing),
            LightingEffect.breathing(colour, nil)
        )
        XCTAssertEqual(
            effect.changingKind(to: LightingEffectKind.reactive),
            LightingEffect.reactive(colour, .medium)
        )
        XCTAssertEqual(
            effect.changingKind(to: LightingEffectKind.wave),
            LightingEffect.wave(.left)
        )
        XCTAssertEqual(
            effect.changingKind(to: LightingEffectKind.starlight),
            LightingEffect.starlight(colour, nil, .medium)
        )
        XCTAssertEqual(
            effect.changingKind(to: LightingEffectKind.ripple),
            LightingEffect.ripple(colour)
        )
    }

    func testCommandLayoutAndChecksum() throws {
        let command = try RazerCommand(
            transactionID: 0x1F,
            commandClass: 0x0F,
            commandID: 0x02,
            arguments: [0x01, 0x05, 0x01, 0x00, 0x00, 0x01, 0xFF, 0x20, 0x00]
        )

        let bytes = [UInt8](command.encode())

        XCTAssertEqual(bytes.count, 90)
        XCTAssertEqual(bytes[1], 0x1F)
        XCTAssertEqual(bytes[5], 9)
        XCTAssertEqual(bytes[6], 0x0F)
        XCTAssertEqual(bytes[7], 0x02)
        XCTAssertEqual(
            Array(bytes[8...16]),
            [0x01, 0x05, 0x01, 0x00, 0x00, 0x01, 0xFF, 0x20, 0x00]
        )
        XCTAssertEqual(bytes[88], bytes[2...87].reduce(0, ^))
    }

    func testStandardStaticEffectFixture() throws {
        let command = try RazerCommands.lighting(
            .staticColor(.init(red: 1, green: 2, blue: 3)),
            target: .backlight,
            transactionID: 0xFF,
            protocol: .standardMatrix
        )

        XCTAssertEqual(command.commandClass, 0x03)
        XCTAssertEqual(command.commandID, 0x0A)
        XCTAssertEqual(command.arguments, [0x06, 1, 2, 3])
    }

    func testExtendedStaticEffectFixture() throws {
        let command = try RazerCommands.lighting(
            .staticColor(.init(red: 1, green: 2, blue: 3)),
            target: .backlight,
            transactionID: 0x3F,
            protocol: .extendedMatrix
        )

        XCTAssertEqual(command.commandClass, 0x0F)
        XCTAssertEqual(command.commandID, 0x02)
        XCTAssertEqual(command.arguments, [0x01, 0x05, 0x01, 0, 0, 1, 1, 2, 3])
    }

    func testMouseExtendedStaticEffectFixture() throws {
        let command = try RazerCommands.lighting(
            .staticColor(.init(red: 1, green: 2, blue: 3)),
            target: .logo,
            transactionID: 0x3F,
            protocol: .mouseExtendedMatrix
        )

        XCTAssertEqual(command.commandClass, 0x03)
        XCTAssertEqual(command.commandID, 0x0D)
        XCTAssertEqual(command.arguments, [0x01, 0x04, 0x06, 1, 2, 3])
    }

    func testMouseExtendedProtocolRejectsUnsupportedWaveEffect() {
        XCTAssertThrowsError(
            try RazerCommands.lighting(
                .wave(.left),
                target: .logo,
                transactionID: 0x3F,
                protocol: .mouseExtendedMatrix
            )
        ) { error in
            XCTAssertEqual(
                error as? RazerProtocolError,
                .unsupportedEffect(
                    effect: .wave,
                    lightingProtocol: .mouseExtendedMatrix
                )
            )
        }
    }

    func testStarlightUsesProtocolSpecificPayloads() throws {
        let first = RazerCore.RGBColor(red: 1, green: 2, blue: 3)
        let second = RazerCore.RGBColor(red: 4, green: 5, blue: 6)
        let standard = try RazerCommands.lighting(
            .starlight(first, second, .slow),
            target: .backlight,
            transactionID: 0x3F,
            protocol: .standardMatrix
        )
        let extended = try RazerCommands.lighting(
            .starlight(first, nil, .fast),
            target: .backlight,
            transactionID: 0x1F,
            protocol: .extendedMatrix
        )

        XCTAssertEqual(
            standard.arguments,
            [0x19, 0x02, 0x03, 1, 2, 3, 4, 5, 6]
        )
        XCTAssertEqual(
            extended.arguments,
            [0x01, 0x05, 0x07, 0x00, 0x01, 0x01, 1, 2, 3]
        )
    }

    func testAnimatedEffectsEnterCustomModeAndEncodeMatrixRows() throws {
        let colour = RazerCore.RGBColor(red: 0x12, green: 0x34, blue: 0x56)
        let standardMode = try RazerCommands.lighting(
            .ripple(colour),
            target: .backlight,
            transactionID: 0xFF,
            protocol: .standardMatrix
        )
        let extendedMode = try RazerCommands.lighting(
            .wheel,
            target: .backlight,
            transactionID: 0x3F,
            protocol: .extendedMatrix
        )
        let standardRow = try RazerCommands.customFrameRow(
            [colour],
            row: 2,
            startColumn: 3,
            transactionID: 0xFF,
            protocol: .standardMatrix
        )
        let extendedRow = try RazerCommands.customFrameRow(
            [colour],
            row: 2,
            startColumn: 3,
            transactionID: 0x3F,
            protocol: .extendedMatrix
        )

        XCTAssertEqual(standardMode.arguments, [0x05, 0x01])
        XCTAssertEqual(extendedMode.arguments, [UInt8](repeating: 0, count: 2) + [0x08] + [UInt8](repeating: 0, count: 9))
        XCTAssertEqual([standardRow.commandClass, standardRow.commandID], [0x03, 0x0B])
        XCTAssertEqual(standardRow.arguments.count, 0x46)
        XCTAssertEqual(Array(standardRow.arguments.prefix(7)), [0xFF, 0x02, 0x03, 0x03, 0x12, 0x34, 0x56])
        XCTAssertEqual([extendedRow.commandClass, extendedRow.commandID], [0x0F, 0x03])
        XCTAssertEqual(extendedRow.arguments.count, 0x47)
        XCTAssertEqual(Array(extendedRow.arguments.prefix(8)), [0x00, 0x00, 0x02, 0x03, 0x03, 0x12, 0x34, 0x56])
    }

    func testMouseExtendedProtocolRejectsStarlight() {
        XCTAssertThrowsError(
            try RazerCommands.lighting(
                .starlight(.init(red: 1, green: 2, blue: 3), nil, .medium),
                target: .logo,
                transactionID: 0x3F,
                protocol: .mouseExtendedMatrix
            )
        ) { error in
            XCTAssertEqual(
                error as? RazerProtocolError,
                .unsupportedEffect(
                    effect: .starlight,
                    lightingProtocol: .mouseExtendedMatrix
                )
            )
        }
    }

    func testMousePerformanceAndPowerCommandsMatchProtocolFixtures() throws {
        let dpi = try RazerCommands.setDPI(16_000, transactionID: 0x3F)
        let polling = try RazerCommands.setPollingRate(.hz1000, transactionID: 0x3F)
        let battery = try RazerCommands.getBatteryLevel(transactionID: 0x1F)
        let charging = try RazerCommands.getChargingStatus(transactionID: 0x1F)

        XCTAssertEqual([dpi.commandClass, dpi.commandID], [0x04, 0x05])
        XCTAssertEqual(dpi.arguments, [0x01, 0x3E, 0x80, 0x3E, 0x80, 0, 0])
        XCTAssertEqual([polling.commandClass, polling.commandID], [0x00, 0x05])
        XCTAssertEqual(polling.arguments, [0x01])
        XCTAssertEqual([battery.commandClass, battery.commandID], [0x07, 0x80])
        XCTAssertEqual([charging.commandClass, charging.commandID], [0x07, 0x84])
    }

    func testMousePerformanceAndPowerResponsesDecode() {
        let dpi = RazerResponse(
            status: .successful,
            arguments: [0x01, 0x3E, 0x80, 0x3E, 0x80, 0, 0]
        )
        let polling = RazerResponse(status: .successful, arguments: [0x02])
        let battery = RazerResponse(status: .successful, arguments: [0, 128])
        let charging = RazerResponse(status: .successful, arguments: [0, 1])

        XCTAssertEqual(DeviceResponseDecoder.dpi(from: dpi), 16_000)
        XCTAssertEqual(DeviceResponseDecoder.pollingRate(from: polling), .hz500)
        XCTAssertEqual(DeviceResponseDecoder.batteryPercentage(from: battery), 50)
        XCTAssertEqual(DeviceResponseDecoder.isCharging(from: charging), true)
    }

    func testProtocolVariantsEncodeEffectSpecificPayloads() throws {
        let color = RazerCore.RGBColor(red: 1, green: 2, blue: 3)
        let fixtures: [
            (
                protocol: LightingProtocol,
                effect: LightingEffect,
                expectedClass: UInt8,
                expectedID: UInt8,
                expectedArguments: [UInt8]
            )
        ] = [
            (.standardMatrix, .reactive(color, .long), 0x03, 0x0A, [0x02, 0x03, 1, 2, 3]),
            (.standardMatrix, .breathing(color, nil), 0x03, 0x0A, [0x03, 0x01, 1, 2, 3, 0, 0, 0]),
            (.extendedMatrix, .off, 0x0F, 0x02, [0x01, 0x05, 0, 0, 0, 0]),
            (.extendedMatrix, .spectrum, 0x0F, 0x02, [0x01, 0x05, 0x03, 0, 0, 0]),
            (.extendedMatrix, .wave(.right), 0x0F, 0x02, [0x01, 0x05, 0x04, 0x02, 0x28, 0]),
            (.extendedMatrix, .reactive(color, .short), 0x0F, 0x02, [0x01, 0x05, 0x05, 0, 0x01, 0x01, 1, 2, 3]),
            (.mouseExtendedMatrix, .off, 0x03, 0x0D, [0x01, 0x05, 0]),
            (.mouseExtendedMatrix, .spectrum, 0x03, 0x0D, [0x01, 0x05, 0x04]),
            (.mouseExtendedMatrix, .reactive(color, .medium), 0x03, 0x0D, [0x01, 0x05, 0x02, 0x02, 1, 2, 3]),
            (.mouseExtendedMatrix, .breathing(color, nil), 0x03, 0x0D, [0x01, 0x05, 0x03, 0x01, 1, 2, 3, 0, 0, 0])
        ]

        for fixture in fixtures {
            let command = try RazerCommands.lighting(
                fixture.effect,
                target: .backlight,
                transactionID: 0x1F,
                protocol: fixture.protocol
            )

            XCTAssertEqual(command.commandClass, fixture.expectedClass)
            XCTAssertEqual(command.commandID, fixture.expectedID)
            XCTAssertEqual(
                command.arguments,
                fixture.expectedArguments,
                "Unexpected payload for \(fixture.protocol) \(fixture.effect.kind)"
            )
        }
    }

    func testExtendedTwoColourBreathingFixture() throws {
        let command = try RazerCommands.lighting(
            .breathing(
                .init(red: 1, green: 2, blue: 3),
                .init(red: 4, green: 5, blue: 6)
            ),
            target: .backlight,
            transactionID: 0x1F,
            protocol: .extendedMatrix
        )

        XCTAssertEqual(
            command.arguments,
            [0x01, 0x05, 0x02, 0x02, 0x00, 0x02, 1, 2, 3, 4, 5, 6]
        )
    }

    func testBrightnessUsesProtocolSpecificCommand() throws {
        let standard = try RazerCommands.brightness(
            255,
            target: .backlight,
            transactionID: 0xFF,
            protocol: .standardMatrix
        )
        let extended = try RazerCommands.brightness(
            255,
            target: .backlight,
            transactionID: 0x3F,
            protocol: .extendedMatrix
        )

        XCTAssertEqual([standard.commandClass, standard.commandID], [0x03, 0x03])
        XCTAssertEqual([extended.commandClass, extended.commandID], [0x0F, 0x04])
        XCTAssertEqual(standard.arguments, [0x01, 0x05, 0xFF])
        XCTAssertEqual(extended.arguments, [0x01, 0x05, 0xFF])
    }

    func testBrightnessPercentageConversionRoundsAndClamps() {
        XCTAssertEqual(RazerCommands.brightnessByte(fromPercentage: -1), 0)
        XCTAssertEqual(RazerCommands.brightnessByte(fromPercentage: 0), 0)
        XCTAssertEqual(RazerCommands.brightnessByte(fromPercentage: 50), 128)
        XCTAssertEqual(RazerCommands.brightnessByte(fromPercentage: 100), 255)
        XCTAssertEqual(RazerCommands.brightnessByte(fromPercentage: 101), 255)
    }

    func testRejectsOversizedCommandPayload() {
        XCTAssertThrowsError(
            try RazerCommand(
                transactionID: 0,
                commandClass: 0,
                commandID: 0,
                arguments: [UInt8](repeating: 0, count: 81)
            )
        ) { error in
            XCTAssertEqual(error as? RazerProtocolError, .invalidArgumentCount(81))
        }
    }

    func testDecodesValidatedSuccessfulResponse() throws {
        let command = try commandFixture()
        let response = try RazerResponse.decode(
            responseFixture(for: command, arguments: [0xAA, 0xBB]),
            for: command
        )

        XCTAssertEqual(response.arguments, [0xAA, 0xBB])
    }

    func testAcceptsMaximumSizedCommandAndResponsePayloads() throws {
        let arguments = Array(UInt8(0)..<UInt8(80))
        let command = try RazerCommand(
            transactionID: 0x1F,
            commandClass: 0x03,
            commandID: 0x0A,
            arguments: arguments
        )

        let encoded = [UInt8](command.encode())
        let response = try RazerResponse.decode(
            responseFixture(for: command, arguments: arguments),
            for: command
        )

        XCTAssertEqual(Array(encoded[8...87]), arguments)
        XCTAssertEqual(response.arguments, arguments)
    }

    func testRejectsMalformedResponseLengths() throws {
        let command = try commandFixture()

        for length in [0, 89, 91] {
            XCTAssertThrowsError(
                try RazerResponse.decode(Data(repeating: 0, count: length), for: command)
            ) { error in
                XCTAssertEqual(error as? RazerProtocolError, .invalidResponseLength(length))
            }
        }
    }

    func testRejectsDeviceControlledArgumentCountBeforeSlicing() throws {
        let command = try commandFixture()

        for argumentCount in [81, 83, 255] {
            var bytes = [UInt8](responseFixture(for: command))
            bytes[5] = UInt8(argumentCount)
            bytes[88] = bytes[2...87].reduce(0, ^)

            XCTAssertThrowsError(
                try RazerResponse.decode(Data(bytes), for: command)
            ) { error in
                XCTAssertEqual(
                    error as? RazerProtocolError,
                    .invalidResponseArgumentCount(argumentCount)
                )
            }
        }
    }

    func testRejectsBadResponseChecksum() throws {
        let command = try commandFixture()
        var bytes = [UInt8](responseFixture(for: command))
        bytes[10] = 0xFF

        XCTAssertThrowsError(try RazerResponse.decode(Data(bytes), for: command)) { error in
            guard case .checksumMismatch = error as? RazerProtocolError else {
                return XCTFail("Expected checksum mismatch, got \(error)")
            }
        }
    }

    func testRejectsMismatchedResponseMetadata() throws {
        let command = try commandFixture()
        var wrongTransaction = [UInt8](responseFixture(for: command))
        wrongTransaction[1] = 0x3F
        var wrongCommand = [UInt8](responseFixture(for: command))
        wrongCommand[7] = 0x0B
        wrongCommand[88] = wrongCommand[2...87].reduce(0, ^)

        XCTAssertThrowsError(
            try RazerResponse.decode(Data(wrongTransaction), for: command)
        ) { error in
            XCTAssertEqual(
                error as? RazerProtocolError,
                .transactionMismatch(expected: 0x1F, actual: 0x3F)
            )
        }
        XCTAssertThrowsError(
            try RazerResponse.decode(Data(wrongCommand), for: command)
        ) { error in
            XCTAssertEqual(
                error as? RazerProtocolError,
                .commandMismatch(
                    expectedClass: 0x03,
                    expectedID: 0x0A,
                    actualClass: 0x03,
                    actualID: 0x0B
                )
            )
        }
    }

    func testSurfacesRejectedStatuses() throws {
        let command = try commandFixture()

        for status in [
            RazerResponse.Status.busy.rawValue,
            RazerResponse.Status.timeout.rawValue,
            UInt8.max
        ] {
            XCTAssertThrowsError(
                try RazerResponse.decode(responseFixture(for: command, status: status), for: command)
            ) { error in
                XCTAssertEqual(
                    error as? RazerProtocolError,
                    .deviceRejected(status: status)
                )
            }
        }
    }

    private func commandFixture() throws -> RazerCommand {
        try RazerCommand(
            transactionID: 0x1F,
            commandClass: 0x03,
            commandID: 0x0A,
            arguments: []
        )
    }

    private func responseFixture(
        for command: RazerCommand,
        status: UInt8 = RazerResponse.Status.successful.rawValue,
        arguments: [UInt8] = []
    ) -> Data {
        var bytes = [UInt8](repeating: 0, count: RazerCommand.reportLength)
        bytes[0] = status
        bytes[1] = command.transactionID
        bytes[5] = UInt8(arguments.count)
        bytes[6] = command.commandClass
        bytes[7] = command.commandID
        bytes.replaceSubrange(8..<(8 + arguments.count), with: arguments)
        bytes[88] = bytes[2...87].reduce(0, ^)
        return Data(bytes)
    }
}
