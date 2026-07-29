import Foundation
import NetworkExtension
import OSLog

final class ProviderMessenger {
    enum MessagingError: LocalizedError {
        case encoding(Error)
        case sending(Error)
        case missingResponse
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case let .encoding(error):
                return "Unable to encode provider command: \(error.localizedDescription)"
            case let .sending(error):
                return "Unable to send provider command: \(error.localizedDescription)"
            case .missingResponse:
                return "The provider did not return a response."
            case let .decoding(error):
                return "Unable to decode provider response: \(error.localizedDescription)"
            }
        }
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = Logger(
        subsystem: "dev.tavernblink.TavernBlink",
        category: "messaging"
    )

    func send(
        _ command: ProviderCommand,
        through session: NETunnelProviderSession,
        completion: @escaping (Result<ProviderResponse, Error>) -> Void
    ) {
        let data: Data
        do {
            data = try encoder.encode(command)
        } catch {
            completion(.failure(MessagingError.encoding(error)))
            return
        }

        let start = ContinuousClock.now
        logger.info(
            "Sending provider action \(command.action.rawValue, privacy: .public), request \(command.requestID.uuidString, privacy: .public)"
        )
        do {
            try session.sendProviderMessage(data) { [decoder, logger] responseData in
                let duration = start.duration(to: .now)
                let milliseconds = Int(duration.components.seconds * 1_000)
                    + Int(duration.components.attoseconds / 1_000_000_000_000_000)
                guard let responseData else {
                    logger.error(
                        "Provider request \(command.requestID.uuidString, privacy: .public) returned no response after \(milliseconds) ms"
                    )
                    completion(.failure(MessagingError.missingResponse))
                    return
                }
                do {
                    let response = try decoder.decode(ProviderResponse.self, from: responseData)
                    logger.info(
                        "Provider request \(command.requestID.uuidString, privacy: .public) completed in \(milliseconds) ms with \(response.result.rawValue, privacy: .public)"
                    )
                    completion(.success(response))
                } catch {
                    logger.error(
                        "Provider response decoding failed for \(command.requestID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                    completion(.failure(MessagingError.decoding(error)))
                }
            }
        } catch {
            logger.error(
                "Provider request \(command.requestID.uuidString, privacy: .public) could not be sent: \(error.localizedDescription, privacy: .public)"
            )
            completion(.failure(MessagingError.sending(error)))
        }
    }
}
