import Foundation
import Supabase

@MainActor
final class SupabaseAuthManager: ObservableObject {
    static let shared = SupabaseAuthManager()

    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var userId: String?

    private init() {
        Task {
            await checkSession()
        }
    }

    func checkSession() async {
        do {
            let session = try await SupabaseConfig.client.auth.session
            isAuthenticated = true
            userEmail = session.user.email
            userId = session.user.id.uuidString
        } catch {
            isAuthenticated = false
            userEmail = nil
            userId = nil
        }
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await SupabaseConfig.client.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(displayName)]
        )
        isAuthenticated = true
        userEmail = result.user.email
        userId = result.user.id.uuidString
    }

    func signIn(email: String, password: String) async throws {
        let session = try await SupabaseConfig.client.auth.signIn(
            email: email,
            password: password
        )
        isAuthenticated = true
        userEmail = session.user.email
        userId = session.user.id.uuidString
    }

    func signOut() async throws {
        try await SupabaseConfig.client.auth.signOut()
        isAuthenticated = false
        userEmail = nil
        userId = nil
    }
}
