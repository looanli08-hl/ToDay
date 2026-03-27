# Codex Prompt: 构建 ToDay HarmonyOS NEXT 版本

## 任务概述

你需要为 HarmonyOS NEXT 平台从零构建 ToDay App 的完整手机端应用。ToDay 是一个智能手表生活记录与可视化 App，核心功能是将华为手表的健康数据（心率、步数、睡眠、运动）推断为语义化的日常事件，呈现为"今日画卷"——一条从凌晨到深夜的可视化时间轴。用户还可以手动记录心情状态。

**已有的 iOS 版本在 `ios/ToDay/` 目录下，仅供参考逻辑和设计，不要复制 Swift 代码。所有代码用 ArkTS 从零编写。**

项目输出目录：`harmonyos/ToDay/`

---

## 一、项目结构

```
harmonyos/ToDay/
├── entry/src/main/
│   ├── ets/
│   │   ├── app/
│   │   │   └── AppContainer.ets          // 依赖注入容器
│   │   ├── common/
│   │   │   ├── theme/
│   │   │   │   └── TodayTheme.ets        // 设计 tokens（颜色、字号、间距）
│   │   │   └── components/
│   │   │       ├── ContentCard.ets        // 通用卡片容器
│   │   │       ├── EyebrowLabel.ets       // 小标题标签
│   │   │       ├── FlexibleBadgeRow.ets   // 自适应标签行
│   │   │       └── IntensityBar.ets       // 强度进度条
│   │   ├── model/
│   │   │   ├── SharedDataTypes.ets        // 核心数据模型
│   │   │   └── MoodRecord.ets            // 心情记录模型
│   │   ├── data/
│   │   │   ├── HealthDataProvider.ets     // 华为 Health Kit 数据获取
│   │   │   ├── EventInferenceEngine.ets   // 事件推断引擎
│   │   │   ├── MockDataProvider.ets       // 模拟数据（开发测试用）
│   │   │   ├── DayDataAggregator.ets      // 多源数据聚合
│   │   │   ├── LocationService.ets        // 定位服务
│   │   │   ├── WeatherService.ets         // 天气服务
│   │   │   └── StorageService.ets         // 本地持久化（RDB）
│   │   ├── viewmodel/
│   │   │   └── TodayViewModel.ets         // 主 ViewModel
│   │   ├── pages/
│   │   │   ├── Index.ets                  // 主 Tab 页（今日 / 回看 / 设置）
│   │   │   ├── TodayPage.ets             // 今日画卷页
│   │   │   ├── HistoryPage.ets           // 历史回看页
│   │   │   ├── SettingsPage.ets          // 设置页
│   │   │   └── HistoryDayDetail.ets      // 单日详情页
│   │   └── components/
│   │       ├── today/
│   │       │   ├── OverviewStatCard.ets   // 概览统计卡
│   │       │   ├── FlowSignatureView.ets  // 日节律流线图
│   │       │   ├── DayScrollView.ets      // 时间轴滚动视图
│   │       │   ├── EventCardView.ets      // 事件卡片
│   │       │   ├── QuickRecordSheet.ets   // 快速记录弹窗
│   │       │   ├── EventDetailView.ets    // 事件详情弹窗
│   │       │   ├── AnnotationSheet.ets    // 标注弹窗
│   │       │   └── RecentDayCard.ets      // 最近日卡片
│   │       └── history/
│   │           ├── WeeklyInsightView.ets  // 周洞察视图
│   │           └── CalendarDayCell.ets    // 日历日期格子
│   ├── resources/
│   │   └── base/
│   │       └── element/
│   │           └── string.json            // 中文字符串资源
│   └── module.json5                       // 模块配置
├── build-profile.json5
└── oh-package.json5
```

---

## 二、设计规范（Design Tokens）

以下是从 iOS 版本提取的精确设计变量，两端必须保持一致。在 `TodayTheme.ets` 中定义。

### 颜色系统

所有颜色支持 light/dark 模式。格式：`{ light: '#RRGGBB', dark: '#RRGGBB' }`

```typescript
// 基础色板
background:    { light: '#FAFAF8', dark: '#111412' }
card:          { light: '#FFFFFF', dark: '#1A1E1B' }
elevatedCard:  { light: '#F3EFE7', dark: '#202622' }
ink:           { light: '#1A1A1A', dark: '#F4F2ED' }
inkSoft:       { light: '#3D3D3D', dark: '#D8D3CC' }
inkMuted:      { light: '#8A8A8A', dark: '#A9A49C' }
inkFaint:      { light: '#B8B8B8', dark: '#6A6F6A' }
border:        { light: '#E2E0DC', dark: '#313731' }

// 强调色
accent:        { light: '#C59661', dark: '#D9B27E' }
accentSoft:    { light: '#F5E9D8', dark: '#3A2E20' }
teal:          { light: '#5B9A8B', dark: '#7CC1AF' }
tealSoft:      { light: '#E4F2EE', dark: '#20352F' }
rose:          { light: '#C97B7B', dark: '#D89898' }
roseSoft:      { light: '#F7E7E7', dark: '#392526' }
blue:          { light: '#7B9CC9', dark: '#9AB7DD' }
blueSoft:      { light: '#E8EFF9', dark: '#223043' }

// 时间轴渐变色（画卷背景）
scrollNight:   { light: '#202C57', dark: '#17203F' }
scrollSunrise: { light: '#D28953', dark: '#A6633A' }
scrollGold:    { light: '#E9D18B', dark: '#B39446' }
scrollNoon:    { light: '#BFDDF3', dark: '#385D7F' }
scrollSunset:  { light: '#E0A16D', dark: '#A16A44' }
scrollViolet:  { light: '#5F4978', dark: '#3A2B4C' }

// 事件类型专用色
workoutOrange: { light: '#D76F3D', dark: '#F09B66' }
walkGreen:     { light: '#5C9C70', dark: '#7CC18D' }
sleepIndigo:   { light: '#4A5FA9', dark: '#788DDB' }
```

### 字体规范

```typescript
// 页面大标题
titleLarge:  { size: 33, weight: 'regular', family: 'serif', italic: true }
// 卡片标题
titleCard:   { size: 23, weight: 'regular', family: 'serif', italic: true }
// 详情标题
titleDetail: { size: 28, weight: 'regular', family: 'serif', italic: true }
// 小标题标签 (eyebrow)
eyebrow:     { size: 11, weight: 'medium', family: 'monospace', tracking: 2.4 }
// 正文
body:        { size: 14, weight: 'regular' }
// 统计数值
statValue:   { size: 24, weight: 'bold', family: 'monospace' }
// 时间标签
timeLabel:   { size: 12, weight: 'medium', family: 'monospace' }
// 时钟标签
clockLabel:  { size: 11, weight: 'medium', family: 'monospace' }
```

### 间距与圆角

```typescript
spacing:   { xs: 4, sm: 8, md: 14, lg: 18, xl: 20, xxl: 24 }
radius:    { card: 20, button: 16, statCard: 16, capsule: 999, eventCard: 14 }
padding:   { cardInner: 18, screenHorizontal: 20 }
```

### 时间轴画卷渐变（从上到下对应 0:00 → 24:00）

```typescript
scrollGradientStops: [
  { color: scrollNight,   position: 0.0 },
  { color: scrollNight,   position: 5/24 },
  { color: scrollSunrise, position: 7/24 },
  { color: scrollGold,    position: 12/24 },
  { color: scrollNoon,    position: 14/24 },
  { color: scrollSunset,  position: 18/24 },
  { color: scrollViolet,  position: 20/24 },
  { color: scrollNight,   position: 1.0 }
]
```

---

## 三、数据模型

### EventKind 事件类型枚举

```typescript
enum EventKind {
  SLEEP = 'sleep',
  WORKOUT = 'workout',
  COMMUTE = 'commute',
  ACTIVE_WALK = 'activeWalk',
  QUIET_TIME = 'quietTime',
  USER_ANNOTATED = 'userAnnotated',
  MOOD = 'mood'
}
```

每种事件类型对应的 UI 属性：

| EventKind | icon | flowColor | flowBackground | flowIntensity | badgeTitle |
|-----------|------|-----------|----------------|---------------|------------|
| sleep | 🌙 | blue | blueSoft | 0.24 | 睡眠 |
| workout | 🏃 | rose | roseSoft | 0.82 | 运动 |
| commute | 🚶 | rose | roseSoft | 0.68 | 通勤 |
| activeWalk | 👟 | rose | roseSoft | 0.68 | 步行 |
| quietTime | ☁️ | inkFaint | elevatedCard | 0.20 | 留白 |
| userAnnotated | ⌘ | teal | tealSoft | 0.90 | 标注 |
| mood | ✦ | accent | accentSoft | 0.48 | 心情 |

### EventConfidence

```typescript
enum EventConfidence { LOW = 0, MEDIUM = 1, HIGH = 2 }
```

### InferredEvent 推断事件

```typescript
interface InferredEvent {
  id: string                          // UUID
  kind: EventKind
  startDate: number                   // 时间戳 ms
  endDate: number
  confidence: EventConfidence
  isLive: boolean                     // 当前进行中
  displayName: string                 // "睡眠" / "活跃步行" / "安静的上午"
  userAnnotation?: string             // 用户自定义标注名
  subtitle?: string                   // 描述行，如 "深睡 3.5 小时, 浅睡 2 小时"
  associatedMetrics?: EventMetrics
  photoAttachments: MoodPhotoAttachment[]
}
```

`resolvedName` = `userAnnotation ?? displayName`

`isBlankCandidate` = `kind === QUIET_TIME || confidence <= LOW`（表示这是可被用户标注的空白段）

### EventMetrics

```typescript
interface EventMetrics {
  averageHeartRate?: number
  maxHeartRate?: number
  minHeartRate?: number
  heartRateSamples?: HeartRateSample[]  // { date: number, value: number }
  weather?: HourlyWeather
  location?: LocationVisit
  photos?: PhotoReference[]
  sleepStages?: SleepStageSegment[]
  stepCount?: number
  activeEnergy?: number     // 千卡
  distance?: number         // 米
  workoutType?: string      // "跑步" / "骑行" / etc.
}
```

### SleepStage

```typescript
enum SleepStage { AWAKE = 'awake', REM = 'rem', LIGHT = 'light', DEEP = 'deep', UNKNOWN = 'unknown' }
```

睡眠阶段颜色映射：deep→scrollNight, light→sleepIndigo, rem→scrollSunrise, awake→scrollGold, unknown→inkFaint

### MoodRecord 心情记录

```typescript
interface MoodRecord {
  id: string
  mood: Mood
  note: string
  createdAt: number
  endedAt?: number
  isTracking: boolean         // 是否正在进行
  captureMode: 'point' | 'session'
  photoAttachments: MoodPhotoAttachment[]
}
```

### Mood 枚举（12 种心情）

| key | 中文名 | emoji |
|-----|--------|-------|
| happy | 开心 | 😊 |
| calm | 平静 | 🌿 |
| focused | 专注 | 🎯 |
| grateful | 感恩 | 🙏 |
| excited | 兴奋 | 🤩 |
| tired | 疲惫 | 😴 |
| anxious | 焦虑 | 😰 |
| sad | 难过 | 😔 |
| irritated | 烦躁 | 😤 |
| bored | 无聊 | 🥱 |
| sleepy | 困倦 | 😪 |
| satisfied | 满足 | ☺️ |

心情→颜色映射（用于 RecentDayCard / 日历格子）：
happy→accent, calm→teal, focused→teal, grateful→scrollGold, excited→workoutOrange, tired→blue, anxious→scrollViolet, sad→sleepIndigo, irritated→rose, bored→inkFaint, sleepy→blue, satisfied→scrollSunrise

### HourlyWeather

```typescript
interface HourlyWeather {
  date: number
  temperature: number         // 摄氏度
  condition: WeatherCondition // clear/cloudy/rain/snow/fog/wind/thunderstorm/unknown
  symbolName: string
}
```

天气中文映射：clear→晴, cloudy→多云, rain→雨, snow→雪, fog→雾, wind→风, thunderstorm→雷暴, unknown→未知

### DayTimeline

```typescript
interface DayTimeline {
  date: number
  summary: string
  source: 'mock' | 'healthKit'
  stats: TimelineStat[]
  entries: InferredEvent[]
}
```

### DayRawData（原始数据聚合）

```typescript
interface DayRawData {
  date: number
  activitySummary?: ActivitySummaryData
  hourlyWeather: HourlyWeather[]
  locationVisits: LocationVisit[]
  photos: PhotoReference[]
  heartRateSamples: DateValueSample[]  // { startDate, endDate, value (bpm) }
  stepSamples: DateValueSample[]       // { startDate, endDate, value (步数) }
  sleepSamples: SleepSample[]          // { startDate, endDate, stage }
  workouts: WorkoutSample[]            // { startDate, endDate, activityType, activeEnergy?, distance? }
  activeEnergySamples: DateValueSample[]
  moodRecords: MoodRecord[]
}
```

---

## 四、事件推断引擎（核心算法）

这是整个 App 的核心逻辑。将华为手表的原始健康数据转化为语义化事件。

### 算法流程

输入：`DayRawData` + 日期
输出：`InferredEvent[]`（按时间排序）

```
1. 如果没有任何健康数据，返回一个全天 quietTime 事件
2. 构建高置信度事件（sleep + workout）
   - 睡眠：将连续的睡眠样本（间隔 ≤ 5 分钟）合并为一个睡眠事件
   - 运动：从运动记录直接映射
   - 排列到时间轴上，记录已占用区间
3. 构建中置信度事件（movement）
   - 将步数样本按 5 分钟间隔聚类
   - 结合心率分析每个聚类：
     - 静息心率基线 = 所有心率样本中最低 25% 的平均值
     - 高心率阈值 = 静息心率 + 30
     - 高步频阈值 = 60 步/分钟
   - 分类规则：
     - 高心率 + 高步频 → activeWalk (HIGH)
     - 高心率 + 低步频 → quietTime (MEDIUM)
     - 正常心率 + 高步频 → activeWalk (MEDIUM)
     - 其他：根据时间段判断 commute（早 7-9 / 晚 17-19 且 15-60 分钟）或 activeWalk
   - 过滤：仅保留 ≥ 5 分钟的事件
4. 填充 quietTime 事件
   - 在高/中置信度事件的间隙中填入 quietTime
   - 按时段边界（6:00, 12:00, 14:00, 18:00, 22:00）分段
   - 命名规则：
     - 6-12: "安静的上午"
     - 12-14: "午间时光"
     - 14-18: "安静的下午"
     - 18-22: "安静的夜晚"
     - 其他: "安静时光"
   - 相邻同类型 quietTime（间隔 < 1 秒，总时长 < 3 小时）合并
5. 为每个事件附加 metrics
   - 匹配时间段内的心率样本 → averageHeartRate, maxHeartRate, minHeartRate
   - 最近的天气数据
   - 重叠的地点访问记录
   - 时间段内的照片
   - 步数和消耗能量的比例分配
6. 构建 mood 事件（从用户手动记录）
7. 合并排序所有事件
```

### 关键常量

```typescript
MERGE_GAP_THRESHOLD = 5 * 60 * 1000        // 5 分钟（合并间隔）
MINIMUM_INFERRED_DURATION = 5 * 60 * 1000   // 5 分钟（最短推断时长）
MOVEMENT_MIN_CLUSTER_DURATION = 10 * 60 * 1000  // 10 分钟（步行聚类最短时长）
RESTING_HR_PERCENTILE = 0.25               // 取最低 25% 心率作为基线
ELEVATED_HR_OFFSET = 30                     // 高于静息心率 30 bpm 算活跃
HIGH_CADENCE_THRESHOLD = 60                 // 60 步/分钟
COMMUTE_HOURS_MORNING = [7, 8]             // 早通勤
COMMUTE_HOURS_EVENING = [17, 18]           // 晚通勤
COMMUTE_DURATION_RANGE = [15*60*1000, 60*60*1000]  // 15-60 分钟
QUIET_MERGE_MAX_DURATION = 3 * 60 * 60 * 1000  // quietTime 合并上限 3 小时
```

### 睡眠事件 subtitle 格式

按 [深睡, 浅睡, 快眼动, 清醒] 顺序列出各阶段时长：
`"深睡 3.5 小时, 浅睡 2 小时, 快眼动 1.5 小时, 清醒 0.5 小时"`

### 运动事件 subtitle 格式

`"{时长} 分钟 · {热量} 千卡 · {距离}"` （各字段可选）

### 步行事件 subtitle 格式

`"{步数} 步 · 平均 {心率} 次/分"`

---

## 五、华为 Health Kit API 映射

用华为运动健康服务（Health Kit）替代 Apple HealthKit。

### 需要获取的数据类型

| 数据 | 华为 Health Kit DataType | 说明 |
|------|-------------------------|------|
| 心率 | `DataType.DT_INSTANTANEOUS_HEART_RATE` | 连续心率采样 |
| 步数 | `DataType.DT_CONTINUOUS_STEPS_DELTA` | 增量步数 |
| 活动能量 | `DataType.DT_CONTINUOUS_CALORIES_BURNT` | 消耗热量 |
| 睡眠 | `DataType.DT_CONTINUOUS_SLEEP` | 睡眠分段（含阶段） |
| 运动记录 | `DataType.DT_CONTINUOUS_EXERCISE_BEGIN_END` | 运动开始/结束 |

### 权限申请

在 `module.json5` 中配置：
- `ohos.permission.HEALTH_READ` — 读取健康数据
- `ohos.permission.APPROXIMATELY_LOCATION` — 大致定位（天气用）
- `ohos.permission.READ_IMAGEVIDEO` — 读取照片

### 数据获取流程

1. 调用 `huawei.health.HealthDataController` 请求授权
2. 使用 `readData()` 按时间范围查询各类型数据
3. 将华为数据格式转换为 `DayRawData` 中的通用类型
4. 注意：华为睡眠数据的阶段枚举可能与 Apple 不同，需要做映射

### Mock 模式

- 提供 `MockDataProvider`，生成一天的模拟数据
- 模拟数据应包含：2 段睡眠（昨晚+午觉）、1-2 次运动、多段步行、若干安静时段
- 当 Health Kit 不可用时（如模拟器）自动降级到 Mock 模式

---

## 六、UI 组件规格

### 6.1 主页结构 (TodayPage)

从上到下：

1. **Header 区域**
   - 日期行：格式 `"2026 · 03 · 15 周日"` — eyebrow 字体
   - 标题："今日画卷" — titleLarge 字体（serif italic）
   - 右侧三个圆形按钮（42x42）：心情记录 ❤️、分享 ↗、刷新 ↻
   - 摘要文字：来自 timeline.summary，默认 "先把今天铺成一张可回看的画卷，再决定哪些片段值得长期留下。" — body 字体 inkMuted 色

2. **概览统计条**（水平滚动）
   - 4 个 OverviewStatCard，每个 92px 宽
   - 片段数 (blue/blueSoft) | 记录数 (teal/tealSoft) | 备注数 (rose/roseSoft) | 来源 (accent/accentSoft)
   - 每个卡片：上方小标签（11px inkMuted），下方数值（statValue 字体，对应 tint 色）
   - 圆角 16，1px border 描边

3. **今日脉络（Flow Signature）**—— ContentCard 包裹
   - eyebrow: "今日脉络"
   - 标题: "今日脉络" — titleCard
   - 描述: "把一天里的起伏、停顿和推进压成一条流线..." — body inkMuted
   - **流线图**（82px 高）：
     - X 轴 = 0:00 到 24:00
     - Y 轴 = 心率归一化后的振幅
     - 绘制方式：上边界线、中心线、下边界线围成流体形状
     - 颜色：根据事件类型分段渐变（sleep→blue, workout→rose, quiet→inkFaint, mood→accent）
     - 峰值点（intensity ≥ 0.75 且为 workout/activeWalk）显示 7px 圆点
   - 底部时间刻度：00:00 / 06:00 / 12:00 / 18:00 / 24:00

4. **今日时间轴（Day Scroll Canvas）**
   - eyebrow: "今日时间轴"
   - 标题: "今日时间轴" — titleCard
   - 描述: "从凌晨到夜里，一天的起伏与留白。"
   - **画卷容器**：圆角 20，背景为从上到下的天色渐变（见 scrollGradientStops）
   - 内容为垂直列表，三种行类型：
     - **事件行 (eventRow)**：左侧时间标签（白色半透明）→ 时间线竖线 + 圆点 → EventCardView
     - **留白行 (quietGapRow)**：简化的间隔标记，高度根据时长变化（<15 分钟 8px / 15-60 分钟 24px / 1-3 小时 36px / >3 小时 48px）
     - **心情行 (moodRow)**：小圆点 + 胶囊形心情标记
   - 当前时间指示器：白色圆点 + 水平线

5. **今日自动总结** —— ContentCard
   - eyebrow: "今日总结"
   - 标题: "今日自动总结"
   - headline（16px semibold inkSoft）
   - narrative（body inkMuted）
   - badges（FlexibleBadgeRow, accent 色调）

6. **七日节律** —— ContentCard (tealSoft 背景)
   - eyebrow: "七日节律"
   - 标题: "最近 7 天"
   - headline + narrative + badges (teal 色调)

7. **最近记录** —— ContentCard
   - eyebrow: "最近几天"
   - 标题: "最近记录" + 右侧 "查看全部" 按钮
   - 最多 3 个 RecentDayCard

8. **底部操作栏**（悬浮在底部）
   - 无进行中记录时：全宽 accent 色按钮 "记录此刻"
   - 有进行中记录时：
     - 显示进行中状态（"进行中" teal 胶囊 + 标题 + 详情）
     - 两个按钮："补一个打点" (card 色描边) | "结束这段状态" (teal 色填充)
   - 容器：elevatedCard 背景，圆角 20，border 描边，轻微阴影

### 6.2 EventCardView 事件卡片

**普通事件卡片**（非 mood）：
- 左侧 4px 宽色条（颜色见 cardFill 规则）
- 右侧内容区 padding-left 12：
  - 第一行：badge title（10px bold mono, cardFill 色）+ 事件名（15px semibold ink）+ 时长文本（13px bold mono inkMuted）
  - 第二行（可选）：详情行（subtitle · 地点 · 天气，13px inkMuted）
  - 第三行（可选，仅睡眠）：睡眠阶段彩条（SleepStageRibbon，6px 高）
- 背景：card 色半透明 + ultraThinMaterial 毛玻璃效果
- 圆角 14

cardFill 颜色规则：
- sleep → sleepIndigo 0.78
- workout → 骑行类 blue 0.86 / 跑步类 workoutOrange 0.9 / 其他 rose 0.88
- commute/activeWalk → walkGreen 0.86
- quietTime → glass (白色 0.18)
- userAnnotated → teal 0.82
- mood → accent

`isBlankCandidate` 的卡片：虚线边框，降低透明度，右下角 "点击记录" 提示

**Mood 标记**（胶囊形）：
- 20px 圆形 emoji 图标 + 名称 + 时间
- 胶囊形状，card 色半透明背景

### 6.3 QuickRecordSheet 快速记录弹窗

- 标题区：标题 ("记录此刻" / "补一个打点") + 模式标签 (accent / teal 胶囊)
- 心情网格：3 列 LazyGrid，12 个心情选项
  - 每个：emoji + 中文名，选中时 accentSoft 背景 + accent 描边
- 备注输入框
- 照片区：最多 3 张，横向滚动预览
- 时间选择器
- 底部操作栏：
  - flexible 模式：两个按钮 "打点" + "开始一段"
  - pointOnly 模式：单按钮 "保存打点"

### 6.4 EventDetailView 事件详情

- header 卡片：事件名 + 时间范围 + 时长 + badge + subtitle + 天气/地点信息
  - 背景色：cardFill（quietTime 用 0.35 透明度，其他 0.92）
  - 文字色：quietTime 用 ink/inkMuted，其他用白色/白色半透明
- 照片区（如有）
- 运动详情（workout/commute/activeWalk）：
  - 心率折线图 + 面积图（高 180px）
  - 三个 metric 卡片：平均/最高/最低心率
  - 三个 metric 卡片：步数/热量/距离
- 睡眠详情（sleep）：
  - 睡眠阶段彩条（28px 高）
  - 各阶段时长 metric 卡片
- 留白标注区：提示文字 + "标注这段时间" teal 按钮

### 6.5 HistoryPage 历史回看

- 顶部：WeeklyInsightView（最近 14 天的周洞察）
- 月历区 ContentCard：
  - 月份导航：左右箭头 + 月份标题（titleCard 字体）
  - 7x6 网格日历
  - 每个日期格子（74px 高）：
    - 日期数字 + 主导心情 emoji
    - 底部 6 个色块条，显示当天事件分布颜色
    - 今天：accentSoft 背景 + accent 描边
    - 未来日期：降低透明度

### 6.6 SettingsPage 设置

- 数据权限区：健康数据 / 位置权限 / 照片权限（显示当前状态）
- 隐私区：隐私政策 / 服务条款 / 数据说明
- 关于区：版本号 / 联系我们 / 官网
- 数据管理区："清除所有标注和记录" 红色按钮 + 二次确认

### 6.7 通用组件

**ContentCard**：
- VStack alignment: leading, spacing: 14
- padding: 18
- 背景色（默认 card）
- border: 1px border 色圆角矩形描边
- 圆角: 20

**EyebrowLabel**：
- 11px medium monospace, inkMuted 色, tracking 2.4

**FlexibleBadgeRow**：
- 水平排列标签，空间不足时切换为垂直
- 标签样式：12px medium inkSoft, 胶囊形，背景色根据 tone (accent→accentSoft, teal→tealSoft)

**IntensityBar**：
- 3px 高胶囊进度条
- 宽度 56px，进度 = sqrt(min(max(minutes, 5), 240) / 240)
- 背景 border 色，前景为事件 flowColor

**OverviewStatCard**：
- 92px 宽，padding 14x16
- 上方 label（11px inkMuted），下方 value（statValue 字体，tint 色）
- 背景色为 background 参数，border 描边

---

## 七、ViewModel 状态管理

### TodayViewModel 核心状态

```typescript
// 发布的状态
timeline?: DayTimeline           // 当前日时间轴
isLoading: boolean
errorMessage?: string
showQuickRecord: boolean
quickRecordMode: 'flexible' | 'pointOnly'
activeRecord?: MoodRecord        // 当前进行中的心情记录
insightSummary?: InsightSummary  // 今日总结
weeklyInsight?: WeeklyInsight    // 周洞察
recentDigests: RecentDayDigest[] // 最近几天摘要
todayManualRecordCount: number
todayNoteCount: number
```

### 核心方法

- `loadIfNeeded()` — 首次加载
- `load(forceReload)` — 加载/刷新时间轴
- `startMoodRecord(record)` — 开始心情记录（point 或 session）
- `finishActiveMoodRecord()` — 结束进行中的记录
- `annotateEvent(event, title)` — 标注事件
- `loadTimelines(dates)` — 批量加载多日时间轴（用于历史页）

### 数据流

```
用户操作 → ViewModel 方法 → DataProvider 获取原始数据 → InferenceEngine 推断事件
→ 合并手动记录 → 缓存到本地数据库 → 更新 UI 状态
```

---

## 八、本地存储方案

使用鸿蒙 RDB（关系型数据库）替代 SwiftData：

### 表结构

```sql
CREATE TABLE mood_records (
  id TEXT PRIMARY KEY,
  mood TEXT NOT NULL,
  note TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  ended_at INTEGER,
  is_tracking INTEGER DEFAULT 0,
  capture_mode TEXT DEFAULT 'point',
  photo_attachments TEXT DEFAULT '[]'   -- JSON array
);

CREATE TABLE day_timelines (
  date_key TEXT PRIMARY KEY,            -- 'yyyy-MM-dd'
  summary TEXT DEFAULT '',
  source TEXT DEFAULT 'mock',
  stats TEXT DEFAULT '[]',              -- JSON
  entries TEXT DEFAULT '[]'             -- JSON
);

CREATE TABLE event_annotations (
  event_id TEXT PRIMARY KEY,
  annotation TEXT NOT NULL
);
```

---

## 九、InsightComposer 总结生成

### 今日总结 (InsightSummary)

纯本地规则生成（不依赖 AI），根据当日事件统计：
- `headline`: 一句话概括，如 "活跃的一天，3 段运动"
- `narrative`: 2-3 句描述
- `badges`: 关键标签，如 ["7850 步", "活跃 2.5 小时", "睡眠 7 小时"]

### 周洞察 (WeeklyInsight)

统计最近 7 天的趋势：
- `headline`: 如 "本周节奏稳定"
- `narrative`: 趋势描述
- `badges`: 如 ["日均 8200 步", "平均睡眠 6.8 小时", "运动 4 次"]

---

## 十、开发顺序建议

### Phase 1: 基础框架 + Mock 数据
1. 创建项目结构
2. 实现 TodayTheme（所有设计 tokens）
3. 实现数据模型（SharedDataTypes, MoodRecord）
4. 实现 MockDataProvider（生成一天的模拟数据）
5. 实现 EventInferenceEngine（核心推断算法）
6. 实现 StorageService（RDB 本地存储）

### Phase 2: 今日页核心 UI
1. TodayPage 整体框架 + header + overview stats
2. ContentCard + EyebrowLabel + FlexibleBadgeRow
3. FlowSignatureView（流线图）
4. DayScrollView + EventCardView（时间轴画卷）
5. BottomActionBar

### Phase 3: 交互功能
1. QuickRecordSheet（心情记录弹窗）
2. EventDetailView（事件详情弹窗）
3. AnnotationSheet（标注弹窗）
4. TodayViewModel 完整状态管理

### Phase 4: 历史 + 设置
1. HistoryPage（月历 + 周洞察）
2. HistoryDayDetail
3. SettingsPage
4. InsightComposer（总结生成）

### Phase 5: 接入华为 Health Kit
1. HealthDataProvider（替换 Mock）
2. 权限请求流程
3. 数据格式适配
4. 真机测试验证

---

## 十一、重要实现细节

### 时间轴画卷的天色渐变

画卷背景从上到下模拟一天的天色变化，渐变色定义见 scrollGradientStops。这是整个 App 最具辨识度的视觉元素。

### 留白段的时段命名

画卷中没有明确事件的时间段叫"留白"，根据时段自动命名：
- 0-5: "未记夜色"
- 5-7: "晨起留白"
- 7-12: "上午留白"
- 12-14: "午间留白"
- 14-18: "下午留白"
- 18-20: "傍晚留白"
- 20+: "夜晚留白"

### 事件 ID 生成

使用 SHA-256 哈希从 `kind|startTimestamp|endTimestamp|displayName` 生成确定性 UUID，保证同一事件在不同加载时 ID 稳定。

### 时长格式化

- ≥60 分钟: "X 小时" 或 "X 小时 Y 分钟"
- <60 分钟: "X 分钟"
- 距离 ≥1000 米: "X.X 公里"；<1000 米: "X 米"

### 全部文案使用中文

所有 UI 文案、标签、提示语均使用简体中文。日期格式使用中国区域（zh_CN）。

---

## 十二、额外要求

1. **先实现 Mock 模式能跑通完整流程**，再接入真实 Health Kit。
2. **所有颜色必须支持 dark mode**，使用 TodayTheme 统一管理。
3. **代码注释使用中文**。
4. **不要引入任何第三方库**，全部使用鸿蒙原生 API。
5. **照片功能先用占位图**，后续接入媒体库。
6. **天气功能先用 Mock 数据**，后续接入华为天气 API 或第三方。
7. 确保所有交互有 loading 状态和 error 状态处理。
8. 画卷（DayScrollView）中的毛玻璃效果在 ArkUI 中使用 `backdropBlur` 实现。
