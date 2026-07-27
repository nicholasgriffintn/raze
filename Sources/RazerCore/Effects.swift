import Foundation

public struct RGBColor: Codable, Equatable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum WaveDirection: UInt8, Codable, Sendable {
    case left = 1
    case right = 2
}

public enum ReactiveSpeed: UInt8, Codable, Sendable {
    case short = 1
    case medium = 2
    case long = 3
}

public enum StarlightSpeed: UInt8, Codable, Sendable {
    case fast = 1
    case medium = 2
    case slow = 3
}

public enum LightingEffectKind: String, Codable, CaseIterable, Sendable {
    case off
    case spectrum
    case staticColor
    case breathing
    case reactive
    case wave
    case starlight
    case ripple
    case wheel
}

public enum LightingEffect: Codable, Equatable, Sendable {
    case off
    case spectrum
    case staticColor(RGBColor)
    case breathing(RGBColor, RGBColor?)
    case reactive(RGBColor, ReactiveSpeed)
    case wave(WaveDirection)
    case starlight(RGBColor, RGBColor?, StarlightSpeed)
    case ripple(RGBColor)
    case wheel

    public var kind: LightingEffectKind {
        switch self {
        case .off: .off
        case .spectrum: .spectrum
        case .staticColor: .staticColor
        case .breathing: .breathing
        case .reactive: .reactive
        case .wave: .wave
        case .starlight: .starlight
        case .ripple: .ripple
        case .wheel: .wheel
        }
    }

    public var primaryColor: RGBColor {
        switch self {
        case .staticColor(let color),
             .breathing(let color, _),
             .reactive(let color, _),
             .starlight(let color, _, _),
             .ripple(let color):
            color
        default:
            .init(red: 0, green: 255, blue: 80)
        }
    }

    public func changingKind(to kind: LightingEffectKind) -> Self {
        switch kind {
        case .off:
            .off
        case .spectrum:
            .spectrum
        case .staticColor:
            .staticColor(primaryColor)
        case .breathing:
            .breathing(primaryColor, nil)
        case .reactive:
            .reactive(primaryColor, .medium)
        case .wave:
            .wave(.left)
        case .starlight:
            .starlight(primaryColor, nil, .medium)
        case .ripple:
            .ripple(primaryColor)
        case .wheel:
            .wheel
        }
    }
}

public enum LightingTarget: UInt8, Codable, CaseIterable, Sendable {
    case all = 0x00
    case scrollWheel = 0x01
    case battery = 0x03
    case logo = 0x04
    case backlight = 0x05
}

public enum RazerCommands {
    public static func lighting(
        _ effect: LightingEffect,
        target: LightingTarget,
        transactionID: UInt8,
        protocol lightingProtocol: LightingProtocol,
        storage: UInt8 = 0x01
    ) throws -> RazerCommand {
        let encoded = try encode(
            effect,
            target: target,
            protocol: lightingProtocol,
            storage: storage
        )
        return try RazerCommand(
            transactionID: transactionID,
            commandClass: encoded.commandClass,
            commandID: encoded.commandID,
            arguments: encoded.arguments
        )
    }

    public static func brightness(
        _ value: UInt8,
        target: LightingTarget,
        transactionID: UInt8,
        protocol lightingProtocol: LightingProtocol,
        storage: UInt8 = 0x01
    ) throws -> RazerCommand {
        switch lightingProtocol {
        case .standardMatrix, .mouseExtendedMatrix:
            return try RazerCommand(
                transactionID: transactionID,
                commandClass: 0x03,
                commandID: 0x03,
                arguments: [storage, target.rawValue, value]
            )
        case .extendedMatrix:
            return try RazerCommand(
                transactionID: transactionID,
                commandClass: 0x0F,
                commandID: 0x04,
                arguments: [storage, target.rawValue, value]
            )
        }
    }

    public static func brightnessByte(fromPercentage percentage: Double) -> UInt8 {
        let clamped = min(max(percentage, 0), 100)
        return UInt8((clamped * 255 / 100).rounded())
    }

    public static func customFrameRow(
        _ colours: [RGBColor],
        row: UInt8,
        startColumn: UInt8 = 0,
        transactionID: UInt8,
        protocol lightingProtocol: LightingProtocol
    ) throws -> RazerCommand {
        guard
            !colours.isEmpty,
            colours.count <= 22,
            Int(startColumn) + colours.count <= 256
        else {
            throw RazerProtocolError.invalidArgumentCount(colours.count * 3)
        }
        let lastColumn = startColumn + UInt8(colours.count - 1)
        let rgb = colours.flatMap { [$0.red, $0.green, $0.blue] }

        switch lightingProtocol {
        case .standardMatrix:
            var arguments = [UInt8](repeating: 0, count: 0x46)
            arguments.replaceSubrange(
                0..<4,
                with: [0xFF, row, startColumn, lastColumn]
            )
            arguments.replaceSubrange(4..<(4 + rgb.count), with: rgb)
            return try RazerCommand(
                transactionID: transactionID,
                commandClass: 0x03,
                commandID: 0x0B,
                arguments: arguments
            )
        case .extendedMatrix:
            var arguments = [UInt8](repeating: 0, count: 0x47)
            arguments.replaceSubrange(2..<5, with: [row, startColumn, lastColumn])
            arguments.replaceSubrange(5..<(5 + rgb.count), with: rgb)
            return try RazerCommand(
                transactionID: transactionID,
                commandClass: 0x0F,
                commandID: 0x03,
                arguments: arguments
            )
        case .mouseExtendedMatrix:
            throw RazerProtocolError.unsupportedEffect(
                effect: .wheel,
                lightingProtocol: lightingProtocol
            )
        }
    }

    private static func encode(
        _ effect: LightingEffect,
        target: LightingTarget,
        protocol lightingProtocol: LightingProtocol,
        storage: UInt8
    ) throws -> (commandClass: UInt8, commandID: UInt8, arguments: [UInt8]) {
        switch lightingProtocol {
        case .standardMatrix:
            return (0x03, 0x0A, standardArguments(for: effect))
        case .extendedMatrix:
            return (0x0F, 0x02, extendedArguments(for: effect, target: target, storage: storage))
        case .mouseExtendedMatrix:
            return (
                0x03,
                0x0D,
                try mouseArguments(for: effect, target: target, storage: storage)
            )
        }
    }

    private static func standardArguments(for effect: LightingEffect) -> [UInt8] {
        switch effect {
        case .off:
            return [0x00]
        case .wave(let direction):
            return [0x01, direction.rawValue]
        case .reactive(let color, let speed):
            return [0x02, speed.rawValue, color.red, color.green, color.blue]
        case .breathing(let first, let second):
            if let second {
                return [
                    0x03, 0x02,
                    first.red, first.green, first.blue,
                    second.red, second.green, second.blue
                ]
            }
            return [0x03, 0x01, first.red, first.green, first.blue, 0x00, 0x00, 0x00]
        case .spectrum:
            return [0x04]
        case .staticColor(let color):
            return [0x06, color.red, color.green, color.blue]
        case .starlight(let first, let second, let speed):
            if let second {
                return [
                    0x19, 0x02, speed.rawValue,
                    first.red, first.green, first.blue,
                    second.red, second.green, second.blue
                ]
            }
            return [
                0x19, 0x01, speed.rawValue,
                first.red, first.green, first.blue,
                0x00, 0x00, 0x00
            ]
        case .ripple, .wheel:
            return [0x05, 0x01]
        }
    }

    private static func extendedArguments(
        for effect: LightingEffect,
        target: LightingTarget,
        storage: UInt8
    ) -> [UInt8] {
        let prefix = [storage, target.rawValue]
        switch effect {
        case .off:
            return prefix + [0x00, 0x00, 0x00, 0x00]
        case .staticColor(let color):
            return prefix + [0x01, 0x00, 0x00, 0x01, color.red, color.green, color.blue]
        case .breathing(let first, let second):
            if let second {
                return prefix + [
                    0x02, 0x02, 0x00, 0x02,
                    first.red, first.green, first.blue,
                    second.red, second.green, second.blue
                ]
            }
            return prefix + [0x02, 0x01, 0x00, 0x01, first.red, first.green, first.blue]
        case .spectrum:
            return prefix + [0x03, 0x00, 0x00, 0x00]
        case .wave(let direction):
            return prefix + [0x04, direction.rawValue, 0x28, 0x00]
        case .reactive(let color, let speed):
            return prefix + [0x05, 0x00, speed.rawValue, 0x01, color.red, color.green, color.blue]
        case .starlight(let first, let second, let speed):
            if let second {
                return prefix + [
                    0x07, 0x00, speed.rawValue, 0x02,
                    first.red, first.green, first.blue,
                    second.red, second.green, second.blue
                ]
            }
            return prefix + [
                0x07, 0x00, speed.rawValue, 0x01,
                first.red, first.green, first.blue
            ]
        case .ripple, .wheel:
            return [0x00, 0x00, 0x08] + [UInt8](repeating: 0, count: 9)
        }
    }

    private static func mouseArguments(
        for effect: LightingEffect,
        target: LightingTarget,
        storage: UInt8
    ) throws -> [UInt8] {
        let prefix = [storage, target.rawValue]
        switch effect {
        case .off:
            return prefix + [0x00]
        case .wave, .starlight, .ripple, .wheel:
            throw RazerProtocolError.unsupportedEffect(
                effect: effect.kind,
                lightingProtocol: .mouseExtendedMatrix
            )
        case .reactive(let color, let speed):
            return prefix + [0x02, speed.rawValue, color.red, color.green, color.blue]
        case .breathing(let first, let second):
            if let second {
                return prefix + [
                    0x03, 0x02,
                    first.red, first.green, first.blue,
                    second.red, second.green, second.blue
                ]
            }
            return prefix + [0x03, 0x01, first.red, first.green, first.blue, 0x00, 0x00, 0x00]
        case .spectrum:
            return prefix + [0x04]
        case .staticColor(let color):
            return prefix + [0x06, color.red, color.green, color.blue]
        }
    }
}
