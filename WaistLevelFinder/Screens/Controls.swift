import SwiftUI

/// A big chrome shutter release.
struct ShutterButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @Environment(\.language) private var language

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.45)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.9)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 58, height: 58)
                Circle()
                    .fill(Color(red: 0.85, green: 0.35, blue: 0.2))
                    .frame(width: 14, height: 14)
            }
            .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
        }
        .buttonStyle(ShutterPressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(language.pick("快门", "Shutter"))
    }
}

private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// Loupe, focusing screen, exposure compensation and focal length, in a 2×2 grid.
struct ToolButtons: View {
    @Binding var isLoupeOn: Bool
    @Binding var screen: FocusingScreen
    @Binding var exposureBias: Double
    @Binding var zoom: Double
    @Environment(\.language) private var language

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 14) {
            GridRow {
                ToolButton(title: language.pick("放大镜", "Loupe"), isOn: isLoupeOn) {
                    isLoupeOn.toggle()
                } icon: {
                    Image(systemName: "plus.magnifyingglass")
                }
                ToolButton(title: screen.title(in: language), isOn: false) {
                    screen = screen.next
                } icon: {
                    Image(systemName: screen.symbol)
                }
            }
            GridRow {
                ToolButton(title: language.pick("曝光", "Exposure"), isOn: exposureBias != 0) {
                    let index = exposureBiasSteps.firstIndex(of: exposureBias) ?? 0
                    exposureBias = exposureBiasSteps[(index + 1) % exposureBiasSteps.count]
                } icon: {
                    Text(formattedEV(exposureBias))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                }
                ToolButton(title: zoom == 2 ? "≈48mm" : "≈24mm", isOn: false) {
                    zoom = zoom == 2 ? 1 : 2
                } icon: {
                    Text(zoom == 2 ? "2×" : "1×")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }
}

private struct ToolButton<Icon: View>: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    @ViewBuilder let icon: Icon

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon
                    .font(.title3)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(isOn ? Color.accentColor : Color(white: 0.16)))
                    .foregroundStyle(isOn ? .black : .white)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
    }
}
