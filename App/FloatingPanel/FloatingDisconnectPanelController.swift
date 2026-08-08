import AppKit
import SwiftUI

@MainActor
final class FloatingDisconnectPanelController {
    private let panel: NSPanel

    init(
        model: AppModel,
        languageSettings: AppLanguageSettings
    ) {
        panel = NSPanel(
            contentRect: NSRect(
                origin: .zero,
                size: FloatingPanelConfiguration.contentSize
            ),
            styleMask: FloatingPanelConfiguration.styleMask,
            backing: .buffered,
            defer: false
        )
        FloatingPanelConfiguration.apply(to: panel)
        panel.contentViewController = NSHostingController(
            rootView: FloatingDisconnectView(
                model: model,
                languageSettings: languageSettings
            )
        )

        if !panel.setFrameUsingName(FloatingPanelConfiguration.autosaveName) {
            positionNearTopRight()
        }
        // Frame autosaving also restores an older window size. Keep the saved
        // position, but always use the current compact control dimensions.
        FloatingPanelConfiguration.normalizeContentSize(of: panel)
        panel.setFrameAutosaveName(FloatingPanelConfiguration.autosaveName)
    }

    func show() {
        panel.orderFrontRegardless()
    }

    private func positionNearTopRight() {
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            panel.center()
            return
        }
        let origin = NSPoint(
            x: visibleFrame.maxX - panel.frame.width - 24,
            y: visibleFrame.maxY - panel.frame.height - 24
        )
        panel.setFrameOrigin(origin)
    }
}

private struct FloatingDisconnectView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var languageSettings: AppLanguageSettings
    @State private var isHovering = false

    private var strings: AppStrings {
        AppStrings(languageSettings.language)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(model.canDisconnect ? 0.32 : 0.18))

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    .white.opacity(model.canDisconnect ? 0.34 : 0.16),
                    lineWidth: 1
                )

            Button {
                model.disconnectNow()
            } label: {
                ZStack {
                    Circle()
                        .fill(actionFill)
                        .frame(width: 58, height: 58)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    .white.opacity(
                                        model.canDisconnect ? 0.55 : 0.18
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                        .shadow(
                            color: model.canDisconnect
                                ? .red.opacity(isHovering ? 0.72 : 0.5)
                                : .clear,
                            radius: isHovering ? 16 : 11
                        )

                    Image(systemName: "bolt.slash.fill")
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(
                            model.canDisconnect
                                ? Color.white
                                : Color.white.opacity(0.42)
                        )
                        .frame(width: 36, height: 36, alignment: .center)

                    Circle()
                        .fill(model.canDisconnect ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .stroke(.black.opacity(0.45), lineWidth: 1.5)
                        }
                        .shadow(
                            color: model.canDisconnect
                                ? .green.opacity(0.8)
                                : .clear,
                            radius: 5
                        )
                        .offset(x: 22, y: -22)
                }
                .frame(width: 62, height: 62)
                .scaleEffect(isHovering && model.canDisconnect ? 1.035 : 1)
                .contentShape(Circle())
            }
            .buttonStyle(FloatingDisconnectButtonStyle())
            .disabled(!model.canDisconnect)
            .accessibilityLabel(strings.disconnectNow)
            .help(
                model.canDisconnect
                    ? strings.closeActiveFlowHelp
                    : strings.waitingForActiveFlowHelp
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
        }
        .frame(width: 82, height: 82)
        .padding(2)
    }

    private var actionFill: LinearGradient {
        let colors: [Color]
        if model.canDisconnect {
            colors = [
                Color(red: 1, green: 0.31, blue: 0.23),
                Color(red: 0.78, green: 0.05, blue: 0.12)
            ]
        } else {
            colors = [
                Color.white.opacity(0.14),
                Color.white.opacity(0.07)
            ]
        }
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct FloatingDisconnectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(
                .easeOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}
