import AVFoundation
import CoreImage

enum CaptureError: LocalizedError {
    case unavailable
    case noImageData

    var errorDescription: String? {
        switch self {
        case .unavailable: "相机不可用"
        case .noImageData: "没有拿到照片数据"
        }
    }
}

/// Owns the `AVCaptureSession` and does all of its work on a private serial queue,
/// as AVFoundation recommends.
nonisolated final class CaptureEngine: @unchecked Sendable {
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "WaistLevelFinder.capture")
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
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else { return }
        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        self.device = device
    }

    /// Focuses and meters at a point in the capture device's coordinate space (0...1).
    func focus(at devicePoint: CGPoint) {
        queue.async {
            guard let device = self.device, (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }

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

    /// Takes a photo and returns it as a square JPEG, cropped from the centre
    /// the same way the viewfinder crops the preview.
    func capture(rotationAngle: CGFloat, mirrored: Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.device != nil, let connection = self.photoOutput.connection(with: .video) else {
                    continuation.resume(throwing: CaptureError.unavailable)
                    return
                }
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }

                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .quality
                let id = settings.uniqueID

                self.inFlight[id] = PhotoDelegate { result in
                    self.queue.async {
                        self.inFlight[id] = nil
                        continuation.resume(with: result.flatMap { self.squareJPEG(from: $0, mirrored: mirrored) })
                    }
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self.inFlight[id]!)
            }
        }
    }

    private func squareJPEG(from data: Data, mirrored: Bool) -> Result<Data, Error> {
        guard var image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            return .failure(CaptureError.noImageData)
        }
        let extent = image.extent
        let side = min(extent.width, extent.height)
        image = image
            .cropped(to: CGRect(x: extent.midX - side / 2, y: extent.midY - side / 2, width: side, height: side))
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        if mirrored {
            // Flip horizontally, the way the image looks on the ground glass.
            image = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -side, y: 0))
        }
        // The orientation is already applied; drop it so it isn't applied twice.
        image = image.settingProperties([:])

        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.displayP3)!
        let options = [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95]
        guard let jpeg = ciContext.jpegRepresentation(of: image, colorSpace: colorSpace, options: options) else {
            return .failure(CaptureError.noImageData)
        }
        return .success(jpeg)
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
