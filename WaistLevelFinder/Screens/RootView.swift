import SwiftUI

struct RootView: View {
    @State private var camera = CameraController()
    @State private var hinge: DeviceHinge?
    @State private var isLoupeOn = false
    @State private var isBlackout = false
    @State private var isCapturing = false
    @State private var isShowingSettings = false
    @State private var toast: String?

    @AppStorage(SettingsKey.focusingScreen) private var screen = FocusingScreen.grid
    @AppStorage(SettingsKey.saveMirrored) private var saveMirrored = false
    @AppStorage(SettingsKey.rotationCorrection) private var rotationCorrection = 0
    @AppStorage(SettingsKey.exposureCount) private var exposureCount = 0

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            // 👇 The fold is a division region, active only while the device is partially folded.
            // A horizontal fold means the tabletop pose: our waist-level pose.
            let layout = FinderLayout(size: proxy.size, fold: proxy.reservedRegions(kind: .division).first?.frame)

            ZStack(alignment: .topLeading) {
                if let hood = layout.hood {
                    HoodPanel(hinge: hinge) { isShowingSettings = true }
                        .frame(width: hood.width, height: hood.height)
                        .position(x: hood.midX, y: hood.midY)
                        .transition(.opacity)
                }

                GroundGlassView(
                    camera: camera,
                    screen: screen,
                    isLoupeOn: isLoupeOn,
                    isBlackout: isBlackout,
                    rotationAngle: normalizedDegrees(camera.previewAngle + CGFloat(rotationCorrection))
                )
                .frame(width: layout.glass.width, height: layout.glass.height)
                .position(x: layout.glass.midX, y: layout.glass.midY)

                ToolButtons(
                    isVertical: layout.toolsAreVertical,
                    isLoupeOn: $isLoupeOn,
                    screen: $screen,
                    onSettings: layout.hood == nil ? { isShowingSettings = true } : nil
                )
                .position(layout.tools)

                ExposureCounter(exposureCount: exposureCount)
                    .position(layout.counter)

                ShutterButton(isEnabled: camera.state == .running && !isCapturing, action: shoot)
                    .position(layout.shutter)

                if case .handheld(let isBookPose) = layout.mode, hinge != nil {
                    PoseHint(isBookPose: isBookPose)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }

                if let toast {
                    Text(toast)
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: .capsule)
                        .position(x: layout.glass.midX, y: layout.glass.minY + 32)
                        .transition(.opacity)
                }
            }
            .animation(.smooth, value: layout.mode)
        }
        .background(Color(white: 0.07).ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .heavy), trigger: exposureCount)
        .sensoryFeedback(.selection, trigger: isLoupeOn)
        .onHingeChange { _, newContext in
            hinge = newContext.hinge
        }
        .task {
            await camera.start()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if camera.state == .idle { Task { await camera.start() } }
            case .background:
                camera.stop()
            default:
                break
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheet()
        }
    }

    private func shoot() {
        guard !isCapturing else { return }
        isCapturing = true
        isBlackout = true

        Task {
            defer { isCapturing = false }
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(.easeOut(duration: 0.3)) { isBlackout = false }

            do {
                let jpeg = try await camera.capturePhoto(mirrored: saveMirrored, rotationCorrection: rotationCorrection)
                try await PhotoLibrary.save(jpeg)
                exposureCount += 1
                if exposureCount % exposuresPerRoll == 0 {
                    showToast("一卷拍完了，换新卷继续")
                }
            } catch {
                showToast(error.localizedDescription)
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toast == message {
                withAnimation { toast = nil }
            }
        }
    }
}

/// Tells you how to get into the waist-level pose.
private struct PoseHint: View {
    let isBookPose: Bool

    var body: some View {
        Label(
            isBookPose ? "横过来，让摄像头那一半竖起来" : "半折到 90° 左右，进入腰平模式",
            systemImage: isBookPose ? "rotate.right" : "laptopcomputer"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: .capsule)
    }
}
