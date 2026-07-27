#if os(macOS)
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some View {
        Form {
            Toggle(
                "Launch Raze at login",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )

            LabeledContent("Status", value: launchAtLogin.status.displayName)

            if launchAtLogin.status == .requiresApproval {
                Text("Allow Raze under Login Items in System Settings to finish enabling it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = launchAtLogin.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Open Login Items Settings") {
                launchAtLogin.openLoginItemsSettings()
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}
#endif
