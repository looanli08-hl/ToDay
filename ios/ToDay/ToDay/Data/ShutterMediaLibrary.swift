import Foundation
import UIKit

enum ShutterMediaLibrary {
    private static let directoryName = "ShutterMedia"

    static var baseDirectoryURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return baseURL.appendingPathComponent(directoryName, isDirectory: true)
    }

    // MARK: - Store

    static func storePhoto(_ imageData: Data) throws -> String {
        guard let image = UIImage(data: imageData),
              let normalized = image.jpegData(compressionQuality: 0.85) else {
            throw ShutterMediaError.invalidImageData
        }
        let filename = "\(UUID().uuidString).jpg"
        try writeFile(data: normalized, filename: filename)
        return filename
    }

    static func storeVoice(_ audioData: Data) throws -> String {
        let filename = "\(UUID().uuidString).m4a"
        try writeFile(data: audioData, filename: filename)
        return filename
    }

    static func storeVideo(_ videoData: Data) throws -> String {
        let filename = "\(UUID().uuidString).mov"
        try writeFile(data: videoData, filename: filename)
        return filename
    }

    static func copyVideoFile(from sourceURL: URL) throws -> String {
        let filename = "\(UUID().uuidString).mov"
        let destination = baseDirectoryURL.appendingPathComponent(filename)
        try ensureDirectoryExists()
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return filename
    }

    // MARK: - Query

    static func fileURL(for filename: String) -> URL {
        baseDirectoryURL.appendingPathComponent(filename)
    }

    static func fileExists(filename: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: filename).path)
    }

    // MARK: - Delete

    static func deleteFile(filename: String) {
        let url = fileURL(for: filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private static func writeFile(data: Data, filename: String) throws {
        try ensureDirectoryExists()
        let url = baseDirectoryURL.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
    }

    private static func ensureDirectoryExists() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: baseDirectoryURL.path) {
            try fm.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        }
    }
}

enum ShutterMediaError: LocalizedError {
    case invalidImageData
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "照片数据无效，请重新拍摄。"
        case .fileWriteFailed:
            return "文件保存失败，请重试。"
        }
    }
}
