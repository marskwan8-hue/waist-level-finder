import SwiftUI

@main
struct WaistLevelFinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(SettingsKey.language) private var languagePreference = LanguagePreference.system

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .environment(\.language, Language(languagePreference))
        }
    }
}
