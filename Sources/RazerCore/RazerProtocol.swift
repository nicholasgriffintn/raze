import Foundation

public enum RazerProtocolError: Error, Equatable, LocalizedError {
    case invalidArgumentCount(Int)
    case unsupportedEffect(effect: LightingEffectKind, lightingProtocol: LightingProtocol)
    case invalidResponseLength(Int)
    case invalidResponseArgumentCount(Int)
    case checksumMismatch(expected: UInt8, actual: UInt8)
    case deviceRejected(status: UInt8)
    case transactionMismatch(expected: UInt8, actual: UInt8)
    case commandMismatch(
        expectedClass: UInt8,
        expectedID: UInt8,
        actualClass: UInt8,
        actualID: UInt8
    )

    public var errorDescription: String? {
        switch self {
        case .invalidArgumentCount(let count): "Command has \(count) argument bytes; maximum is 80."
        case .unsupportedEffect(let effect, let lightingProtocol):
            "\(effect.rawValue) is not supported by the \(lightingProtocol.rawValue) protocol."
        case .invalidResponseLength(let count): "Device returned \(count) bytes; expected 90."
        case .invalidResponseArgumentCount(let count):
            "Device response declares \(count) argument bytes; maximum is 80."
        case .checksumMismatch(let expected, let actual):
            "Response checksum mismatch: expected 0x\(String(expected, radix: 16)), got 0x\(String(actual, radix: 16))."
        case .deviceRejected(let status): "Device rejected command (status 0x\(String(status, radix: 16)))."
        case .transactionMismatch(let expected, let actual):
            "Transaction mismatch: expected 0x\(String(expected, radix: 16)), got 0x\(String(actual, radix: 16))."
        case .commandMismatch(let expectedClass, let expectedID, let actualClass, let actualID):
            "Response command mismatch: expected 0x\(String(expectedClass, radix: 16))/0x\(String(expectedID, radix: 16)), got 0x\(String(actualClass, radix: 16))/0x\(String(actualID, radix: 16))."
        }
    }
}

public struct RazerCommand: Equatable, Sendable {
    public static let reportLength = 90
    public let transactionID: UInt8
    public let commandClass: UInt8
    public let commandID: UInt8
    public let arguments: [UInt8]

    public init(transactionID: UInt8, commandClass: UInt8, commandID: UInt8, arguments: [UInt8]) throws {
        guard arguments.count <= 80 else { throw RazerProtocolError.invalidArgumentCount(arguments.count) }
        self.transactionID = transactionID
        self.commandClass = commandClass
        self.commandID = commandID
        self.arguments = arguments
    }

    public func encode() -> Data {
        var bytes = [UInt8](repeating: 0, count: Self.reportLength)
        bytes[1] = transactionID
        bytes[5] = UInt8(arguments.count)
        bytes[6] = commandClass
        bytes[7] = commandID
        bytes.replaceSubrange(8..<(8 + arguments.count), with: arguments)
        bytes[88] = bytes[2...87].reduce(0, ^)
        return Data(bytes)
    }
}

public struct RazerResponse: Equatable, Sendable {
    public enum Status: UInt8, Sendable {
        case newCommand = 0x00
        case busy = 0x01
        case successful = 0x02
        case failure = 0x03
        case timeout = 0x04
        case unsupported = 0x05
    }

    public let status: Status
    public let arguments: [UInt8]

    public static func decode(_ data: Data, for command: RazerCommand) throws -> Self {
        guard data.count == RazerCommand.reportLength else {
            throw RazerProtocolError.invalidResponseLength(data.count)
        }
        let bytes = [UInt8](data)
        guard bytes[1] == command.transactionID else {
            throw RazerProtocolError.transactionMismatch(expected: command.transactionID, actual: bytes[1])
        }
        guard bytes[6] == command.commandClass, bytes[7] == command.commandID else {
            throw RazerProtocolError.commandMismatch(
                expectedClass: command.commandClass,
                expectedID: command.commandID,
                actualClass: bytes[6],
                actualID: bytes[7]
            )
        }
        let checksum = bytes[2...87].reduce(0, ^)
        guard bytes[88] == checksum else {
            throw RazerProtocolError.checksumMismatch(expected: checksum, actual: bytes[88])
        }
        guard let status = Status(rawValue: bytes[0]), status == .successful else {
            throw RazerProtocolError.deviceRejected(status: bytes[0])
        }
        let argumentCount = Int(bytes[5])
        guard argumentCount <= 80 else {
            throw RazerProtocolError.invalidResponseArgumentCount(argumentCount)
        }
        return Self(status: status, arguments: Array(bytes[8..<(8 + argumentCount)]))
    }
}
