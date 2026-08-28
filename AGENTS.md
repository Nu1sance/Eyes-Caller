# AGENTS.md — Eyes Caller 开发与维护指南

本文档面向在本仓库中继续开发、排查和发布 Eyes Caller 的编码 Agent。请先阅读本文件，再修改代码。

## 1. 产品目标

Eyes Caller（界面名“眺眺”）是一个原生 macOS 视力休息提醒工具，遵循 20–20–20 原则：

- 专注 20 分钟；
- 提醒用户看向约 6 米外；
- 完整远眺 20 秒；
- 完成后开始下一轮 20 分钟。

产品强调：可靠后台提醒、低打扰、护眼配色、可爱但克制的动画，以及极低的使用负担。不要把它扩展成账号、云同步、目标管理或复杂健康平台，除非用户明确提出。

## 2. 技术栈与系统要求

- Swift 6
- SwiftUI
- 少量 AppKit，用于窗口、Dock、状态栏和 `NSPanel`
- UserNotifications，用于 macOS 系统通知
- Swift Package Manager
- 最低系统：macOS 13
- Bundle Identifier：`com.eyescaller.EyesCaller`

项目当前不是标准 Xcode `.xcodeproj`，而是 Swift Package executable。`Scripts/build-app.sh` 会把 release 可执行文件组装成本地 `.app`。

## 3. 常用命令

### Debug 编译

```bash
swift build
```

### Release 编译

```bash
swift build -c release
```

### 快速开发运行

```bash
swift run EyesCaller
```

注意：`swift run` 启动的是裸可执行文件，不具备正式 `.app` 身份。主界面、菜单栏、后台计时和小弹窗可工作，但 macOS 系统通知不可注册，应用会降级到小弹窗。Dock 也可能先把进程识别为 `exec`，运行时会由 `ApplicationIcon` 尝试重新应用图标。

### 构建推荐的本地 App

```bash
./Scripts/build-app.sh release
open dist/EyesCaller.app
```

生成位置：

```text
dist/EyesCaller.app
```

该 App 使用 ad-hoc 签名，适合本机开发和测试，不适合无警告地公开分发。

### 安装到当前用户的 Applications

```bash
mkdir -p ~/Applications
rm -rf ~/Applications/EyesCaller.app
ditto dist/EyesCaller.app ~/Applications/EyesCaller.app
open ~/Applications/EyesCaller.app
```

### 安装到系统 Applications

不要在未获得用户明确同意时执行 `sudo`。用户确认后可使用：

```bash
sudo rm -rf /Applications/EyesCaller.app
sudo ditto dist/EyesCaller.app /Applications/EyesCaller.app
open /Applications/EyesCaller.app
```

安装副本不会随源代码自动更新。修改后必须重新构建并覆盖旧 App。

## 4. 目录结构

```text
Package.swift
Support/Info.plist
Scripts/build-app.sh
Assets/
  AppIcon.svg
  AppIcon.png
  AppIcon.iconset/
  MenuBarIcon.svg
Sources/EyesCaller/
  App/
    EyesCallerApp.swift
  Design/
    Theme.swift
  Desktop/
    ApplicationIcon.swift
    ApplicationVisibility.swift
    NotificationManager.swift
    ReminderPanelController.swift
  Models/
    AppearanceController.swift
    EyeCareStatisticsStore.swift
    RestSessionModel.swift
  Resources/
    AppIcon.icns
    MenuBarIcon.png
  Views/
    CompactReminderView.swift
    Components.swift
    EyesCallerRootView.swift
    HorizonGardenView.swift
    MenuBarContentView.swift
    SessionViews.swift
    SettingsView.swift
    StatisticsHeatmapView.swift
    StatisticsMetricCard.swift
    StatisticsView.swift
```

## 5. 核心架构

### `EyesCallerApp.swift`

应用级状态的唯一创建点：

- `RestSessionModel`
- `EyeCareStatisticsStore`
- `AppearanceController`

这些对象必须保持单例式共享，不要在子视图中重新创建，否则会造成计时、统计、昼夜模式或菜单状态分裂。

应用只有一个主 `Window`，不要改回 `WindowGroup`。曾经使用 `WindowGroup` 时可能产生多个主窗口、重复通知和重复完成音。

### `RestSessionModel.swift`

状态机：

```text
focus → ready → resting → completed → focus/ready
```

关键约束：

- 使用绝对 `Date` 计算剩余时间，不依赖累计 Timer tick；
- `ready` 状态不会自动重复通知；
- 用户处理提醒前，下一轮 20 分钟不会开始；
- 只在 `completeRest(at:)` 中记录统计；
- 同一轮完整远眺只能统计一次；
- 如果休眠期间 20 秒已结束，恢复或重新开始时先结算上一轮；
- `completed` 状态可以保留供用户查看，但下一轮时间仍在后台推进。

不要把统计写入放到 SwiftUI `onChange`，否则可能因视图重建重复计数。

### `AppearanceController.swift`

负责：

- 白天/夜晚模式；
- 手动切换；
- 自动切换开关；
- 默认 08:00 白天、20:00 夜晚；
- 跨午夜时间段；
- 手动临时覆盖至下一计划边界；
- 系统时钟和时区变化后的重新计算；
- 一次性等待下一个时间边界，自动关闭时不持续轮询。

主题偏好存储在：

```text
UserDefaults suite: com.eyescaller.preferences
key: appearance.preferences
```

不要恢复为每几秒持续发布状态的轮询方式。那会造成菜单、主窗口和弹窗持续无意义重绘。

主题变化前会发送：

```swift
Notification.Name.eyesCallerAppearanceWillChange
```

主窗口使用该通知在 mode 发布前覆盖旧画面快照，再于下一轮主线程淡出，以避免主题切换第一帧闪烁。修改此流程时必须保持顺序：

```text
捕获旧画面 → 立即覆盖 → 发布新主题 → 新主题首帧提交 → 淡出旧画面
```

### `EyeCareStatisticsStore.swift`

统计保存在：

```text
UserDefaults suite: com.eyescaller.statistics
key: eye-care-statistics.payload
```

数据包含：

- schema version；
- 首次使用日期；
- 首次使用自然日 key；
- 每日完成次数。

规则：

- 日期桶固定使用 Gregorian calendar；
- 只有完整 20 秒才计数；
- 统计面板显示最近 12 周；
- 颜色档位为 0、1、2、3、4+；
- 损坏 payload 要先备份，不要直接覆盖；
- 当前实现包含 v1 → v2 迁移。

测试统计时使用唯一临时 suite，不要污染用户真实数据。除非明确知道数据是 Agent 生成的测试数据，否则不要删除上述 suite。

## 6. 后台、Dock 与状态栏行为

关闭主窗口左上角红叉时：

1. 主窗口执行 `orderOut`；
2. 应用切换为 `.accessory`；
3. Dock 图标消失；
4. 进程、计时、状态栏图标继续存在。

状态栏选择“显示眺眺”时：

1. 应用切回 `.regular`；
2. 重新应用 App 图标；
3. 激活应用；
4. 恢复现有主窗口。

只有状态栏中的“退出眺眺”才真正结束进程。

### Dock 图标的重要约束

`.accessory → .regular` 会让 macOS 重建 Dock tile，可能恢复为默认 `exec` 图标。因此：

- 首次启动调用 `ApplicationIcon.applyAfterDockTileRecreation()`；
- 每次 `ApplicationVisibility.showMainWindow()` 也必须再次调用；
- 不要删除下一主线程周期的第二次图标应用。

### 状态栏菜单的重要约束

`MenuBarContentView` 故意是静态 `Equatable` 菜单，不观察每秒倒计时。

此前菜单显示实时秒数时，每秒 `objectWillChange` 会让原生 `NSMenu` 重建，导致鼠标下的蓝色高亮向上跳动。不要在菜单中重新加入实时秒数、动态条件行或 `@ObservedObject`。菜单按钮可以持有实时模型引用并执行操作，但菜单结构在打开期间必须稳定。

状态栏使用 `MenuBarIcon.png` template image，不要改回自定义 SwiftUI `ZStack`。SwiftUI 图形曾出现“区域可点击但图标不可见”的问题。

## 7. 通知行为

到达 20 分钟时：

- 每个周期只发送一次通知；
- `notificationOnly`：只发送系统通知；
- `notificationAndPopup`：系统通知 + 紧凑弹窗；
- 系统通知不可用、未授权或提醒展示被关闭时，自动使用弹窗兜底；
- 用户一直不操作时保持在 `ready`，不会反复轰炸通知；
- 睡眠期间错过多个周期也不会补发多条通知。

系统通知要求有 Bundle Identifier，因此应使用 `dist/EyesCaller.app` 验证，不能只用 `swift run`。

通知点击行为：

- 点击普通通知：恢复主窗口；
- 点击“开始远眺”：恢复主窗口并进入 20 秒倒计时；
- 点击小弹窗：通过共享模型执行开始、稍后或打开主体。

`ReminderPanelController` 创建的是非激活 `NSPanel`。它不会自然继承主窗口 appearance，因此必须显式应用 `GardenAppearance`，并监听系统高对比度选项变化。

## 8. 昼夜主题与动画

### 颜色系统

所有通用界面颜色应从 `GardenTheme` 语义令牌取得，例如：

- `ink`
- `mutedInk`
- `surface`
- `surfaceStrong`
- `border`
- `fern`
- `buttonText`
- `activityEmpty` 到 `activityPeak`

不要在普通组件中直接增加 `Color.white` 或固定浅色 hex。固定场景色只应出现在 `HorizonGardenView` 等明确区分昼夜的插画层。

夜晚模式不是简单反色：

- 背景为深青绿；
- 文字为柔和偏绿白；
- 强调色使用月光蓝和暖黄；
- 避免纯黑和大面积纯白；
- 保持小字号文字和按钮的对比度。

### 昼夜过渡

右侧场景包含：

- 太阳落下/升起；
- 月亮升起/落下；
- 星点和萤火分阶段出现；
- 天空、山丘、植物和角色换色；
- 原有鼠标景深视差。

主窗口还有 AppKit 快照交叉淡出，用于避免 `NSAppearance` 切换的瞬时闪屏。`PassThroughImageView` 必须允许鼠标事件穿透，并保留安全清理逻辑，防止快速连续切换后旧快照永久覆盖界面。

### 动画性能

- `HorizonGardenView` Timeline 最高约 15 FPS；
- 鼠标视差按约 30 FPS 采样；
- 主窗口隐藏或完全遮挡时暂停场景 Timeline；
- 白天不构建不可见的星点与萤火层；
- 云朵必须从画面外完整进入，并在完全离开后才重置循环；
- 不要使用会让云朵在边缘突然刷新的不完整取模轨迹。

### 减少动态效果

必须尊重：

```swift
@Environment(\.accessibilityReduceMotion)
```

启用后：

- hover pointer 归零；
- 太阳/月亮不做长位移；
- 星光和萤火不闪烁；
- 呼吸动画在运行中也必须停止，而不是只在首次出现时检查；
- sheet 和主题过渡不应继续长动画。

## 9. 用户使用方法

### 正常工作流程

1. 打开 Eyes Caller；
2. 应用开始 20 分钟专注计时；
3. 到时收到通知；
4. 点击“开始远眺”；
5. 看向约 6 米外 20 秒；
6. 页面明显变色并提示完成；
7. 下一轮自动开始。

### 设置

设置面板可选择：

- 仅系统通知；
- 系统通知 + 小弹窗；
- 完成提示音；
- 自动昼夜切换；
- 白天与夜晚开始时间。

自动昼夜模式开启后，手动切换只临时保持到下一个计划边界。

### 统计

主界面顶部格子按钮打开“远眺足迹”：

- 陪伴天数；
- 今日远眺次数；
- 累计次数；
- 最近 12 周热力格；
- 鼠标悬停显示具体日期与次数。

## 10. 验证要求

每次修改至少执行：

```bash
swift build
swift build -c release
```

涉及资源、Info.plist、通知或发布结构时，还要执行：

```bash
./Scripts/build-app.sh release
```

构建输出中不应有 warning 或 error。

当前环境曾只有 Command Line Tools，可能没有 XCTest/Swift Testing 模块。若测试框架不可用，可用独立临时 Swift 检查程序验证纯模型，但不要把必然无法运行的测试 target 留在 Package.swift 中。安装完整 Xcode 后可补正式测试。

### 视觉验收规则

用户已明确要求：最终界面视觉由用户肉眼确认。

除非用户再次明确授权，否则 Agent 不应：

- 自动移动系统鼠标；
- 自动点击 UI；
- 自动截屏并替用户宣称视觉验收通过。

Agent 可以：

- 做代码审查；
- 编译 Debug/Release；
- 做确定性模型测试；
- 启动最新版应用供用户检查；
- 清楚列出需要用户确认的视觉场景。

## 11. 本地安装与公开发布的区别

`Scripts/build-app.sh` 当前执行：

- release 构建；
- 创建 `.app` 目录结构；
- 写入 `Info.plist`；
- 复制 App 和菜单栏图标；
- ad-hoc codesign。

这足以本机安装，但不等于正式发布。

公开分发并获得正常 Gatekeeper 体验通常需要：

1. Apple Developer Program；
2. Developer ID Application 证书；
3. Hardened Runtime；
4. 正式 codesign；
5. `notarytool` 公证；
6. `stapler` 写入票据；
7. DMG 或 ZIP；
8. `codesign`、`spctl` 和 stapler 验证。

不要把 ad-hoc 签名的 `dist/EyesCaller.app` 描述成已认证或已公证版本。

## 12. 当前未实现范围

- 登录时自动启动
- 自动更新
- Developer ID 正式签名与 Apple 公证
- DMG 正式发布流程
- Mac App Store
- 账号和云同步
- 跨设备统计
- 数据导出/导入
- 基于地理位置的真实日出日落
- 复杂目标、排行榜或健康评分

## 13. 修改前后的检查清单

修改前：

- 确认没有同时运行多个 EyesCaller 进程；
- 确认使用的是 `.build/debug` 还是 `dist/EyesCaller.app`；
- 不要误删用户真实统计和偏好；
- 阅读相关模型和视图的完整文件。

修改后：

- Debug 和 Release 编译；
- 如涉及资源，重建 `.app`；
- 检查红叉后进程是否应继续运行；
- 检查状态栏菜单不要重新引入秒级刷新；
- 检查 Dock 恢复后重新应用图标；
- 检查系统通知在 `.app` 中验证；
- 检查白天、夜晚和减少动态效果；
- 检查统计只增加一次；
- 将视觉确认点交给用户肉眼检查。
