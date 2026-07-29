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

    var message: String {
        switch self {
        case .needsInstall:
            return "Network component is not installed"
        case .needsApproval:
            return "Approve TavernBlink in System Settings"
        case .configurationMissing:
            return "Transparent proxy is not configured"
        case .starting:
            return "Network component is starting"
        case .readyNoFlow:
            return "Ready; waiting for a target flow"
        case let .readyWithFlow(count):
            return "Ready with \(count) target flow\(count == 1 ? "" : "s")"
        case .disconnecting:
            return "Closing target flows"
        case let .success(count):
            return "Closed \(count) target flow\(count == 1 ? "" : "s")"
        case .error:
            return "An operation failed"
        }
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
