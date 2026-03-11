import Foundation
import UIKit

enum MoodPhotoLibrary {
    private static let directoryName = "MoodPhotos"

    static func storeImageData(_ data: Data) throws -> MoodPhotoAttachment {
        guard let image = UIImage(data: data),
              let normalizedData = image.jpegData(compressionQuality: 0.88) else {
            throw MoodPhotoLibraryError.invalidImageData
        }

        let attachment = MoodPhotoAttachment(filename: "\(UUID().uuidString).jpg")
        let fileURL = url(for: attachment)

        try ensureDirectoryExists()
        try normalizedData.write(to: fileURL, options: .atomic)
        return attachment
    }

    static func image(for attachment: MoodPhotoAttachment) -> UIImage? {
        guard let data = try? Data(contentsOf: url(for: attachment)) else {
            return nil
        }

        return UIImage(data: data)
    }

    static func url(for attachment: MoodPhotoAttachment) -> URL {
        directoryURL.appendingPathComponent(attachment.filename, isDirectory: false)
    }

    private static var directoryURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return baseURL.appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func ensureDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }
}

enum MoodPhotoLibraryError: LocalizedError {
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "有一张照片读取失败，请重新选择。"
        }
    }
}
