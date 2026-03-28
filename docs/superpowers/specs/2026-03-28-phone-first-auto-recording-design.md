# Phone-First Auto Recording System

Date: 2026-03-28
Status: Approved

## Overview

Restructure ToDay's auto-recording system from Apple Watch (HealthKit) dependency to iPhone-first architecture. iPhone sensors (motion, location, pedometer, device state) provide the base recording capability. Apple Watch becomes an optional enhancement that improves precision when available.

### Design Principles

1. **Phone-first** — All core auto-recording works with iPhone alone
2. **Watch as enhancement** — HealthKit data adds precision, never required
3. **No standalone Watch app** — Watch data syncs to iPhone's HealthKit automatically
4. **Batch over real-time** — Query sensor history periodically, don't monitor continuously
5. **Record more, not less** — Low thresholds, high density; user can dismiss, but missed events can't be recovered

## Architecture

```
┌────────────────── Collectors ──────────────────┐
│  MotionCollector    — CMMotionActivityManager   │
│  LocationCollector  — CLVisit + SigLocChange    │
│  PedometerCollector — CMPedometer               │
│  DeviceStateCollector — charge/lock events       │
│  HealthKitCollector — optional, Watch data       │
└──────────────────┬─────────────────────────────┘
                   ↓
        ┌─── SensorDataStore ───┐
        │  SwiftData, per-day   │
        │  30-day retention     │
        └──────────┬────────────┘
                   ↓
        ┌─── PhoneInferenceEngine ──┐
        │  Cross-source inference    │
        │  Rule-based (simple→ML)    │
        │  Output: [InferredEvent]   │
        └──────────┬────────────────┘
                   ↓
        ┌─── PlaceManager ─────┐
        │  Auto-learn places    │
        │  Home/work detection  │
        │  Idle-time prompts    │
        └───────────────────────┘
```

## Part 1: Sensor Collectors

### Protocol

```swift
protocol SensorCollecting {
    var sensorType: SensorType { get }
    var isAvailable: Bool { get }
    func collectData(for date: Date) async throws -> [SensorReading]
    func requestAuthorizationIfNeeded() async throws
}

enum SensorType: String, Codable {
    case motion, location, pedometer, deviceState, healthKit
}
```

### MotionCollector

- Queries `CMMotionActivityManager.queryActivityStarting(from:to:)` for up to 7 days of history
- Outputs: time range + activity type (walking/running/automotive/cycling/stationary) + confidence (low/medium/high)
- Permission: Motion & Fitness (requested on first use)

### LocationCollector

- Evolves from existing `LocationService`
- Background: Significant Location Change monitoring (survives app termination)
- Real-time: `CLLocationManager.startMonitoringVisits()` delivers `CLVisit` objects via delegate — stored immediately to SensorDataStore as they arrive (same pattern as DeviceStateCollector)
- `collectData(for:)` reads back stored visits/locations for that day from SensorDataStore (not from iOS API)
- Outputs: coordinates + arrival/departure times + duration

### PedometerCollector

- Queries `CMPedometer.queryPedometerData(from:to:)`
- Outputs: steps, distance, floors ascended (segmented hourly)

### DeviceStateCollector

- Listens to `UIDevice.batteryStateDidChangeNotification` (charge start/stop)
- Listens to `UIApplication.protectedDataDidBecomeAvailableNotification` (unlock)
- Listens to `UIApplication.protectedDataWillBecomeUnavailableNotification` (lock)
- Event-driven: writes to SensorDataStore in real-time (not historical query)

### HealthKitCollector (Optional Enhancement)

- Extracted from existing `HealthKitTimelineDataProvider` collection logic
- `isAvailable` returns true only when HealthKit has data (Watch paired)
- Outputs: heart rate, sleep, workouts, etc.
- When available, InferenceEngine uses this data to boost confidence of other inferences

### Background Scheduling

```
SignificantLocationChange → wake app → record location + trigger lightweight collection
BGAppRefreshTask (hourly) → batch-query all Collectors → write to SensorDataStore
BGProcessingTask (nightly) → full day reconstruction + backfill 7 days + purge expired data
```

All leveraging existing `BackgroundTaskManager` infrastructure.

## Part 2: SensorDataStore

### Data Model

```swift
struct SensorReading: Codable {
    let id: UUID
    let sensorType: SensorType
    let timestamp: Date
    let endTimestamp: Date?
    let payload: SensorPayload
}

enum SensorPayload: Codable {
    case motion(activity: MotionActivity, confidence: MotionConfidence)
    case location(latitude: Double, longitude: Double, horizontalAccuracy: Double)
    case visit(latitude: Double, longitude: Double, arrivalDate: Date, departureDate: Date?)
    case pedometer(steps: Int, distance: Double?, floorsAscended: Int?)
    case deviceState(event: DeviceEvent)
    case healthKit(metric: String, value: Double)
}

enum MotionActivity: String, Codable {
    case stationary, walking, running, automotive, cycling, unknown
}

enum MotionConfidence: String, Codable {
    case low, medium, high
}

enum DeviceEvent: String, Codable {
    case screenUnlock, screenLock, chargingStart, chargingStop
}
```

### Storage

- SwiftData: `SensorReadingEntity`, indexed by day
- Deduplication: same timestamp + same sensor type = skip
- Query: `readings(for date: Date, type: SensorType?) -> [SensorReading]`
- Retention: 30 days, cleaned during nightly BGProcessingTask

## Part 3: PhoneInferenceEngine

### Interface

```swift
protocol PhoneInferring {
    func inferEvents(from readings: [SensorReading], on date: Date,
                     places: [KnownPlace]) -> [InferredEvent]
}
```

Input: all raw data for the day + known places. Output: existing `InferredEvent` array (reuses current model).

### Inference Rules (by priority)

**1. Sleep**
```
Night: last screenLock + chargingStart → no screenUnlock for > 2 hours → sleep
Day: no screenUnlock for > 40 minutes during 11:00-17:00 → nap
Confidence: .high if HealthKit sleep data available, .medium otherwise
```

**2. Commute/Travel**
```
motion = automotive + location changing continuously → commute
If origin is "home" and destination is "work" → "Commute to work"
Min duration: > 2 minutes
```

**3. Exercise**
```
walking > 10 min + high step density → "Walking exercise"
running (any duration) → "Running"
Location at known exercise place + any motion → "Exercise", confidence boost
```

**4. Location Stays**
```
Visit data: stayed at coordinates > 5 minutes
→ Query PlaceManager for place name
→ "At home" / "At school" / "At [place]"
```

**5. Blank Period Guessing**
```
Phone stationary + no screenUnlock > 15 min + not sleep
→ "Possibly away from phone"
→ If at gym location → "Possibly exercising?"
→ confidence: .low (triggers user confirmation)
```

**6. HealthKit Enhancement (when Watch available)**
```
Heart rate data → refine sleep accuracy to minute-level
Workout records → replace exercise guesses with exact data
Heart rate variability → assist exercise intensity judgment
```

### Event Merging

```
Consecutive same-type events with gap < 3 minutes → merge
Example: walking 3min → stationary 1min → walking 5min → "Walking 9 min"
```

### Adjusted Thresholds (record more, not less)

| Type | Threshold | Notes |
|------|-----------|-------|
| Sleep (night) | > 2h no unlock | |
| Nap (day) | > 40min no unlock | 11:00-17:00 only |
| Walking exercise vs walk | > 10min | < 10min still recorded as "walk" |
| Any walk | >= 1min | All walks recorded |
| Location stay | > 5min | Short cafe visit counts |
| Away from phone | > 15min | PE class, shower, etc. |
| Commute | > 2min | Short bike ride counts |

### Confidence Levels and User Interaction

| Confidence | Meaning | Timeline Style | Interaction |
|------------|---------|----------------|-------------|
| `.high` | Multi-source verified or direct HealthKit | Solid card, full color | Tap for details |
| `.medium` | Single source, clear pattern | Solid card, slightly lighter | Tap to modify |
| `.low` | Guess (blank period or conflicting data) | Dashed border, semi-transparent, ? icon | Tap to confirm/correct/dismiss |

## Part 4: PlaceManager

### Data Model

```swift
struct KnownPlace: Codable, Identifiable {
    let id: UUID
    var name: String?
    var category: PlaceCategory
    let coordinate: CLLocationCoordinate2D
    let radius: Double              // default 100m
    var visitCount: Int
    var totalDuration: TimeInterval
    var lastVisitDate: Date
    var isConfirmedByUser: Bool
}

enum PlaceCategory: String, Codable {
    case home       // nighttime primary
    case work       // weekday daytime primary
    case frequent   // visited >= 3 times in 7 days
    case visited    // visited but not frequent
}
```

### Auto-Learning Rules

```
Home: most-visited location during 22:00-6:00 + visited > 3 days → home
Work: most-visited location during weekday 8:00-18:00 + visited > 3 days + not home → work
Frequent: visited >= 3 times in 7 days → frequent
```

### Idle-Time Place Naming

```
Trigger conditions:
  1. New place (visitCount == 1) with stay > 15 minutes
  2. User is actively using app (foreground)
  3. Last prompt was > 30 minutes ago

Display: inline card in timeline (not popup, not notification)
  "You visited a new place (2:30 PM, stayed 40 min)"
  [Map thumbnail]
  [Name this place]  [Ignore]
```

### Coordinate Matching

```
Is user at known place?
  distance(current, KnownPlace.coordinate) < KnownPlace.radius
  Default radius: 100m
  User can adjust (e.g., university campus → 300m)
```

### Learning Feedback

When user confirms/corrects a `.low` confidence event:
- Event confidence → `.high`
- Pattern stored: (place + time_of_day + day_of_week) → activity
- Next occurrence: infer as `.medium` automatically

Simple mapping table `(place, timeSlot, weekday) → activity`, no ML needed.

## Part 5: Code Migration

### Migration Phases

```
Phase 1: Build infrastructure (no existing code changes)
  - SensorCollecting protocol
  - SensorDataStore (SwiftData Entity)
  - PlaceManager
  - PhoneInferenceEngine

Phase 2: Implement Collectors
  - MotionCollector (new)
  - PedometerCollector (new)
  - DeviceStateCollector (new)
  - LocationCollector (evolve from LocationService)
  - HealthKitCollector (extract from HealthKitTimelineDataProvider)

Phase 3: New PhoneTimelineDataProvider
  - Implements TimelineDataProviding protocol
  - Calls all Collectors → SensorDataStore → InferenceEngine
  - Replace AppContainer.makeTimelineProvider()

Phase 4: Expand BackgroundTaskManager
  - BGAppRefreshTask → invoke all Collectors
  - BGProcessingTask → full rebuild + cleanup

Phase 5: Cleanup
  - Remove HealthKitTimelineDataProvider (split into Collector + Engine)
  - Remove HealthKitEventInferenceEngine (merged into PhoneInferenceEngine)
  - Rename LocationService → LocationCollector
  - Remove ToDayWatch target + WatchConnectivity code
```

### AppContainer Change

```swift
// Before
static func makeTimelineProvider() -> any TimelineDataProviding {
    #if targetEnvironment(simulator)
    return MockTimelineDataProvider()
    #else
    if HKHealthStore.isHealthDataAvailable() {
        return HealthKitTimelineDataProvider()
    }
    return MockTimelineDataProvider()
    #endif
}

// After
static func makeTimelineProvider() -> any TimelineDataProviding {
    #if targetEnvironment(simulator)
    return MockTimelineDataProvider()
    #else
    return PhoneTimelineDataProvider(
        collectors: availableCollectors(),
        store: sensorDataStore,
        inferenceEngine: phoneInferenceEngine,
        placeManager: placeManager
    )
    #endif
}
```

### Watch App Removal

- Delete `ios/ToDay/ToDayWatch/` directory
- Remove Watch target from `project.yml`
- Remove `PhoneConnectivityManager` / `WatchConnectivityManager`
- Keep `HealthKitCollector` — Watch data read via iPhone HealthKit sync, zero extra code

### Permission Changes

```yaml
# New
NSMotionUsageDescription: "用于识别你的运动状态（步行、跑步、骑车等）"
NSLocationAlwaysAndWhenInUseUsageDescription: "用于自动记录你的位置变化和常去地点"

# Kept
NSHealthShareUsageDescription  # existing, Watch data optional enhancement

# Upgraded
Location: WhenInUse → Always (for Significant Location Change background wake)
```

## Scope

### This Iteration
- Location inference (home/away/commute + auto place learning)
- Motion activity (CMMotionActivity: walk/run/drive/cycle/stationary)
- Pedometer (steps, distance)
- Sleep inference (charging + screen usage patterns)
- Blank period smart guessing + user confirmation
- HealthKit as optional enhancement
- Remove standalone Watch app target

### Future Iterations
- EventKit calendar integration
- MusicKit
- Bluetooth device inference
- Manual place management page
- Screen time app categorization
- Photo capture recording
- Time pattern learning (improve guess accuracy)
