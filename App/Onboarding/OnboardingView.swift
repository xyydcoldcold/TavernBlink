import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TavernBlink Setup")
                .font(.title2.bold())

            Text("This development build separates installation, transparent-proxy configuration, and target identity verification so each Phase 0 gate can be tested independently.")

            GroupBox("Required order") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Install and approve the Network System Extension.", systemImage: "1.circle")
                    Label(
                        "Choose Hearthstone and verify its Blizzard signing ID and Team ID.",
                        systemImage: "2.circle"
                    )
                    Label("Save and start the transparent proxy configuration.", systemImage: "3.circle")
                    Label("Restart Hearthstone so new flows can reach the provider.", systemImage: "4.circle")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            GroupBox("Important") {
                Text("This is an unofficial experiment. Changing a game session by forcing a disconnect may violate Blizzard rules and may put the account at risk. The current provider is fail-open and does not yet claim or relay flows.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }

            Spacer()

            HStack {
                Text(model.status.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") {
                    model.refresh()
                }
            }
        }
        .padding(24)
    }
}
