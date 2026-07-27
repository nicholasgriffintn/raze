#if os(macOS)
import AppKit
import SwiftUI

struct MenuContent: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if model.profiles.isEmpty {
            Text("No saved profiles")
        } else {
            Menu("Apply profile") {
                ForEach(model.profiles) { profile in
                    Button("\(profile.name) — \(profile.deviceDisplayName)") {
                        Task { await model.apply(profile) }
                    }
                }
            }
        }
        Text(model.status.message)
        Divider()
        Button("Open Raze") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Refresh devices") {
            Task { await model.refresh() }
        }
        Divider()
        Button("Quit Raze") {
            NSApp.terminate(nil)
        }
    }
}
#endif
