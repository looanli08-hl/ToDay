import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://fsajffxopgrzjpzwqwng.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZzYWpmZnhvcGdyempwendxd25nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NjMzNDMsImV4cCI6MjA5MDMzOTM0M30.BFhT3uTirbZNLp41ns4NaSaZQgjbGQSMGYdtrLNpNrI"

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey
    )
}
