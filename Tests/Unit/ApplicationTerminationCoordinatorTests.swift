import XCTest

@MainActor
final class ApplicationTerminationCoordinatorTests: XCTestCase {
    private enum StubError: Error {
        case shutdownFailed
    }

    func testSuccessfulShutdownAllowsTermination() async {
        var shutdownCompletion: ((Result<Void, Error>) -> Void)?
        let coordinator = ApplicationTerminationCoordinator { completion in
            shutdownCompletion = completion
        }
        var reply: Bool?
        let replied = expectation(description: "termination reply")

        XCTAssertTrue(coordinator.requestTermination {
            reply = $0
            replied.fulfill()
        })
        XCTAssertTrue(coordinator.isTerminationPending)

        shutdownCompletion?(.success(()))
        await fulfillment(of: [replied])

        XCTAssertEqual(reply, true)
        XCTAssertFalse(coordinator.isTerminationPending)
    }

    func testFailedShutdownCancelsTermination() async {
        var shutdownCompletion: ((Result<Void, Error>) -> Void)?
        let coordinator = ApplicationTerminationCoordinator { completion in
            shutdownCompletion = completion
        }
        var reply: Bool?
        let replied = expectation(description: "termination reply")

        XCTAssertTrue(coordinator.requestTermination {
            reply = $0
            replied.fulfill()
        })
        shutdownCompletion?(.failure(StubError.shutdownFailed))
        await fulfillment(of: [replied])

        XCTAssertEqual(reply, false)
        XCTAssertFalse(coordinator.isTerminationPending)
    }

    func testDuplicateRequestDoesNotStartAnotherShutdown() {
        var shutdownCount = 0
        var shutdownCompletion: ((Result<Void, Error>) -> Void)?
        let coordinator = ApplicationTerminationCoordinator { completion in
            shutdownCount += 1
            shutdownCompletion = completion
        }

        XCTAssertTrue(coordinator.requestTermination { _ in })
        XCTAssertFalse(coordinator.requestTermination { _ in })
        XCTAssertEqual(shutdownCount, 1)

        shutdownCompletion?(.success(()))
    }
}
