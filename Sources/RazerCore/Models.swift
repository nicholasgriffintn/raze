import Foundation

public enum DeviceKind: String, Codable, Sendable {
    case mouse
    case keyboard
    case headset
    case laptop
    case accessory
    case unknown
}

public enum LightingProtocol: String, Codable, Sendable {
    case standardMatrix
    case extendedMatrix
    case mouseExtendedMatrix
}

public enum DeviceSupportLevel: String, Codable, Sendable {
    case community
    case detectionOnly
}

public struct DeviceDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: UInt16 { productID }
    public let productID: UInt16
    public let name: String
    public let kind: DeviceKind
    public let transactionID: UInt8
    public let lightingProtocol: LightingProtocol?
    public let supportLevel: DeviceSupportLevel
    public let targets: [LightingTarget]
    public let supportedEffects: Set<LightingEffectKind>
    public let supportsBrightness: Bool

    public init(
        productID: UInt16,
        name: String,
        kind: DeviceKind,
        transactionID: UInt8,
        lightingProtocol: LightingProtocol?,
        supportLevel: DeviceSupportLevel,
        targets: [LightingTarget],
        supportedEffects: Set<LightingEffectKind>,
        supportsBrightness: Bool
    ) {
        self.productID = productID
        self.name = name
        self.kind = kind
        self.transactionID = transactionID
        self.lightingProtocol = lightingProtocol
        self.supportLevel = supportLevel
        self.targets = targets
        self.supportedEffects = supportedEffects
        self.supportsBrightness = supportsBrightness
    }
}

public struct RazerDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let productID: UInt16
    public let productName: String
    public let serialNumber: String?
    public let kind: DeviceKind
    public let transactionID: UInt8
    public let lightingProtocol: LightingProtocol?
    public let supportLevel: DeviceSupportLevel
    public let targets: [LightingTarget]
    public let supportedEffects: Set<LightingEffectKind>
    public let supportsBrightness: Bool

    public init(
        id: String,
        productID: UInt16,
        productName: String,
        serialNumber: String?,
        kind: DeviceKind,
        transactionID: UInt8,
        lightingProtocol: LightingProtocol?,
        supportLevel: DeviceSupportLevel,
        targets: [LightingTarget],
        supportedEffects: Set<LightingEffectKind>,
        supportsBrightness: Bool
    ) {
        self.id = id
        self.productID = productID
        self.productName = productName
        self.serialNumber = serialNumber
        self.kind = kind
        self.transactionID = transactionID
        self.lightingProtocol = lightingProtocol
        self.supportLevel = supportLevel
        self.targets = targets
        self.supportedEffects = supportedEffects
        self.supportsBrightness = supportsBrightness
    }

    public var supportsLighting: Bool {
        lightingProtocol != nil && !targets.isEmpty
    }
}

public struct DeviceCatalog: Sendable {
    public static let vendorID: UInt16 = 0x1532
    private let definitions: [UInt16: DeviceDefinition]

    public init(definitions: [DeviceDefinition] = Self.builtIns) {
        self.definitions = definitions.reduce(into: [:]) { catalog, definition in
            catalog[definition.productID] = definition
        }
    }

    public func definition(for productID: UInt16) -> DeviceDefinition? { definitions[productID] }
}

public struct DeviceProfile: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var productID: UInt16
    public var target: LightingTarget
    public var effect: LightingEffect
    public var brightness: UInt8

    public init(
        id: UUID = UUID(),
        name: String,
        productID: UInt16,
        target: LightingTarget,
        effect: LightingEffect,
        brightness: UInt8
    ) {
        self.id = id
        self.name = name
        self.productID = productID
        self.target = target
        self.effect = effect
        self.brightness = brightness
    }
}
