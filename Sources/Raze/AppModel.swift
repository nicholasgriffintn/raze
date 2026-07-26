#if os(macOS)
import Foundation
import RazerCore

enum AppStatus: Equatable {
    case loading
    case scanning
    case noDevices
    case ready
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
        case .failure, .unsupported:
            true
        default:
            false
        }
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
    @Published private(set) var profiles: [DeviceProfile] = []
    @Published private(set) var status: AppStatus = .loading

    private let transport: HIDTransport
    private let profileStore: ProfileStore
    private var discoveryTask: Task<Void, Never>?
    private var isRefreshing = false

    init() {
        transport = HIDTransport()
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        profileStore = ProfileStore(
            fileURL: appSupport.appendingPathComponent("Raze/profiles-v1.json")
        )

        Task {
            let profileLoadError = await loadProfiles()
            await refresh()
            if let profileLoadError {
                status = .failure(profileLoadError)
            }
            startAutomaticDiscovery()
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
        reconcileSelection(resetTargetIfNeeded: true)
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
            devices = try await transport.scan()
            reconcileSelection(resetTargetIfNeeded: false)
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    func apply() async {
        guard
            let device = selectedDevice,
            let lightingProtocol = device.lightingProtocol,
            device.targets.contains(target),
            device.supportedEffects.contains(effect.kind)
        else {
            status = .failure("The selected lighting configuration is not supported.")
            return
        }

        status = .applying(device.productName)
        do {
            if device.supportsBrightness {
                let brightnessCommand = try RazerCommands.brightness(
                    RazerCommands.brightnessByte(fromPercentage: brightness),
                    target: target,
                    transactionID: device.transactionID,
                    protocol: lightingProtocol
                )
                _ = try await transport.send(brightnessCommand, to: device)
            }
            let effectCommand = try RazerCommands.lighting(
                effect,
                target: target,
                transactionID: device.transactionID,
                protocol: lightingProtocol
            )
            _ = try await transport.send(effectCommand, to: device)
            status = .success("Applied to \(device.productName).")
        } catch {
            status = .failure(error.localizedDescription)
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
                brightness: UInt8(clamping: Int(brightness.rounded()))
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

        selectedDeviceID = destination.id
        target = profile.target
        effect = profile.effect
        brightness = Double(profile.brightness)
        await apply()
    }

    func deleteProfiles(at offsets: IndexSet) async {
        let originalProfiles = profiles
        for index in offsets.sorted(by: >) where profiles.indices.contains(index) {
            profiles.remove(at: index)
        }
        do {
            try await profileStore.save(profiles)
            status = .success("Profile removed.")
        } catch {
            profiles = originalProfiles
            status = .failure("Could not update profiles: \(error.localizedDescription)")
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

    private func reconcileSelection(resetTargetIfNeeded: Bool) {
        if !devices.contains(where: { $0.id == selectedDeviceID }) {
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
        status = device.supportsLighting
            ? .ready
            : .unsupported(device.productName)
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
