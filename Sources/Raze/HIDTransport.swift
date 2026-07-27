#if os(macOS)
import Foundation
import IOKit
import IOKit.hid
import IOKit.hidsystem
import RazerCore

enum HIDError: LocalizedError {
    case managerOpen(IOReturn)
    case open(IOReturn)
    case write(IOReturn)
    case read(IOReturn)
    case unknownDevice
    case noControlInterface

    var requiresInputMonitoring: Bool {
        switch self {
        case .managerOpen(let code), .open(let code), .write(let code), .read(let code):
            code == kIOReturnNotPermitted
        case .unknownDevice, .noControlInterface:
            false
        }
    }

    var errorDescription: String? {
        switch self {
        case .managerOpen(let code):
            "Could not scan HID devices (IOKit \(code)). Check Input Monitoring permission."
        case .open(let code):
            "Could not open the HID control interface (IOKit \(code)). Check Input Monitoring permission."
        case .write(let code):
            "Could not write the feature report (IOKit \(code))."
        case .read(let code):
            "Could not read the device response (IOKit \(code))."
        case .unknownDevice:
            "Lighting control is unavailable for this device definition."
        case .noControlInterface:
            "No compatible 90-byte feature-report interface was found."
        }
    }
}

enum HIDManagerOpenPolicy {
    static func permitsEnumeration(_ result: IOReturn) -> Bool {
        result == kIOReturnSuccess || result == kIOReturnNotPermitted
    }
}

actor HIDTransport {
    private let manager: IOHIDManager
    private let catalog: DeviceCatalog
    private var handles: [String: IOHIDDevice] = [:]

    init(catalog: DeviceCatalog = DeviceCatalog()) {
        self.catalog = catalog
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(
            manager,
            [kIOHIDVendorIDKey: NSNumber(value: DeviceCatalog.vendorID)] as CFDictionary
        )
    }

    func requestInputMonitoringAccess() -> Bool {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            true
        case kIOHIDAccessTypeUnknown:
            IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        default:
            false
        }
    }

    func scan() throws -> [RazerDevice] {
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard HIDManagerOpenPolicy.permitsEnumeration(openResult) else {
            throw HIDError.managerOpen(openResult)
        }
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            if openResult == kIOReturnNotPermitted {
                throw HIDError.managerOpen(openResult)
            }
            handles.removeAll()
            return []
        }

        var devicesByIdentity: [String: RazerDevice] = [:]
        var controlHandlesByIdentity: [String: [IOHIDDevice]] = [:]
        for handle in set {
            guard
                let rawProductID = integerProperty(handle, kIOHIDProductIDKey),
                let productID = UInt16(exactly: rawProductID)
            else {
                continue
            }

            let serial = stringProperty(handle, kIOHIDSerialNumberKey)
            let reportedName = stringProperty(handle, kIOHIDProductKey)
                ?? "Razer 0x\(String(productID, radix: 16, uppercase: true))"
            let identity = deviceIdentity(
                for: handle,
                productID: productID,
                serialNumber: serial
            )
            let definition = catalog.definition(for: productID)
            let device = RazerDevice(
                id: identity,
                productID: productID,
                productName: definition?.name ?? reportedName,
                serialNumber: serial,
                kind: definition?.kind ?? .unknown,
                transactionID: definition?.transactionID ?? 0,
                lightingProtocol: definition?.lightingProtocol,
                supportLevel: definition?.supportLevel ?? .detectionOnly,
                targets: definition?.targets ?? [],
                supportedEffects: definition?.supportedEffects ?? [],
                supportsBrightness: definition?.supportsBrightness ?? false
            )
            devicesByIdentity[identity] = device
            if maxFeatureReportSize(handle) == RazerCommand.reportLength {
                controlHandlesByIdentity[identity, default: []].append(handle)
            }
        }

        handles = controlHandlesByIdentity.compactMapValues { candidates in
            candidates.count == 1 ? candidates[0] : nil
        }
        return devicesByIdentity.values
            .sorted {
                if $0.productName == $1.productName {
                    return $0.id < $1.id
                }
                return $0.productName.localizedCaseInsensitiveCompare($1.productName) == .orderedAscending
            }
    }

    func hasControlInterface(for device: RazerDevice) -> Bool {
        handles[device.id] != nil
    }

    func send(_ command: RazerCommand, to device: RazerDevice) throws -> RazerResponse? {
        guard device.supportLevel == .community else {
            throw HIDError.unknownDevice
        }
        guard let handle = handles[device.id] else {
            throw HIDError.noControlInterface
        }

        let openResult = IOHIDDeviceOpen(handle, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            throw HIDError.open(openResult)
        }
        defer { IOHIDDeviceClose(handle, IOOptionBits(kIOHIDOptionsTypeNone)) }

        let data = command.encode()
        let writeResult = data.withUnsafeBytes { rawBuffer -> IOReturn in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return kIOReturnBadArgument
            }
            return IOHIDDeviceSetReport(
                handle,
                kIOHIDReportTypeFeature,
                0,
                baseAddress,
                data.count
            )
        }
        guard writeResult == kIOReturnSuccess else {
            throw HIDError.write(writeResult)
        }

        for attempt in 0..<3 {
            Thread.sleep(forTimeInterval: attempt == 0 ? 0.035 : 0.015)
            do {
                return try readResponse(from: handle, for: command)
            } catch RazerProtocolError.deviceRejected(status: RazerResponse.Status.busy.rawValue)
                where attempt < 2 {
                continue
            }
        }
        return nil
    }

    private func readResponse(
        from handle: IOHIDDevice,
        for command: RazerCommand
    ) throws -> RazerResponse? {
        var response = [UInt8](repeating: 0, count: RazerCommand.reportLength)
        var length = response.count
        let readResult = response.withUnsafeMutableBufferPointer { pointer in
            IOHIDDeviceGetReport(
                handle,
                kIOHIDReportTypeFeature,
                0,
                pointer.baseAddress!,
                &length
            )
        }
        if readResult == kIOReturnUnsupported || readResult == kIOReturnNotFound {
            return nil
        }
        guard readResult == kIOReturnSuccess else {
            throw HIDError.read(readResult)
        }
        return try RazerResponse.decode(Data(response.prefix(length)), for: command)
    }

    private func deviceIdentity(
        for handle: IOHIDDevice,
        productID: UInt16,
        serialNumber: String?
    ) -> String {
        if let serialNumber, !serialNumber.isEmpty, serialNumber != "Default string" {
            return "\(productID)-serial-\(serialNumber)"
        }
        if let locationID = integerProperty(handle, kIOHIDLocationIDKey) {
            return "\(productID)-location-\(locationID)"
        }
        var registryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(handle), &registryID)
        return "\(productID)-registry-\(registryID)"
    }

    private func integerProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }

    private func stringProperty(_ device: IOHIDDevice, _ key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private func maxFeatureReportSize(_ device: IOHIDDevice) -> Int {
        integerProperty(device, kIOHIDMaxFeatureReportSizeKey) ?? 0
    }
}
#endif
