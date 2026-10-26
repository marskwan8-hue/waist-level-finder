import Photos

enum PhotoLibrary {
    enum SaveError: LocalizedError {
        case denied

        var errorDescription: String? { "没有相册写入权限，请在“设置”里打开" }
    }

    static func requestAccess() async {
        _ = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }

    static func save(_ jpeg: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.denied }
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: jpeg, options: nil)
        }
    }
}
