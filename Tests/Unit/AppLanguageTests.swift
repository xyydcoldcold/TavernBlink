import XCTest

@MainActor
final class AppLanguageTests: XCTestCase {
    func testChineseStringsCoverStatusAndPrimaryAction() {
        let strings = AppStrings(.simplifiedChinese)

        XCTAssertEqual(strings.disconnectNow, "立即断线")
        XCTAssertEqual(
            strings.statusMessage(.readyWithFlow(2)),
            "已就绪：检测到 2 个目标连接"
        )
    }

    func testSelectedLanguagePersists() {
        let suiteName = "AppLanguageTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create isolated user defaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppLanguageSettings(defaults: defaults)
        XCTAssertEqual(settings.language, .english)

        settings.language = .simplifiedChinese

        let restored = AppLanguageSettings(defaults: defaults)
        XCTAssertEqual(restored.language, .simplifiedChinese)
    }
}
