import SwiftUI

struct RootView: View {
    @State private var camera = CameraController()
    @State private var hinge: DeviceHinge?
    @State private var isLoupeOn = false
    @State private var isBlackout = false
    @State private var isCapturing = false
    @State private var isShowingSettings = false
    @State private var toast: String?
    /// Counts saved photos this session, to trigger the shutter haptic.
    @State private var shotCount = 0

    @AppStorage(SettingsKey.focusingScreen) private var screen = FocusingScreen.grid
    @AppStorage(SettingsKey.saveMirrored) private var saveMirrored = false
    @AppStorage(SettingsKey.rotationCorrection) private var rotationCorrection = 0
    @AppStorage(SettingsKey.appliesLook) private var appliesLook = true
    @AppStorage(SettingsKey.prefersNaturalTone) private var prefersNaturalTone = true
    @AppStorage(SettingsKey.zoom) private var zoom = 2.0
    @AppStorage(SettingsKey.exposureBias) private var exposureBias = 0.0
    @AppStorage(SettingsKey.flipsWaistLevel) private var flipsWaistLevel = true
    @AppStorage(SettingsKey.mirrorsViewfinder) private var mirrorsViewfinder = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.language) private var language

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
                    appliesLook: appliesLook,
                    isMirrored: mirrorsViewfinder
                )
                .frame(width: layout.glass.width, height: layout.glass.height)
                .position(x: layout.glass.midX, y: layout.glass.midY)

                ToolButtons(isLoupeOn: $isLoupeOn, screen: $screen, exposureBias: $exposureBias, zoom: $zoom)
                    .position(layout.tools)

                if let settings = layout.settings {
                    Button(language.pick("设置", "Settings"), systemImage: "gearshape") { isShowingSettings = true }
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .position(settings)
                }

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
        .sensoryFeedback(.impact(weight: .heavy), trigger: shotCount)
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
                shotCount += 1
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
    @Environment(\.language) private var language

    var body: some View {
        VStack(spacing: 2) {
            Label(
                isBookPose
                    ? language.pick("横过来，让摄像头那一半竖起来", "Turn sideways with the camera half standing up")
                    : language.pick("半折到 90° 左右，进入腰平模式", "Fold to about 90° for waist-level mode"),
                systemImage: isBookPose ? "rotate.right" : "laptopcomputer"
            )
            // The app turns the interface itself in the waist-level pose; the lock stops it.
            Text(language.pick("请先在控制中心关闭竖排方向锁定", "Turn off Orientation Lock in Control Center first"))
                .font(.caption2)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: .capsule)
    }
}
