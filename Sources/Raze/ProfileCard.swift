#if os(macOS)
import RazerCore
import SwiftUI

struct ProfileCard: View {
    @EnvironmentObject private var model: AppModel
    let device: RazerDevice
    @State private var profileName = ""

    private var deviceProfiles: [DeviceProfile] {
        model.profiles.filter { $0.productID == device.productID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Profiles", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Text("Save the lighting and performance settings shown above.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                TextField("Profile name", text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { save() }
                Button("Save current settings") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedName.isEmpty || model.isWorking)
            }

            Divider()

            if deviceProfiles.isEmpty {
                Text("No profiles saved for this device.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(deviceProfiles) { profile in
                        ProfileRow(
                            profile: profile,
                            isActive: model.activeProfileID == profile.id,
                            isWorking: model.isWorking,
                            onApply: {
                                Task { await model.apply(profile) }
                            },
                            onDelete: {
                                Task { await model.deleteProfile(id: profile.id) }
                            }
                        )
                    }
                }
            }
        }
        .padding(18)
        .controlCard()
    }

    private var trimmedName: String {
        profileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        Task {
            if await model.saveProfile(named: trimmedName) {
                profileName = ""
            }
        }
    }
}

private struct ProfileRow: View {
    let profile: DeviceProfile
    let isActive: Bool
    let isWorking: Bool
    let onApply: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "bookmark")
                .foregroundStyle(isActive ? Color.green : Color.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(profile.name)
                        .font(.callout.weight(.semibold))
                    if isActive {
                        Text("Active")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }
                }
                Text(profile.settingsSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button(isActive ? "Reapply" : "Apply", action: onApply)
                .buttonStyle(.bordered)
                .disabled(isWorking)

            Menu {
                Button("Delete profile", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("More actions for \(profile.name)")
        }
        .padding(12)
        .background(
            isActive ? Color.green.opacity(0.07) : Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
    }
}
#endif
