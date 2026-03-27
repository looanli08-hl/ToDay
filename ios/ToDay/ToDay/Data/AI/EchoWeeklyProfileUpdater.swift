import Foundation

/// Updates the user profile (Layer 1 memory) from accumulated daily summaries.
///
/// Intended to run once per week (triggered by EchoScheduler, future task).
/// Takes the current profile + recent daily summaries and asks AI to generate
/// an updated portrait of the user.
final class EchoWeeklyProfileUpdater: @unchecked Sendable {

    private let aiService: any EchoAIProviding
    private let memoryManager: EchoMemoryManager
    private let promptBuilder: EchoPromptBuilder

    /// UserDefaults key for last profile update date
    private static let lastUpdateKey = "today.echo.lastProfileUpdate"

    init(
        aiService: any EchoAIProviding,
        memoryManager: EchoMemoryManager,
        promptBuilder: EchoPromptBuilder
    ) {
        self.aiService = aiService
        self.memoryManager = memoryManager
        self.promptBuilder = promptBuilder
    }

    // MARK: - Public

    /// Check if a profile update is due (7+ days since last update) and run it.
    /// Returns `true` if an update was performed.
    @discardableResult
    func updateIfNeeded() async throws -> Bool {
        guard shouldUpdate() else { return false }
        try await updateProfile()
        return true
    }

    /// Force a profile update regardless of timing.
    func updateProfile() async throws {
        let currentProfile = memoryManager.loadUserProfile()?.profileText
        let summaries = memoryManager.loadRecentSummaries(days: 7)

        guard !summaries.isEmpty else {
            // Not enough data yet — skip silently
            return
        }

        let summaryTexts = summaries.map { "\($0.dateKey): \($0.summaryText)" }
        let summaryIDs = summaries.map(\.id)

        let prompt = promptBuilder.buildProfileUpdatePrompt(
            currentProfile: currentProfile,
            recentSummaries: summaryTexts
        )

        let newProfile = try await aiService.generateProfile(prompt: prompt)

        try memoryManager.saveUserProfile(
            text: newProfile.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceSummaryIDs: summaryIDs
        )

        // Record update time
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastUpdateKey)
    }

    // MARK: - Private

    private func shouldUpdate() -> Bool {
        let lastUpdate = UserDefaults.standard.double(forKey: Self.lastUpdateKey)
        guard lastUpdate > 0 else {
            // Never updated — check if we have enough data
            let summaries = memoryManager.loadRecentSummaries(days: 3)
            return summaries.count >= 3
        }

        let lastDate = Date(timeIntervalSince1970: lastUpdate)
        let daysSinceUpdate = Calendar.current.dateComponents(
            [.day], from: lastDate, to: Date()
        ).day ?? 0

        return daysSinceUpdate >= 7
    }
}
