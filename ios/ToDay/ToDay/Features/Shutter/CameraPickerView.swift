import SwiftUI
import UIKit

enum CameraPickerMode {
    case photo
    case video
}

struct CameraPickerView: UIViewControllerRepresentable {
    let mode: CameraPickerMode
    let onCapture: (CameraCaptureResult) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera

        switch mode {
        case .photo:
            picker.mediaTypes = ["public.image"]
            picker.cameraCaptureMode = .photo
        case .video:
            picker.mediaTypes = ["public.movie"]
            picker.cameraCaptureMode = .video
            picker.videoMaximumDuration = 15
            picker.videoQuality = .typeMedium
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (CameraCaptureResult) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (CameraCaptureResult) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                onCapture(.photo(data))
            } else if let videoURL = info[.mediaURL] as? URL {
                onCapture(.video(videoURL))
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

enum CameraCaptureResult {
    case photo(Data)
    case video(URL)
}
