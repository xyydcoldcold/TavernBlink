import XCTest

final class FlowMatcherTests: XCTestCase {
    func testExactSigningIdentifierMatches() {
        XCTAssertTrue(
            FlowMatcher.matches(
                signingIdentifier: "com.blizzard.hearthstone",
                targetSigningIdentifier: "com.blizzard.hearthstone"
            )
        )
    }

    func testDifferentOrMissingIdentifierFailsClosed() {
        XCTAssertFalse(
            FlowMatcher.matches(
                signingIdentifier: "com.blizzard.battlenet",
                targetSigningIdentifier: "com.blizzard.hearthstone"
            )
        )
        XCTAssertFalse(
            FlowMatcher.matches(
                signingIdentifier: nil,
                targetSigningIdentifier: "com.blizzard.hearthstone"
            )
        )
        XCTAssertFalse(
            FlowMatcher.matches(
                signingIdentifier: "com.blizzard.hearthstone",
                targetSigningIdentifier: nil
            )
        )
    }
}
