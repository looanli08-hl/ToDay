# ToDay Shared Components

## 核心组件

### `ContentCard`
- 用于承载标题、摘要、列表或洞察块。
- 默认圆角 `20`，内边距 `18`，1px 边框。
- 支持默认 `card` 背景和强调型 `tealSoft` / `accentSoft` 背景。

### `EyebrowLabel`
- 所有区块的小标题统一用 11px 等宽字体。
- 颜色始终使用 `inkMuted`。
- 字间距统一 `2.4`。

### `OverviewStatCard`
- 宽度固定 `92`。
- 上方为标签，下方为大号数值。
- 颜色成对出现：主色为数值色，soft 色做底。

### `FlowSignature`
- 将一天事件压缩成连续节律条。
- 视觉重点是强弱变化，不强调逐分钟准确度。
- 运动或活跃步行的高峰段需要显示峰值点。

### `EventCard`
- 时间轴中的主要信息块。
- 左侧有色条，右侧是标题、时长、摘要、阶段条。
- `quietTime` 允许更轻的玻璃态背景，并显示“点击记录”提示。

### `QuickRecordSheet`
- 支持两种模式：`flexible` 与 `pointOnly`。
- 心情选择必须优先展示 emoji + 中文名。
- 备注和时间编辑为次要，但始终可见。

### `WeeklyInsight`
- 顶部洞察卡，使用 `tealSoft` 背景。
- 展示短标题、叙述和 badge 列表。

### `CalendarDayCell`
- 月历视图的单元格。
- 包含日期数字、主导心情 emoji、事件颜色分布条。
- 今天需要强调边框与底色。

## 平台差异约束
- iOS / HarmonyOS 共用视觉 token，不强求动画实现一致。
- 权限弹窗、导航样式、分享行为用平台原生交互。
- 手表端后续单独适配，但颜色、卡片、文本风格保持统一。
