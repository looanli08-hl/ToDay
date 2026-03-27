import XCTest
@testable import ToDay

// MARK: - Mock AI Provider

final class MockAIProvider: EchoAIProviding, @unchecked Sendable {
    var respondResult: String = "mock response"
    var summarizeResult: String = "mock summary"
    var profileResult: String = "mock profile"
    var shouldFail = false
    var isAvailable: Bool = true

    private(set) var respondCallCount = 0
    private(set) var summarizeCallCount = 0
    private(set) var profileCallCount = 0

    func respond(messages: [EchoChatMessage]) async throws -> String {
        respondCallCount += 1
        if shouldFail { throw EchoAIError.invalidResponse }
        return respondResult
    }

    func summarize(prompt: String) async throws -> String {
        summarizeCallCount += 1
        if shouldFail { throw EchoAIError.invalidResponse }
        return summarizeResult
    }

    func generateProfile(prompt: String) async throws -> String {
        profileCallCount += 1
        if shouldFail { throw EchoAIError.invalidResponse }
        return profileResult
    }
}

// MARK: - Tests

final class EchoAIServiceTests: XCTestCase {
    private var freeProvider: MockAIProvider!
    private var proProvider: MockAIProvider!
    private var service: EchoAIService!

    override func setUp() {
        super.setUp()
        freeProvider = MockAIProvider()
        proProvider = MockAIProvider()
        service = EchoAIService(
            freeProvider: freeProvider,
            proProvider: proProvider
        )
    }

    func testFreeUserUsesLocalProvider() async throws {
        service.currentTier = .free
        freeProvider.respondResult = "local answer"

        let messages = [EchoChatMessage(role: .user, content: "你好")]
        let result = try await service.respond(messages: messages)

        XCTAssertEqual(result, "local answer")
        XCTAssertEqual(freeProvider.respondCallCount, 1)
        XCTAssertEqual(proProvider.respondCallCount, 0)
    }

    func testProUserUsesDeepSeekProvider() async throws {
        service.currentTier = .pro
        proProvider.respondResult = "pro answer"

        let messages = [EchoChatMessage(role: .user, content: "你好")]
        let result = try await service.respond(messages: messages)

        XCTAssertEqual(result, "pro answer")
        XCTAssertEqual(proProvider.respondCallCount, 1)
        XCTAssertEqual(freeProvider.respondCallCount, 0)
    }

    func testFallbackWhenPreferredProviderUnavailable() async throws {
        service.currentTier = .pro
        proProvider.isAvailable = false
        freeProvider.respondResult = "fallback answer"

        let messages = [EchoChatMessage(role: .user, content: "你好")]
        let result = try await service.respond(messages: messages)

        XCTAssertEqual(result, "fallback answer")
        XCTAssertEqual(freeProvider.respondCallCount, 1)
    }

    func testThrowsWhenNoProviderAvailable() async {
        service.currentTier = .pro
        proProvider.isAvailable = false
        freeProvider.isAvailable = false

        let messages = [EchoChatMessage(role: .user, content: "你好")]
        do {
            _ = try await service.respond(messages: messages)
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is EchoAIError)
        }
    }

    func testSummarizeRoutesToCorrectProvider() async throws {
        service.currentTier = .free
        freeProvider.summarizeResult = "today was good"

        let result = try await service.summarize(prompt: "summarize today")
        XCTAssertEqual(result, "today was good")
        XCTAssertEqual(freeProvider.summarizeCallCount, 1)
    }

    func testGenerateProfileRoutesToCorrectProvider() async throws {
        service.currentTier = .pro
        proProvider.profileResult = "user likes running"

        let result = try await service.generateProfile(prompt: "generate profile")
        XCTAssertEqual(result, "user likes running")
        XCTAssertEqual(proProvider.profileCallCount, 1)
    }
}
