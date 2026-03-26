import Foundation

// WeeklyInsightView has been simplified to a data-only helper.
// All UI rendering is now done directly in HistoryScreen.swift.
// This file is kept for backward compatibility; it can be removed
// once all references are cleaned up.

struct WeeklyTrendPoint: Identifiable {
    let date: Date
    let label: String
    let value: Double

    var id: Date { date }
}
