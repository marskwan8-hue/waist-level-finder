import SwiftUI

/// The square focusing screen as seen from above: the camera image, mirrored left to right
/// like a real waist-level finder, with the screen's texture and markings on top.
struct GroundGlassView: View {
    let camera: CameraController
    let screen: FocusingScreen
    let isLoupeOn: Bool
    let isBlackout: Bool
    let rotationAngle: CGFloat
    let appliesLook: Bool
    let isMirrored: Bool

    @State private var focusMark: FocusMark?

    var body: some View {
        ZStack {
            ZStack {
                CameraPreview(camera: camera, rotationAngle: rotationAngle, appliesLook: appliesLook) { point in
                    showFocusMark(at: point)
                }
                GroundGlassTexture()
                ScreenMarkings(screen: screen)
                if let focusMark {
                    FocusMarkView()
                        .position(focusMark.point)
                        .id(focusMark.id)
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
            }
            // 👇 The real waist-level look: no prism, so left and right are swapped.
            .scaleEffect(x: isMirrored ? -1 : 1, y: 1)
            // The pop-up magnifier enlarges the centre of the screen.
            .scaleEffect(isLoupeOn ? 2.6 : 1)

            Vignette(isLoupe: isLoupeOn)

            if isBlackout {
                // The mirror flips up and the screen goes dark for a moment.
                Color.black
            }

            if camera.state == .denied || camera.state == .unavailable {
                CameraUnavailableView(state: camera.state)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    LinearGradient(colors: [.black, .white.opacity(0.25)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 2
                )
        }
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.black)
                .padding(-6)
                .shadow(color: .black.opacity(0.8), radius: 8)
        }
        .animation(.snappy, value: isLoupeOn)
    }

    private func showFocusMark(at point: CGPoint) {
        let mark = FocusMark(point: point)
        withAnimation(.snappy) { focusMark = mark }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if focusMark?.id == mark.id {
                withAnimation(.easeOut) { focusMark = nil }
            }
        }
    }
}

private struct FocusMark {
    let id = UUID()
    let point: CGPoint
}

private struct FocusMarkView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .stroke(.yellow.opacity(0.85), lineWidth: 1.2)
            .frame(width: 54, height: 54)
            .allowsHitTesting(false)
    }
}

private struct CameraUnavailableView: View {
    let state: CameraController.State
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.slash")
                .font(.largeTitle)
            Text(state == .denied ? "需要相机权限" : "相机不可用")
                .font(.headline)
            if state == .denied {
                Button("打开设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.85))
    }
}
