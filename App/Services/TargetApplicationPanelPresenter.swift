import AppKit
import UniformTypeIdentifiers

@MainActor
final class TargetApplicationPanelPresenter {
    static let defaultDirectoryURL = URL(
        fileURLWithPath: "/Applications",
        isDirectory: true
    )

    static func makePanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = "Choose Hearthstone"
        panel.prompt = "Verify App"
        panel.message = "Select the official Hearthstone application."
        panel.directoryURL = defaultDirectoryURL
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        return panel
    }

    func present(completion: @escaping (URL?) -> Void) {
        let panel = Self.makePanel()

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
