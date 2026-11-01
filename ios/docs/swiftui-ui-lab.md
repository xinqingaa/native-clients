# EngineeringLab｜第三章运行与阅读入口

第三章配合 [iOS 03 正文](../../docs/ios/03-ui-rendering-interaction.md)学习 SwiftUI 的更新、布局、交互、导航和适配。正文解释能力与机制，本目录的教程提供具体 Swift 写法、源码关系、可重复操作和实际观察。五组实验共用已有 EngineeringLab，不另建应用。

## 阅读与运行顺序

| 顺序 | 工程教程 | 应用入口 |
| --- | --- | --- |
| 1 | [更新、列表与滚动](swiftui-updates-and-lists.md) | 更新与列表：局部状态 → 读取位置 → 行身份 → 按需内容 → 滚动目标 |
| 2 | [布局与绘制](swiftui-layout-and-drawing.md) | 布局与绘制：尺寸 → 占位与命中 → Layout → Shape/Canvas → 语言与主题 |
| 3 | [输入与动画](swiftui-input-and-animation.md) | 输入与动画：表单 → 拖动 → 动画目标 → 动画范围 |
| 4 | [导航与呈现](swiftui-navigation-and-presentation.md) | 导航与呈现：系统链接 → 类型化路径 → 基础模态 → 路由与编辑组合 |
| 5 | [自适应布局](swiftui-adaptive-layout.md) | 自适应与 Duo：容器与身份 → 分栏 → 独立区域实验 |

打开 [EngineeringLab.xcodeproj](../EngineeringLab/EngineeringLab.xcodeproj)，选择 EngineeringLab scheme 与可用 Simulator，Run 后进入“UI 与交互”。默认显示更新与列表，通过顶部“切换实验”菜单换组。各组子入口按教程排序，导航与适配在顶部菜单选择子实验，避免再套一层会干扰目标行为的导航容器。

具体类型位于 [UILab](../EngineeringLab/EngineeringLab/UILab)，教程代码取自这些实现；阅读后可修改对应源码，不需要把同名类型再复制进工程。普通 Swift 语法由第一章实验承接，本章重点解释 SwiftUI 声明与平台行为。VS Code 可编辑源码，界面运行、键盘、手势和系统呈现需要 iOS 环境；Xcode 通用操作见 [Xcode 使用与调试](project-started.md)。

## 工具链与构建

2026-11-01 本机为 Xcode 27.1（27A9275）、Apple Swift 6.4、iOS Simulator SDK 27.1。工程最低 iOS 18.0，Swift 6 language mode，默认 MainActor 隔离并启用 Approachable Concurrency。Shape 的无共享状态几何计算显式使用 nonisolated 类型，避免把协议的几何职责带入工程默认的主 actor 隔离。新系统接口保留可用性分支。

从仓库根目录执行构建：

```bash
xcodebuild \
  -project ios/EngineeringLab/EngineeringLab.xcodeproj \
  -scheme EngineeringLab \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/DerivedData \
  build
```

Release 检查将 configuration 改为 Release。generic destination 只构建，不负责安装和交互；运行时仍需选具体 Simulator 或设备。Debug 下的更新与测量日志不进入 Release。

## 状态与复位

所有第三章数据在本次实验的内存中，不读取第二章恢复文件，也不访问网络。返回一个基础实验后再进入通常建立新状态；顶部切换到其他组会结束当前组。导航与适配的“复位”通过新身份重建当前子实验；列表行、读取位置和滚动目标还提供各自复位入口。

比较两个条件时，先复位，再按教程改变同一个变量。身份模式或布局分支的切换本身可能重建内容，教程会说明应比较切换之前还是同一模式内部的操作。遇到与预期不同的结果，记录当前子实验、操作顺序、目标值和环境，不直接把差异归因于缓存或框架随机行为。

## 模型检查与 UI 验证的分工

[UILabChecks.swift](../Tests/UILabChecks.swift)直接检查组合导航的数据规则：目标校验、两条独立路径、限定的重复抑制、提交版本和关闭后结果消费。它不加载 SwiftUI 界面。

```bash
swiftc -swift-version 6 -parse-as-library \
  ios/EngineeringLab/EngineeringLab/UILab/UINavigationModel.swift \
  ios/Tests/UILabChecks.swift \
  -o /tmp/native-clients-ios03-checks
/tmp/native-clients-ios03-checks
```

预期输出各组 PASS，最后为 `UILab checks passed`。界面命中、系统返回、键盘、布局和 sheet 生命周期要在应用里操作。日志可以解释依赖和测量，但不能证明固定调度次数、内存释放或性能收益。

## 验证记录的范围

2026-11-01，重写后的工程已通过 generic iOS Simulator 的 Debug 与 Release 构建；构建仅提示未依赖 AppIntents、跳过元数据提取。上面的模型检查重新执行，三组 PASS，最终输出 `UILab checks passed`。Markdown 本地链接与锚点、差异空白检查通过。

在 iPhone Duo / iOS 27.1 Simulator 实际操作了状态与绑定、属性读取、稳定 / 位置身份和明确重建、简单导航、部分类型化路径、布尔 sheet、草稿取消与完成、语言与 RTL，以及自适应基础计数。各教程就地给出输入、结果、截图及未复测项目。输入动画、完整布局和修正后的区域适配没有完成整组交互复测，构建通过不能代替其运行验证。

原有实现的模拟器观察保留为历史背景；改过的界面以本次明确记录为准。最低部署版本不等于最低版本已经运行，本机没有执行 iOS 18 runtime 验证。

真机输入法、VoiceOver、实际触摸与折叠、分屏和多 Scene 应使用相应条件验证；未操作的项目会标注未执行。本章没有帧时间、GPU 或能耗的受控测量。
