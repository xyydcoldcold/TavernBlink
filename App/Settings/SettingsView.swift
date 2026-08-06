import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var languageSettings: AppLanguageSettings

    private var strings: AppStrings {
        AppStrings(languageSettings.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(strings.settingsTitle)
                .font(.title2.bold())

            GroupBox(strings.general) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(strings.languageLabel, selection: $languageSettings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(language)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(strings.languageHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Text(strings.setupGuide)
                .font(.headline)

            Text(strings.setupDescription)

            GroupBox(strings.requiredOrder) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(strings.installAndApprove, systemImage: "1.circle")
                    Label(
                        strings.chooseAndVerify,
                        systemImage: "2.circle"
                    )
                    Label(strings.saveAndStart, systemImage: "3.circle")
                    Label(strings.restartHearthstone, systemImage: "4.circle")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            GroupBox(strings.important) {
                Text(strings.riskWarning)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }

            Spacer()

            HStack {
                Text(model.status.message(in: languageSettings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(strings.refresh) {
                    model.refresh()
                }
            }
        }
        .padding(24)
    }
}
