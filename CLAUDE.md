# Unfold (working name)

iOS 自动生活记录 App — "把你的一天变成一张会让你想看的生活画卷"

## 当前方向

**被动记录，零输入，睡前打开一看就懂。不批判、不评价，只呈现"你今天是怎么度过的"。**

开发分支: `feature/phone-first-auto-recording`

## MVP 范围（严格）

1. CoreLocation 自动记录地点 + 停留时长
2. 地点自动标签（家、学校、咖啡厅等，CLGeocoder 反向地理编码）
3. 一张精美的"今日画卷"时间轴（设计是核心壁垒）

## 不做（MVP 阶段）

- ❌ 心率 / Apple Watch
- ❌ AI / Echo 伴侣
- ❌ 屏幕时间自动采集
- ❌ 分享卡片 / 社交
- ❌ 云端同步
- ❌ Web / Chrome Extension（已暂停）

## Tech Stack

- SwiftUI + iOS 17+
- CoreLocation (significant location changes + visits)
- CoreMotion (activity recognition)
- SwiftData (local-first storage)
- XcodeGen (project.yml → .xcodeproj)

## 项目结构

```
ios/ToDay/ToDay/
├── App/          — ToDayApp, AppContainer, AppRootScreen
├── Data/
│   ├── Sensors/  — LocationCollector, MotionCollector, PlaceManager, PhoneInferenceEngine, PhoneTimelineDataProvider
│   └── ...       — BackgroundTaskManager, SensorDataStore
├── Features/
│   ├── Today/    — TodayScreen, TodayViewModel, ScrollCanvas (DayScrollView, EventCardView)
│   ├── History/  — HistoryScreen
│   ├── Onboarding/
│   └── Settings/
├── Shared/       — SharedDataTypes, InferredEvent, DayTimeline
└── Models/
```

## 构建命令

```bash
# Build (simulator, no signing)
cd ios/ToDay && xcodegen generate && xcodebuild build -scheme ToDay -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Run tests
cd ios/ToDay && xcodebuild test -scheme ToDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Regenerate Xcode project after adding/removing files
cd ios/ToDay && xcodegen generate
```

## 验证流程

每次改动后必须：
1. `xcodegen generate`
2. Build 通过
3. 180+ tests 通过

## 竞品定位

- 直接竞品：Life Cycle（地点饼图）、Arc Timeline（时间线）
- 差异化：它们给数据，我们给感受。设计是唯一壁垒。

## UI Design

Also read `Projects/ToDay/.impeccable.md` for complete design context (users, brand, references, anti-references, motion, typography).

### Color System (established in TodayTheme.swift)
- Accent: Teal (#5B9A8B / #7CC1AF)
- Background: Warm cream (#F8F5F0) / Warm dark (#121213)
- Semantic: Sleep (indigo), Workout (amber), Walk (green), Commute (blue)
- Rule: No pure black, no pure gray — always tint toward warmth

### Design Principles
1. Reduction is the feature — strip to essence before adding
2. Apple-level quality bar — if it doesn't feel native iOS, it's not done
3. No generic AI aesthetics (no Inter, no purple gradients, no card-in-card)
4. Timeline is art, not data — design for the 11pm passive viewing moment
