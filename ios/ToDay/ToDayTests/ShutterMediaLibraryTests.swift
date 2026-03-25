import XCTest
@testable import ToDay

final class ShutterMediaLibraryTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        let fm = FileManager.default
        let testDir = ShutterMediaLibrary.baseDirectoryURL
        if fm.fileExists(atPath: testDir.path) {
            try? fm.removeItem(at: testDir)
        }
    }

    func testStorePhotoReturnsFilename() throws {
        let image = makeTestImage()
        let data = image.jpegData(compressionQuality: 0.8)!
        let filename = try ShutterMediaLibrary.storePhoto(data)

        XCTAssertTrue(filename.hasSuffix(".jpg"))
        XCTAssertTrue(ShutterMediaLibrary.fileExists(filename: filename))
    }

    func testStoreAndRetrievePhoto() throws {
        let image = makeTestImage()
        let data = image.jpegData(compressionQuality: 0.8)!
        let filename = try ShutterMediaLibrary.storePhoto(data)

        let url = ShutterMediaLibrary.fileURL(for: filename)
        XCTAssertNotNil(url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testDeleteFile() throws {
        let image = makeTestImage()
        let data = image.jpegData(compressionQuality: 0.8)!
        let filename = try ShutterMediaLibrary.storePhoto(data)

        ShutterMediaLibrary.deleteFile(filename: filename)
        XCTAssertFalse(ShutterMediaLibrary.fileExists(filename: filename))
    }

    func testStoreVoiceData() throws {
        let fakeAudioData = Data(repeating: 0xAB, count: 1024)
        let filename = try ShutterMediaLibrary.storeVoice(fakeAudioData)

        XCTAssertTrue(filename.hasSuffix(".m4a"))
        XCTAssertTrue(ShutterMediaLibrary.fileExists(filename: filename))
    }

    func testStoreVideoData() throws {
        let fakeVideoData = Data(repeating: 0xCD, count: 2048)
        let filename = try ShutterMediaLibrary.storeVideo(fakeVideoData)

        XCTAssertTrue(filename.hasSuffix(".mov"))
        XCTAssertTrue(ShutterMediaLibrary.fileExists(filename: filename))
    }

    private func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }
}
