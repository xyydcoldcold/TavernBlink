import Foundation
import NetworkExtension

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

        do {
            try session.sendProviderMessage(data) { [decoder] responseData in
                guard let responseData else {
                    completion(.failure(MessagingError.missingResponse))
                    return
                }
                do {
                    completion(.success(try decoder.decode(ProviderResponse.self, from: responseData)))
                } catch {
                    completion(.failure(MessagingError.decoding(error)))
                }
            }
        } catch {
            completion(.failure(MessagingError.sending(error)))
        }
    }
}
