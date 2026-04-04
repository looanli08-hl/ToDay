# Unfold

## What This Is

Unfold 是一个 iOS 自动生活记录 App，通过手机传感器（位置、运动、设备状态）被动记录用户的一天，零输入生成一张精美的"今日画卷"时间轴。结合 AI 洞察，不仅呈现用户的一天，还帮助他们理解自己的生活模式和习惯。

目标用户：所有想要回看自己一天但懒得手动记录的人。第一批种子用户不限定，通过 Build in Public 吸引早期使用者。

## Core Value

**让用户睡前打开 App，一眼看到自己今天是怎么度过的，并从 AI 那里获得一句让他想继续用的洞察。**

## Requirements

### Validated

- ✓ CoreLocation 位置追踪（significant changes + visits）— existing
- ✓ CoreMotion 活动识别（walking/running/automotive/cycling）— existing
- ✓ PhoneInferenceEngine 事件推理（sleep/commute/exercise/stay/blank）— existing
- ✓ PlaceManager 地点聚类 + 自动分类（home/work/frequent）— existing
- ✓ CLGeocoder 反向地理编码 — existing
- ✓ 垂直时间轴 UI（DayScrollView + EventCardView）— existing
- ✓ 背景任务自动刷新（BGTaskScheduler）— existing
- ✓ SwiftData 本地持久化 — existing
- ✓ 手动记录（mood/shutter/spending/annotation）— existing
- ✓ 历史日期查看 — existing

### Active

- [ ] AI 每日总结 — 一段话概括用户的一天（云端 API）
- [ ] AI 模式识别 — 识别跨天重复行为（"你连续3天下午都在图书馆"）
- [ ] AI 主动推送洞察 — 基于模式识别推送通知
- [ ] Echo 对话 — 用户可以与 AI 对话询问自己的生活数据
- [ ] 跨周/月趋势分析 — 可视化长期生活模式变化
- [ ] 设备端轻量推理 — Apple Intelligence / Core ML 处理简单分析
- [ ] 云端深度分析 — 复杂分析调用 API（混合架构）
- [ ] 画卷视觉打磨 — 时间轴视觉品质达到 Apple 级别
- [ ] Onboarding 权限引导 — 清晰的分步权限请求流程
- [ ] 隐私政策更新 — 符合 CoreLocation Always 审核要求
- [ ] App Icon 设计 — 品牌视觉标识

### Out of Scope

- Apple Watch 集成 — MVP 不做，后续 milestone 考虑
- 屏幕时间自动采集 — 需要 Family Controls entitlement，复杂度高
- 浏览器扩展 / Chrome Extension — 已暂停，Gemini 正面竞争
- Web App — 已暂停
- 社交分享 / 分享卡片 — MVP 后考虑
- 云端同步 — 本地优先，MVP 不需要
- 心率/健康数据 — Watch 整合时再做
- 付费/订阅系统 — 先验证产品再考虑商业模式
- 自定义硬件（手表/耳机/眼镜）— 远期愿景，不在当前 milestone

## Context

**已有代码状态：** 在 `feature/phone-first-auto-recording` 分支上，传感器采集 → 数据存储 → 事件推理 → 时间轴 UI 的完整管线已经跑通。180 个测试通过。Echo AI 基础设施（聊天、记忆、调度）也已有实现但未接入 MVP 流程。

**设计系统：** Impeccable 已配置完成（`.impeccable.md`），定义了品牌调性（intimate, refined, unhurried）、配色（warm cream palette）、参考产品（Flighty, Arc Browser, Apple Weather）和反面参考。

**竞品：** Life Cycle（地点饼图）、Arc Timeline（时间线）。它们给数据，Unfold 给感受 + AI 洞察。

**已知技术问题：** 代码中有硬编码的 DeepSeek API key 需要清理。部分 Watch 相关代码残留。EchoEngine 等模块存在但未接入 phone-first 流程。

**长期愿景：** Unfold 的用户数据可以成为"AI 镜像"项目的一个输入源——通过各种数据深度理解一个人，复刻其 AI 分身。但这是完全独立的产品。

## Constraints

- **Tech Stack**: SwiftUI + iOS 17+ + SwiftData, 不引入第三方 UI 框架
- **隐私**: 数据本地优先，云端 API 调用只传必要上下文，不传原始位置数据
- **设计**: 必须达到 Apple 级别品质，参考 .impeccable.md 设计规范
- **平台**: iPhone only（无 iPad/Mac），MVP 无 Watch
- **AI 后端**: 混合架构 — 设备端处理简单推理，复杂分析调用云端 API
- **Solo dev**: 一个人开发，scope 必须可控

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 回归 iOS 自动记录，放弃 Web/Extension | Gemini 正面竞争 Chrome Side Panel；iOS 被动记录 + 设计有差异化空间 | — Pending |
| 暂定名 Unfold，等用户验证后再取名 | 品牌命名不应阻塞开发，先用 working name | — Pending |
| MVP = 记录 + 轻量 AI，深度 AI 第二层迭代 | 避免再次 scope creep，先做完美记录 + 一个 AI 亮点 | — Pending |
| 混合 AI 架构（设备端 + 云端） | 隐私优先但需要云端能力做复杂分析 | — Pending |
| 先免费验证，后续再加付费 | 先证明产品有人要用 | — Pending |
| 设计是核心壁垒 | 功能可以被复制，设计感和情感体验不容易被复制 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-04 after initialization*
