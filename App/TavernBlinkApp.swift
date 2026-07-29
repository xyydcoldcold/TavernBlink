import SwiftUI

@main
struct TavernBlinkApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("TavernBlink", systemImage: model.status.systemImageName) {
            MenuBarView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            OnboardingView(model: model)
                .frame(width: 520, height: 430)
        }
    }
}
