import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var languageSettings: AppLanguageSettings

    private var strings: AppStrings {
        AppStrings(languageSettings.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: model.status.systemImageName)
                    .foregroundStyle(model.status.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TavernBlink")
                        .font(.headline)
                    Text(model.status.message(in: languageSettings.language))
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
                    Text("\(strings.teamID): \(identity.teamIdentifier)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if identity.verificationMode == .codeSignatureOnly {
                        Label(
                            strings.blizzardVerificationWarning,
                            systemImage: "exclamationmark.shield"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            } else {
                Text(strings.noVerifiedHearthstone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let diagnostics = model.providerDiagnostics {
                VStack(alignment: .leading, spacing: 3) {
                    Text(strings.phaseZeroObservations)
                        .font(.caption.weight(.semibold))
                    Text(
                        strings.flowSummary(
                            observed: diagnostics.observedTCPFlowCount,
                            matched: diagnostics.matchedTCPFlowCount
                        )
                    )
                    Text(strings.lastSigningID(diagnostics.lastObservedSigningIdentifier))
                    .lineLimit(1)
                    if diagnostics.missingSigningIdentifierCount > 0 {
                        Text(
                            strings.flowsMissingSigningID(
                                diagnostics.missingSigningIdentifierCount
                            )
                        )
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

            Button(strings.installNetworkComponent) {
                model.installSystemExtension()
            }

            Button(strings.chooseHearthstone) {
                model.chooseTargetApplication()
            }

            Button(strings.configureAndStartProxy) {
                model.configureAndStartProxy()
            }
            .disabled(!model.canConfigureProxy)

            Button(strings.disconnectNow) {
                model.disconnectNow()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canDisconnect)

            HStack {
                Button(strings.refresh) {
                    model.refresh()
                }
                Spacer()
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Text(strings.settings)
                    }
                } else {
                    Button(strings.settings) {
                        NSApp.sendAction(
                            Selector(("showSettingsWindow:")),
                            to: nil,
                            from: nil
                        )
                    }
                }
            }

            Divider()

            Button(strings.quitTavernBlink) {
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
