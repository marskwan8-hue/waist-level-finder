import Foundation

/// `UserDefaults` keys shared by every `@AppStorage` in the app.
nonisolated enum SettingsKey {
    static let focusingScreen = "focusingScreen"
    static let saveMirrored = "saveMirrored"
    static let rotationCorrection = "rotationCorrection"
    static let appliesLook = "appliesLook"
    static let prefersNaturalTone = "prefersNaturalTone"
    static let zoom = "zoom"
    static let exposureBias = "exposureBias"
    static let flipsWaistLevel = "flipsWaistLevel"
    static let mirrorsViewfinder = "mirrorsViewfinder"
    static let language = "language"
}

/// Exposure compensation steps. The recipe pulls exposure down to deepen shadows.
let exposureBiasSteps: [Double] = [0, -0.3, -0.7, -1, 0.3, 0.7]

/// "−0.3", "+0.7", "±0".
func formattedEV(_ ev: Double) -> String {
    ev == 0 ? "±0" : (ev > 0 ? "+" : "−") + String(format: "%.1f", abs(ev))
}

/// Wraps an angle in degrees into `0..<360`.
func normalizedDegrees(_ degrees: CGFloat) -> CGFloat {
    let wrapped = degrees.truncatingRemainder(dividingBy: 360)
    return wrapped < 0 ? wrapped + 360 : wrapped
}
