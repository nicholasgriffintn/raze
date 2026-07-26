#if os(macOS)
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            DeviceSidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            if let device = model.selectedDevice {
                DeviceDetailView(device: device)
            } else {
                EmptyStateView(
                    title: "No Razer device",
                    message: "Connect a device by USB. Raze checks automatically, or you can refresh now.",
                    systemImage: "cable.connector"
                ) {
                    Task { await model.refresh() }
                }
            }
        }
        .tint(Color(red: 0.12, green: 0.78, blue: 0.34))
    }
}
#endif
