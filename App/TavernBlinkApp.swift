import AppKit
import SwiftUI

@MainActor
final class TavernBlinkAppDelegate: NSObject, NSApplicationDelegate {
    let languageSettings: AppLanguageSettings
    let model: AppModel

    override init() {
        let languageSettings = AppLanguageSettings()
        self.languageSettings = languageSettings
        model = AppModel(languageSettings: languageSettings)
        super.init()
    }

    private lazy var floatingDisconnectPanelController =
        FloatingDisconnectPanelController(
            model: model,
            languageSettings: languageSettings
        )

    private lazy var terminationCoordinator = ApplicationTerminationCoordinator {
        [weak self] completion in
        guard let self else {
            completion(.success(()))
            return
        }
        self.model.prepareForTermination(completion: completion)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.refresh()
        floatingDisconnectPanelController.show()
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
        let strings = AppStrings(languageSettings.language)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = strings.quitFailedTitle
        alert.informativeText = model.lastError
            ?? strings.proxyStillActive
        alert.addButton(withTitle: strings.ok)
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
            MenuBarView(
                model: appDelegate.model,
                languageSettings: appDelegate.languageSettings
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                model: appDelegate.model,
                languageSettings: appDelegate.languageSettings
            )
            .frame(width: 560, height: 560)
        }
    }
}
