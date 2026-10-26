import UIKit

/// Puts the interface the right way up in the waist-level pose.
///
/// Half folded with the fold horizontal, the iPhone Duo picks the landscape orientation with
/// the camera half at the bottom, so the screen, the home gesture, system alerts and the
/// camera's rotation angles are all upside down. While in that pose we allow only the opposite
/// landscape orientation, which makes the system rotate everything the right way up.
enum OrientationLock {
    /// What the app delegate reports as the supported orientations.
    private(set) static var mask: UIInterfaceOrientationMask = .all
    private static var unlockTask: Task<Void, Never>?

    static func enterWaistLevel() {
        unlockTask?.cancel()
        unlockTask = nil
        guard mask == .all, let scene = windowScene else { return }
        switch scene.effectiveGeometry.interfaceOrientation {
        case .landscapeLeft: apply(.landscapeRight, in: scene)
        case .landscapeRight: apply(.landscapeLeft, in: scene)
        default: break
        }
    }

    static func leaveWaistLevel() {
        guard mask != .all, unlockTask == nil else { return }
        // Wait a moment: the fold region can briefly disappear while the interface rotates,
        // and unlocking then would flip the screen straight back.
        unlockTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            unlockTask = nil
            if let scene = windowScene {
                apply(.all, in: scene)
            }
        }
    }

    private static var windowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    private static func apply(_ newMask: UIInterfaceOrientationMask, in scene: UIWindowScene) {
        mask = newMask
        for window in scene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: newMask)) { _ in }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}
