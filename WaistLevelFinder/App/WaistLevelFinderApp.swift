import SwiftUI

@main
struct WaistLevelFinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
