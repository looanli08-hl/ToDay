# ToDay iOS

最小的 `SwiftUI` iPhone 工程，用来验证 `ToDay` 的核心假设：

- 通过 Apple Watch 已采集到的 `HealthKit` 数据理解今天
- 在手机上用时间线而不是一堆图表来回看生活
- 先做本地优先，不依赖后端

## 打开方式

1. 在当前目录运行 `xcodegen generate`
2. 双击生成的 `ToDay.xcodeproj`
3. 在 Xcode 里选择 `iPhone 16` 之类的模拟器
4. 点击运行

## 当前包含

- `SwiftUI` app 骨架
- 一个可运行的 “今日时间线” 占位页面
- 便于后续接入 `HealthKit` 的基础数据模型

## 下一步

- 给 app 加上 `HealthKit` capability
- 请求读取步数、心率、睡眠和运动数据
- 用真实数据替换占位 timeline
