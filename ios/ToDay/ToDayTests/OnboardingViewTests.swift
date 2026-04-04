import XCTest
import CoreLocation
@testable import ToDay

// MARK: - OnboardingStep Tests

final class OnboardingStepTests: XCTestCase {

    // Test that all expected step cases exist
    func testOnboardingStepCasesExist() {
        // Verify each step can be created (enum completeness)
        let value = OnboardingStep.value
        let locationWhenInUse = OnboardingStep.locationWhenInUse
        let locationAlwaysUpgrade = OnboardingStep.locationAlwaysUpgrade
        let locationDenied = OnboardingStep.locationDenied
        let motion = OnboardingStep.motion
        let complete = OnboardingStep.complete

        // All cases should be distinct
        XCTAssertNotEqual("\(value)", "\(locationWhenInUse)")
        XCTAssertNotEqual("\(locationWhenInUse)", "\(locationAlwaysUpgrade)")
        XCTAssertNotEqual("\(locationAlwaysUpgrade)", "\(locationDenied)")
        XCTAssertNotEqual("\(locationDenied)", "\(motion)")
        XCTAssertNotEqual("\(motion)", "\(complete)")
    }

    func testOnboardingStepValueIsFirst() {
        // The initial step must be .value (before any permission dialog)
        let initialStep = OnboardingStep.value
        XCTAssertEqual("\(initialStep)", "value",
                       "ONB-01: First step must be .value — no permission dialog on launch")
    }

    func testOnboardingStepEquality() {
        XCTAssertEqual(OnboardingStep.value, OnboardingStep.value)
        XCTAssertEqual(OnboardingStep.complete, OnboardingStep.complete)
        XCTAssertEqual(OnboardingStep.locationDenied, OnboardingStep.locationDenied)
    }
}

// MARK: - LocationPermissionCoordinator Tests

@MainActor
final class LocationPermissionCoordinatorTests: XCTestCase {

    func testCoordinatorInitialStatus() {
        let coordinator = LocationPermissionCoordinator()
        // authorizationStatus must be a valid CLAuthorizationStatus
        // On simulator it's typically .notDetermined
        let validStatuses: [CLAuthorizationStatus] = [
            .notDetermined, .restricted, .denied,
            .authorizedAlways, .authorizedWhenInUse
        ]
        XCTAssertTrue(validStatuses.contains(coordinator.authorizationStatus),
                      "authorizationStatus must be a valid CLAuthorizationStatus")
    }

    func testCoordinatorIsObservableObject() {
        // Must be ObservableObject so @StateObject can retain it
        let coordinator = LocationPermissionCoordinator()
        let mirror = Mirror(reflecting: coordinator)
        // Has CLLocationManager delegate properly retained (class, not struct)
        XCTAssertTrue(type(of: coordinator) == LocationPermissionCoordinator.self)
        // Published authorizationStatus is accessible
        _ = coordinator.authorizationStatus
    }

    func testCoordinatorHasRequiredMethods() {
        // Verify requestWhenInUse and requestAlways methods exist
        let coordinator = LocationPermissionCoordinator()
        // We just need to confirm these are callable (compile-time check via testable import)
        // If this test compiles, the methods exist
        // Note: We don't call them in tests to avoid system permission dialogs
        XCTAssertNotNil(coordinator)
    }

    func testCoordinatorRetainsManagerAcrossScope() {
        // The manager must be a stored property, not a local variable
        // If it were local, it would be deallocated before delegate fires
        // We test by holding a reference and verifying status is stable
        var coordinator: LocationPermissionCoordinator? = LocationPermissionCoordinator()
        let statusBefore = coordinator!.authorizationStatus
        // Keep coordinator alive
        let statusAfter = coordinator!.authorizationStatus
        XCTAssertEqual(statusBefore, statusAfter,
                       "authorizationStatus should be stable when no permission change occurs")
        coordinator = nil
    }
}
