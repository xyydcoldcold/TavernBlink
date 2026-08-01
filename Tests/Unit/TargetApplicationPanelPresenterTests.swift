import UniformTypeIdentifiers
import XCTest

@MainActor
final class TargetApplicationPanelPresenterTests: XCTestCase {
    func testPanelSupportsNavigationAndStartsInApplications() {
        let panel = TargetApplicationPanelPresenter.makePanel()

        XCTAssertEqual(
            panel.directoryURL?.standardizedFileURL,
            TargetApplicationPanelPresenter.defaultDirectoryURL
        )
        XCTAssertEqual(panel.allowedContentTypes, [.application])
        XCTAssertTrue(panel.canChooseFiles)
        XCTAssertFalse(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
        XCTAssertTrue(panel.resolvesAliases)
    }
}
