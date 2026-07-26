#if os(macOS)
import RazerCore
import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var model: AppModel
    let device: RazerDevice

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DeviceHeader(device: device)
                if device.supportsLighting {
                    LightingCard(device: device)
                    ProfileCard()
                } else {
                    UnsupportedDeviceCard(device: device)
                }
                StatusBanner(status: model.status)
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.green.opacity(0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .navigationTitle(device.productName)
    }
}

private struct DeviceHeader: View {
    let device: RazerDevice

    var body: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text(device.productName)
                    .font(.title2.weight(.semibold))
                HStack(spacing: 7) {
                    Text(String(format: "PID %04X", device.productID))
                    Text("•")
                    Text(device.supportsLighting ? "Community control" : "Detection only")
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

                if device.supportsLighting {
                    HStack(spacing: 7) {
                        CapabilityChip(
                            title: "\(device.targets.count) \(device.targets.count == 1 ? "zone" : "zones")",
                            systemImage: "scope"
                        )
                        CapabilityChip(
                            title: "\(device.supportedEffects.count) effects",
                            systemImage: "sparkles"
                        )
                        if device.supportsBrightness {
                            CapabilityChip(title: "Brightness", systemImage: "sun.max")
                        }
                    }
                    .padding(.top, 7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if device.targets.count <= 1 {
                DeviceArtwork(kind: device.kind)
                    .frame(width: 210)
                    .accessibilityHidden(true)
            }
        }
        .padding(18)
        .controlCard()
    }
}

private struct CapabilityChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Color.primary.opacity(0.05),
                in: Capsule(style: .continuous)
            )
    }
}

private struct LightingCard: View {
    @EnvironmentObject private var model: AppModel
    let device: RazerDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Lighting", systemImage: "lightbulb.led")
                .font(.headline)

            if device.targets.count > 1 {
                DeviceZoneSelector(device: device, selection: $model.target)
            } else if let target = device.targets.first {
                Label(target.displayName, systemImage: "scope")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            EffectEditor(
                effect: $model.effect,
                supportedKinds: device.supportedEffects
            )

            if device.supportsBrightness {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Brightness")
                        Spacer()
                        Text("\(Int(model.brightness))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $model.brightness, in: 0...100, step: 1) {
                        Text("Brightness")
                    }
                    .labelsHidden()
                    .accessibilityLabel("Brightness")
                    .accessibilityValue("\(Int(model.brightness)) percent")
                }
            }

            HStack {
                Spacer()
                Button {
                    Task { await model.apply() }
                } label: {
                    if model.isWorking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Apply lighting", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(18)
        .controlCard()
    }
}

private struct ProfileCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var profileName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Save this setup", systemImage: "bookmark")
                .font(.headline)
            HStack {
                TextField("Profile name", text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { save() }
                Button("Save") { save() }
                    .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .controlCard()
    }

    private func save() {
        Task {
            if await model.saveProfile(named: profileName) {
                profileName = ""
            }
        }
    }
}

private struct UnsupportedDeviceCard: View {
    let device: RazerDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Lighting controls unavailable", systemImage: "shield.lefthalf.filled")
                .font(.headline)
            Text(
                "Raze recognises this product, but keeps it read-only until its command family and capabilities are mapped."
            )
            .foregroundStyle(.secondary)
            Text("Include PID \(String(format: "%04X", device.productID)) when reporting hardware support.")
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .padding(18)
        .controlCard()
    }
}

private struct StatusBanner: View {
    let status: AppStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.isFailure ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(status.isFailure ? Color.orange : Color.green)
            Text(status.message)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.message)")
    }
}
#endif
