#if os(macOS)
import Foundation
import RazerCore

enum AppStatus: Equatable {
    case loading
    case scanning
    case noDevices
    case ready
    case inputMonitoringRequired
    case unsupported(String)
    case applying(String)
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .loading:
            "Loading profiles…"
        case .scanning:
            "Looking for Razer devices…"
        case .noDevices:
            "No Razer devices found. Connect a device by USB, then refresh."
        case .ready:
            "Ready."
        case .inputMonitoringRequired:
            "Input Monitoring is off. Enable Raze in System Settings, then quit and reopen it."
        case .unsupported(let name):
            "\(name) is recognised, but its lighting protocol is not yet mapped."
        case .applying(let name):
            "Applying lighting to \(name)…"
        case .success(let message), .failure(let message):
            message
        }
    }

    var isFailure: Bool {
        switch self {
        case .failure, .inputMonitoringRequired, .unsupported:
            true
        default:
            false
        }
    }

    var requiresInputMonitoring: Bool {
        self == .inputMonitoringRequired
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var devices: [RazerDevice] = []
    @Published var selectedDeviceID: String?
    @Published var target: LightingTarget = .all
    @Published var effect: LightingEffect = .staticColor(
        .init(red: 0, green: 255, blue: 80)
    )
    @Published var brightness: Double = 100
    @Published var dpi: Double = 800
    @Published var pollingRate: PollingRate = .hz1000
    @Published private(set) var powerStatus: DevicePowerStatus?
    @Published private(set) var profiles: [DeviceProfile] = []
    @Published private(set) var activeProfileID: UUID?
    @Published private(set) var automationAssignments: [AutomationEvent: UUID] = [:]
    @Published private(set) var status: AppStatus = .loading

    private let transport: HIDTransport
    private let profileStore: ProfileStore
    private let automationStore: AutomationStore
    private var discoveryTask: Task<Void, Never>?
    private var isRefreshing = false
    private var ignoredSelectionChangeID: String?
    private lazy var lightingAnimation = LightingAnimationController(
        transport: transport
    ) { [weak self] message in
        self?.status = .failure(message)
    }
    private lazy var eventMonitor = SystemEventMonitor { [weak self] event in
        Task { await self?.handleAutomationEvent(event) }
    }

    init() {
        transport = HIDTransport()
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        profileStore = ProfileStore(
            fileURL: appSupport.appendingPathComponent("Raze/profiles-v1.json")
        )
        automationStore = AutomationStore(
            fileURL: appSupport.appendingPathComponent("Raze/automation-v1.json")
        )

        Task {
            let hasInputMonitoringAccess = await transport.requestInputMonitoringAccess()
            let profileLoadError = await loadProfiles()
            let automationLoadError = await loadAutomation()
            await refresh()
            await refreshDeviceControls()
            if !hasInputMonitoringAccess {
                status = .inputMonitoringRequired
            } else if let loadError = profileLoadError ?? automationLoadError {
                status = .failure(loadError)
            }
            startAutomaticDiscovery()
            eventMonitor.start()
            await handleAutomationEvent(.appLaunch)
        }
    }

    deinit {
        discoveryTask?.cancel()
    }

    var selectedDevice: RazerDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    var isWorking: Bool {
        if case .applying = status {
            return true
        }
        return isRefreshing
    }

    func selectionChanged() {
        if ignoredSelectionChangeID == selectedDeviceID {
            ignoredSelectionChangeID = nil
            return
        }
        activeProfileID = nil
        lightingAnimation.stop()
        reconcileSelection(resetTargetIfNeeded: true)
        Task { await refreshDeviceControls() }
    }

    func refresh(silent: Bool = false) async {
        guard !isRefreshing, !isWorking else {
            return
        }
        isRefreshing = true
        if !silent {
            status = .scanning
        }
        defer { isRefreshing = false }

        do {
            let previousSelectionID = selectedDeviceID
            devices = try await transport.scan()
            let previousSelectionStillExists = devices.contains {
                $0.id == previousSelectionID
            }
            reconcileSelection(
                resetTargetIfNeeded: false,
                updateStatus: !silent || !previousSelectionStillExists
            )
            if silent,
               let selectedDevice,
               selectedDevice.controlCapabilities.supportsBattery {
                await refreshPowerStatus(for: selectedDevice)
            }
        } catch {
            setOperationFailure(error)
        }
    }

    func apply() async {
        activeProfileID = nil
        await applyLighting()
    }

    private func applyLighting() async {
        guard
            let device = selectedDevice,
            device.targets.contains(target),
            device.supportedEffects.contains(effect.kind)
        else {
            status = .failure("The selected lighting configuration is not supported.")
            return
        }

        status = .applying(device.productName)
        do {
            try await sendLighting(
                effect: effect,
                target: target,
                brightness: brightness,
                to: device
            )
            status = .success("Applied to \(device.productName).")
        } catch {
            setOperationFailure(error)
        }
    }

    func applyDeviceControls() async {
        activeProfileID = nil
        await applyPerformanceControls()
    }

    private func applyPerformanceControls() async {
        guard let device = selectedDevice else {
            status = .failure("Select a connected device.")
            return
        }
        let capabilities = device.controlCapabilities
        guard capabilities.dpiRange != nil || !capabilities.pollingRates.isEmpty else {
            status = .failure("Performance controls are unavailable for this device.")
            return
        }

        status = .applying(device.productName)
        do {
            try await sendPerformance(
                dpi: Int(dpi.rounded()),
                pollingRate: pollingRate,
                to: device
            )
            status = .success("Applied performance settings to \(device.productName).")
        } catch {
            setOperationFailure(error)
        }
    }

    func refreshDeviceControls() async {
        guard let device = selectedDevice else {
            powerStatus = nil
            return
        }
        let capabilities = device.controlCapabilities

        if capabilities.dpiRange != nil {
            do {
                if let response = try await transport.send(
                    RazerCommands.getDPI(transactionID: device.transactionID),
                    to: device
                ),
                   let currentDPI = DeviceResponseDecoder.dpi(from: response) {
                    dpi = Double(currentDPI)
                }
            } catch {
                setPermissionFailureIfNeeded(error)
            }
        }
        if !capabilities.pollingRates.isEmpty {
            do {
                if let response = try await transport.send(
                    RazerCommands.getPollingRate(transactionID: device.transactionID),
                    to: device
                ),
                   let currentRate = DeviceResponseDecoder.pollingRate(from: response) {
                    pollingRate = currentRate
                }
            } catch {
                setPermissionFailureIfNeeded(error)
            }
        }
        if capabilities.supportsBattery {
            await refreshPowerStatus(for: device)
        } else {
            powerStatus = nil
        }
    }

    func saveProfile(named rawName: String) async -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let device = selectedDevice,
            device.supportsLighting,
            device.targets.contains(target),
            device.supportedEffects.contains(effect.kind),
            !name.isEmpty
        else {
            status = .failure("Choose a supported device and enter a profile name.")
            return false
        }

        let originalProfiles = profiles
        profiles.append(
            .init(
                name: name,
                productID: device.productID,
                target: target,
                effect: effect,
                brightness: UInt8(clamping: Int(brightness.rounded())),
                dpi: device.controlCapabilities.dpiRange == nil ? nil : Int(dpi.rounded()),
                pollingRate: device.controlCapabilities.pollingRates.isEmpty
                    ? nil
                    : pollingRate
            )
        )
        do {
            try await profileStore.save(profiles)
            status = .success("Saved profile “\(name)”.")
            return true
        } catch {
            profiles = originalProfiles
            status = .failure("Could not save profiles: \(error.localizedDescription)")
            return false
        }
    }

    func apply(_ profile: DeviceProfile) async {
        let matches = devices.filter { $0.productID == profile.productID }
        let destination: RazerDevice?
        if let selectedDevice, matches.contains(selectedDevice) {
            destination = selectedDevice
        } else if matches.count == 1 {
            destination = matches[0]
        } else {
            destination = nil
        }

        guard let destination else {
            status = .failure(
                matches.isEmpty
                    ? "The device for this profile is not connected."
                    : "Select which matching device should receive this profile."
            )
            return
        }
        guard
            destination.targets.contains(profile.target),
            destination.supportedEffects.contains(profile.effect.kind)
        else {
            status = .failure("This profile is incompatible with the connected device.")
            return
        }

        if selectedDeviceID != destination.id {
            ignoredSelectionChangeID = destination.id
            selectedDeviceID = destination.id
        }
        target = profile.target
        effect = profile.effect
        brightness = Double(profile.brightness)

        if let profileDPI = profile.dpi {
            dpi = Double(profileDPI)
        }
        if let profilePollingRate = profile.pollingRate {
            pollingRate = profilePollingRate
        }

        status = .applying(destination.productName)
        do {
            try await sendLighting(
                effect: profile.effect,
                target: profile.target,
                brightness: Double(profile.brightness),
                to: destination
            )
            if profile.dpi != nil || profile.pollingRate != nil {
                try await sendPerformance(
                    dpi: profile.dpi,
                    pollingRate: profile.pollingRate,
                    to: destination
                )
            }
            activeProfileID = profile.id
            status = .success("Applied profile “\(profile.name)”.")
        } catch {
            activeProfileID = nil
            setOperationFailure(
                error,
                message: "Could not apply profile “\(profile.name)”: \(error.localizedDescription)"
            )
        }
    }

    private func sendLighting(
        effect: LightingEffect,
        target: LightingTarget,
        brightness: Double,
        to device: RazerDevice
    ) async throws {
        guard let lightingProtocol = device.lightingProtocol else {
            throw HIDError.unknownDevice
        }

        lightingAnimation.stop()
        if device.supportsBrightness {
            let brightnessCommand = try RazerCommands.brightness(
                RazerCommands.brightnessByte(fromPercentage: brightness),
                target: target,
                transactionID: device.transactionID,
                protocol: lightingProtocol
            )
            _ = try await transport.send(brightnessCommand, to: device)
        }
        switch effect {
        case .ripple, .wheel:
            try await lightingAnimation.start(
                effect: effect,
                target: target,
                on: device
            )
        default:
            let effectCommand = try RazerCommands.lighting(
                effect,
                target: target,
                transactionID: device.transactionID,
                protocol: lightingProtocol
            )
            _ = try await transport.send(effectCommand, to: device)
        }
    }

    private func sendPerformance(
        dpi requestedDPI: Int?,
        pollingRate requestedPollingRate: PollingRate?,
        to device: RazerDevice
    ) async throws {
        let capabilities = device.controlCapabilities
        if let requestedDPI, let dpiRange = capabilities.dpiRange {
            let selectedDPI = min(max(requestedDPI, dpiRange.lowerBound), dpiRange.upperBound)
            _ = try await transport.send(
                RazerCommands.setDPI(selectedDPI, transactionID: device.transactionID),
                to: device
            )
            dpi = Double(selectedDPI)
        }
        if let requestedPollingRate,
           capabilities.pollingRates.contains(requestedPollingRate) {
            _ = try await transport.send(
                RazerCommands.setPollingRate(
                    requestedPollingRate,
                    transactionID: device.transactionID
                ),
                to: device
            )
            pollingRate = requestedPollingRate
        }
    }

    func deleteProfile(id: UUID) async {
        let originalProfiles = profiles
        let originalAssignments = automationAssignments
        guard profiles.contains(where: { $0.id == id }) else {
            return
        }
        profiles.removeAll { $0.id == id }
        do {
            try await profileStore.save(profiles)
            let profileIDs = Set(profiles.map(\.id))
            automationAssignments = automationAssignments.filter {
                profileIDs.contains($0.value)
            }
            try await automationStore.save(automationAssignments)
            if activeProfileID == id {
                activeProfileID = nil
            }
            status = .success("Profile removed.")
        } catch {
            profiles = originalProfiles
            automationAssignments = originalAssignments
            try? await profileStore.save(originalProfiles)
            try? await automationStore.save(originalAssignments)
            status = .failure("Could not update profiles: \(error.localizedDescription)")
        }
    }

    func setAutomation(_ event: AutomationEvent, profileID: UUID?) async {
        let originalAssignments = automationAssignments
        if let profileID {
            guard profiles.contains(where: { $0.id == profileID }) else {
                status = .failure("That profile no longer exists.")
                return
            }
            automationAssignments[event] = profileID
        } else {
            automationAssignments.removeValue(forKey: event)
        }

        do {
            try await automationStore.save(automationAssignments)
            status = .success("Updated automatic profiles.")
        } catch {
            automationAssignments = originalAssignments
            status = .failure(
                "Could not save automatic profiles: \(error.localizedDescription)"
            )
        }
    }

    private func loadProfiles() async -> String? {
        do {
            profiles = try await profileStore.load()
            return nil
        } catch {
            return "Could not load profiles: \(error.localizedDescription)"
        }
    }

    private func loadAutomation() async -> String? {
        do {
            automationAssignments = try await automationStore.load()
            return nil
        } catch {
            return "Could not load automatic profiles: \(error.localizedDescription)"
        }
    }

    private func handleAutomationEvent(_ event: AutomationEvent) async {
        guard
            !isWorking,
            let profileID = automationAssignments[event],
            let profile = profiles.first(where: { $0.id == profileID })
        else {
            return
        }
        await apply(profile)
    }

    private func reconcileSelection(
        resetTargetIfNeeded: Bool,
        updateStatus: Bool = true
    ) {
        if !devices.contains(where: { $0.id == selectedDeviceID }) {
            lightingAnimation.stop()
            selectedDeviceID = devices.first?.id
        }
        guard let device = selectedDevice else {
            status = .noDevices
            return
        }
        if resetTargetIfNeeded || !device.targets.contains(target) {
            target = device.targets.first ?? .all
        }
        if !device.supportedEffects.contains(effect.kind),
           let supportedKind = LightingEffectKind.allCases.first(
               where: device.supportedEffects.contains
           ) {
            effect = effect.changingKind(to: supportedKind)
        }
        if updateStatus {
            status = device.supportsLighting
                ? .ready
                : .unsupported(device.productName)
        }
    }

    private func refreshPowerStatus(for device: RazerDevice) async {
        let batteryResponse: RazerResponse?
        do {
            batteryResponse = try await transport.send(
                RazerCommands.getBatteryLevel(transactionID: device.transactionID),
                to: device
            )
        } catch {
            powerStatus = nil
            setPermissionFailureIfNeeded(error)
            return
        }
        guard let percentage = batteryResponse.flatMap(
            DeviceResponseDecoder.batteryPercentage(from:)
        ) else {
            powerStatus = nil
            return
        }

        let chargingResponse: RazerResponse?
        do {
            chargingResponse = try await transport.send(
                RazerCommands.getChargingStatus(transactionID: device.transactionID),
                to: device
            )
        } catch {
            setPermissionFailureIfNeeded(error)
            chargingResponse = nil
        }
        let isCharging = chargingResponse.flatMap(
            DeviceResponseDecoder.isCharging(from:)
        ) ?? false
        powerStatus = .init(percentage: percentage, isCharging: isCharging)
    }

    private func setOperationFailure(_ error: Error, message: String? = nil) {
        if let hidError = error as? HIDError, hidError.requiresInputMonitoring {
            status = .inputMonitoringRequired
        } else {
            status = .failure(message ?? error.localizedDescription)
        }
    }

    private func setPermissionFailureIfNeeded(_ error: Error) {
        guard let hidError = error as? HIDError, hidError.requiresInputMonitoring else {
            return
        }
        status = .inputMonitoringRequired
    }

    private func startAutomaticDiscovery() {
        discoveryTask?.cancel()
        discoveryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else {
                    return
                }
                await self?.refresh(silent: true)
            }
        }
    }
}
#endif
