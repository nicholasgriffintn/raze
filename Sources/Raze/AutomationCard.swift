#if os(macOS)
import RazerCore
import SwiftUI

struct AutomationCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Profile automation", systemImage: "bolt.badge.clock")
                .font(.headline)

            Text("Choose which saved profile to apply when macOS changes state.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ForEach(AutomationEvent.allCases, id: \.self) { event in
                HStack {
                    Label(event.displayName, systemImage: event.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker(event.displayName, selection: selection(for: event)) {
                        Text("Do nothing").tag(UUID?.none)
                        ForEach(model.profiles) { profile in
                            Text("\(profile.name) — \(profile.deviceDisplayName)")
                                .tag(Optional(profile.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 210)
                }
            }
        }
        .padding(18)
        .controlCard()
    }

    private func selection(for event: AutomationEvent) -> Binding<UUID?> {
        Binding(
            get: { model.automationAssignments[event] },
            set: { profileID in
                Task { await model.setAutomation(event, profileID: profileID) }
            }
        )
    }
}
#endif
