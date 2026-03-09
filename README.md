# ToDay

`ToDay` 是一个以生活记录与回看为核心的 iPhone 应用原型。

当前仓库以 `SwiftUI` iOS 工程为主，目标是先验证这条产品路径：

- 把生活片段、状态变化和关键记录整理成一条私人时间线
- 先做本地优先体验，再逐步扩展到账号、同步和网页端
- 先做中文版本，再预留国际化能力
- 通过 Pro 订阅验证“自动总结与连续洞察”的付费价值

## 项目结构

- `ios/ToDay`：主 iOS 工程
- `docs/today-commercialization-brief.md`：商业化与产品方向草案

## 本地运行

在当前目录执行：

```bash
cd ios/ToDay
xcodegen generate
open ToDay.xcodeproj
```

然后在 Xcode 里选择一个 iPhone 模拟器直接运行。
