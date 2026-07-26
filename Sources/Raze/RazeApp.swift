#if os(macOS)
import SwiftUI

@main
struct RazeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Raze", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 540)
        }
        .defaultSize(width: 900, height: 640)

        MenuBarExtra("Raze", systemImage: "lightbulb.led") {
            MenuContent()
                .environmentObject(model)
        }
    }
}
#endif
