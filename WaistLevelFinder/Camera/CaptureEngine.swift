import AVFoundation
import CoreImage

enum CaptureError: LocalizedError {
    case unavailable
    case noImageData

    var errorDescription: String? {
        switch self {
        case .unavailable: Language.current.pick("相机不可用", "The camera isn't available")
        case .noImageData: Language.current.pick("没有拿到照片数据", "The photo couldn't be read")
        }
    }
}

/// How a photo should be taken and finished.
nonisolated struct CaptureOptions: Sendable {
    var rotationAngle: CGFloat
    var mirrored: Bool
    var appliesLook: Bool
    /// Prefer a single frame over multi-frame fusion (Smart HDR, Deep Fusion) for more natural tones.
    var prefersNaturalTone: Bool
}

/// Owns the `AVCaptureSession` and does all of its work on a private serial queue,
/// as AVFoundation recommends.
nonisolated final class CaptureEngine: @unchecked Sendable {
    let session = AVCaptureSession()
    /// The latest viewfinder frame, for the live preview.
    let frames = FrameBox()

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "WaistLevelFinder.capture")
    private let videoQueue = DispatchQueue(label: "WaistLevelFinder.video")
    private let ciContext = CIContext()
    private var device: AVCaptureDevice?
    /// Keeps each photo delegate alive until its photo arrives. Only touched on `queue`.
    private var inFlight: [Int64: PhotoDelegate] = [:]

    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                self.configureIfNeeded()
                if self.device != nil, !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume(returning: self.session.isRunning)
            }
        }
    }

    func stop() {
        queue.async {
            self.session.stopRunning()
        }
    }

    private func configureIfNeeded() {
        guard device == nil else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(photoOutput), session.canAddOutput(videoOutput) else { return }
        session.addInput(input)
        session.addOutput(photoOutput)
        session.addOutput(videoOutput)

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(frames, queue: videoQueue)

        // Full sensor resolution (48 MP where the camera has it).
        if let largest = device.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            photoOutput.maxPhotoDimensions = largest
        }
        photoOutput.maxPhotoQualityPrioritization = .quality
        self.device = device
    }

    /// Focuses and meters at a point in the capture device's coordinate space (0...1).
    func focus(at devicePoint: CGPoint) {
        configureDevice { device in
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .continuousAutoExposure
            }
        }
    }

    /// 2× on the main camera is about 48 mm, close to a medium-format standard lens.
    func setZoom(_ factor: CGFloat) {
        configureDevice { device in
            device.videoZoomFactor = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        }
    }

    func setExposureBias(_ ev: Float) {
        configureDevice { device in
            device.setExposureTargetBias(min(max(ev, device.minExposureTargetBias), device.maxExposureTargetBias), completionHandler: nil)
        }
    }

    private func configureDevice(_ change: @escaping @Sendable (AVCaptureDevice) -> Void) {
        queue.async {
            guard let device = self.device, (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }
            change(device)
        }
    }

    /// Takes a photo and returns it as a square JPEG, cropped from the centre
    /// the same way the viewfinder crops the preview.
    func capture(_ options: CaptureOptions) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.device != nil, let connection = self.photoOutput.connection(with: .video) else {
                    continuation.resume(throwing: CaptureError.unavailable)
                    return
                }
                if connection.isVideoRotationAngleSupported(options.rotationAngle) {
                    connection.videoRotationAngle = options.rotationAngle
                }

                let settings = AVCapturePhotoSettings()
                settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
                settings.photoQualityPrioritization = options.prefersNaturalTone ? .speed : .quality
                let id = settings.uniqueID

                self.inFlight[id] = PhotoDelegate { result in
                    self.queue.async {
                        self.inFlight[id] = nil
                        continuation.resume(with: result.flatMap { self.finish($0, options: options) })
                    }
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self.inFlight[id]!)
            }
        }
    }

    private func finish(_ data: Data, options: CaptureOptions) -> Result<Data, Error> {
        guard var image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            return .failure(CaptureError.noImageData)
        }
        let extent = image.extent
        let side = min(extent.width, extent.height)
        image = image
            .cropped(to: CGRect(x: extent.midX - side / 2, y: extent.midY - side / 2, width: side, height: side))
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        if options.mirrored {
            // Flip horizontally, the way the image looks on the ground glass.
            image = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -side, y: 0))
        }
        if options.appliesLook {
            image = ClassicLook.sharpen(ClassicLook.apply(to: image))
        }
        // The orientation is already applied; drop it so it isn't applied twice.
        image = image.settingProperties([:])

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let options = [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95]
        guard let jpeg = ciContext.jpegRepresentation(of: image, colorSpace: colorSpace, options: options) else {
            return .failure(CaptureError.noImageData)
        }
        return .success(jpeg)
    }
}

/// Receives viewfinder frames on the video queue and hands the newest one to the renderer.
nonisolated final class FrameBox: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var image: CIImage?
    private var count = 0

    /// The newest frame and a number that changes with every new frame.
    var latest: (image: CIImage, number: Int)? {
        lock.withLock { image.map { ($0, count) } }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let frame = CIImage(cvPixelBuffer: pixelBuffer)
        lock.withLock {
            image = frame
            count &+= 1
        }
    }
}

nonisolated private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<Data, Error>) -> Void

    init(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            completion(.success(data))
        } else {
            completion(.failure(CaptureError.noImageData))
        }
    }
}
