# Plan 2: Shutter System (Floating Button + Capture Panel + Persistence)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Shutter capture system — a floating action button (FAB) on home and timeline tabs, a bottom-sheet capture panel with text/photo/video options, long-press voice recording on the FAB, media file storage, and integration with ShutterRecordStoring so captured events appear on the timeline immediately.

**Architecture:** Create a `ShutterManager` (following `MoodRecordManager` pattern) that manages ShutterRecord CRUD through `ShutterRecordStoring`. Build a reusable `ShutterFloatingButton` overlay and a `ShutterPanel` bottom sheet. Use `UIImagePickerController` wrapped in `UIViewControllerRepresentable` for camera capture. Store media files in the app's Application Support directory via a new `ShutterMediaLibrary` utility. Integrate shutter records into the timeline merge pipeline in `TodayViewModel`.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, AVFoundation, UIKit (UIImagePickerController), XCTest

**Spec:** `docs/superpowers/specs/2026-03-25-auto-journal-evolution-design.md` — sections 4 (Shutter) and 3 (Data Models)

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `ToDay/Data/ShutterManager.swift` | CRUD + query for ShutterRecord, owns ShutterRecordStoring |
| `ToDay/Data/ShutterMediaLibrary.swift` | Save/load/delete media files (photos, videos, voice) in app sandbox |
| `ToDay/Features/Shutter/ShutterFloatingButton.swift` | Reusable FAB overlay view with tap + long-press gestures |
| `ToDay/Features/Shutter/ShutterPanel.swift` | Bottom sheet with text/photo/video capture options |
| `ToDay/Features/Shutter/ShutterTextComposer.swift` | Inline text input view within the panel |
| `ToDay/Features/Shutter/CameraPickerView.swift` | UIImagePickerController wrapper for photo/video capture |
| `ToDay/Features/Shutter/VoiceRecordingOverlay.swift` | Visual overlay shown during long-press voice recording |
| `ToDayTests/ShutterManagerTests.swift` | Tests for ShutterManager CRUD + query logic |
| `ToDayTests/ShutterMediaLibraryTests.swift` | Tests for media file save/delete operations |

### Modified Files

| File | Changes |
|------|---------|
| `ToDay/Features/Today/TodayViewModel.swift` | Add ShutterManager, merge shutter records into timeline |
| `ToDay/App/AppContainer.swift` | Inject ShutterRecordStoring into TodayViewModel |
| `ToDay/App/AppRootScreen.swift` | Overlay ShutterFloatingButton on home + timeline tabs |
| `ios/ToDay/project.yml` | Add NSCameraUsageDescription + NSMicrophoneUsageDescription Info.plist keys |

All paths are relative to `ios/ToDay/`.

---

## Task 1: ShutterMediaLibrary — Media File Storage

**Files:**
- Create: `ios/ToDay/ToDay/Data/ShutterMediaLibrary.swift`
- Create: `ios/ToDay/ToDayTests/ShutterMediaLibraryTests.swift`

- [ ] **Step 1: Write tests for ShutterMediaLibrary**

Create `ios/ToDay/ToDayTests/ShutterMediaLibraryTests.swift`:

```swift
import XCTest
@testable import ToDay

final class ShutterMediaLibraryTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        // Clean up test files
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
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/ShutterMediaLibraryTests 2>&1 | tail -20`

Expected: Compile error — `ShutterMediaLibrary` not defined

- [ ] **Step 3: Create ShutterMediaLibrary.swift**

Create `ios/ToDay/ToDay/Data/ShutterMediaLibrary.swift`:

```swift
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
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/ShutterMediaLibraryTests 2>&1 | tail -20`

Expected: All 5 tests PASS

- [ ] **Step 5: Run full test suite to check no regressions**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/ShutterMediaLibrary.swift ToDayTests/ShutterMediaLibraryTests.swift
git commit -m "feat: add ShutterMediaLibrary for photo/video/voice file storage"
```

---

## Task 2: ShutterManager — Business Logic Layer

**Files:**
- Create: `ios/ToDay/ToDay/Data/ShutterManager.swift`
- Create: `ios/ToDay/ToDayTests/ShutterManagerTests.swift`

- [ ] **Step 1: Write tests for ShutterManager**

Create `ios/ToDay/ToDayTests/ShutterManagerTests.swift`:

```swift
import SwiftData
import XCTest
@testable import ToDay

final class ShutterManagerTests: XCTestCase {
    func testSaveTextRecord() {
        let manager = makeManager()
        let record = ShutterRecord(type: .text, textContent: "突然想到一个好主意")

        manager.save(record)

        XCTAssertEqual(manager.records.count, 1)
        XCTAssertEqual(manager.records[0].textContent, "突然想到一个好主意")
        XCTAssertEqual(manager.records[0].type, .text)
    }

    func testSaveVoiceRecord() {
        let manager = makeManager()
        let record = ShutterRecord(
            type: .voice,
            mediaFilename: "voice_001.m4a",
            voiceTranscript: nil,
            duration: 5.2
        )

        manager.save(record)

        XCTAssertEqual(manager.records.count, 1)
        XCTAssertEqual(manager.records[0].type, .voice)
        XCTAssertEqual(manager.records[0].duration, 5.2, accuracy: 0.01)
    }

    func testRecordsForDateFiltersCorrectly() {
        let manager = makeManager()
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let todayRecord = ShutterRecord(createdAt: today, type: .text, textContent: "今天")
        let yesterdayRecord = ShutterRecord(createdAt: yesterday, type: .text, textContent: "昨天")

        manager.save(todayRecord)
        manager.save(yesterdayRecord)

        let todayRecords = manager.records(on: today)
        XCTAssertEqual(todayRecords.count, 1)
        XCTAssertEqual(todayRecords[0].textContent, "今天")
    }

    func testDeleteRecord() {
        let manager = makeManager()
        let record = ShutterRecord(type: .text, textContent: "要删除的")

        manager.save(record)
        XCTAssertEqual(manager.records.count, 1)

        manager.delete(id: record.id)
        XCTAssertEqual(manager.records.count, 0)
    }

    func testDeleteRecordCleansUpMediaFile() {
        let manager = makeManager()
        // Create a fake media file
        let filename = "test_delete_\(UUID().uuidString).jpg"
        let url = ShutterMediaLibrary.fileURL(for: filename)
        try? FileManager.default.createDirectory(
            at: ShutterMediaLibrary.baseDirectoryURL,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 0xFF, count: 64))

        let record = ShutterRecord(type: .photo, mediaFilename: filename)
        manager.save(record)
        manager.delete(id: record.id)

        XCTAssertFalse(ShutterMediaLibrary.fileExists(filename: filename))
    }

    func testRecordsReturnedNewestFirst() {
        let manager = makeManager()
        let earlier = ShutterRecord(
            createdAt: Date().addingTimeInterval(-3600),
            type: .text,
            textContent: "早"
        )
        let later = ShutterRecord(
            createdAt: Date(),
            type: .text,
            textContent: "晚"
        )

        manager.save(earlier)
        manager.save(later)

        XCTAssertEqual(manager.records[0].textContent, "晚")
        XCTAssertEqual(manager.records[1].textContent, "早")
    }

    func testReloadFromStore() {
        let store = makeStore()
        let manager = ShutterManager(recordStore: store)

        // Save directly to store, bypassing manager
        let record = ShutterRecord(type: .text, textContent: "外部保存")
        try? store.save(record)

        XCTAssertEqual(manager.records.count, 0)
        manager.reloadFromStore()
        XCTAssertEqual(manager.records.count, 1)
    }

    func testToInferredEventsConvertsAll() {
        let manager = makeManager()
        manager.save(ShutterRecord(type: .text, textContent: "文字"))
        manager.save(ShutterRecord(type: .photo, mediaFilename: "photo.jpg"))

        let events = manager.inferredEvents(on: Date())
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.allSatisfy { $0.kind == .shutter })
    }

    private func makeStore() -> SwiftDataShutterRecordStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: ShutterRecordEntity.self, configurations: config)
        return SwiftDataShutterRecordStore(container: container)
    }

    private func makeManager() -> ShutterManager {
        ShutterManager(recordStore: makeStore())
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/ShutterManagerTests 2>&1 | tail -20`

Expected: Compile error — `ShutterManager` not defined

- [ ] **Step 3: Create ShutterManager.swift**

Create `ios/ToDay/ToDay/Data/ShutterManager.swift`:

```swift
import Foundation

/// Manages CRUD and query for ShutterRecord.
/// Mirrors the MoodRecordManager pattern — owned by TodayViewModel, not an ObservableObject itself.
@MainActor
final class ShutterManager {
    private(set) var records: [ShutterRecord] = []

    private let recordStore: any ShutterRecordStoring
    private let calendar: Calendar

    init(recordStore: any ShutterRecordStoring, calendar: Calendar = .current) {
        self.recordStore = recordStore
        self.calendar = calendar
        reloadFromStore()
    }

    // MARK: - Queries

    func records(on date: Date) -> [ShutterRecord] {
        records
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func inferredEvents(on date: Date) -> [InferredEvent] {
        records(on: date).map { $0.toInferredEvent() }
    }

    // MARK: - Mutations

    func save(_ record: ShutterRecord) {
        try? recordStore.save(record)
        records.append(record)
        records.sort { $0.createdAt > $1.createdAt }
    }

    func delete(id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        let removed = records.remove(at: index)

        // Clean up media file if present
        if let filename = removed.mediaFilename {
            ShutterMediaLibrary.deleteFile(filename: filename)
        }

        try? recordStore.delete(id)
    }

    func reloadFromStore() {
        records = recordStore.loadAll()
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/ShutterManagerTests 2>&1 | tail -20`

Expected: All 8 tests PASS

- [ ] **Step 5: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/ShutterManager.swift ToDayTests/ShutterManagerTests.swift
git commit -m "feat: add ShutterManager for shutter record CRUD and timeline integration"
```

---

## Task 3: Integrate ShutterManager into TodayViewModel

**Files:**
- Modify: `ios/ToDay/ToDay/Features/Today/TodayViewModel.swift`
- Modify: `ios/ToDay/ToDay/App/AppContainer.swift`

- [ ] **Step 1: Add ShutterManager to TodayViewModel**

In `ios/ToDay/ToDay/Features/Today/TodayViewModel.swift`, add the ShutterManager as a dependency.

Find this block (around line 19-21):

```swift
    // MARK: - Managers

    private let recordManager: MoodRecordManager
    private let annotationStore: AnnotationStore
    private let insightComposer: TodayInsightComposer
```

Replace with:

```swift
    // MARK: - Managers

    private let recordManager: MoodRecordManager
    private let shutterManager: ShutterManager
    private let annotationStore: AnnotationStore
    private let insightComposer: TodayInsightComposer
```

- [ ] **Step 2: Update init to accept ShutterRecordStoring**

Find the init signature (around line 42-49):

```swift
    init(
        provider: any TimelineDataProviding,
        recordStore: any MoodRecordStoring,
        insightComposer: TodayInsightComposer = TodayInsightComposer(),
        phoneConnectivityManager: PhoneConnectivityManager? = nil,
        modelContainer: ModelContainer,
        calendar: Calendar = .current
    ) {
```

Replace with:

```swift
    init(
        provider: any TimelineDataProviding,
        recordStore: any MoodRecordStoring,
        shutterRecordStore: any ShutterRecordStoring = SwiftDataShutterRecordStore(container: AppContainer.modelContainer),
        insightComposer: TodayInsightComposer = TodayInsightComposer(),
        phoneConnectivityManager: PhoneConnectivityManager? = nil,
        modelContainer: ModelContainer,
        calendar: Calendar = .current
    ) {
```

Find this line inside the init body (around line 54):

```swift
        self.recordManager = MoodRecordManager(recordStore: recordStore, calendar: calendar)
```

Add after it:

```swift
        self.shutterManager = ShutterManager(recordStore: shutterRecordStore, calendar: calendar)
```

- [ ] **Step 3: Add shutter-related published state and methods**

Find this line (around line 16-17):

```swift
    @Published var showQuickRecord = false
    @Published private(set) var quickRecordMode: QuickRecordSheetMode = .flexible
```

Add after it:

```swift
    @Published var showShutterPanel = false
    @Published var isRecordingVoice = false
```

Add a new MARK section after the "Mood Records" section (after `removeMoodRecord` around line 128):

```swift
    // MARK: - Shutter Records

    var shutterRecords: [ShutterRecord] { shutterManager.records }

    func todayShutterCount(on date: Date? = nil) -> Int {
        shutterManager.records(on: date ?? timeline?.date ?? Date()).count
    }

    func saveShutterRecord(_ record: ShutterRecord) {
        shutterManager.save(record)
        showShutterPanel = false
        isRecordingVoice = false
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }

    func deleteShutterRecord(id: UUID) {
        shutterManager.delete(id: id)
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }
```

- [ ] **Step 4: Merge shutter events into the timeline**

Find the `mergedTimeline` method (around line 226). Locate the line that builds `manualEntries`:

```swift
        let manualEntries = recordsForDay.map { $0.toInferredEvent(referenceDate: Date(), calendar: calendar) }
```

Add after it:

```swift
        let shutterEntries = shutterManager.inferredEvents(on: base.date)
```

Find the line that combines all entries (around line 254):

```swift
        let entries = (manualEntries + syntheticEntries + annotatedBase).sorted { lhs, rhs in
```

Replace with:

```swift
        let entries = (manualEntries + shutterEntries + syntheticEntries + annotatedBase).sorted { lhs, rhs in
```

- [ ] **Step 5: Update load method to reload shutter data**

Find inside the `load(forceReload:)` method (around line 82-83):

```swift
        recordManager.reloadFromStore()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
```

Replace with:

```swift
        recordManager.reloadFromStore()
        shutterManager.reloadFromStore()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
```

Also find the `handleExternalRecordsUpdate` method (around line 367-369):

```swift
    private func handleExternalRecordsUpdate() {
        recordManager.reloadFromStore()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }
```

Replace with:

```swift
    private func handleExternalRecordsUpdate() {
        recordManager.reloadFromStore()
        shutterManager.reloadFromStore()
        rebuildTimeline(referenceDate: currentBaseTimeline?.date ?? Date())
    }
```

- [ ] **Step 6: Update AppContainer to pass shutterRecordStore**

In `ios/ToDay/ToDay/App/AppContainer.swift`, find the `makeTodayViewModel` method (around line 19-28):

```swift
    @MainActor
    static func makeTodayViewModel() -> TodayViewModel {
        let viewModel = TodayViewModel(
            provider: makeTimelineProvider(),
            recordStore: makeMoodRecordStore(),
            phoneConnectivityManager: phoneConnectivityManager,
            modelContainer: modelContainer
        )
```

Replace with:

```swift
    @MainActor
    static func makeTodayViewModel() -> TodayViewModel {
        let viewModel = TodayViewModel(
            provider: makeTimelineProvider(),
            recordStore: makeMoodRecordStore(),
            shutterRecordStore: makeShutterRecordStore(),
            phoneConnectivityManager: phoneConnectivityManager,
            modelContainer: modelContainer
        )
```

- [ ] **Step 7: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 8: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 9: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Today/TodayViewModel.swift ToDay/App/AppContainer.swift
git commit -m "feat: integrate ShutterManager into TodayViewModel and timeline merge"
```

---

## Task 4: Camera/Microphone Permissions in project.yml

**Files:**
- Modify: `ios/ToDay/project.yml`

- [ ] **Step 1: Add NSCameraUsageDescription and NSMicrophoneUsageDescription**

In `ios/ToDay/project.yml`, find the ToDay target settings section (around line 41-43):

```yaml
        INFOPLIST_KEY_NSHealthShareUsageDescription: ToDay 读取你的运动、心率和睡眠数据，用来生成每日生活画卷。所有数据仅存储在本地。
        INFOPLIST_KEY_NSLocationWhenInUseUsageDescription: ToDay 记录你到访过的地点，让画卷上的事件有地理上下文。位置数据仅存储在本地。
        INFOPLIST_KEY_NSPhotoLibraryUsageDescription: ToDay 读取你当天拍摄的照片，将它们匹配到画卷中对应的事件。照片不会上传。
```

Add after the last line:

```yaml
        INFOPLIST_KEY_NSCameraUsageDescription: ToDay 使用相机拍摄照片和视频，快速记录生活碎片。媒体文件仅存储在本地。
        INFOPLIST_KEY_NSMicrophoneUsageDescription: ToDay 使用麦克风录制语音备忘，帮你用最少的操作捕捉灵感。录音仅存储在本地。
```

- [ ] **Step 2: Regenerate project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add project.yml
git commit -m "feat: add camera and microphone usage descriptions for shutter capture"
```

---

## Task 5: CameraPickerView — UIImagePickerController Wrapper

**Files:**
- Create: `ios/ToDay/ToDay/Features/Shutter/CameraPickerView.swift`

- [ ] **Step 1: Create CameraPickerView.swift**

Create directory `ios/ToDay/ToDay/Features/Shutter/` and file `CameraPickerView.swift`:

```swift
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
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Shutter/CameraPickerView.swift
git commit -m "feat: add CameraPickerView UIImagePickerController wrapper for photo/video"
```

---

## Task 6: ShutterTextComposer — Text Input View

**Files:**
- Create: `ios/ToDay/ToDay/Features/Shutter/ShutterTextComposer.swift`

- [ ] **Step 1: Create ShutterTextComposer.swift**

Create `ios/ToDay/ToDay/Features/Shutter/ShutterTextComposer.swift`:

```swift
import SwiftUI

struct ShutterTextComposer: View {
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    let onSend: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("写下此刻的想法…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .padding(14)
                    .background(TodayTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(TodayTheme.border, lineWidth: 1)
                    )

                Button {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSend(trimmed)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? TodayTheme.inkFaint
                                : TodayTheme.accent
                        )
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            isFocused = true
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Shutter/ShutterTextComposer.swift
git commit -m "feat: add ShutterTextComposer for quick text capture"
```

---

## Task 7: VoiceRecordingOverlay — Long-Press Voice Capture

**Files:**
- Create: `ios/ToDay/ToDay/Features/Shutter/VoiceRecordingOverlay.swift`

- [ ] **Step 1: Create VoiceRecordingOverlay.swift**

Create `ios/ToDay/ToDay/Features/Shutter/VoiceRecordingOverlay.swift`:

```swift
import AVFoundation
import SwiftUI

struct VoiceRecordingOverlay: View {
    @StateObject private var recorder = VoiceRecorder()
    let onFinish: (Data, TimeInterval) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundStyle(TodayTheme.accent)
                    .symbolEffect(.variableColor.iterative, isActive: recorder.isRecording)

                Text(recorder.isRecording ? "正在录音…" : "准备中…")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TodayTheme.ink)

                Text(formattedDuration)
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .foregroundStyle(TodayTheme.inkSoft)

                Text("松手结束录音")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(TodayTheme.elevatedCard)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: TodayTheme.ink.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
        .onAppear {
            recorder.startRecording()
        }
        .onDisappear {
            if recorder.isRecording {
                recorder.stopRecording()
            }
            if let data = recorder.recordedData, recorder.duration > 0.5 {
                onFinish(data, recorder.duration)
            } else {
                onCancel()
            }
        }
    }

    private var formattedDuration: String {
        let seconds = Int(recorder.duration)
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var duration: TimeInterval = 0
    private(set) var recordedData: Data?

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    private var tempFileURL: URL?

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shutter_voice_\(UUID().uuidString).m4a")
        tempFileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            startTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let startTime = self.startTime else { return }
                    self.duration = Date().timeIntervalSince(startTime)
                }
            }
        } catch {
            // Recording failed silently — user will see no waveform
        }
    }

    func stopRecording() {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        isRecording = false

        if let startTime {
            duration = Date().timeIntervalSince(startTime)
        }

        if let url = tempFileURL {
            recordedData = try? Data(contentsOf: url)
            // Clean up temp file
            try? FileManager.default.removeItem(at: url)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Shutter/VoiceRecordingOverlay.swift
git commit -m "feat: add VoiceRecordingOverlay with AVAudioRecorder for voice capture"
```

---

## Task 8: ShutterPanel — Bottom Sheet with Capture Options

**Files:**
- Create: `ios/ToDay/ToDay/Features/Shutter/ShutterPanel.swift`

- [ ] **Step 1: Create ShutterPanel.swift**

Create `ios/ToDay/ToDay/Features/Shutter/ShutterPanel.swift`:

```swift
import SwiftUI

enum ShutterPanelMode: Equatable {
    case menu
    case text
    case camera(CameraPickerMode)
}

struct ShutterPanel: View {
    @ObservedObject var viewModel: TodayViewModel
    @State private var mode: ShutterPanelMode = .menu
    @State private var showCameraUnavailableAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .menu:
                    menuView
                case .text:
                    textView
                case .camera(let cameraMode):
                    cameraView(mode: cameraMode)
                }
            }
            .background(TodayTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if mode == .menu {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = .menu
                            }
                        }
                    } label: {
                        Image(systemName: mode == .menu ? "xmark" : "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TodayTheme.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(TodayTheme.card)
                            .clipShape(Circle())
                    }
                }
            }
            .alert("相机不可用", isPresented: $showCameraUnavailableAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("当前设备没有可用的相机，请在真机上使用此功能。")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Menu View

    private var menuView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("快门")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text("捕捉此刻的灵光一现，不用分类、不用打标签。")
                    .font(.system(size: 14))
                    .foregroundStyle(TodayTheme.inkMuted)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            VStack(spacing: 10) {
                shutterOption(
                    icon: "text.cursor",
                    title: "文字",
                    subtitle: "写下脑海里的念头",
                    tint: TodayTheme.accent
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .text
                    }
                }

                shutterOption(
                    icon: "camera.fill",
                    title: "拍照",
                    subtitle: "用镜头记住这一刻",
                    tint: TodayTheme.teal
                ) {
                    #if targetEnvironment(simulator)
                    showCameraUnavailableAlert = true
                    #else
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .camera(.photo)
                    }
                    #endif
                }

                shutterOption(
                    icon: "video.fill",
                    title: "视频",
                    subtitle: "录一段 15 秒短片",
                    tint: TodayTheme.rose
                ) {
                    #if targetEnvironment(simulator)
                    showCameraUnavailableAlert = true
                    #else
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .camera(.video)
                    }
                    #endif
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func shutterOption(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TodayTheme.ink)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(TodayTheme.inkMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TodayTheme.inkFaint)
            }
            .padding(14)
            .background(TodayTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(TodayTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text View

    private var textView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("文字快门")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(TodayTheme.ink)

                Text("写完按发送，会自动出现在时间线上。")
                    .font(.system(size: 13))
                    .foregroundStyle(TodayTheme.inkMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            ShutterTextComposer { text in
                let record = ShutterRecord(type: .text, textContent: text)
                viewModel.saveShutterRecord(record)
                dismiss()
            } onCancel: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = .menu
                }
            }
        }
    }

    // MARK: - Camera View

    private func cameraView(mode: CameraPickerMode) -> some View {
        CameraPickerView(mode: mode) { result in
            handleCameraResult(result)
        } onCancel: {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.mode = .menu
            }
        }
        .ignoresSafeArea()
    }

    private func handleCameraResult(_ result: CameraCaptureResult) {
        switch result {
        case .photo(let data):
            do {
                let filename = try ShutterMediaLibrary.storePhoto(data)
                let record = ShutterRecord(type: .photo, mediaFilename: filename)
                viewModel.saveShutterRecord(record)
                dismiss()
            } catch {
                // Silently fail — user can retry
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = .menu
                }
            }
        case .video(let url):
            do {
                let filename = try ShutterMediaLibrary.copyVideoFile(from: url)
                // Get video duration
                let asset = AVURLAsset(url: url)
                let duration = CMTimeGetSeconds(asset.duration)
                let record = ShutterRecord(
                    type: .video,
                    mediaFilename: filename,
                    duration: duration.isFinite ? duration : nil
                )
                viewModel.saveShutterRecord(record)
                dismiss()
            } catch {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = .menu
                }
            }
        }
    }
}
```

**Note:** Add `import AVFoundation` at the top of the file for `AVURLAsset` / `CMTimeGetSeconds`.

Replace the import section at the top with:

```swift
import AVFoundation
import SwiftUI
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Shutter/ShutterPanel.swift
git commit -m "feat: add ShutterPanel bottom sheet with text, photo, and video capture"
```

---

## Task 9: ShutterFloatingButton — FAB Overlay

**Files:**
- Create: `ios/ToDay/ToDay/Features/Shutter/ShutterFloatingButton.swift`

- [ ] **Step 1: Create ShutterFloatingButton.swift**

Create `ios/ToDay/ToDay/Features/Shutter/ShutterFloatingButton.swift`:

```swift
import SwiftUI

struct ShutterFloatingButton: View {
    @ObservedObject var viewModel: TodayViewModel
    @State private var isLongPressing = false
    @State private var longPressStarted = false

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                shutterButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 12)
            }
        }
    }

    private var shutterButton: some View {
        Button {
            // Single tap — open shutter panel
            if !longPressStarted {
                viewModel.showShutterPanel = true
            }
            longPressStarted = false
        } label: {
            Image(systemName: "camera.aperture")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            isLongPressing
                                ? TodayTheme.rose
                                : TodayTheme.accent
                        )
                )
                .shadow(color: TodayTheme.accent.opacity(0.35), radius: 12, x: 0, y: 6)
                .scaleEffect(isLongPressing ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isLongPressing)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    longPressStarted = true
                    isLongPressing = true
                    viewModel.isRecordingVoice = true
                }
        )
        .accessibilityLabel("快门")
        .accessibilityHint("单击打开快门面板，长按录制语音")
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Shutter/ShutterFloatingButton.swift
git commit -m "feat: add ShutterFloatingButton FAB with tap and long-press gestures"
```

---

## Task 10: Wire FAB + Panel into AppRootScreen

**Files:**
- Modify: `ios/ToDay/ToDay/App/AppRootScreen.swift`

- [ ] **Step 1: Add floating button overlay and sheet bindings**

Replace the entire content of `ios/ToDay/ToDay/App/AppRootScreen.swift` with:

```swift
import SwiftUI

private enum AppTab: Hashable {
    case home
    case timeline
    case echo
    case settings
}

struct AppRootScreen: View {
    @AppStorage("today.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @ObservedObject var todayViewModel: TodayViewModel
    @State private var selectedTab: AppTab = .home

    private var showFloatingButton: Bool {
        selectedTab == .home || selectedTab == .timeline
    }

    var body: some View {
        if hasCompletedOnboarding {
            ZStack {
                TabView(selection: $selectedTab) {
                    TodayScreen(
                        viewModel: todayViewModel,
                        onOpenHistory: { selectedTab = .timeline }
                    )
                    .tabItem {
                        Label("首页", systemImage: "square.grid.2x2.fill")
                    }
                    .tag(AppTab.home)

                    HistoryScreen(viewModel: todayViewModel)
                    .tabItem {
                        Label("时间线", systemImage: "clock.fill")
                    }
                    .tag(AppTab.timeline)

                    EchoScreen()
                    .tabItem {
                        Label("Echo", systemImage: "bell.badge.fill")
                    }
                    .tag(AppTab.echo)

                    SettingsView()
                        .tabItem {
                            Label("设置", systemImage: "gear")
                        }
                        .tag(AppTab.settings)
                }
                .tint(TodayTheme.teal)

                if showFloatingButton {
                    ShutterFloatingButton(viewModel: todayViewModel)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .sheet(isPresented: $todayViewModel.showShutterPanel) {
                ShutterPanel(viewModel: todayViewModel)
            }
            .fullScreenCover(isPresented: $todayViewModel.isRecordingVoice) {
                VoiceRecordingOverlay { data, duration in
                    do {
                        let filename = try ShutterMediaLibrary.storeVoice(data)
                        let record = ShutterRecord(
                            type: .voice,
                            mediaFilename: filename,
                            voiceTranscript: nil, // STT deferred to future plan
                            duration: duration
                        )
                        todayViewModel.saveShutterRecord(record)
                    } catch {
                        // Voice save failed — silently dismiss
                    }
                } onCancel: {
                    todayViewModel.isRecordingVoice = false
                }
            }
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
cd ios/ToDay && git add ToDay/App/AppRootScreen.swift
git commit -m "feat: wire ShutterFloatingButton and ShutterPanel into AppRootScreen"
```

---

## Task 11: Update TodayScreen Overview Stats with Shutter Count

**Files:**
- Modify: `ios/ToDay/ToDay/Features/Today/TodayScreen.swift`

- [ ] **Step 1: Add shutter count to overview stats**

In `ios/ToDay/ToDay/Features/Today/TodayScreen.swift`, find the `overviewStats` computed property (around line 490):

```swift
    private var overviewStats: [OverviewStat] {
        let entryCount = viewModel.timeline?.entries.count ?? 0
        let sourceText = viewModel.timeline?.source.badgeTitle ?? "本地"

        return [
            OverviewStat(label: "片段", value: "\(entryCount)", tint: TodayTheme.blue, background: TodayTheme.blueSoft),
            OverviewStat(label: "记录", value: "\(viewModel.todayManualRecordCount)", tint: TodayTheme.teal, background: TodayTheme.tealSoft),
            OverviewStat(label: "备注", value: "\(viewModel.todayNoteCount)", tint: TodayTheme.rose, background: TodayTheme.roseSoft),
            OverviewStat(label: "来源", value: sourceText, tint: TodayTheme.accent, background: TodayTheme.accentSoft)
        ]
    }
```

Replace with:

```swift
    private var overviewStats: [OverviewStat] {
        let entryCount = viewModel.timeline?.entries.count ?? 0
        let sourceText = viewModel.timeline?.source.badgeTitle ?? "本地"
        let shutterCount = viewModel.todayShutterCount()

        return [
            OverviewStat(label: "片段", value: "\(entryCount)", tint: TodayTheme.blue, background: TodayTheme.blueSoft),
            OverviewStat(label: "记录", value: "\(viewModel.todayManualRecordCount)", tint: TodayTheme.teal, background: TodayTheme.tealSoft),
            OverviewStat(label: "快门", value: "\(shutterCount)", tint: TodayTheme.scrollGold, background: TodayTheme.scrollGold.opacity(0.12)),
            OverviewStat(label: "来源", value: sourceText, tint: TodayTheme.accent, background: TodayTheme.accentSoft)
        ]
    }
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Today/TodayScreen.swift
git commit -m "feat: show shutter count in TodayScreen overview stats"
```

---

## Task 12: Update Preview + Final Verification

**Files:**
- Modify: `ios/ToDay/ToDay/Features/Today/TodayScreen.swift` (preview at bottom)

- [ ] **Step 1: Update TodayScreen preview to include shutter entities**

In `ios/ToDay/ToDay/Features/Today/TodayScreen.swift`, find the preview container at the bottom (around line 530-534):

```swift
@MainActor
private let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(for: MoodRecordEntity.self, DayTimelineEntity.self, configurations: configuration)
}()
```

Replace with:

```swift
@MainActor
private let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(
        for: MoodRecordEntity.self,
        DayTimelineEntity.self,
        ShutterRecordEntity.self,
        SpendingRecordEntity.self,
        configurations: configuration
    )
}()
```

- [ ] **Step 2: Build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite — final check**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass (existing + all new from this plan)

- [ ] **Step 4: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Today/TodayScreen.swift
git commit -m "chore: update preview container to include Shutter and Spending entities"
```

---

## Summary

After completing all 12 tasks, the codebase will have:

- **ShutterMediaLibrary**: Local file storage for photos, videos, and voice recordings in app sandbox
- **ShutterManager**: CRUD + query layer for ShutterRecord, with media file cleanup on delete
- **ShutterFloatingButton**: Reusable FAB overlay on home + timeline tabs, with single-tap and long-press gestures
- **ShutterPanel**: Bottom sheet with 3 capture modes (text, photo, video)
- **ShutterTextComposer**: Inline keyboard text input with send button
- **VoiceRecordingOverlay**: Full-screen overlay for long-press voice recording with AVAudioRecorder
- **CameraPickerView**: UIImagePickerController wrapper for photo/video capture (15 sec video limit)
- **Timeline integration**: Shutter events appear immediately on the timeline after recording
- **Overview stats**: Shutter count shown on home screen
- **Camera + Microphone permissions**: Info.plist usage descriptions
- **2 new test files**: 13+ tests covering ShutterManager and ShutterMediaLibrary

**Not included (deferred):**
- Voice-to-text transcription (voiceTranscript is saved as `nil`; STT is future work)
- Echo configuration UI (Plan 4)
- Cloud sync
