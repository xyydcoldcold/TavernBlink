import Security
import XCTest

final class TargetAppIdentityResolverTests: XCTestCase {
    func testExpectedBlizzardIdentityIsAccepted() {
        XCTAssertTrue(
            TargetAppIdentityResolver.isExpectedHearthstoneIdentity(
                signingIdentifier: "unity.Blizzard Entertainment.Hearthstone",
                teamIdentifier: "G847MC6JZ5"
            )
        )
    }

    func testDifferentSigningIdentifierOrTeamIsRejected() {
        XCTAssertFalse(
            TargetAppIdentityResolver.isExpectedHearthstoneIdentity(
                signingIdentifier: "com.blizzard.battlenet",
                teamIdentifier: "G847MC6JZ5"
            )
        )
        XCTAssertFalse(
            TargetAppIdentityResolver.isExpectedHearthstoneIdentity(
                signingIdentifier: "unity.Blizzard Entertainment.Hearthstone",
                teamIdentifier: "OTHERTEAM1"
            )
        )
    }

    func testOnlyResourceSealErrorsAllowFallback() {
        XCTAssertTrue(TargetAppIdentityResolver.isResourceSealError(errSecCSBadResource))
        XCTAssertTrue(TargetAppIdentityResolver.isResourceSealError(errSecCSResourcesInvalid))
        XCTAssertTrue(TargetAppIdentityResolver.isResourceSealError(errSecCSResourcesNotFound))
        XCTAssertTrue(TargetAppIdentityResolver.isResourceSealError(errSecCSResourcesNotSealed))

        XCTAssertFalse(TargetAppIdentityResolver.isResourceSealError(errSecCSSignatureFailed))
        XCTAssertFalse(TargetAppIdentityResolver.isResourceSealError(errSecCSReqFailed))
        XCTAssertFalse(TargetAppIdentityResolver.isResourceSealError(errSecCSUnsigned))
    }
}
