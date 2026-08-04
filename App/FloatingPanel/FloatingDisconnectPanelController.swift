import AppKit
import SwiftUI

@MainActor
final class FloatingDisconnectPanelController {
    private let panel: NSPanel

    init(model: AppModel) {
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
            rootView: FloatingDisconnectView(model: model)
        )

        if !panel.setFrameUsingName(FloatingPanelConfiguration.autosaveName) {
            positionNearTopRight()
        }
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

    var body: some View {
        Button {
            model.disconnectNow()
        } label: {
            Label("Disconnect Now", systemImage: "bolt.slash.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.canDisconnect)
        .help(
            model.canDisconnect
                ? "Close the active Hearthstone target flow."
                : "Waiting for an active Hearthstone target flow."
        )
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.12))
        }
        .padding(2)
    }
}
