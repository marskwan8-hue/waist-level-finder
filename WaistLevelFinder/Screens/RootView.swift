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
    @AppStorage(SettingsKey.appliesLook) private var appliesLook = true
    @AppStorage(SettingsKey.prefersNaturalTone) private var prefersNaturalTone = true
    @AppStorage(SettingsKey.zoom) private var zoom = 2.0
    @AppStorage(SettingsKey.exposureBias) private var exposureBias = 0.0
    @AppStorage(SettingsKey.flipsWaistLevel) private var flipsWaistLevel = true

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            // 👇 The fold is a division region, active only while the device is partially folded.
            // A horizontal fold means the tabletop pose: our waist-level pose.
            let fold = proxy.reservedRegions(kind: .division).first?.frame
            let layout = FinderLayout(size: proxy.size, fold: fold)
            let locksOrientation = flipsWaistLevel && layout.mode == .waistLevel

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
                    rotationAngle: normalizedDegrees(camera.previewAngle + CGFloat(rotationCorrection)),
                    appliesLook: appliesLook
                )
                .frame(width: layout.glass.width, height: layout.glass.height)
                .position(x: layout.glass.midX, y: layout.glass.midY)

                ToolButtons(isLoupeOn: $isLoupeOn, screen: $screen, exposureBias: $exposureBias, zoom: $zoom)
                    .position(layout.tools)

                if let settings = layout.settings {
                    Button("设置", systemImage: "gearshape") { isShowingSettings = true }
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .position(settings)
                }

                ExposureCounter(exposureCount: exposureCount)
                    .position(layout.counter)

                ShutterButton(isEnabled: camera.state == .running && !isCapturing, action: shoot)
                    .position(layout.shutter)

                if case .handheld(let isBookPose) = layout.mode, hinge != nil {
                    PoseHint(isBookPose: isBookPose)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }

                if isShowingSettings {
                    ZStack {
                        Color.black.opacity(0.5)
                            .onTapGesture { isShowingSettings = false }
                        SettingsSheet { isShowingSettings = false }
                            .frame(maxWidth: 560)
                            .clipShape(.rect(cornerRadius: 20))
                            .padding(16)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .transition(.opacity)
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
            .animation(.smooth, value: isShowingSettings)
            .onChange(of: locksOrientation, initial: true) { _, locks in
                if locks {
                    OrientationLock.enterWaistLevel()
                } else {
                    OrientationLock.leaveWaistLevel()
                }
            }
        }
        .background(Color(white: 0.07).ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .heavy), trigger: exposureCount)
        .sensoryFeedback(.selection, trigger: isLoupeOn)
        .onHingeChange { _, newContext in
            hinge = newContext.hinge
        }
        .task {
            await camera.start()
            // Ask up front rather than on the first shot, so the alert doesn't interrupt framing.
            await PhotoLibrary.requestAccess()
        }
        .onChange(of: camera.state) { _, state in
            if state == .running { applyCameraSettings() }
        }
        .onChange(of: zoom) { applyCameraSettings() }
        .onChange(of: exposureBias) { applyCameraSettings() }
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
    }

    private func applyCameraSettings() {
        camera.setZoom(zoom)
        camera.setExposureBias(exposureBias)
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
                let jpeg = try await camera.capturePhoto(
                    mirrored: saveMirrored,
                    rotationCorrection: rotationCorrection,
                    appliesLook: appliesLook,
                    prefersNaturalTone: prefersNaturalTone
                )
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
