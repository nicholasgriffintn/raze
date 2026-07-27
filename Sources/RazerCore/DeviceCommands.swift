import Foundation

public enum PollingRate: Int, Codable, CaseIterable, Sendable {
    case hz125 = 125
    case hz500 = 500
    case hz1000 = 1000

    var protocolValue: UInt8 {
        switch self {
        case .hz125: 0x08
        case .hz500: 0x02
        case .hz1000: 0x01
        }
    }

    init?(protocolValue: UInt8) {
        switch protocolValue {
        case 0x08: self = .hz125
        case 0x02: self = .hz500
        case 0x01: self = .hz1000
        default: return nil
        }
    }
}

public struct DevicePowerStatus: Equatable, Sendable {
    public let percentage: Int
    public let isCharging: Bool

    public init(percentage: Int, isCharging: Bool) {
        self.percentage = percentage
        self.isCharging = isCharging
    }
}

public struct DeviceControlCapabilities: Equatable, Sendable {
    public let dpiRange: ClosedRange<Int>?
    public let pollingRates: [PollingRate]
    public let supportsBattery: Bool

    public init(
        dpiRange: ClosedRange<Int>? = nil,
        pollingRates: [PollingRate] = [],
        supportsBattery: Bool = false
    ) {
        self.dpiRange = dpiRange
        self.pollingRates = pollingRates
        self.supportsBattery = supportsBattery
    }
}

public extension RazerDevice {
    var controlCapabilities: DeviceControlCapabilities {
        guard kind == .mouse, supportLevel == .community else {
            return .init()
        }
        let lowercasedName = productName.lowercased()
        let supportsBattery = [
            "wireless", "receiver", "bluetooth", "hyperspeed", "ultimate", "dock"
        ].contains { lowercasedName.contains($0) }
        let maximumDPI = productID == 0x005C ? 16_000 : 20_000
        return .init(
            dpiRange: 100...maximumDPI,
            pollingRates: PollingRate.allCases,
            supportsBattery: supportsBattery
        )
    }
}

public extension RazerCommands {
    static func setDPI(_ dpi: Int, transactionID: UInt8) throws -> RazerCommand {
        let clamped = UInt16(clamping: min(max(dpi, 100), 26_000))
        let high = UInt8((clamped >> 8) & 0xFF)
        let low = UInt8(clamped & 0xFF)
        return try RazerCommand(
            transactionID: transactionID,
            commandClass: 0x04,
            commandID: 0x05,
            arguments: [0x01, high, low, high, low, 0x00, 0x00]
        )
    }

    static func getDPI(transactionID: UInt8) throws -> RazerCommand {
        try RazerCommand(
            transactionID: transactionID,
            commandClass: 0x04,
            commandID: 0x85,
            arguments: [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        )
    }

    static func setPollingRate(
        _ rate: PollingRate,
        transactionID: UInt8
    ) throws -> RazerCommand {
        try RazerCommand(
            transactionID: transactionID,
            commandClass: 0x00,
            commandID: 0x05,
            arguments: [rate.protocolValue]
        )
    }

    static func getPollingRate(transactionID: UInt8) throws -> RazerCommand {
        try RazerCommand(
            transactionID: transactionID,
            commandClass: 0x00,
            commandID: 0x85,
            arguments: [0x00]
        )
    }

    static func getBatteryLevel(transactionID: UInt8) throws -> RazerCommand {
        try RazerCommand(
            transactionID: transactionID,
            commandClass: 0x07,
            commandID: 0x80,
            arguments: [0x00, 0x00]
        )
    }

    static func getChargingStatus(transactionID: UInt8) throws -> RazerCommand {
        try RazerCommand(
            transactionID: transactionID,
            commandClass: 0x07,
            commandID: 0x84,
            arguments: [0x00, 0x00]
        )
    }
}

public enum DeviceResponseDecoder {
    public static func dpi(from response: RazerResponse) -> Int? {
        guard response.arguments.count >= 3 else { return nil }
        return Int(response.arguments[1]) << 8 | Int(response.arguments[2])
    }

    public static func pollingRate(from response: RazerResponse) -> PollingRate? {
        guard let value = response.arguments.first else { return nil }
        return PollingRate(protocolValue: value)
    }

    public static func batteryPercentage(from response: RazerResponse) -> Int? {
        guard response.arguments.count >= 2 else { return nil }
        return Int((Double(response.arguments[1]) * 100 / 255).rounded())
    }

    public static func isCharging(from response: RazerResponse) -> Bool? {
        guard response.arguments.count >= 2 else { return nil }
        return response.arguments[1] != 0
    }
}
