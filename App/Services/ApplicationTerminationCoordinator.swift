import Foundation

@MainActor
final class ApplicationTerminationCoordinator {
    typealias ShutdownOperation = (
        @escaping (Result<Void, Error>) -> Void
    ) -> Void

    private let shutdownOperation: ShutdownOperation
    private(set) var isTerminationPending = false

    init(shutdownOperation: @escaping ShutdownOperation) {
        self.shutdownOperation = shutdownOperation
    }

    @discardableResult
    func requestTermination(
        reply: @escaping (Bool) -> Void
    ) -> Bool {
        guard !isTerminationPending else {
            return false
        }

        isTerminationPending = true
        shutdownOperation { [weak self] result in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.isTerminationPending = false
                switch result {
                case .success:
                    reply(true)
                case .failure:
                    reply(false)
                }
            }
        }
        return true
    }
}
