import SwiftUI

enum AppStatus: Equatable {
    case needsInstall
    case needsApproval
    case configurationMissing
    case starting
    case readyNoFlow
    case readyWithFlow(Int)
    case disconnecting
    case success(Int)
    case error

    func message(in language: AppLanguage) -> String {
        AppStrings(language).statusMessage(self)
    }

    var systemImageName: String {
        switch self {
        case .readyWithFlow:
            return "bolt.horizontal.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .needsApproval, .starting:
            return "clock.badge.exclamationmark"
        case .error:
            return "exclamationmark.triangle.fill"
        default:
            return "bolt.horizontal.circle"
        }
    }

    var tint: Color {
        switch self {
        case .readyWithFlow, .success:
            return .green
        case .needsApproval, .starting:
            return .orange
        case .error:
            return .red
        default:
            return .secondary
        }
    }
}
