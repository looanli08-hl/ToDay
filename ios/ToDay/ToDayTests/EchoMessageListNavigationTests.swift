import XCTest
import SwiftData
@testable import ToDay

/// Tests for EchoMessageManager freeChat creation and navigation wiring.
///
/// Plan 05-01 (RED phase): testCreateFreeChatMessageReturnsEntityWithThreadId verifies
/// the base behavior that already works — createFreeChatMessage() returns a valid entity.
/// This test MUST PASS now (AIC-03 base behavior is already implemented).
///
/// Plan 05-03: testFreeChatNavigationAppendsEntityIdToPath verifies that the navigation
/// path mechanism works — entity returned by createFreeChatMessage has a valid UUID that
/// can be appended to NavigationPath. This test verifies the data contract that makes
/// NavigationPath.append(entity.id) safe to call.
@MainActor
final class EchoMessageListNavigationTests: XCTestCase {
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

    // MARK: - AIC-03: Base Behavior (GREEN — already implemented)

    /// GREEN: createFreeChatMessage returns a non-nil entity with a valid threadId.
    ///
    /// Validates that EchoMessageManager.createFreeChatMessage():
    /// - Returns an entity with messageType == .freeChat
    /// - Sets a valid non-default UUID as threadId
    /// - The entity's id differs from its threadId (session != message)
    ///
    /// This test MUST PASS as-is (the creation logic is fully implemented).
    func testCreateFreeChatMessageReturnsEntityWithThreadId() throws {
        let entity = try manager.createFreeChatMessage()

        // Type must be freeChat
        XCTAssertEqual(entity.messageType, .freeChat,
            "createFreeChatMessage must return an entity with messageType == .freeChat")

        // threadId must be a valid UUID (not the zero UUID)
        XCTAssertNotEqual(entity.threadId, UUID(uuidString: "00000000-0000-0000-0000-000000000000"),
            "threadId must be a valid non-zero UUID")

        // Entity id differs from threadId — they are separate identifiers
        XCTAssertNotEqual(entity.id, entity.threadId,
            "entity.id (message ID) must differ from entity.threadId (session ID)")

        // Verify the session was actually persisted in SwiftData
        let context = ModelContext(container)
        let threadId = entity.threadId
        var descriptor = FetchDescriptor<EchoChatSessionEntity>(
            predicate: #Predicate { $0.id == threadId }
        )
        descriptor.fetchLimit = 1
        let session = try context.fetch(descriptor).first
        XCTAssertNotNil(session,
            "An EchoChatSessionEntity with the returned threadId must exist in SwiftData")
    }

    // MARK: - AIC-01: Navigation Contract (GREEN after Plan 05-03)

    /// GREEN (after Plan 05-03): entity.id returned by createFreeChatMessage is a valid
    /// UUID that can be appended to NavigationPath for programmatic navigation.
    ///
    /// This test verifies the data contract that makes NavigationStack(path:) navigation
    /// safe: the entity has a non-default UUID id suitable for .navigationDestination(for: UUID.self).
    ///
    /// Relation to EchoMessageListView: freeChatButton calls
    ///   `navigationPath.append(entity.id)` — this test confirms entity.id is always valid.
    func testFreeChatEntityIdIsValidForNavigationPathAppend() throws {
        // Create two freeChat entities — both must have distinct, valid UUIDs
        let entity1 = try manager.createFreeChatMessage()
        let entity2 = try manager.createFreeChatMessage()

        // Both ids are non-zero UUIDs (safe to append to NavigationPath)
        let zeroUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        XCTAssertNotEqual(entity1.id, zeroUUID,
            "entity1.id must be a non-zero UUID for NavigationPath.append to navigate correctly")
        XCTAssertNotEqual(entity2.id, zeroUUID,
            "entity2.id must be a non-zero UUID for NavigationPath.append to navigate correctly")

        // Each tap on freeChat creates a NEW entity — ids must differ (no duplicate accumulation)
        XCTAssertNotEqual(entity1.id, entity2.id,
            "Each createFreeChatMessage call must return a unique entity id — no duplicate accumulation")

        // Two separate threads must also be created
        XCTAssertNotEqual(entity1.threadId, entity2.threadId,
            "Each freeChat call must create a separate EchoChatSession — no thread sharing")

        // Manager must reflect both messages
        XCTAssertEqual(manager.allMessages.count, 2,
            "allMessages must contain both freeChat entities after two createFreeChatMessage calls")
    }
}
