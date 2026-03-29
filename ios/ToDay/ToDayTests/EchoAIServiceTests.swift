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
    private var mockProvider: MockAIProvider!
    private var service: EchoAIService!

    override func setUp() {
        super.setUp()
        mockProvider = MockAIProvider()
        service = EchoAIService(provider: mockProvider)
    }

    func testRespondCallsProvider() async throws {
        mockProvider.respondResult = "hello"

        let messages = [EchoChatMessage(role: .user, content: "你好")]
        let result = try await service.respond(messages: messages)

        XCTAssertEqual(result, "hello")
        XCTAssertEqual(mockProvider.respondCallCount, 1)
    }

    func testThrowsWhenProviderUnavailable() async {
        mockProvider.isAvailable = false

        let messages = [EchoChatMessage(role: .user, content: "你好")]
        do {
            _ = try await service.respond(messages: messages)
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is EchoAIError)
        }
    }

    func testSummarizeCallsProvider() async throws {
        mockProvider.summarizeResult = "today was good"

        let result = try await service.summarize(prompt: "summarize today")
        XCTAssertEqual(result, "today was good")
        XCTAssertEqual(mockProvider.summarizeCallCount, 1)
    }

    func testGenerateProfileCallsProvider() async throws {
        mockProvider.profileResult = "user likes running"

        let result = try await service.generateProfile(prompt: "generate profile")
        XCTAssertEqual(result, "user likes running")
        XCTAssertEqual(mockProvider.profileCallCount, 1)
    }
}
