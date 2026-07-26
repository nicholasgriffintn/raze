#if os(macOS)
import RazerCore
import SwiftUI

struct DeviceSidebar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selectedDeviceID) {
            Section("Devices") {
                if model.devices.isEmpty {
                    Label("No devices connected", systemImage: "cable.connector.slash")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.devices) { device in
                    HStack(spacing: 10) {
                        Image(systemName: device.kind.systemImage)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.productName)
                                .lineLimit(1)
                            Text(device.supportsLighting ? "Lighting control" : "Detected only")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Circle()
                            .fill(device.supportsLighting ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                            .accessibilityLabel(
                                device.supportsLighting ? "Lighting supported" : "Detection only"
                            )
                    }
                    .tag(device.id)
                }
            }

            Section("Profiles") {
                if model.profiles.isEmpty {
                    Text("No saved profiles")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.profiles) { profile in
                    Button {
                        Task { await model.apply(profile) }
                    } label: {
                        Label(profile.name, systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            guard let index = model.profiles.firstIndex(where: { $0.id == profile.id }) else {
                                return
                            }
                            Task { await model.deleteProfiles(at: IndexSet(integer: index)) }
                        }
                    }
                }
                .onDelete { offsets in
                    Task { await model.deleteProfiles(at: offsets) }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Raze")
        .onChange(of: model.selectedDeviceID) { _ in
            model.selectionChanged()
        }
        .toolbar {
            Button {
                Task { await model.refresh() }
            } label: {
                Label("Refresh devices", systemImage: "arrow.clockwise")
            }
            .disabled(model.isWorking)
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}
#endif
