# HarmonyOS ToDay — 与 iOS 版完全对齐

## 目标

将 `harmonyos/ToDay/` 的功能和 UI 与 `ios/ToDay/` 完全对齐。iOS 版是唯一参考标准。在修改任何 HarmonyOS 文件之前，先读对应的 iOS Swift 源文件理解完整实现，然后用 ArkTS/ArkUI 的方式忠实复刻。

**重要约束：**
- 这是 HarmonyOS NEXT (API 12+) 项目，使用 ArkTS + ArkUI 声明式框架
- 所有文件在 `harmonyos/ToDay/entry/src/main/ets/` 下
- iOS 参考源码在 `ios/ToDay/ToDay/` 下
- 不要改动 iOS 端任何文件
- 每个文件修改后必须确保 import 路径正确、类型完整、无编译错误
- 先读再改，不要凭猜测写代码

---

## Phase 1: 修复断裂的数据基础

当前 `SharedDataTypes.ets` 只有 UI 展示用的简单模型类和 mock builder 函数。而 `EventInferenceEngine.ets`、`DayDataAggregator.ets`、`TodayViewModel.ets` 以及所有组件都 import 了大量不存在的类型，导致整个数据层无法编译。

### 1.1 补全 SharedDataTypes.ets

**参考** `ios/ToDay/ToDay/Shared/SharedDataTypes.swift` 和 `ios/ToDay/ToDay/Shared/MoodRecord.swift`。

需要在 `model/SharedDataTypes.ets` 中补全以下所有类型（保留现有 builder 函数不变）：

```
// 枚举
export enum EventKind { Sleep, Workout, Commute, ActiveWalk, QuietTime, UserAnnotated, Mood }
// 注意：当前只有 Sleep/Workout/Walk/Focus/Mood/Recovery，要改成与 iOS 一致的 7 种

export enum EventConfidence { Low, Medium, High }

export enum SleepStage { Awake, REM, Light, Deep, Unknown }

export enum TimelineSource { Mock, HealthKit }

// 核心数据接口
export interface HeartRateSample { date: Date; value: number; }

export interface SleepSample { startDate: Date; endDate: Date; stage: SleepStage; }

export interface WorkoutSample {
  startDate: Date; endDate: Date; activityType: number;
  activeEnergy?: number; distance?: number; displayName: string;
}

export interface LocationVisit {
  latitude: number; longitude: number;
  arrivalDate: Date; departureDate: Date; placeName?: string;
}

export interface HourlyWeather {
  date: Date; temperature: number; condition: string; symbolName: string;
}

export interface PhotoReference {
  id: string; date: Date; color?: string;
}

export interface SleepStageSegment {
  start: Date; end: Date; stage: SleepStage;
}

export interface EventMetrics {
  averageHeartRate?: number;
  maxHeartRate?: number;
  minHeartRate?: number;
  heartRateSamples: HeartRateSample[];
  weather?: HourlyWeather;
  location?: LocationVisit;
  photos: PhotoReference[];
  sleepStages: SleepStageSegment[];
  stepCount?: number;
  activeEnergy?: number;
  distance?: number;
  workoutType?: string;
}

export interface InferredEvent {
  id: string;
  kind: EventKind;
  startDate: Date;
  endDate: Date;
  confidence: EventConfidence;
  isLive: boolean;
  displayName: string;
  userAnnotation?: string;
  subtitle?: string;
  associatedMetrics: EventMetrics;
  photoAttachments: PhotoReference[];
}

export interface DayTimeline {
  date: Date;
  summary: string;
  source: TimelineSource;
  stats: TimelineStat[];
  entries: InferredEvent[];
}

export interface TimelineStat {
  title: string;
  value: string;
}

export interface DayRawData {
  heartRateSamples: HeartRateSample[];
  stepSamples: Array<{ date: Date; value: number }>;
  activeEnergySamples: Array<{ date: Date; value: number }>;
  sleepSamples: SleepSample[];
  workouts: WorkoutSample[];
  activitySummary: { activeEnergyBurned: number; exerciseMinutes: number; standHours: number };
  locationVisits: LocationVisit[];
  hourlyWeather: HourlyWeather[];
  photos: PhotoReference[];
  moodRecords: MoodRecord[];
}

// Insight 相关
export interface InsightSummary {
  headline: string;
  narrative: string;
  badges: string[];
}

export interface WeeklyInsight {
  headline: string;
  narrative: string;
  badges: string[];
}

export interface RecentDayDigest {
  id: string;
  date: Date;
  moodEmoji: string;
  title: string;
  detail: string;
  notePreview?: string;
  dotColor: string;
}
```

同时导出 helper 函数：
```
export function startOfDay(date: Date): Date
export function formatClock(date: Date): string   // "HH:mm"
export function formatDateFull(date: Date): string // "yyyy · MM · dd EEE"
export function durationMinutes(start: Date, end: Date): number
```

### 1.2 更新 MoodRecord.ets

**参考** `ios/ToDay/ToDay/Shared/MoodRecord.swift`。

当前 MoodKind 只有 6 种，iOS 有 12 种。需要改为与 iOS 完全一致：

```
export type Mood = 'happy' | 'calm' | 'focused' | 'grateful' | 'excited' | 'tired' |
  'anxious' | 'sad' | 'irritated' | 'bored' | 'sleepy' | 'satisfied';
```

每种 mood 必须有对应的 emoji 和中文名映射（参考 iOS `MoodRecord.swift` 中的 emoji 和 displayName）：
- happy → 😊 开心
- calm → 🌿 平静
- focused → 🎯 专注
- grateful → 🙏 感恩
- excited → 🤩 兴奋
- tired → 😮‍💨 疲惫
- anxious → 😰 焦虑
- sad → 😢 难过
- irritated → 😤 烦躁
- bored → 😐 无聊
- sleepy → 😴 困倦
- satisfied → 😌 满足

### 1.3 修复 EventInferenceEngine.ets / DayDataAggregator.ets / TodayViewModel.ets

这些文件当前 import 了 SharedDataTypes 中不存在的类型。Phase 1.1 补全类型后，检查每个文件的 import 语句，确保所有引用的类型都存在且路径正确。逐个文件编译验证。

### 1.4 接通 AppContainer

**参考** `ios/ToDay/ToDay/App/AppContainer.swift`。

当前 `app/AppContainer.ets` 有完整的服务实例化逻辑但从未被使用。需要：
1. 在 `EntryAbility.ets` 或 `Index.ets` 中实例化 AppContainer
2. 将 `todayViewModel` 通过 @Provide/@Consume 或 props 传递到各 Page
3. 确保 TodayPage、HistoryPage、SettingsPage 都能访问到 ViewModel

---

## Phase 2: 色彩系统对齐

### 2.1 TodayTheme 完全重写

**参考** `ios/ToDay/ToDay/Features/Today/TodayTheme.swift`（读取此文件获取精确值）。

当前 HarmonyOS 的配色与 iOS 差异极大（例如 accent 是 #FF6B35 橘色，iOS 是 #C59661 青铜色）。必须完全对齐：

**结构色：**
- `background`: Light #FAFAF8 | Dark #111412
- `card`: Light #FFFFFF | Dark #1A1E1B
- `elevatedCard`: Light #F3EFE7 | Dark #202622
- `border`: Light #E2E0DC | Dark #313731

**文字色（改名为 ink 系列以匹配 iOS）：**
- `ink`: Light #1A1A1A | Dark #F4F2ED
- `inkSoft`: Light #3D3D3D | Dark #D8D3CC
- `inkMuted`: Light #8A8A8A | Dark #A9A49C
- `inkFaint`: Light #B8B8B8 | Dark #6A6F6A

**语义色：**
- `accent`: Light #C59661 | Dark #D9B27E
- `accentSoft`: Light #F5E9D8 | Dark #3A2E20
- `teal`: Light #5B9A8B | Dark #7CC1AF
- `tealSoft`: Light #E4F2EE | Dark #20352F
- `rose`: Light #C97B7B | Dark #D89898
- `roseSoft`: Light #F7E7E7 | Dark #392526
- `blue`: Light #7B9CC9 | Dark #9AB7DD
- `blueSoft`: Light #E8EFF9 | Dark #223043

**时间轴渐变色（新增）：**
- `scrollNight`: Light #202C57 | Dark #17203F
- `scrollSunrise`: Light #D28953 | Dark #A6633A
- `scrollGold`: Light #E9D18B | Dark #B39446
- `scrollNoon`: Light #BFDDF3 | Dark #385D7F
- `scrollSunset`: Light #E0A16D | Dark #A16A44
- `scrollViolet`: Light #5F4978 | Dark #3A2B4C

**活动类型色（新增）：**
- `workoutOrange`: Light #D76F3D | Dark #F09B66
- `walkGreen`: Light #5C9C70 | Dark #7CC18D
- `sleepIndigo`: Light #4A5FA9 | Dark #788DDB

**效果色（新增）：**
- `glass`: 白色 opacity 0.18

**布局尺寸（更新）：**
- `pagePadding`: 20 (现在是 16，改为 20)
- `sectionGap`: 18 (现在是 14)
- `cardRadius`: 20 (现在是 22)
- `chipRadius`: Capsule 样式

### 2.2 更新所有组件的颜色引用

所有现有组件（EventCardView、DayScrollView、QuickRecordSheet 等）中调用 TodayTheme 的方式需要统一更新，匹配新的方法名和签名。

---

## Phase 3: TodayPage 完全重构

**参考** `ios/ToDay/ToDay/Features/Today/TodayScreen.swift`（读取此文件）。

当前 TodayPage 是一个平铺的 mock 卡片列表，与 iOS 的精细布局差距巨大。需要完全重构为以下结构：

### 3.1 页面整体结构

```
Scroll {
  Column(spacing: 18) {
    // 1. 头部区域
    HeaderSection()

    // 2. 概览统计（水平滚动）
    OverviewStatsRow()

    // 3. 今日脉络（Flow Signature）
    FlowSignatureSection()

    // 4. 今日时间轴（核心画布）
    DayScrollView()

    // 5. 自动总结（条件显示）
    InsightSummarySection()

    // 6. 最近 7 天（条件显示）
    WeeklyInsightSection()

    // 7. 最近记录（条件显示）
    RecentDaysSection()
  }
}

// 8. 底部悬浮操作栏
BottomActionBar()
```

### 3.2 头部区域

**参考** `TodayScreen.swift` 头部布局：
- 日期文字：等宽字体，"yyyy · MM · dd EEE" 格式
- 标题："今日画卷"，大号衬线斜体（iOS 33pt，ArkUI 用类似大号加粗）
- 副标题描述文字
- 右侧 3 个圆形图标按钮（心形=快速记录, 分享, 刷新），42×42，圆形背景

### 3.3 概览统计卡片

**参考** `TodayFlowViews.swift` 中的 `OverviewStatsRow`：
- 水平 Scroll，间距 10
- 每个卡片固定宽 92，padding 14h/16v
- 显示：小标签（11pt）+ 大数值（24pt 粗等宽）+ 颜色背景
- 数据从 ViewModel.timeline.stats 取

### 3.4 Flow Signature 可视化

**参考** `TodayFlowViews.swift` 中的 `TodayFlowSignatureView`：
- 高度 82
- 根据心率数据绘制类河流曲线
- 使用 Canvas 或 Path 绘制贝塞尔曲线
- 渐变填充：从 scrollNight → scrollSunrise → scrollGold → scrollNoon → scrollSunset → scrollViolet
- 高活动量的点有标记圆点
- 如果无数据则不显示

### 3.5 DayScrollView 时间轴画布

**参考** `ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift`（读取此文件）。

这是核心差异最大的组件，需要完全重写：

布局结构：
```
Column {
  // 渐变背景（24 小时颜色过渡）
  ForEach(时间轴条目) {
    Row {
      // 左列：时间标签（44pt 宽，等宽字体，白色半透明）
      // 中列：时间线指示器（圆点 + 竖线连接，20pt 宽）
      // 右列：事件卡片（EventCardView）或心情标记（MoodMarker）
    }

    // 如果相邻事件间有 ≥15 分钟空白，显示"留白"行
    // 留白行高度根据时长：<15min=8, 15-60=24, 60-180=36, >180=48
    // 留白行可点击，触发 AnnotationSheet
  }

  // 如果是今天，显示当前时间指针（白色圆点 + 横线）
}
```

**渐变背景**实现：使用 linearGradient 从 scrollNight 过渡到 scrollViolet，对应 24 小时的颜色变化。

**时间线指示器**：每个事件左侧有一个彩色圆点（颜色与事件类型对应），圆点之间用竖线连接。

**当前时间指针**：仅今天显示，白色圆点 6pt + 水平线延伸到右侧。

### 3.6 EventCardView 重写

**参考** `ios/ToDay/ToDay/Features/Today/ScrollCanvas/EventCardView.swift`（读取此文件）。

完全重新实现 EventCardView：
- 左侧 4pt 粗的彩色竖条（颜色根据事件类型）
- 顶部行：事件图标（30×30）+ 名称（15pt semi-bold）+ 时长（13pt 粗等宽）
- 描述行：subtitle 文字
- 指标行：距离、热量、心率等小徽章
- 睡眠事件：底部显示 SleepStageRibbon（深/浅/REM/清醒 的彩色比例条，高 6pt）
- 照片徽章（如有照片）
- 静息时间(QuietTime)：虚线边框，"点击记录" 提示，玻璃效果背景
- 进行中(isLive)：脉冲指示器

**事件卡片背景色**（根据 iOS `EventCardView` 的 cardFill）：
- Sleep: sleepIndigo, opacity 0.78
- Workout(cycling): blue, opacity 0.86
- Workout(running): workoutOrange, opacity 0.9
- Workout(other): rose, opacity 0.88
- Commute/ActiveWalk: walkGreen, opacity 0.86
- QuietTime: glass (white 0.18)
- UserAnnotated: teal, opacity 0.82
- Mood: accent

**心情标记**（MoodMarker）：与事件卡片不同，是小型水平胶囊 pill：
- emoji + 心情名 + 时间
- 最小高度 38

### 3.7 底部操作栏

**参考** `TodayScreen.swift` 底部的操作栏：

**无活动记录时：**
- 大按钮 "记录此刻"（accent 色）
- 下方小字 "打点或开始一段状态"

**有活动记录时：**
- 显示 "进行中" badge + 当前心情 + 开始时间
- 两个按钮："补一个打点"（次要）+ "结束这段状态"（teal 色）

### 3.8 接入 ViewModel 数据

TodayPage 必须从 TodayViewModel 获取所有数据，不再使用 buildTodayStats() 等 mock builder：
- `timeline` → 时间轴事件列表
- `insightSummary` → 自动总结
- `weeklyInsight` → 周洞察
- `recentDigests` → 最近记录
- `activeRecord` → 当前活动记录状态
- `isLoading` → 加载状态

---

## Phase 4: 弹窗交互

### 4.1 QuickRecordSheet

**参考** `ios/ToDay/ToDay/Features/Today/QuickRecordSheet.swift`（读取此文件）。

当前组件已存在但未接入。需要：
1. 将心情选项从 6 个扩展到 12 个（3×4 网格）
2. 接入 ViewModel 的 startMoodRecord / finishActiveMoodRecord
3. 从 TodayPage 底部栏和头部按钮触发显示
4. 实现"灵活"和"打点"两种模式
5. 添加时间选择器（当前/提前 15/30/60 分钟）
6. 照片区域保持占位符即可（后续接入）

### 4.2 EventDetailView 弹窗

**参考** `ios/ToDay/ToDay/Features/Today/EventDetailView.swift`（读取此文件）。

从时间轴点击事件卡片触发。需要实现：
1. 头部：事件名称（大号衬线字体）+ 时间范围 badge + 时长 + 天气/位置 chips
2. 照片区域：水平滚动，150×150 缩略图
3. 心率图表：用 Canvas 绘制折线图（catmull-rom 平滑插值）+ 面积填充
4. 三列指标卡：平均心率、最高心率、最低心率 / 步数、热量、距离
5. 睡眠事件：详细阶段条 + 各阶段时长网格（深睡/浅睡/快眼动/清醒）
6. 静息/低置信度事件："标注这段时间" 按钮

### 4.3 AnnotationSheet

**参考** `ios/ToDay/ToDay/Features/Today/AnnotationSheet.swift`（读取此文件）。

从时间轴的"留白"行点击触发。需要实现：
1. 标题 "标注这段时间" + 时间范围
2. 3×4 预设网格（12 个常见活动 + 图标）：工作、阅读、学习、做饭、用餐、家务、购物、社交、发呆、散步、午休、其他
3. 自定义输入框
4. "确认标注" 按钮
5. 接入 ViewModel.annotateEvent()

---

## Phase 5: HistoryPage 月历视图

**参考** `ios/ToDay/ToDay/Features/History/HistoryScreen.swift`（读取此文件）。

当前 HistoryPage 是简单的 14 天摘要列表，iOS 是完整的月历网格。需要重构为：

### 5.1 月历视图

```
Column {
  // 周洞察卡片（顶部）
  WeeklyInsightView()

  // 月份选择器（← 月份标题 →）
  MonthPicker()

  // 星期标题行（日 一 二 三 四 五 六）
  WeekdayHeader()

  // 日历网格（7 列）
  Grid(7 columns) {
    ForEach(days) {
      CalendarDayCell()
    }
  }
}
```

### 5.2 CalendarDayCell 重写

**参考** `ios/ToDay/ToDay/Features/History/HistoryScreen.swift` 中的 `HistoryCalendarDayCell`：
- 高度 74
- 日期数字（15pt，今天加粗）
- 主情绪 emoji（如有）
- 底部 6 色预览条（显示当天事件类型分布，8pt 高）
- 今天特殊样式：accentSoft 背景 + accent 边框
- 点击导航到 HistoryDayDetail

### 5.3 HistoryDayDetailScreen

**参考** `ios/ToDay/ToDay/Features/History/HistoryDayDetailScreen.swift`（读取此文件）。

当前是骨架。需要实现：
1. 摘要卡片（accentSoft 背景 + eyebrow label + 标题 + 叙述 + badge 行）
2. 时间轴画布（复用 DayScrollView，但无当前时间指针）
3. 手动记录区（标题 "手动记录" + 每条记录的 emoji/心情/时间/备注卡片）

---

## Phase 6: SettingsPage 完善

**参考** `ios/ToDay/ToDay/Features/Settings/SettingsView.swift`（读取此文件）。

当前 SettingsPage 极简。需要补全：

1. **数据权限**区域：健康数据 / 位置 / 照片，各显示当前状态
2. **隐私**区域：隐私政策 / 服务条款 / 数据说明
3. **关于**区域：版本号 / 联系邮箱 / 官网
4. **数据管理**：
   - "清除所有标注和记录" 按钮（红色，destructive）
   - 确认对话框
   - 成功 toast 动画

保留现有的主题切换功能。

---

## Phase 7: Onboarding 引导页

**参考** `ios/ToDay/ToDay/Features/Onboarding/OnboardingView.swift`（读取此文件）。

新增 `pages/OnboardingPage.ets`：
1. 居中布局
2. 标题 "ToDay"（42pt）
3. 副标题 "把每一天变成可见的故事"
4. 3 行权限说明（心形=健康数据，定位=位置，照片=照片），每行图标 + 说明
5. "开始记录" 主按钮
6. "稍后设置" 次要按钮
7. 在 Index.ets 中根据首次启动状态决定显示 Onboarding 还是 Tab 页

---

## Phase 8: 导航与页面路由

### 8.1 Tab 导航

**参考** `ios/ToDay/ToDay/App/AppRootScreen.swift`：
- 3 个 Tab：今日 / 回看 / 设置
- Tab 图标使用 SymbolGlyph 或相近图标
- Tab 激活色使用 teal 色

### 8.2 页面导航

在 `main_pages.json` 中注册所有新页面路由：
- pages/Index（主入口）
- pages/OnboardingPage（引导）
- pages/HistoryDayDetail（历史日详情）

使用 Navigation + NavPathStack 实现 History → DayDetail 的 push 导航。

---

## Phase 9: 动画与过渡

**参考** iOS 的动画参数：
- 心情选择：easeInOut 0.15s
- Sheet 弹出/收起：默认 spring 动画
- 成功 toast：spring(response 0.28, dampingFraction 0.82)
- 事件展开：opacity + move(edge: top) 组合
- 当前时间指针：每 60 秒更新位置

在 ArkUI 中使用 `animateTo()` 和 `.transition()` 实现对应效果。

---

## Phase 10: Mock 数据验证

完成以上所有修改后，确保 Mock 数据流完整运行：
1. AppContainer 正确初始化所有 service
2. MockDataProvider 生成 DayRawData
3. EventInferenceEngine 将 DayRawData 转为 InferredEvent[]
4. DayDataAggregator 组装 DayTimeline
5. TodayViewModel 加载并暴露数据
6. TodayPage 正确渲染所有数据
7. HistoryPage 月历正确显示 14 天数据
8. 所有弹窗可正常打开和交互

---

## 文件清单

需要修改的现有文件：
- `model/SharedDataTypes.ets` — 补全所有核心类型
- `model/MoodRecord.ets` — 12 种心情
- `common/theme/TodayTheme.ets` — 完全重写色彩系统
- `pages/Index.ets` — AppContainer 接入、Onboarding 判断
- `pages/TodayPage.ets` — 完全重构
- `pages/HistoryPage.ets` — 月历视图重构
- `pages/SettingsPage.ets` — 补全所有设置项
- `pages/HistoryDayDetail.ets` — 完整实现
- `components/today/DayScrollView.ets` — 时间轴画布重写
- `components/today/EventCardView.ets` — 按 iOS 规格重写
- `components/today/EventDetailView.ets` — 完整实现
- `components/today/QuickRecordSheet.ets` — 12 心情 + 接入 ViewModel
- `components/today/AnnotationSheet.ets` — 12 预设 + 接入 ViewModel
- `components/today/FlowSignatureView.ets` — 心率河流曲线
- `components/today/OverviewStatCard.ets` — 按 iOS 92pt 规格
- `components/today/RecentDayCard.ets` — 按 iOS 样式
- `components/history/CalendarDayCell.ets` — 月历单元格重写
- `components/history/WeeklyInsightView.ets` — 按 iOS 样式
- `common/components/ContentCard.ets` — 更新 padding 和圆角
- `common/components/EyebrowLabel.ets` — 修复字体引用
- `common/components/FlexibleBadgeRow.ets` — 按 iOS 样式
- `common/components/IntensityBar.ets` — 按 iOS 样式
- `data/EventInferenceEngine.ets` — 修复 import，确保编译
- `data/DayDataAggregator.ets` — 修复 import，确保编译
- `data/MockDataProvider.ets` — 修复 import，确保编译
- `data/StorageService.ets` — 修复 import，确保编译
- `viewmodel/TodayViewModel.ets` — 修复 import + 接入 pages
- `app/AppContainer.ets` — 修复 import + 被 Index 使用
- `entryability/EntryAbility.ets` — 按需调整

需要新建的文件：
- `pages/OnboardingPage.ets` — 引导页

需要更新的配置：
- `entry/src/main/resources/base/profile/main_pages.json` — 添加 OnboardingPage 路由
