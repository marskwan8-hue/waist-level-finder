import Foundation

/// `UserDefaults` keys shared by every `@AppStorage` in the app.
enum SettingsKey {
    static let focusingScreen = "focusingScreen"
    static let saveMirrored = "saveMirrored"
    static let rotationCorrection = "rotationCorrection"
    static let exposureCount = "exposureCount"
}

/// A roll of 120 film in a 6×6 back gives 12 exposures.
let exposuresPerRoll = 12

/// Wraps an angle in degrees into `0..<360`.
func normalizedDegrees(_ degrees: CGFloat) -> CGFloat {
    let wrapped = degrees.truncatingRemainder(dividingBy: 360)
    return wrapped < 0 ? wrapped + 360 : wrapped
}
