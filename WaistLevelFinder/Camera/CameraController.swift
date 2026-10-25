import AVFoundation
import Observation

/// The main-actor face of the camera: permission, state, and which way is up.
@Observable
final class CameraController {
    enum State {
        case idle, running, denied, unavailable
    }

    private(set) var state: State = .idle
    /// The rotation that keeps the horizon level in the preview, in degrees.
    private(set) var previewAngle: CGFloat = 90

    let engine = CaptureEngine()
    var frames: FrameBox { engine.frames }

    @ObservationIgnored private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored private var rotationObservation: NSKeyValueObservation?

    func start() async {
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            state = .unavailable
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            state = .denied
            return
        }
        state = await engine.start() ? .running : .unavailable
    }

    func stop() {
        engine.stop()
        state = .idle
    }

    /// Tracks device rotation relative to the interface of the layer that shows the preview.
    /// Call it whenever a preview view is created.
    func attach(previewLayer: CALayer) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { @Sendable [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            Task { @MainActor in
                self?.previewAngle = angle
            }
        }
    }

    func focus(at devicePoint: CGPoint) {
        engine.focus(at: devicePoint)
    }

    func setZoom(_ factor: CGFloat) {
        engine.setZoom(factor)
    }

    func setExposureBias(_ ev: Double) {
        engine.setExposureBias(Float(ev))
    }

    func capturePhoto(mirrored: Bool, rotationCorrection: Int, appliesLook: Bool, prefersNaturalTone: Bool) async throws -> Data {
        let base = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 90
        let options = CaptureOptions(
            rotationAngle: normalizedDegrees(base + CGFloat(rotationCorrection)),
            mirrored: mirrored,
            appliesLook: appliesLook,
            prefersNaturalTone: prefersNaturalTone
        )
        return try await engine.capture(options)
    }
}
