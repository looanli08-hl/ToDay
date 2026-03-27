# ToDayCore 核心引擎架构设计

**日期**: 2026-03-27
**状态**: 已确认，待实现

---

## 1. 目标

将 ToDay 的核心逻辑抽成独立的 Swift Package（ToDayCore），实现：
- iOS / macOS / Linux 可编译（零平台依赖）
- 插件化数据源架构（DataSourcePlugin）
- 增强版推理引擎（智能分类、交通识别、异常检测、跨天分析、习惯学习）
- 开源友好（社区可贡献插件 + 推理规则）

---

## 2. Package 结构

```
Packages/
└── ToDayCore/
    ├── Package.swift
    ├── Sources/
    │   ├── Models/
    │   │   ├── RawSample.swift          ← 统一原始数据格式
    │   │   ├── SampleType.swift         ← 数据类型枚举
    │   │   ├── InferredEvent.swift      ← 推理后的事件
    │   │   ├── EventKind.swift          ← 事件类型枚举
    │   │   ├── DayTimeline.swift        ← 一天的时间线
    │   │   ├── DayRawData.swift         ← 兼容层（从 RawSample 构建）
    │   │   └── SupportingTypes.swift    ← 天气/位置/照片等通用类型
    │   │
    │   ├── Plugins/
    │   │   ├── DataSourcePlugin.swift   ← 插件协议
    │   │   └── PluginRegistry.swift     ← 插件注册中心
    │   │
    │   ├── Inference/
    │   │   ├── EventInferenceEngine.swift    ← 核心推理引擎
    │   │   ├── SleepInference.swift          ← 睡眠检测 + 质量评分
    │   │   ├── WorkoutInference.swift        ← 运动识别 + 强度分级
    │   │   ├── MovementInference.swift       ← 步行/通勤 + 交通方式
    │   │   ├── QuietTimeInference.swift      ← 安静时段智能分类
    │   │   ├── AnomalyDetection.swift        ← 异常检测
    │   │   ├── TrendAnalysis.swift           ← 跨天趋势分析
    │   │   ├── HabitLearning.swift           ← 习惯学习
    │   │   └── EventMerger.swift             ← 事件合并 + 去重 + 重叠解决
    │   │
    │   └── Echo/
    │       ├── EchoAIProviding.swift         ← AI 服务协议
    │       ├── EchoPromptBuilder.swift       ← Prompt 组装（核心逻辑部分）
    │       └── EchoMemoryTypes.swift         ← 记忆层类型定义
    │
    └── Tests/
        ├── InferenceTests/
        │   ├── SleepInferenceTests.swift
        │   ├── WorkoutInferenceTests.swift
        │   ├── MovementInferenceTests.swift
        │   ├── QuietTimeInferenceTests.swift
        │   ├── AnomalyDetectionTests.swift
        │   └── EventMergerTests.swift
        └── PluginTests/
            └── PluginRegistryTests.swift
```

---

## 3. 核心协议

### 3.1 DataSourcePlugin

```swift
public protocol DataSourcePlugin: Sendable {
    /// 插件唯一标识
    var id: String { get }
    /// 显示名称
    var name: String { get }
    /// SF Symbol 图标名
    var icon: String { get }
    /// 插件描述
    var description: String { get }

    /// 是否可用（权限已授权等）
    var isAvailable: Bool { get }

    /// 采集指定日期的原始数据
    func fetchRawData(for date: Date) async throws -> [RawSample]

    /// 可选：插件自带的推理规则
    /// 默认返回空数组，插件可覆盖以提供专属事件推理
    func inferEvents(from samples: [RawSample], on date: Date) -> [InferredEvent]
}

// 默认实现：没有专属推理
public extension DataSourcePlugin {
    func inferEvents(from samples: [RawSample], on date: Date) -> [InferredEvent] { [] }
}
```

### 3.2 RawSample（统一原始数据格式）

```swift
public struct RawSample: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let type: SampleType
    public let startDate: Date
    public let endDate: Date
    public let value: Double?
    public let unit: String?
    public let metadata: [String: String]
    public let sourcePluginId: String
}

public enum SampleType: String, Codable, Hashable, Sendable {
    // 健康
    case heartRate
    case steps
    case activeEnergy
    case sleep
    case workout
    case activitySummary

    // 环境
    case location
    case weather
    case photo

    // 用户输入
    case mood
    case shutter
    case screenTime

    // 可扩展
    case custom
}
```

### 3.3 PluginRegistry

```swift
public final class PluginRegistry: @unchecked Sendable {
    public private(set) var plugins: [DataSourcePlugin] = []

    public func register(_ plugin: DataSourcePlugin)
    public func unregister(id: String)
    public func plugin(for id: String) -> DataSourcePlugin?

    /// 从所有已注册插件采集数据
    public func fetchAllRawData(for date: Date) async -> [RawSample]

    /// 从所有插件收集专属推理结果
    public func fetchPluginInferences(from samples: [RawSample], on date: Date) -> [InferredEvent]
}
```

---

## 4. 推理引擎

### 4.1 总流程

```
输入：[RawSample]（来自所有插件）
  │
  ├─ 1. 按类型分拣样本
  │
  ├─ 2. 核心推理（并行）
  │   ├── SleepInference      → 睡眠事件 + 质量评分
  │   ├── WorkoutInference     → 运动事件 + 强度分级
  │   ├── MovementInference    → 步行/通勤 + 交通方式
  │   └── QuietTimeInference   → 安静时段智能分类
  │
  ├─ 3. 插件专属推理
  │   └── 各插件的 inferEvents() 结果
  │
  ├─ 4. EventMerger
  │   ├── 合并相邻同类事件（间隔 < 5 分钟）
  │   ├── 按优先级解决重叠（高 > 中 > 低）
  │   ├── 裁剪到当日边界
  │   └── 最小时长过滤（< 5 分钟的推理事件丢弃）
  │
  ├─ 5. 指标附加
  │   ├── 心率范围
  │   ├── 天气
  │   ├── 位置
  │   └── 照片匹配
  │
  └─ 6. 输出：DayTimeline
```

### 4.2 各推理模块

#### SleepInference
- **输入**：sleep 类型的 RawSample
- **输出**：睡眠事件（含阶段分布）
- **改进**：
  - 睡眠质量评分（0-100）：深睡占比 × 40 + 总时长达标 × 30 + 连续性 × 30
  - 入睡/醒来时间记录

#### WorkoutInference
- **输入**：workout 类型的 RawSample
- **输出**：运动事件
- **改进**：
  - 强度分级：根据心率储备法（HRR）分为轻度/中度/高强度
  - 运动类型保留（跑步/骑行/游泳等）

#### MovementInference
- **输入**：steps + location 类型的 RawSample
- **输出**：步行/通勤事件
- **改进**：
  - 交通方式识别：计算移动速度
    - < 6 km/h → 步行
    - 6-25 km/h → 骑行
    - > 25 km/h → 开车/地铁
  - 结合位置变化判断：位置变了 = 通勤，没变 = 散步
  - 不再仅依赖时间段判断通勤

#### QuietTimeInference
- **输入**：所有事件的空白时段 + location + 时间
- **输出**：智能分类的安静事件
- **改进**：
  - 根据时间 + 位置 + 心率综合判断：
    - 工作地点 + 工作时间 → 「工作」
    - 家 + 中午 → 「午餐/午休」
    - 家 + 晚上 → 「休闲」
    - 咖啡厅/餐厅 → 「社交/用餐」
  - 需要习惯学习模块提供「常去地点」分类

#### AnomalyDetection
- **输入**：今天的事件 + 最近 7 天的历史数据
- **输出**：异常标记列表
- **检测**：
  - 步数比 7 天均值低 50% → 标记
  - 睡眠时长偏离均值 > 1.5 小时 → 标记
  - 运动中断（连续 N 天有运动，今天没有）→ 标记
  - 心率异常（静息心率偏离均值）→ 标记
- **输出给 Echo**：触发关怀消息

#### TrendAnalysis
- **输入**：最近 N 天的 DayTimeline
- **输出**：趋势摘要
- **分析**：
  - 运动趋势（上升/下降/持平）
  - 睡眠趋势
  - 活跃度趋势
  - 输出给 Echo 周报和仪表盘洞察

#### HabitLearning
- **输入**：累计的历史数据
- **输出**：用户习惯模型
- **学习**：
  - 常规起床时间
  - 常规工作地点/时间
  - 常规运动时间/类型
  - 常去地点分类（家/公司/健身房/咖啡厅）
- **存储**：持久化到本地，定期更新
- **用途**：QuietTimeInference 用它来分类安静时段

#### EventMerger
- **输入**：所有推理结果（核心 + 插件）
- **输出**：去重、不重叠、排序好的 [InferredEvent]
- **逻辑**：
  - 相邻同类事件合并（间隔 < 5 分钟）
  - 按置信度优先级解决重叠
  - 裁剪到当日边界
  - 最小时长过滤

---

## 5. iOS App 改造

### 内置插件

```
ios/ToDay/Plugins/
├── HealthKitPlugin.swift      → 心率/步数/运动/睡眠/活动环
├── LocationPlugin.swift       → CLVisit 地点轨迹
├── PhotoPlugin.swift          → 当天照片元数据
├── WeatherPlugin.swift        → 按时段天气
├── ShutterPlugin.swift        → 快门记录（已有数据转 RawSample）
├── MoodPlugin.swift           → 心情记录
└── ScreenTimePlugin.swift     → 屏幕时间
```

### App 启动时注册

```swift
let registry = PluginRegistry()
registry.register(HealthKitPlugin())
registry.register(LocationPlugin())
registry.register(PhotoPlugin())
registry.register(WeatherPlugin())
registry.register(ShutterPlugin(store: shutterStore))
registry.register(MoodPlugin(store: moodStore))
```

---

## 6. 开源后社区插件示例

```swift
// Spotify 插件（社区贡献）
struct SpotifyPlugin: DataSourcePlugin {
    var id = "community.spotify"
    var name = "Spotify"
    var icon = "music.note"

    func fetchRawData(for date: Date) async throws -> [RawSample] {
        // 调用 Spotify API 获取播放历史
        // 返回 [RawSample(type: .custom, metadata: ["app": "Spotify", "track": "..."])]
    }

    func inferEvents(from samples: [RawSample], on date: Date) -> [InferredEvent] {
        // 把连续播放的歌曲合并成「在听音乐」事件
    }
}
```

---

## 7. 不在 MVP 范围内

- 后台持续采集（Background Tasks）— 后续单独做
- 桌面端插件（macOS 屏幕时间、文件系统等）— macOS 版时做
- MCP Server 模式 — 桌面端时做
- 插件市场/动态加载 — 远期
