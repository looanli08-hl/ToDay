# HarmonyOS ToDay — 视觉精修（基于当前代码状态）

## 背景

当前代码的数据层、ViewModel、色彩系统已经与 iOS 对齐。但 UI 组件的**视觉呈现**与 iOS 差距很大。本次修改只聚焦 UI 层的精修，不改动数据层逻辑。

**核心参考**：iOS 源码在 `ios/ToDay/ToDay/` 下。每个任务开始前**必须**先读对应的 iOS Swift 文件理解精确布局，然后用 ArkUI 忠实复刻。

**修改范围**：仅限 `harmonyos/ToDay/entry/src/main/ets/` 下的文件。

---

## 任务 1：DayScrollView 时间轴画布重写

**参考文件**：`ios/ToDay/ToDay/Features/Today/ScrollCanvas/DayScrollView.swift`

这是视觉差距最大的组件。当前问题：
- 事件之间 `space: 12` 间距太大，看起来像列表不像画卷
- 连接线是每个事件各画一段，不连贯
- 所有时间线圆点都是白色，没有事件类型区分
- 没有"留白"行（静息时段的动态间距）
- 没有当前时间指针的动态定位

### 需要改成：

**文件**：`components/today/DayScrollView.ets`

1. **连续竖线**：用一根从第一个事件到最后一个事件的连续竖线贯穿，而不是每个事件各画一段。竖线宽度 1.5px，颜色 `alpha('#FFFFFF', 0.25)`。

2. **彩色圆点**：每个事件的时间线圆点颜色跟事件类型对应。使用 `eventTintColor(entry, mode)` 获取颜色。圆点大小 8px。

3. **紧凑间距**：去掉 `Column({ space: 12 })`。事件之间不使用固定间距，而是通过"留白行"来控制视觉节奏。

4. **留白行**：如果两个相邻事件之间有 ≥15 分钟的时间空白，插入一个"留白指示行"：
   - 高度根据空白时长动态计算：<15min 不显示, 15-60min=24px, 60-180min=36px, >180min=48px
   - 显示虚线文字："留白 · {时长}" 白色半透明
   - 可点击触发 `onBlankTap`

5. **当前时间指针**：白色圆点 6px + 水平线延伸到右侧。位置根据当前时间在时间轴中的比例动态计算。每 60 秒更新一次位置。仅今天显示。

6. **布局微调**：
   - 时间标签列宽 44px（当前 48，偏大）
   - 时间线指示器列宽 20px（当前 12，偏窄）
   - 事件卡片 layoutWeight(1)
   - padding 减为 14（当前 18）

---

## 任务 2：EventCardView 事件卡片精修

**参考文件**：`ios/ToDay/ToDay/Features/Today/ScrollCanvas/EventCardView.swift`

### 需要改的：

**文件**：`components/today/EventCardView.ets`

1. **类型化背景色**：当前所有非静息卡片都是 `card` 色半透明背景。需要根据事件类型设置不同的半透明背景：

```
SLEEP: TodayTheme.alpha(TodayTheme.color('sleepIndigo', mode), 0.78)
WORKOUT(cycling): TodayTheme.alpha(TodayTheme.color('blue', mode), 0.86)
WORKOUT(running): TodayTheme.alpha(TodayTheme.color('workoutOrange', mode), 0.9)
WORKOUT(other): TodayTheme.alpha(TodayTheme.color('rose', mode), 0.88)
COMMUTE/ACTIVE_WALK: TodayTheme.alpha(TodayTheme.color('walkGreen', mode), 0.86)
QUIET_TIME: TodayTheme.glass(mode, 0.18) + 虚线边框（已有）
USER_ANNOTATED: TodayTheme.alpha(TodayTheme.color('teal', mode), 0.82)
MOOD: TodayTheme.alpha(TodayTheme.color('accent', mode), 0.85)
```

2. **文字颜色适配**：有色背景的卡片上，文字应该用白色或浅色以保证可读性：
   - 事件名称：白色 opacity 0.95
   - 时长标签：白色 opacity 0.75
   - 描述文字：白色 opacity 0.7
   - 静息时间(QUIET_TIME)保持当前的 ink 系列颜色

3. **左侧竖条去掉**：有了彩色背景后，左侧 4px 竖条不再需要（iOS 也没有）。改为圆角卡片直接用背景色区分。

4. **卡片 padding 调整**：
   - padding: { left: 12, right: 14, top: 12, bottom: 12 }（当前 14 all sides 偏大）
   - 圆角: 14px（当前 20px 偏大）

5. **照片数量 badge**：如果 `event.photoAttachments.length > 0`，在卡片右下角显示 "📷 {count}" 小 badge。

6. **isLive 脉冲指示**：如果 `event.isLive === true`，在事件名称旁显示一个绿色小圆点 + "进行中" 文字。

---

## 任务 3：OverviewStatCard 精修

**参考文件**：`ios/ToDay/ToDay/Features/Today/TodayFlowViews.swift` 中的 `OverviewStatCardView`

**文件**：`components/today/OverviewStatCard.ets`

当前可能存在的问题：卡片尺寸、字体大小、颜色映射。对齐到 iOS 规格：
- 固定宽度 92px
- padding: 14 水平, 16 垂直
- 标签：11px, inkMuted
- 数值：24px, bold, monospace, ink 色
- 背景：对应的 softTone 色 + 1px border（对应的 tone 色, opacity 0.3）
- 圆角：16px

---

## 任务 4：FlowSignatureView 心率曲线

**参考文件**：`ios/ToDay/ToDay/Features/Today/TodayFlowViews.swift` 中的 `TodayFlowSignatureView`

**文件**：`components/today/FlowSignatureView.ets`

这是"今日脉络"部分的可视化。需要：
- 用 Canvas 绘制基于事件时间和强度的曲线
- X 轴：0-24 小时
- Y 轴：事件强度（每种事件的 intensity 值来自 `getEventVisual(kind).intensity`）
- 曲线下方用 linearGradient 填充（scrollNight → scrollSunrise → scrollGold → scrollNoon → scrollSunset → scrollViolet）
- 曲线线宽 2.4px
- 活动高峰处标记小圆点（7px 直径）
- 高度 82px

如果 Canvas 在 ArkUI 中难以实现平滑贝塞尔曲线，可以用分段色条（当前实现的思路）但需要更精细：
- 每个色条的高度应该反映事件的 intensity
- 色条之间用极小的间距（1-2px）
- 色条颜色使用事件对应的 tone 色

---

## 任务 5：HistoryPage 月历视图

**参考文件**：`ios/ToDay/ToDay/Features/History/HistoryScreen.swift`

**文件**：`pages/HistoryPage.ets` + `components/history/CalendarDayCell.ets`

当前 HistoryPage 是 14 天摘要列表，iOS 是月历网格。需要重构为：

### 页面结构：
```
Column {
  // 1. 周洞察卡片
  WeeklyInsightView(...)

  // 2. 月份选择器
  Row {
    Button("←")   // 上个月
    Text("2026 年 3 月")  // 当前月份
    Button("→")   // 下个月
  }

  // 3. 星期标题行
  Row { "日" "一" "二" "三" "四" "五" "六" }

  // 4. 日历网格（7 列）
  // 使用 Grid 或 Flex(wrap) 排列
  ForEach(daysInMonth) {
    CalendarDayCell(...)
  }
}
```

### CalendarDayCell 规格（参考 iOS `HistoryCalendarDayCell`）：
- 尺寸：等分 7 列，高度 74px
- 日期数字：15px，今天加粗
- 主情绪 emoji（如有数据）
- 底部：最多 6 个小色条（高 8px, 间距 2px），颜色对应当天事件类型
- 今天特殊样式：accentSoft 背景 + accent 边框 1px
- 其他月份的日期：opacity 0.3
- 点击可导航到日详情（先不实现导航，保留 onClick 回调）

### 月份数据加载：
- 使用 ViewModel 的 `loadTimelines(dates)` 批量加载当月所有日期的数据
- 从 `digestForDate(date)` 获取每天的摘要
- 有数据的日期显示 emoji 和色条，无数据显示空白

---

## 任务 6：QuickRecordSheet 扩展为 12 心情

**参考文件**：`ios/ToDay/ToDay/Features/Today/QuickRecordSheet.swift`

**文件**：`components/today/QuickRecordSheet.ets`

当前的心情选项只有 6 个，iOS 有 12 个。需要：
1. 使用 `getMoodOptions()` 获取全部 12 种心情（数据已在 MoodRecord.ets 中定义）
2. 改为 3×4 网格排列（使用 Grid 或嵌套 Row+Column）
3. 每个心情按钮：约 80×80，emoji（24px）+ 中文名（12px），选中态 accent 边框

---

## 任务 7：底部操作栏视觉微调

**参考文件**：`ios/ToDay/ToDay/Features/Today/TodayScreen.swift` 底部的 action bar

**文件**：`pages/TodayPage.ets` 中的 `buildBottomActionBar()`

当前实现基本正确，微调：
- 底部栏背景加 `shadow`：`color = ink.opacity(0.06), radius = 18, offsetY = -8`
- 背景色改为 `background` 色 + 0.92 opacity（毛玻璃效果）
- "记录此刻"按钮内的 `⊕` 换成更精致的 `+` 号样式
- 整个底部栏 position 改为 sticky bottom，不随滚动

---

## 任务 8：Settings 和通用 UI 润色

### SettingsPage 补全
**参考**：`ios/ToDay/ToDay/Features/Settings/SettingsView.swift`

补全以下区域：
1. **数据权限**：健康数据 / 位置 / 照片 状态显示
2. **关于**：版本号 (0.1.0) / 联系方式
3. **数据管理**："清除所有标注和记录" 红色按钮 + 确认弹窗
4. 保留现有的主题切换

### 全局动画
在关键交互处添加 `animateTo()` 过渡：
- 弹窗出现/消失：opacity + translateY 组合，duration 200ms
- 心情选择：scale 轻微弹跳，duration 150ms
- 切换 Tab：默认 ArkUI Tab 动画即可

---

## 执行顺序

建议按以下顺序执行，每完成一个任务验证 Previewer 效果：

1. **任务 2** (EventCardView) — 最小改动，最大视觉提升
2. **任务 1** (DayScrollView) — 核心画卷体验
3. **任务 3** (OverviewStatCard) — 快速打磨
4. **任务 4** (FlowSignatureView) — 锦上添花
5. **任务 6** (QuickRecordSheet) — 功能补全
6. **任务 5** (HistoryPage) — 最大改动量
7. **任务 7** (底部栏) — 微调
8. **任务 8** (Settings + 动画) — 收尾

每个任务完成后确保：
- 所有 import 正确
- 无 TypeScript 编译错误
- 保持与现有 ViewModel 和数据层的正确连接
