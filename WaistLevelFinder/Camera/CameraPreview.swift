import AVFoundation
import SwiftUI

/// The live camera image, filling its frame. Tapping focuses at that point.
struct CameraPreview: UIViewRepresentable {
    let camera: CameraController
    let rotationAngle: CGFloat
    /// Passed in so the view updates once the session has its connection.
    let isRunning: Bool
    /// Called with the tap location in this view's own coordinates.
    var onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        camera.attach(previewLayer: view.previewLayer)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.onTap = { [camera, onTap] layerPoint, devicePoint in
            camera.focus(at: devicePoint)
            onTap(layerPoint)
        }
        if isRunning, let connection = view.previewLayer.connection,
           connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var onTap: ((_ layerPoint: CGPoint, _ devicePoint: CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        // In the view's own coordinates, so mirroring and the loupe zoom are already undone.
        let point = recognizer.location(in: self)
        onTap?(point, previewLayer.captureDevicePointConverted(fromLayerPoint: point))
    }
}
