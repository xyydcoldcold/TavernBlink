import AppKit
import SwiftUI

@MainActor
final class TavernBlinkAppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    private lazy var terminationCoordinator = ApplicationTerminationCoordinator {
        [weak self] completion in
        guard let self else {
            completion(.success(()))
            return
        }
        self.model.prepareForTermination(completion: completion)
    }

    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        guard !terminationCoordinator.isTerminationPending else {
            return .terminateLater
        }

        terminationCoordinator.requestTermination { [weak self, weak sender] shouldTerminate in
            guard let sender else {
                return
            }
            if !shouldTerminate {
                self?.presentQuitBlockedAlert()
            }
            sender.reply(toApplicationShouldTerminate: shouldTerminate)
        }
        return .terminateLater
    }

    private func presentQuitBlockedAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "TavernBlink could not quit safely"
        alert.informativeText = model.lastError
            ?? "The transparent proxy is still active. TavernBlink was left open."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

@main
struct TavernBlinkApp: App {
    @NSApplicationDelegateAdaptor(TavernBlinkAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra(
            "TavernBlink",
            systemImage: appDelegate.model.status.systemImageName
        ) {
            MenuBarView(model: appDelegate.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            OnboardingView(model: appDelegate.model)
                .frame(width: 520, height: 430)
        }
    }
}
