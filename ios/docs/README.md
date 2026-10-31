# iOS 工程文档

## 工具与环境入口

- [iOS 开发环境与 Codex 工具配置](codex-setup.md)：Xcode、Swift、Simulator 和工具连接的手动配置与验证。

## 日常学习入口

- [Xcode 使用与调试：EngineeringLab](project-started.md)：直接打开现有工程，认识窗口、运行、Preview、控制台、构建报告、断点、单步和配置切换。全程使用同一个 App。
- [iOS 01：Swift 语言与运行机制](../../docs/ios/01-language-runtime-concurrency.md)：类型、空安全、内存、同步异步、线程、事件循环与并发；具体写法见 swift-core。
- [Swift 类型与数据处理实验](../../swift-core/docs/01-values-and-data.md)：在独立程序中练习具体语法。

## 第二章配套实验

三组实验共用 EngineeringLab 的“应用与生命周期”标签，按顺序操作。正文见 [iOS 02](../../docs/ios/02-app-lifecycle.md)。

- [页面声明与状态身份](swiftui-pages-and-state.md)：App、Scene、View 的声明，输入更新与身份重建，局部与共享状态。
- [生命周期与任务](lifecycle-and-tasks.md)：Scene 与页面事件、视图关联任务、手动任务、取消和前后台观察。
- [对象内存与进程恢复](state-restoration.md)：State 的强引用、额外持有与 deinit，任务持有，以及场景状态和保存数据的重启对照。

## 工程基础实验

- [EngineeringLab｜工程基础实验](engineering-foundations.md)：配合 [iOS 07](../../docs/ios/07-engineering-foundations.md)检查工程模型、依赖、资源、配置、增量与故障。日志和断点的通用操作只在 Xcode 教程维护。

## 内容职责

本目录维护当前 iOS 应用的对象与接口设计、封装、配置、操作与真实验证。平台机制与判断归核心正文，系统语言写法归 Swift 文档；各篇保留理解当前内容所需的局部解释，通过链接衔接。

从当前场景、错误行为和预期结果出发，说明应用怎样落实方案。后续按实际问题补充状态、导航、数据、系统接入、性能、测试与交付，不由现有实验的功能列表决定核心知识结构。

构建、模拟器运行、真机行为与学习掌握分别记录，不把操作说明或截图存在视为全部验证通过。
