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
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(0.12))
                Image(systemName: device.kind.systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.green)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text(device.productName)
                    .font(.title2.weight(.semibold))
                HStack(spacing: 8) {
                    Text(String(format: "PID %04X", device.productID))
                    Text("•")
                    Text(device.supportsLighting ? "Community control" : "Detection only")
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .controlCard()
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
                Picker("Zone", selection: $model.target) {
                    ForEach(device.targets, id: \.self) { target in
                        Text(target.displayName).tag(target)
                    }
                }
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
                    } minimumValueLabel: {
                        Text("0%")
                    } maximumValueLabel: {
                        Text("100%")
                    }
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
