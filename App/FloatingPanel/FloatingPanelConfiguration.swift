import AppKit

enum FloatingPanelConfiguration {
    static let autosaveName = "TavernBlinkFloatingDisconnectPanel"
    static let contentSize = NSSize(width: 86, height: 86)
    static let styleMask: NSWindow.StyleMask = [
        .borderless,
        .nonactivatingPanel
    ]

    @MainActor
    static func apply(to panel: NSPanel) {
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient
        ]
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.setContentSize(contentSize)
    }

    @MainActor
    static func normalizeContentSize(of panel: NSPanel) {
        panel.setContentSize(contentSize)
    }
}
