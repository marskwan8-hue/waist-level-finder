import SwiftUI

/// The upright half in waist-level mode: the back of the finder hood, facing you.
struct HoodPanel: View {
    let hinge: DeviceHinge?
    let onSettings: () -> Void

    private var angle: Double? { hinge?.angle.degrees }
    private var isGoodAngle: Bool {
        guard let angle else { return false }
        return (70...115).contains(angle)
    }

    var body: some View {
        ZStack {
            LeatheretteBackground()

            VStack {
                HStack(alignment: .top) {
                    if let angle {
                        Label("\(Int(angle.rounded()))°", systemImage: "angle")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(isGoodAngle ? .green : .orange)
                            .contentTransition(.numericText(value: angle))
                            .accessibilityLabel("折叠角度 \(Int(angle.rounded())) 度")
                    }
                    Spacer()
                    Button("设置", systemImage: "gearshape", action: onSettings)
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(20)
        }
        .clipped()
    }
}

/// Black pebbled covering, like the outside of a camera body.
private struct LeatheretteBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.11), Color(white: 0.05)], startPoint: .top, endPoint: .bottom)
            Image(uiImage: GrainTexture.image)
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.35)
        }
        .ignoresSafeArea()
    }
}
