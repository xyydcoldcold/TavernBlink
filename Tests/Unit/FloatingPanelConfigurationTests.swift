import AppKit
import XCTest

@MainActor
final class FloatingPanelConfigurationTests: XCTestCase {
    func testConfigurationSupportsFullscreenFloatingInteraction() {
        let panel = NSPanel(
            contentRect: NSRect(
                origin: .zero,
                size: FloatingPanelConfiguration.contentSize
            ),
            styleMask: FloatingPanelConfiguration.styleMask,
            backing: .buffered,
            defer: false
        )

        FloatingPanelConfiguration.apply(to: panel)

        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.transient))
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.isFloatingPanel)
        XCTAssertTrue(panel.becomesKeyOnlyIfNeeded)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertTrue(panel.isMovableByWindowBackground)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertFalse(panel.isReleasedWhenClosed)
        XCTAssertEqual(panel.contentView?.frame.size, FloatingPanelConfiguration.contentSize)
    }
}
