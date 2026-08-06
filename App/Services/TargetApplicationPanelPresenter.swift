import AppKit
import UniformTypeIdentifiers

@MainActor
final class TargetApplicationPanelPresenter {
    static let defaultDirectoryURL = URL(
        fileURLWithPath: "/Applications",
        isDirectory: true
    )

    static func makePanel(language: AppLanguage = .english) -> NSOpenPanel {
        let strings = AppStrings(language)
        let panel = NSOpenPanel()
        panel.title = strings.chooseHearthstoneTitle
        panel.prompt = strings.verifyApp
        panel.message = strings.chooseHearthstoneMessage
        panel.directoryURL = defaultDirectoryURL
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        return panel
    }

    func present(
        language: AppLanguage,
        completion: @escaping (URL?) -> Void
    ) {
        let panel = Self.makePanel(language: language)

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        // Let the MenuBarExtra button event finish and application activation
        // settle before asking the out-of-process Open panel to become key.
        DispatchQueue.main.async {
            panel.begin { response in
                completion(response == .OK ? panel.url : nil)
            }
        }
    }
}
