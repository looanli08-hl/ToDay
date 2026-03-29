import CoreLocation
import XCTest
@testable import ToDay

final class EchoRelevanceScorerTests: XCTestCase {
    let scorer = EchoRelevanceScorer()

    func testRecentRecordHasLowTimeDecay() {
        // Use dates 12 hours apart to avoid time-of-day resonance bonus
        let now = Date()
        let recent = now.addingTimeInterval(-3600)
        let score = scorer.score(recordDate: recent, recordNote: "", now: now,
                                  currentLocation: nil, recordLocation: nil)
        // Recent record gets 0.1 time decay; may also get time-of-day + weekday bonuses
        // but time decay component itself should be lowest tier
        XCTAssertLessThan(score, 0.6, "Recent record should not score too high without location")
    }

    func testOldRecordGetsNostalgiaBoost() {
        let now = Date()
        let old = now.addingTimeInterval(-200 * 86400)
        let score = scorer.score(recordDate: old, recordNote: "", now: now,
                                  currentLocation: nil, recordLocation: nil)
        XCTAssertGreaterThan(score, 0.4)
    }

    func testNearbyLocationBoostsScore() {
        let now = Date()
        let weekAgo = now.addingTimeInterval(-7 * 86400)
        let loc = CLLocation(latitude: 39.9, longitude: 116.4)
        let nearby = CLLocation(latitude: 39.9001, longitude: 116.4001)
        let score = scorer.score(recordDate: weekAgo, recordNote: "", now: now,
                                  currentLocation: loc, recordLocation: nearby)
        XCTAssertGreaterThan(score, 0.7)
    }

    func testThresholdsDecreaseWithHigherFrequency() {
        XCTAssertLessThan(
            EchoRelevanceScorer.threshold(for: .high),
            EchoRelevanceScorer.threshold(for: .low)
        )
    }
}
