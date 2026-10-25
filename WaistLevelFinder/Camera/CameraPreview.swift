import CoreImage
import MetalKit
import SwiftUI

/// The live camera image, colour graded and filling its frame. Tapping focuses at that point.
struct CameraPreview: UIViewRepresentable {
    let camera: CameraController
    let rotationAngle: CGFloat
    let appliesLook: Bool
    /// Called with the tap location in this view's own coordinates.
    var onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.frames = camera.frames
        camera.attach(previewLayer: view.layer)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.rotationAngle = rotationAngle
        view.appliesLook = appliesLook
        view.onTap = { [camera, onTap] viewPoint, devicePoint in
            camera.focus(at: devicePoint)
            onTap(viewPoint)
        }
    }
}

/// Draws the newest camera frame with Core Image into a Metal view, aspect-filled.
final class PreviewView: MTKView {
    var frames: FrameBox?
    var rotationAngle: CGFloat = 90
    var appliesLook = true
    var onTap: ((_ viewPoint: CGPoint, _ devicePoint: CGPoint) -> Void)?

    private let commandQueue: MTLCommandQueue?
    private let ciContext: CIContext?
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private var lastFrameNumber = -1
    private var lastAngle: CGFloat = -1
    private var lastAppliesLook = true
    /// The size of the last frame after rotating it upright, for mapping taps.
    private var uprightFrameSize: CGSize = .zero

    init() {
        let device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        ciContext = device.map { CIContext(mtlDevice: $0, options: [.cacheIntermediates: false]) }
        super.init(frame: .zero, device: device)
        framebufferOnly = false
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        preferredFramesPerSecond = 60
        backgroundColor = .black
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let latest = frames?.latest else { return }
        let (frame, number) = latest
        // Only redraw for a new frame or a changed setting.
        guard number != lastFrameNumber || rotationAngle != lastAngle || appliesLook != lastAppliesLook else { return }
        guard let ciContext, let drawable = currentDrawable, let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        let target = drawableSize
        guard target.width > 0, target.height > 0 else { return }

        var image = frame.oriented(Self.orientation(forQuarterTurns: Self.quarterTurns(rotationAngle)))
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        uprightFrameSize = image.extent.size

        // Scale before grading, so the colour cube only runs on the pixels we show.
        let scale = max(target.width / image.extent.width, target.height / image.extent.height)
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        image = image.transformed(by: CGAffineTransform(
            translationX: -(image.extent.width - target.width) / 2,
            y: -(image.extent.height - target.height) / 2
        ))
        if appliesLook {
            image = HasselbladLook.apply(to: image)
        }

        ciContext.render(image, to: drawable.texture, commandBuffer: commandBuffer,
                         bounds: CGRect(origin: .zero, size: target), colorSpace: colorSpace)
        commandBuffer.present(drawable)
        commandBuffer.commit()

        lastFrameNumber = number
        lastAngle = rotationAngle
        lastAppliesLook = appliesLook
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        // In the view's own coordinates, so mirroring and the loupe zoom are already undone.
        let point = recognizer.location(in: self)
        let upright = uprightFrameSize
        guard bounds.width > 0, bounds.height > 0, upright.width > 0, upright.height > 0 else { return }

        // Undo the aspect fill: where the tap lands in the upright frame, 0...1, top-left origin.
        let scale = max(bounds.width / upright.width, bounds.height / upright.height)
        let u = (point.x / scale + (upright.width - bounds.width / scale) / 2) / upright.width
        let v = (point.y / scale + (upright.height - bounds.height / scale) / 2) / upright.height

        // Undo the rotation: device points are in the sensor's landscape orientation.
        let devicePoint = switch Self.quarterTurns(rotationAngle) {
        case 1: CGPoint(x: v, y: 1 - u)
        case 2: CGPoint(x: 1 - u, y: 1 - v)
        case 3: CGPoint(x: 1 - v, y: u)
        default: CGPoint(x: u, y: v)
        }
        onTap?(point, devicePoint)
    }

    /// Clockwise quarter turns, 0...3, for a rotation angle in degrees.
    private static func quarterTurns(_ degrees: CGFloat) -> Int {
        Int((normalizedDegrees(degrees) / 90).rounded()) % 4
    }

    private static func orientation(forQuarterTurns turns: Int) -> CGImagePropertyOrientation {
        switch turns {
        case 1: .right
        case 2: .down
        case 3: .left
        default: .up
        }
    }
}
