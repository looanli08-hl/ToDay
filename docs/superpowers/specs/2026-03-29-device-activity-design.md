# DeviceActivity Screen Time Integration Design

## Goal

Replace manual screen time input with automatic app usage category tracking via Apple's DeviceActivityFramework. Show categorized usage (social, games, entertainment, etc.) on Dashboard and timeline.

## Architecture

```
ToDay (Main App)
├── Request FamilyControls authorization
├── Embed DeviceActivityReport view
├── ScreenTimeCollector reads summary from App Group
└── Dashboard card + timeline events

ToDayScreenTimeReport (Extension Target)
└── TotalActivityReport: DeviceActivityReportScene
     └── Renders categorized usage as SwiftUI View
     └── Writes summary to App Group shared UserDefaults
```

## Data Flow

1. User grants Screen Time authorization (FamilyControls)
2. Extension receives device activity data via DeviceActivityReport
3. Extension renders categorized view AND writes summary to shared UserDefaults
4. Main app's ScreenTimeCollector reads summary from shared UserDefaults
5. PhoneInferenceEngine creates timeline events per category
6. Dashboard card shows total screen time from real data

## App Group

Uses existing `group.com.looanli.today` App Group for data sharing.

Shared UserDefaults key: `today.screenTime.summary`
Format: JSON-encoded `ScreenTimeSummary` struct with date, total time, and per-category breakdowns.

## Fallback

- No FamilyControls entitlement → gracefully skip, show "--" on card
- User denies authorization → same as above
- Feature flag `today.screenTime.useDeviceActivity` controls real vs mock data

## Files

### New
- `ToDayScreenTimeReport/` — Extension target directory
- `ToDayScreenTimeReport/TotalActivityReport.swift` — DeviceActivityReportScene implementation
- `ToDay/Data/Sensors/ScreenTimeCollector.swift` — Reads shared data, creates SensorReadings

### Modified
- `project.yml` — Add extension target
- `ToDay/Features/Settings/SettingsView.swift` — Screen Time authorization button
- `ToDay/Data/Sensors/PhoneInferenceEngine.swift` — Infer screen time events
- `ToDay/Features/Dashboard/DashboardViewModel.swift` — Read screen time from collector data
