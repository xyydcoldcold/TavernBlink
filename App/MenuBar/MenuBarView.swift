import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: model.status.systemImageName)
                    .foregroundStyle(model.status.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TavernBlink")
                        .font(.headline)
                    Text(model.status.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let identity = model.targetIdentity {
                VStack(alignment: .leading, spacing: 2) {
                    Text(identity.displayName)
                    Text(identity.signingIdentifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("No verified Hearthstone application selected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let diagnostics = model.providerDiagnostics {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Phase 0 flow observations")
                        .font(.caption.weight(.semibold))
                    Text("TCP observed: \(diagnostics.observedTCPFlowCount) · target matches: \(diagnostics.matchedTCPFlowCount)")
                    Text(
                        "Last source signing ID: \(diagnostics.lastObservedSigningIdentifier ?? "not observed")"
                    )
                    .lineLimit(1)
                    if diagnostics.missingSigningIdentifierCount > 0 {
                        Text("Flows missing signing ID: \(diagnostics.missingSigningIdentifierCount)")
                    }
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Divider()

            Button("Install Network Component") {
                model.installSystemExtension()
            }

            Button("Choose Hearthstone…") {
                model.chooseTargetApplication()
            }

            Button("Configure and Start Proxy") {
                model.configureAndStartProxy()
            }
            .disabled(!model.canConfigureProxy)

            Button("Disconnect Now") {
                model.disconnectNow()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canDisconnect)

            HStack {
                Button("Refresh") {
                    model.refresh()
                }
                Button("Disable") {
                    model.disableProxy()
                }
                Spacer()
                Button("Details…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }

            Divider()

            Button("Quit TavernBlink") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 340)
        .task {
            model.refresh()
        }
    }
}
