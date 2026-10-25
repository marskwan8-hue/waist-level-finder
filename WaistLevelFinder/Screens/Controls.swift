import SwiftUI

/// A big chrome shutter release.
struct ShutterButton: View {
    let isEnabled: Bool
    let action: () -> Void

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
        .accessibilityLabel("快门")
    }
}

private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// Loupe, focusing screen and settings.
struct ToolButtons: View {
    let isVertical: Bool
    @Binding var isLoupeOn: Bool
    @Binding var screen: FocusingScreen
    /// Settings live on the hood in waist-level mode, so the button is optional here.
    var onSettings: (() -> Void)?

    var body: some View {
        let layout = isVertical ? AnyLayout(VStackLayout(spacing: 18)) : AnyLayout(HStackLayout(spacing: 18))
        layout {
            ToolButton(title: "放大镜", symbol: "plus.magnifyingglass", isOn: isLoupeOn) {
                isLoupeOn.toggle()
            }
            ToolButton(title: screen.title, symbol: screen.symbol, isOn: false) {
                screen = screen.next
            }
            if let onSettings {
                ToolButton(title: "设置", symbol: "gearshape", isOn: false, action: onSettings)
            }
        }
    }
}

private struct ToolButton: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(isOn ? Color.accentColor : Color(white: 0.16)))
                    .foregroundStyle(isOn ? .black : .white)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// The exposure counter window of a 12-exposure film back.
struct ExposureCounter: View {
    let exposureCount: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("\(exposureCount % exposuresPerRoll + 1)")
                .font(.system(size: 26, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 50, height: 38)
                .background(RoundedRectangle(cornerRadius: 4).fill(.black))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.35), lineWidth: 1))
                .contentTransition(.numericText())
            Text("/ \(exposuresPerRoll)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .animation(.snappy, value: exposureCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(exposureCount % exposuresPerRoll + 1) 张，共 \(exposuresPerRoll) 张")
    }
}
