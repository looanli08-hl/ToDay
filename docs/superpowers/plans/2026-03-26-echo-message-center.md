# Plan: Echo Message Center

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Echo tab from a single chat page into a **message center** — Echo proactively sends messages (daily insights, shutter echoes, emotion care, etc.) that appear as a list. Each message opens an independent conversation thread with source-specific AI context.

**Architecture:** Add `EchoMessageEntity` SwiftData model + `EchoMessageStoring` protocol (following `EchoItemEntity`/`EchoItemStoring` patterns). Create `EchoMessageManager` for CRUD + unread tracking. Build `EchoMessageListView` as the new Echo tab root, `EchoMessageCard` for list items, and `EchoThreadView`/`EchoThreadViewModel` for per-thread conversations. Update `EchoScheduler` to produce messages. Wire unread badge on tab.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest

**Spec:** `docs/superpowers/specs/2026-03-26-echo-message-center-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `ToDay/Shared/EchoMessage.swift` | `EchoMessageType` enum, `EchoSourceData` struct, `EchoSourceType` enum |
| `ToDay/Data/EchoMessageEntity.swift` | SwiftData entity for message list items |
| `ToDay/Data/EchoMessageStoring.swift` | `EchoMessageStoring` protocol + `SwiftDataEchoMessageStore` |
| `ToDay/Data/AI/EchoMessageManager.swift` | Message CRUD, unread count, message generation |
| `ToDay/Features/Echo/EchoMessageListView.swift` | New Echo tab root — message list UI |
| `ToDay/Features/Echo/EchoMessageCard.swift` | Reusable card component for one message |
| `ToDay/Features/Echo/EchoThreadView.swift` | Conversation detail page (per-thread) |
| `ToDay/Features/Echo/EchoThreadViewModel.swift` | Per-thread ViewModel managing one conversation |
| `ToDayTests/EchoMessageStoreTests.swift` | Tests for EchoMessage persistence |
| `ToDayTests/EchoMessageManagerTests.swift` | Tests for EchoMessageManager logic |

### Modified Files

| File | Changes |
|------|---------|
| `ToDay/Data/AI/EchoPromptBuilder.swift` | Add `buildThreadMessages()` method with source-data context |
| `ToDay/Data/AI/EchoScheduler.swift` | Generate `EchoMessage` entries alongside daily summary / profile / emotion triggers |
| `ToDay/App/AppContainer.swift` | Register `EchoMessageEntity` in ModelContainer, create `EchoMessageManager` singleton, add factory methods |
| `ToDay/App/AppRootScreen.swift` | Replace `EchoChatScreen` with `EchoMessageListView`, add unread badge on Echo tab |
| `ToDay/App/ToDayApp.swift` | Add `EchoMessageManager` StateObject, pass to `AppRootScreen` |

All paths are relative to `ios/ToDay/`.

---

## Task 1: EchoMessage Data Model

**Files:**
- Create: `ios/ToDay/ToDay/Shared/EchoMessage.swift`

- [ ] **Step 1: Create EchoMessage.swift with type enum and source data struct**

Create `ios/ToDay/ToDay/Shared/EchoMessage.swift`:

```swift
import Foundation

// MARK: - Message Type

enum EchoMessageType: String, Codable, CaseIterable, Sendable {
    case dailyInsight   // 每日洞察
    case shutterEcho    // 快门回响
    case thoughtOrg     // 想法整理
    case emotionCare    // 情绪关怀
    case todoReminder   // 待办提醒
    case mirrorUpdate   // 镜子更新
    case freeChat       // 自由对话

    var icon: String {
        switch self {
        case .dailyInsight:  return "🌿"
        case .shutterEcho:   return "🌟"
        case .thoughtOrg:    return "💭"
        case .emotionCare:   return "🤗"
        case .todoReminder:  return "⏰"
        case .mirrorUpdate:  return "🪞"
        case .freeChat:      return "✨"
        }
    }

    var defaultTitle: String {
        switch self {
        case .dailyInsight:  return "今日洞察"
        case .shutterEcho:   return "快门回响"
        case .thoughtOrg:    return "想法整理"
        case .emotionCare:   return "Echo 想跟你说"
        case .todoReminder:  return "待办提醒"
        case .mirrorUpdate:  return "我对你有了新的了解"
        case .freeChat:      return "随便聊聊"
        }
    }
}

// MARK: - Source Type

enum EchoSourceType: String, Codable, Sendable {
    case shutterRecord   // 关联快门记录
    case dateRange       // 关联时间段
    case moodTrend       // 近期心情趋势
    case userProfile     // 用户画像
    case todayData       // 今日数据
}

// MARK: - Source Data

struct EchoSourceData: Codable, Hashable, Sendable {
    let type: EchoSourceType
    let shutterRecordIDs: [UUID]?
    let dateRangeStart: Date?
    let dateRangeEnd: Date?
    let sourceDescription: String

    init(
        type: EchoSourceType,
        shutterRecordIDs: [UUID]? = nil,
        dateRangeStart: Date? = nil,
        dateRangeEnd: Date? = nil,
        sourceDescription: String
    ) {
        self.type = type
        self.shutterRecordIDs = shutterRecordIDs
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.sourceDescription = sourceDescription
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Shared/EchoMessage.swift
git commit -m "feat: add EchoMessageType, EchoSourceType, EchoSourceData models"
```

---

## Task 2: EchoMessageEntity SwiftData + Store

**Files:**
- Create: `ios/ToDay/ToDay/Data/EchoMessageEntity.swift`
- Create: `ios/ToDay/ToDay/Data/EchoMessageStoring.swift`
- Create: `ios/ToDay/ToDayTests/EchoMessageStoreTests.swift`

- [ ] **Step 1: Write tests for EchoMessage persistence**

Create `ios/ToDay/ToDayTests/EchoMessageStoreTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ToDay

final class EchoMessageStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataEchoMessageStore!

    @MainActor
    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: EchoMessageEntity.self,
            EchoChatSessionEntity.self,
            EchoChatMessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = SwiftDataEchoMessageStore(container: container)
    }

    override func tearDown() {
        container = nil
        store = nil
        super.tearDown()
    }

    func testSaveAndLoadMessage() throws {
        let sourceData = EchoSourceData(
            type: .todayData,
            sourceDescription: "今日数据"
        )
        let sourceJSON = try JSONEncoder().encode(sourceData)

        let entity = EchoMessageEntity(
            type: EchoMessageType.dailyInsight.rawValue,
            title: "今日洞察",
            preview: "今天运动了 45 分钟",
            sourceDescription: "来自：今日数据",
            sourceDataJSON: sourceJSON,
            isRead: false,
            threadId: UUID()
        )

        try store.save(entity)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "今日洞察")
        XCTAssertEqual(loaded.first?.isRead, false)
    }

    func testUnreadCount() throws {
        let threadId1 = UUID()
        let threadId2 = UUID()

        let msg1 = EchoMessageEntity(
            type: EchoMessageType.dailyInsight.rawValue,
            title: "洞察 1",
            preview: "预览 1",
            sourceDescription: "来自：今日数据",
            isRead: false,
            threadId: threadId1
        )
        let msg2 = EchoMessageEntity(
            type: EchoMessageType.shutterEcho.rawValue,
            title: "快门回响",
            preview: "预览 2",
            sourceDescription: "来自：3月23日快门",
            isRead: true,
            threadId: threadId2
        )

        try store.save(msg1)
        try store.save(msg2)

        XCTAssertEqual(store.unreadCount(), 1)
    }

    func testMarkAsRead() throws {
        let entity = EchoMessageEntity(
            type: EchoMessageType.emotionCare.rawValue,
            title: "情绪关怀",
            preview: "最近有点累",
            sourceDescription: "来自：近期心情趋势",
            isRead: false,
            threadId: UUID()
        )
        try store.save(entity)

        try store.markAsRead(id: entity.id)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.first?.isRead, true)
        XCTAssertEqual(store.unreadCount(), 0)
    }

    func testDeleteMessage() throws {
        let entity = EchoMessageEntity(
            type: EchoMessageType.freeChat.rawValue,
            title: "随便聊聊",
            preview: "",
            sourceDescription: "",
            isRead: false,
            threadId: UUID()
        )
        try store.save(entity)
        XCTAssertEqual(store.loadAll().count, 1)

        try store.delete(id: entity.id)
        XCTAssertEqual(store.loadAll().count, 0)
    }

    func testLoadAllSortedByCreatedAtDescending() throws {
        let older = EchoMessageEntity(
            type: EchoMessageType.dailyInsight.rawValue,
            title: "旧消息",
            preview: "",
            sourceDescription: "",
            isRead: false,
            threadId: UUID(),
            createdAt: Date().addingTimeInterval(-3600)
        )
        let newer = EchoMessageEntity(
            type: EchoMessageType.shutterEcho.rawValue,
            title: "新消息",
            preview: "",
            sourceDescription: "",
            isRead: false,
            threadId: UUID(),
            createdAt: Date()
        )

        try store.save(older)
        try store.save(newer)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.title, "新消息")
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoMessageStoreTests 2>&1 | tail -20`

Expected: Compile error — `EchoMessageEntity` and `SwiftDataEchoMessageStore` do not exist

- [ ] **Step 3: Create EchoMessageEntity.swift**

Create `ios/ToDay/ToDay/Data/EchoMessageEntity.swift`:

```swift
import Foundation
import SwiftData

@Model
final class EchoMessageEntity {
    @Attribute(.unique) var id: UUID
    /// Raw value of EchoMessageType
    var type: String
    /// Message title
    var title: String
    /// Content preview (first ~2 lines)
    var preview: String
    /// Human-readable source label, e.g. "来自：今日数据"
    var sourceDescription: String
    /// JSON-encoded EchoSourceData for passing to AI context
    var sourceDataJSON: Data?
    /// When this message was created
    var createdAt: Date
    /// Whether the user has opened this message
    var isRead: Bool
    /// ID of the associated EchoChatSessionEntity for the conversation thread
    var threadId: UUID

    init(
        id: UUID = UUID(),
        type: String,
        title: String,
        preview: String,
        sourceDescription: String,
        sourceDataJSON: Data? = nil,
        isRead: Bool = false,
        threadId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.preview = preview
        self.sourceDescription = sourceDescription
        self.sourceDataJSON = sourceDataJSON
        self.isRead = isRead
        self.threadId = threadId
        self.createdAt = createdAt
    }

    // MARK: - Convenience

    /// Decoded message type enum.
    var messageType: EchoMessageType {
        EchoMessageType(rawValue: type) ?? .freeChat
    }

    /// Decoded source data (nil if sourceDataJSON is nil or corrupt).
    var sourceData: EchoSourceData? {
        guard let data = sourceDataJSON else { return nil }
        return try? JSONDecoder().decode(EchoSourceData.self, from: data)
    }
}
```

- [ ] **Step 4: Create EchoMessageStoring.swift**

Create `ios/ToDay/ToDay/Data/EchoMessageStoring.swift`:

```swift
import Foundation
import SwiftData

protocol EchoMessageStoring {
    func loadAll() -> [EchoMessageEntity]
    func unreadCount() -> Int
    func markAsRead(id: UUID) throws
    func save(_ entity: EchoMessageEntity) throws
    func delete(id: UUID) throws
}

struct SwiftDataEchoMessageStore: EchoMessageStoring {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() -> [EchoMessageEntity] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoMessageEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities
    }

    func unreadCount() -> Int {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoMessageEntity>(
            predicate: #Predicate { $0.isRead == false }
        )
        descriptor.includePendingChanges = false

        guard let entities = try? context.fetch(descriptor) else {
            return 0
        }
        return entities.count
    }

    func markAsRead(id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoMessageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        guard let entity = try context.fetch(descriptor).first else { return }
        entity.isRead = true
        if context.hasChanges {
            try context.save()
        }
    }

    func save(_ entity: EchoMessageEntity) throws {
        let context = ModelContext(container)
        let entityId = entity.id
        var descriptor = FetchDescriptor<EchoMessageEntity>(
            predicate: #Predicate { $0.id == entityId }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.type = entity.type
            existing.title = entity.title
            existing.preview = entity.preview
            existing.sourceDescription = entity.sourceDescription
            existing.sourceDataJSON = entity.sourceDataJSON
            existing.isRead = entity.isRead
            existing.threadId = entity.threadId
        } else {
            context.insert(entity)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func delete(id: UUID) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<EchoMessageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let entity = try context.fetch(descriptor).first {
            context.delete(entity)
            try context.save()
        }
    }
}
```

- [ ] **Step 5: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoMessageStoreTests 2>&1 | tail -20`

Expected: All 5 tests PASS

- [ ] **Step 6: Run full test suite to check no regressions**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All 154+ tests still pass

- [ ] **Step 7: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/EchoMessageEntity.swift ToDay/Data/EchoMessageStoring.swift ToDayTests/EchoMessageStoreTests.swift
git commit -m "feat: add EchoMessageEntity SwiftData model and store with tests"
```

---

## Task 3: EchoMessageManager

**Files:**
- Create: `ios/ToDay/ToDay/Data/AI/EchoMessageManager.swift`
- Create: `ios/ToDay/ToDayTests/EchoMessageManagerTests.swift`

- [ ] **Step 1: Write tests for EchoMessageManager**

Create `ios/ToDay/ToDayTests/EchoMessageManagerTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ToDay

@MainActor
final class EchoMessageManagerTests: XCTestCase {
    private var container: ModelContainer!
    private var manager: EchoMessageManager!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: EchoMessageEntity.self,
            EchoChatSessionEntity.self,
            EchoChatMessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = SwiftDataEchoMessageStore(container: container)
        manager = EchoMessageManager(store: store, container: container)
    }

    override func tearDown() {
        container = nil
        manager = nil
        super.tearDown()
    }

    func testGenerateMessageCreatesEntityAndThread() throws {
        let sourceData = EchoSourceData(
            type: .todayData,
            sourceDescription: "今日数据"
        )

        let message = try manager.generateMessage(
            type: .dailyInsight,
            title: "今日洞察",
            preview: "今天运动了 45 分钟，比昨天多",
            sourceDescription: "来自：今日数据",
            sourceData: sourceData,
            initialEchoMessage: "今天运动了 45 分钟，比昨天多了不少，身体在回应你的坚持呢。"
        )

        XCTAssertEqual(message.messageType, .dailyInsight)
        XCTAssertEqual(message.isRead, false)
        XCTAssertEqual(manager.unreadCount, 1)

        // Verify thread was created with initial Echo message
        let context = ModelContext(container)
        let threadId = message.threadId
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == threadId }
        )
        descriptor.fetchLimit = 1
        let session = try context.fetch(descriptor).first
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.messages.count, 1)
        XCTAssertEqual(session?.messages.first?.role, EchoChatRole.assistant.rawValue)
    }

    func testMarkAsReadUpdatesUnreadCount() throws {
        let msg = try manager.generateMessage(
            type: .shutterEcho,
            title: "快门回响",
            preview: "你 3 天前提到的创意",
            sourceDescription: "来自：3月23日快门",
            sourceData: nil,
            initialEchoMessage: "你 3 天前提到了一个创意，想聊聊后续吗？"
        )
        XCTAssertEqual(manager.unreadCount, 1)

        try manager.markAsRead(id: msg.id)
        XCTAssertEqual(manager.unreadCount, 0)
    }

    func testLoadAllReturnsMessages() throws {
        _ = try manager.generateMessage(
            type: .dailyInsight,
            title: "洞察 1",
            preview: "预览 1",
            sourceDescription: "来源 1",
            sourceData: nil,
            initialEchoMessage: "内容 1"
        )
        _ = try manager.generateMessage(
            type: .emotionCare,
            title: "关怀",
            preview: "预览 2",
            sourceDescription: "来源 2",
            sourceData: nil,
            initialEchoMessage: "内容 2"
        )

        XCTAssertEqual(manager.allMessages.count, 2)
    }

    func testCreateFreeChatMessage() throws {
        let msg = try manager.createFreeChatMessage()
        XCTAssertEqual(msg.messageType, .freeChat)
        XCTAssertEqual(msg.title, "随便聊聊")
        XCTAssertEqual(msg.isRead, true) // freeChat is immediately "read"
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoMessageManagerTests 2>&1 | tail -20`

Expected: Compile error — `EchoMessageManager` does not exist

- [ ] **Step 3: Create EchoMessageManager.swift**

Create `ios/ToDay/ToDay/Data/AI/EchoMessageManager.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class EchoMessageManager: ObservableObject {
    // MARK: - Published State

    @Published private(set) var allMessages: [EchoMessageEntity] = []
    @Published private(set) var unreadCount: Int = 0

    // MARK: - Dependencies

    private let store: any EchoMessageStoring
    private let container: ModelContainer

    init(store: any EchoMessageStoring, container: ModelContainer) {
        self.store = store
        self.container = container
        refresh()
    }

    // MARK: - Refresh

    /// Reload messages and unread count from store.
    func refresh() {
        allMessages = store.loadAll()
        unreadCount = store.unreadCount()
    }

    // MARK: - Mark As Read

    func markAsRead(id: UUID) throws {
        try store.markAsRead(id: id)
        refresh()
    }

    // MARK: - Delete

    func deleteMessage(id: UUID) throws {
        try store.delete(id: id)
        refresh()
    }

    // MARK: - Generate Message

    /// Create a new message with an associated chat thread. The thread is pre-seeded
    /// with Echo's initial message so it appears when the user opens the thread.
    ///
    /// - Parameters:
    ///   - type: Message type (dailyInsight, shutterEcho, etc.)
    ///   - title: Message title for the list
    ///   - preview: Preview text (first ~2 lines)
    ///   - sourceDescription: Human-readable source label ("来自：XXX")
    ///   - sourceData: Optional structured source data for AI context
    ///   - initialEchoMessage: Echo's first message in the thread (full version of the preview)
    /// - Returns: The saved EchoMessageEntity
    @discardableResult
    func generateMessage(
        type: EchoMessageType,
        title: String,
        preview: String,
        sourceDescription: String,
        sourceData: EchoSourceData?,
        initialEchoMessage: String
    ) throws -> EchoMessageEntity {
        // 1. Create a chat session (thread) for this message
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(
            title: title
        )
        // Seed Echo's first message into the thread
        session.addMessage(role: .assistant, content: initialEchoMessage)
        context.insert(session)
        try context.save()

        // 2. Encode source data
        var sourceDataJSON: Data?
        if let sourceData {
            sourceDataJSON = try JSONEncoder().encode(sourceData)
        }

        // 3. Create and save the message entity
        let entity = EchoMessageEntity(
            type: type.rawValue,
            title: title,
            preview: preview,
            sourceDescription: sourceDescription,
            sourceDataJSON: sourceDataJSON,
            isRead: false,
            threadId: session.id
        )
        try store.save(entity)

        refresh()
        return entity
    }

    // MARK: - Free Chat

    /// Create a freeChat message — no source data, immediately marked as read.
    @discardableResult
    func createFreeChatMessage() throws -> EchoMessageEntity {
        let context = ModelContext(container)
        let session = EchoChatSessionEntity(
            title: "随便聊聊"
        )
        context.insert(session)
        try context.save()

        let entity = EchoMessageEntity(
            type: EchoMessageType.freeChat.rawValue,
            title: "随便聊聊",
            preview: "",
            sourceDescription: "",
            isRead: true,
            threadId: session.id
        )
        try store.save(entity)

        refresh()
        return entity
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing:ToDayTests/EchoMessageManagerTests 2>&1 | tail -20`

Expected: All 4 tests PASS

- [ ] **Step 5: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoMessageManager.swift ToDayTests/EchoMessageManagerTests.swift
git commit -m "feat: add EchoMessageManager with CRUD, unread tracking, and thread creation"
```

---

## Task 4: EchoMessageCard (Reusable Card Component)

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoMessageCard.swift`

- [ ] **Step 1: Create EchoMessageCard.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoMessageCard.swift`:

```swift
import SwiftUI

/// A card representing one Echo message in the message list.
/// Shows type icon, title, preview, source badge, and time.
/// Unread messages use bold title styling.
struct EchoMessageCard: View {
    let entity: EchoMessageEntity

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Type icon
            Text(entity.messageType.icon)
                .font(.title3)
                .frame(width: 32, height: 32)

            // Content
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                // Title + time row
                HStack(alignment: .firstTextBaseline) {
                    Text(entity.title)
                        .font(entity.isRead ? AppFont.subheadline : AppFont.headline)
                        .foregroundStyle(AppColor.label)
                        .lineLimit(1)

                    Spacer()

                    Text(Self.relativeTime(entity.createdAt))
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.labelTertiary)
                }

                // Preview
                if !entity.preview.isEmpty {
                    Text(entity.preview)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.labelSecondary)
                        .lineLimit(2)
                }

                // Source badge
                if !entity.sourceDescription.isEmpty {
                    HStack(spacing: AppSpacing.xxs) {
                        Text("📌")
                            .font(.caption2)
                        Text(entity.sourceDescription)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.labelTertiary)
                    }
                    .padding(.top, AppSpacing.xxxs)
                }
            }

            // Unread dot
            if !entity.isRead {
                Circle()
                    .fill(AppColor.echo)
                    .frame(width: 8, height: 8)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .appShadow(.subtle)
    }

    // MARK: - Time Formatting

    private static func relativeTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日"
            return formatter.string(from: date)
        }
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Echo/EchoMessageCard.swift
git commit -m "feat: add EchoMessageCard view with type icon, preview, source badge, and unread dot"
```

---

## Task 5: EchoThreadViewModel

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoThreadViewModel.swift`

- [ ] **Step 1: Create EchoThreadViewModel.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoThreadViewModel.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class EchoThreadViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var displayMessages: [EchoChatMessage] = []
    @Published private(set) var isGenerating = false
    @Published var errorMessage: String?

    // MARK: - Properties

    let threadId: UUID
    let sourceData: EchoSourceData?
    let messageType: EchoMessageType
    let sourceDescription: String

    // MARK: - Dependencies

    private let aiService: any EchoAIProviding
    private let memoryManager: EchoMemoryManager
    private let promptBuilder: EchoPromptBuilder
    private let container: ModelContainer

    // MARK: - Internal

    private var currentSession: EchoChatSessionEntity?

    init(
        threadId: UUID,
        sourceData: EchoSourceData?,
        messageType: EchoMessageType,
        sourceDescription: String,
        aiService: any EchoAIProviding,
        memoryManager: EchoMemoryManager,
        promptBuilder: EchoPromptBuilder,
        container: ModelContainer
    ) {
        self.threadId = threadId
        self.sourceData = sourceData
        self.messageType = messageType
        self.sourceDescription = sourceDescription
        self.aiService = aiService
        self.memoryManager = memoryManager
        self.promptBuilder = promptBuilder
        self.container = container
    }

    // MARK: - Load Thread

    func loadThread() {
        let context = ModelContext(container)
        let id = threadId
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let session = try? context.fetch(descriptor).first {
            currentSession = session
            displayMessages = session.toChatMessages()
        }
    }

    // MARK: - Send Message

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil

        // Add user message to display
        let userMessage = EchoChatMessage(role: .user, content: trimmed)
        displayMessages.append(userMessage)

        // Persist user message
        persistMessage(role: .user, content: trimmed)

        // Generate AI response
        isGenerating = true

        do {
            let recentMessages = Array(displayMessages.suffix(20).dropLast())
            let messages = promptBuilder.buildThreadMessages(
                userInput: trimmed,
                personality: currentPersonality,
                sourceData: sourceData,
                sourceDescription: sourceDescription,
                messageType: messageType,
                conversationHistory: recentMessages
            )

            let response = try await aiService.respond(messages: messages)

            let assistantMessage = EchoChatMessage(role: .assistant, content: response)
            displayMessages.append(assistantMessage)

            persistMessage(role: .assistant, content: response)
        } catch {
            errorMessage = (error as? EchoAIError)?.errorDescription
                ?? "AI 回应失败：\(error.localizedDescription)"
        }

        isGenerating = false
    }

    // MARK: - Private

    private var currentPersonality: EchoPersonality {
        guard let raw = UserDefaults.standard.string(forKey: "today.echo.personality") else {
            return .gentle
        }
        return EchoPersonality(rawValue: raw) ?? .gentle
    }

    private func persistMessage(role: EchoChatRole, content: String) {
        guard let session = currentSession else { return }
        let context = ModelContext(container)

        let sessionID = session.id
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == sessionID }
        )
        descriptor.fetchLimit = 1

        guard let liveSession = try? context.fetch(descriptor).first else { return }
        liveSession.addMessage(role: role, content: content)
        try? context.save()

        currentSession = liveSession
    }
}
```

- [ ] **Step 2: Add `buildThreadMessages` to EchoPromptBuilder**

In `ios/ToDay/ToDay/Data/AI/EchoPromptBuilder.swift`, add the following method after the existing `buildMessages` method (after line 43):

```swift
    // MARK: - Thread Message Assembly

    /// Build the full message array for a thread-specific chat.
    /// Includes source data context so Echo knows what triggered this conversation.
    func buildThreadMessages(
        userInput: String,
        personality: EchoPersonality,
        sourceData: EchoSourceData?,
        sourceDescription: String,
        messageType: EchoMessageType,
        conversationHistory: [EchoChatMessage] = []
    ) -> [EchoChatMessage] {
        var messages: [EchoChatMessage] = []

        // System message with full context + source-specific context
        let systemContent = buildThreadSystemPrompt(
            personality: personality,
            sourceData: sourceData,
            sourceDescription: sourceDescription,
            messageType: messageType
        )
        messages.append(EchoChatMessage(role: .system, content: systemContent))

        // Append conversation history (prior turns)
        messages.append(contentsOf: conversationHistory)

        // Current user input
        messages.append(EchoChatMessage(role: .user, content: userInput))

        return messages
    }

    /// Build system prompt for a thread, including source-specific context.
    private func buildThreadSystemPrompt(
        personality: EchoPersonality,
        sourceData: EchoSourceData?,
        sourceDescription: String,
        messageType: EchoMessageType
    ) -> String {
        var parts: [String] = []

        // 1. Personality
        parts.append(personality.systemPromptPrefix)

        // 2. Thread context instruction
        let typeLabel: String
        switch messageType {
        case .dailyInsight:  typeLabel = "今日洞察"
        case .shutterEcho:   typeLabel = "快门回响"
        case .thoughtOrg:    typeLabel = "想法整理"
        case .emotionCare:   typeLabel = "情绪关怀"
        case .todoReminder:  typeLabel = "待办提醒"
        case .mirrorUpdate:  typeLabel = "画像更新"
        case .freeChat:      typeLabel = "自由对话"
        }
        parts.append("【当前对话主题】\n这是一个「\(typeLabel)」类型的对话。\(sourceDescription)")

        // 3. Source-specific data
        if let source = sourceData {
            var sourceContext = "【来源数据】\n类型：\(source.type.rawValue)\n描述：\(source.sourceDescription)"
            if let ids = source.shutterRecordIDs, !ids.isEmpty {
                sourceContext += "\n关联快门记录数量：\(ids.count)"
            }
            if let start = source.dateRangeStart, let end = source.dateRangeEnd {
                let formatter = DateFormatter()
                formatter.dateFormat = "M月d日"
                sourceContext += "\n时间范围：\(formatter.string(from: start)) - \(formatter.string(from: end))"
            }
            parts.append(sourceContext)
        }

        // 4. User Profile (Layer 1)
        if let profile = memoryManager.loadUserProfile(),
           !profile.profileText.isEmpty {
            parts.append("【用户画像】\n\(profile.profileText)")
        }

        // 5. Recent Summaries (Layer 2)
        let summaries = memoryManager.loadRecentSummaries(days: 7)
        if !summaries.isEmpty {
            let summaryTexts = summaries.map { "\($0.dateKey): \($0.summaryText)" }
            parts.append("【近期动态】\n\(summaryTexts.joined(separator: "\n"))")
        }

        // 6. Conversation Memory (Layer 4)
        if let memory = memoryManager.loadConversationMemory(),
           !memory.memorySummary.isEmpty {
            parts.append("【对话记忆】\n\(memory.memorySummary)")
        }

        return parts.joined(separator: "\n\n")
    }
```

- [ ] **Step 3: Regenerate Xcode project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 5: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Echo/EchoThreadViewModel.swift ToDay/Data/AI/EchoPromptBuilder.swift
git commit -m "feat: add EchoThreadViewModel and thread-specific prompt building with source context"
```

---

## Task 6: EchoThreadView (Conversation Detail Page)

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoThreadView.swift`

- [ ] **Step 1: Create EchoThreadView.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoThreadView.swift`:

```swift
import SwiftUI

/// Conversation detail page for a single Echo message thread.
/// Reuses EchoChatBubbleView and EchoChatInputBar from the existing chat system.
struct EchoThreadView: View {
    @ObservedObject var viewModel: EchoThreadViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Source banner
            if !viewModel.sourceDescription.isEmpty && viewModel.messageType != .freeChat {
                sourceBanner
            }

            // Scrollable chat area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Chat messages
                        ForEach(Array(viewModel.displayMessages.enumerated()), id: \.element.id) { index, message in
                            let isLast = index == viewModel.displayMessages.count - 1
                            EchoChatBubbleView(
                                message: message,
                                isLastMessage: isLast
                            )
                        }

                        // Thinking indicator
                        if viewModel.isGenerating {
                            EchoThinkingView()
                                .padding(.top, AppSpacing.xxs)
                        }

                        // Error message
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        // Bottom anchor
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.displayMessages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Input bar
            EchoChatInputBar(
                text: $inputText,
                isFocused: $isInputFocused,
                isGenerating: viewModel.isGenerating,
                isTemporaryMode: false
            ) { text in
                Task {
                    await viewModel.sendMessage(text)
                }
            }
        }
        .background(AppColor.background)
        .navigationTitle(viewModel.messageType.icon + " " + viewModel.messageType.defaultTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadThread()
        }
    }

    // MARK: - Source Banner

    private var sourceBanner: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "link")
                .font(.caption2)
                .foregroundStyle(AppColor.echo)

            Text("关于：\(viewModel.sourceDescription)")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColor.soft(AppColor.echo))
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(AppColor.workout)

            Text(error)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelSecondary)
                .lineLimit(2)

            Spacer()

            Button("重试") {
                viewModel.errorMessage = nil
            }
            .font(AppFont.caption)
            .foregroundStyle(AppColor.echo)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColor.soft(AppColor.workout))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xxs)
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Echo/EchoThreadView.swift
git commit -m "feat: add EchoThreadView conversation detail page with source banner and chat bubbles"
```

---

## Task 7: EchoMessageListView (New Echo Tab Root)

**Files:**
- Create: `ios/ToDay/ToDay/Features/Echo/EchoMessageListView.swift`

- [ ] **Step 1: Create EchoMessageListView.swift**

Create `ios/ToDay/ToDay/Features/Echo/EchoMessageListView.swift`:

```swift
import SwiftUI

/// The new Echo tab root view — a message center showing all Echo-initiated messages.
/// Each message links to an independent conversation thread.
struct EchoMessageListView: View {
    @ObservedObject var messageManager: EchoMessageManager
    let threadViewModelFactory: (EchoMessageEntity) -> EchoThreadViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppSpacing.sm) {
                    if messageManager.allMessages.isEmpty {
                        emptyState
                    } else {
                        // Message list
                        ForEach(messageManager.allMessages, id: \.id) { message in
                            NavigationLink(value: message.id) {
                                EchoMessageCard(entity: message)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    try? messageManager.deleteMessage(id: message.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }

                    // Bottom entry: free chat
                    freeChatButton
                        .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColor.background)
            .navigationTitle("Echo")
            .navigationDestination(for: UUID.self) { messageId in
                if let message = messageManager.allMessages.first(where: { $0.id == messageId }) {
                    let vm = threadViewModelFactory(message)
                    EchoThreadView(viewModel: vm)
                        .onAppear {
                            if !message.isRead {
                                try? messageManager.markAsRead(id: message.id)
                            }
                        }
                }
            }
            .refreshable {
                messageManager.refresh()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
                .frame(height: AppSpacing.xxl)

            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.echo)

            Text("Echo 还没有给你发消息")
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.labelSecondary)

            Text("Echo 会根据你的日常记录主动给你发消息，\n就像一个关心你的朋友。")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.labelTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }

    // MARK: - Free Chat Button

    private var freeChatButton: some View {
        Button {
            if let msg = try? messageManager.createFreeChatMessage() {
                // The NavigationLink will handle navigation via the message list refresh
                // We could also navigate programmatically if needed
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text("✨")
                    .font(.body)

                Text("跟 Echo 随便聊聊")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.echo)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppColor.labelTertiary)
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(AppColor.soft(AppColor.echo), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd ios/ToDay && git add ToDay/Features/Echo/EchoMessageListView.swift
git commit -m "feat: add EchoMessageListView as new Echo tab root with message cards and free chat entry"
```

---

## Task 8: Update EchoScheduler to Generate Messages

**Files:**
- Modify: `ios/ToDay/ToDay/Data/AI/EchoScheduler.swift`

- [ ] **Step 1: Add EchoMessageManager dependency and message generation to EchoScheduler**

In `ios/ToDay/ToDay/Data/AI/EchoScheduler.swift`, make the following changes:

**a) Add `messageManager` property.** After line 16 (`private let memoryManager: EchoMemoryManager`), add:

```swift
    private var messageManager: EchoMessageManager?
```

**b) Add a setter for messageManager.** After the `init(...)` block (after line 45), add:

```swift
    /// Set the message manager. Called after AppContainer wires everything up
    /// (to break the circular dependency between scheduler and manager).
    func setMessageManager(_ manager: EchoMessageManager) {
        self.messageManager = manager
    }
```

**c) Update `onAppBackground` to also create a dailyInsight message.** In the `onAppBackground` method, after the line `UserDefaults.standard.set(todayKey, forKey: Self.lastDailySummaryKey)` (line 96) and before the prune call, add:

```swift
            // Create a dailyInsight message in the message center
            if let manager = messageManager {
                let summary = memoryManager.loadSummary(forDateKey: todayKey)
                let insightText = summary?.summaryText ?? "今天的数据已整理好"
                let preview = String(insightText.prefix(60))

                let sourceData = EchoSourceData(
                    type: .todayData,
                    sourceDescription: "今日数据"
                )

                await MainActor.run {
                    try? manager.generateMessage(
                        type: .dailyInsight,
                        title: "今日洞察",
                        preview: preview,
                        sourceDescription: "来自：今日数据",
                        sourceData: sourceData,
                        initialEchoMessage: insightText
                    )
                }
            }
```

**d) Update `onAppLaunch` to create mirrorUpdate message when profile is updated.** After the existing `try await weeklyProfileUpdater.updateIfNeeded()` call (line 111), add:

```swift
            // Check if profile was just updated (by looking at profile update timestamp)
            if let profile = memoryManager.loadUserProfile() {
                let calendar = Calendar.current
                if calendar.isDateInToday(profile.lastUpdatedAt),
                   let manager = messageManager {
                    let preview = String(profile.profileText.prefix(60))
                    let sourceData = EchoSourceData(
                        type: .userProfile,
                        sourceDescription: "你的生活画像"
                    )
                    await MainActor.run {
                        try? manager.generateMessage(
                            type: .mirrorUpdate,
                            title: "我对你有了新的了解",
                            preview: preview,
                            sourceDescription: "来自：你的生活画像",
                            sourceData: sourceData,
                            initialEchoMessage: profile.profileText
                        )
                    }
                }
            }
```

**e) Update `onStrongEmotion` to create emotionCare message.** After the existing `dailySummaryGenerator.generateDailySummary(...)` call (lines 130-136), add:

```swift
            // Create an emotion care message
            if let manager = messageManager {
                let summary = memoryManager.loadSummary(forDateKey: todayKey)
                let insightText = summary?.summaryText ?? "看起来你现在心情有些起伏"
                let preview = String(insightText.prefix(60))

                let sourceData = EchoSourceData(
                    type: .moodTrend,
                    sourceDescription: "近期心情趋势"
                )

                await MainActor.run {
                    try? manager.generateMessage(
                        type: .emotionCare,
                        title: "Echo 想跟你说",
                        preview: preview,
                        sourceDescription: "来自：近期心情趋势",
                        sourceData: sourceData,
                        initialEchoMessage: insightText
                    )
                }
            }
```

- [ ] **Step 2: Regenerate Xcode project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All existing tests still pass

- [ ] **Step 4: Commit**

```bash
cd ios/ToDay && git add ToDay/Data/AI/EchoScheduler.swift
git commit -m "feat: update EchoScheduler to generate EchoMessage entries for daily insight, mirror update, and emotion care"
```

---

## Task 9: Wire Everything Together (AppContainer + AppRootScreen + ToDayApp)

**Files:**
- Modify: `ios/ToDay/ToDay/App/AppContainer.swift`
- Modify: `ios/ToDay/ToDay/App/AppRootScreen.swift`
- Modify: `ios/ToDay/ToDay/App/ToDayApp.swift`

- [ ] **Step 1: Register EchoMessageEntity in ModelContainer and add factory methods to AppContainer**

In `ios/ToDay/ToDay/App/AppContainer.swift`:

**a) Add `EchoMessageEntity` to the `makeModelContainer` method.** In the `ModelContainer(for:...)` call (line 146-158), add `EchoMessageEntity.self` after `EchoChatMessageEntity.self`:

```swift
    private static func makeModelContainer() -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: MoodRecordEntity.self,
                DayTimelineEntity.self,
                ShutterRecordEntity.self,
                SpendingRecordEntity.self,
                ScreenTimeRecordEntity.self,
                EchoItemEntity.self,
                UserProfileEntity.self,
                DailySummaryEntity.self,
                ConversationMemoryEntity.self,
                EchoChatSessionEntity.self,
                EchoChatMessageEntity.self,
                EchoMessageEntity.self
            )
            migrateLegacyMoodRecordsIfNeeded(into: container)
            return container
        } catch {
            fatalError("无法创建 MoodRecord SwiftData 容器：\(error.localizedDescription)")
        }
    }
```

**b) Add `echoMessageStore` and `echoMessageManager` singletons.** After the existing `echoScheduler` declaration (around line 34), add:

```swift
    private static let echoMessageStore = SwiftDataEchoMessageStore(container: modelContainer)
```

**c) Add factory/getter methods.** After the existing `getEchoScheduler()` method (around line 142), add:

```swift
    @MainActor
    static let echoMessageManager: EchoMessageManager = {
        let manager = EchoMessageManager(store: echoMessageStore, container: modelContainer)
        echoScheduler.setMessageManager(manager)
        return manager
    }()

    @MainActor
    static func getEchoMessageManager() -> EchoMessageManager {
        echoMessageManager
    }

    @MainActor
    static func makeEchoThreadViewModel(for message: EchoMessageEntity) -> EchoThreadViewModel {
        EchoThreadViewModel(
            threadId: message.threadId,
            sourceData: message.sourceData,
            messageType: message.messageType,
            sourceDescription: message.sourceData?.sourceDescription ?? "",
            aiService: echoAIService,
            memoryManager: echoMemoryManager,
            promptBuilder: echoPromptBuilder,
            container: modelContainer
        )
    }
```

- [ ] **Step 2: Update AppRootScreen to use EchoMessageListView with unread badge**

In `ios/ToDay/ToDay/App/AppRootScreen.swift`:

**a) Replace `echoChatViewModel` with `echoMessageManager` in the properties.** Change line 15 from:

```swift
    @ObservedObject var echoChatViewModel: EchoChatViewModel
```

to:

```swift
    @ObservedObject var echoMessageManager: EchoMessageManager
```

**b) Replace the Echo tab content.** Replace the `EchoChatScreen` usage (line 49):

```swift
                    EchoChatScreen(viewModel: echoChatViewModel, echoViewModel: echoViewModel)
                    .tabItem {
                        Label("Echo", systemImage: "sparkles")
                    }
                    .tag(AppTab.echo)
```

with:

```swift
                    EchoMessageListView(
                        messageManager: echoMessageManager,
                        threadViewModelFactory: { message in
                            AppContainer.makeEchoThreadViewModel(for: message)
                        }
                    )
                    .tabItem {
                        Label("Echo", systemImage: "sparkles")
                    }
                    .tag(AppTab.echo)
                    .badge(echoMessageManager.unreadCount > 0 ? echoMessageManager.unreadCount : 0)
```

**c) Update `SettingsView` reference.** The `SettingsView` currently takes `echoChatViewModel` — replace with updated parameters. Change line 55-56:

```swift
                    SettingsView(echoViewModel: echoViewModel, echoChatViewModel: echoChatViewModel)
```

to:

```swift
                    SettingsView(echoViewModel: echoViewModel)
```

> **Note:** If `SettingsView` requires `echoChatViewModel` for the Mirror feature, keep the old chat ViewModel or adapt `SettingsView` to use `EchoMessageManager`. Verify at build time and adjust as needed. If `SettingsView` still needs `echoChatViewModel`, keep it as an additional parameter passed from `ToDayApp`.

- [ ] **Step 3: Update ToDayApp to use EchoMessageManager**

In `ios/ToDay/ToDay/App/ToDayApp.swift`:

**a) Replace `echoChatViewModel` with `echoMessageManager`.** Change line 9:

```swift
    @StateObject private var echoChatViewModel = AppContainer.makeEchoChatViewModel()
```

to:

```swift
    @StateObject private var echoMessageManager = AppContainer.getEchoMessageManager()
```

**b) Update AppRootScreen initialization.** Change lines 16-20:

```swift
            AppRootScreen(
                todayViewModel: viewModel,
                echoViewModel: echoViewModel,
                echoChatViewModel: echoChatViewModel
            )
```

to:

```swift
            AppRootScreen(
                todayViewModel: viewModel,
                echoViewModel: echoViewModel,
                echoMessageManager: echoMessageManager
            )
```

> **Note:** If `SettingsView` or other parts of the app still reference `echoChatViewModel` directly, keep the `@StateObject` and pass it through. The build step will surface any remaining references.

- [ ] **Step 4: Regenerate Xcode project and build**

Run: `cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

> **Troubleshooting:** If build fails due to `SettingsView` still referencing `echoChatViewModel`, check what `SettingsView` needs and either:
> - Keep `echoChatViewModel` as an additional parameter alongside `echoMessageManager`
> - Refactor `SettingsView` to get the mirror feature from `EchoMessageManager` or a standalone mirror ViewModel

- [ ] **Step 5: Run full test suite**

Run: `cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: All tests pass (154+ tests)

- [ ] **Step 6: Commit**

```bash
cd ios/ToDay && git add ToDay/App/AppContainer.swift ToDay/App/AppRootScreen.swift ToDay/App/ToDayApp.swift
git commit -m "feat: wire Echo message center — replace EchoChatScreen with EchoMessageListView, add unread badge"
```

---

## Build Verification

After all tasks are complete, run the full verification sequence:

```bash
# 1. Regenerate project
cd ios/ToDay && xcodegen generate

# 2. Build iOS
xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 3. Build Watch
xcodebuild build -scheme ToDayWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 4. Run all tests
xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: All builds succeed, all tests pass.
