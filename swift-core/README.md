# Swift Core

Swift 的独立语言与机制实验，共五组可执行入口和五篇主题文档。每组包含多个小例子：无参数按文档顺序运行整组，也可指定子例。直接在 macOS 终端或 VS Code 集成终端看输出，无需先打开 Xcode App 工程。

## 第一次运行

从仓库根目录执行：

```bash
swift --version
swift run --package-path swift-core ValuesDemo
```

包要求 Swift 6.2 或更新工具链、macOS 15 或更新系统，采用 Swift 6 language mode。macOS 最低版本来自 Synchronization.Mutex 等实验 API，不是 Swift 语言本身的最低系统要求。2026-10-30 实际运行环境为 Apple Swift 6.4、macOS 27.0、arm64。

SwiftPM 首次构建会先打印进度，然后显示 `=== optional ===` 等子例标签与实验结果；构建信息通常在标准错误流，结果在标准输出。找不到 swift 时，需要先准备可用的 Swift 工具链；本次没有安装或修改本机工具。进入包目录后也可直接运行：

```bash
cd swift-core
swift run ValuesDemo
```

以下命令统一以仓库根目录为起点。在 swift-core 目录内执行时，去掉 `--package-path swift-core`。

## 学习分组

| 文档 | 可执行入口 | 子例参数 |
| --- | --- | --- |
| [01｜类型与数据处理](docs/01-values-and-data.md) | ValuesDemo | optional、collections、errors |
| [02｜函数与类型组织](docs/02-functions-and-modeling.md) | ModelingDemo | functions、members、composition |
| [03｜协议与泛型](docs/03-protocols-and-generics.md) | ProtocolsDemo | dispatch、abstraction、associated |
| [04｜内存与所有权](docs/04-memory-and-ownership.md) | MemoryDemo | sharing、cycles、captures |
| [05｜调度与并发](docs/05-execution-and-concurrency.md) | ConcurrencyDemo | dispatch、runloop、tasks、actors、streams |

各篇在同一主题内说明源码、输入、写法、输出与修改练习。语言特性和机制的连贯介绍见 [iOS 01](../docs/ios/01-language-runtime-concurrency.md)。

## 选择整组或单个子例

```bash
swift run --package-path swift-core ModelingDemo
swift run --package-path swift-core ModelingDemo --list
swift run --package-path swift-core ModelingDemo members
swift run --package-path swift-core ConcurrencyDemo tasks actors
```

不传参数或传 all 运行整组，--list／--help 列出子例；也可指定一个或多个名称。多个子例仍按源码规定的顺序执行，与参数先后无关；未知名称会打印提示并以退出码 2 结束。dispatch 在协议组表示方法派发，在并发组表示 Dispatch 队列，所属可执行入口决定含义。

## 在 VS Code 或 Xcode 中使用

VS Code 中打开仓库根目录，选择 Terminal → New Terminal，在集成终端执行上面的命令即可。补全和编辑器内断点需要相应 Swift 扩展，它们是额外编辑能力。现有 [.vscode/launch.json](../.vscode/launch.json) 已对应五个入口的 Debug／Release 配置，args 可以填入子例名；本次验证终端命令，没有操作 VS Code 的 F5 调试。

Xcode 可以打开 Package.swift，选择对应 executable scheme，在控制台看结果。它是可选入口，通用操作见独立的 [Xcode 教程](../ios/docs/project-started.md)，语言实验不要求 Simulator。Dispatch、RunLoop 和 Mutex 在本包使用 macOS 平台能力，不据此推断 iOS UI 行为。

## 构建、测试与源码位置

```bash
swift build --package-path swift-core
swift test --package-path swift-core
swift run --package-path swift-core -c release MemoryDemo
```

默认使用 Debug。需要对照优化后的寿命观察时，可单独选择 Release；实验文档会区分实际运行的配置。

[Package.swift](Package.swift) 声明五个 executable targets、一个 SwiftCore 库和一个测试 target。每组内部按子例拆源文件，属于同一个模块；同一组中可以共同使用类型，不必再建立新的包或启动配置。普通 import 依赖 public 等可见性，测试可以用 @testable import 访问启用测试支持的 internal 声明。具体辅助对象见[源码组织](Sources/README.md)，关键行为测试见[测试说明](Tests/README.md)。

Swift tools version 规定 manifest API 与最低工具要求，swiftLanguageModes 则明确语言模式。当前包没有配置默认 MainActor 隔离，也没有开启 NonisolatedNonsendingByDefault；App 模块的设置需要单独核对。

Diagnostics 中的四个文件故意不能通过类型检查，不属于正常 targets。类型与分支诊断归入实验 01，隔离与捕获诊断归入实验 05，运行方法就在对应小节。构建产物位于已忽略的 .build，不需要提交。

## 验证范围

2026-10-30 已在上述环境构建并运行五个整组入口，检查各子例选择、列表与错误参数；五个 Swift Testing 用例通过，四个诊断出现预期编译错误。各组文档记录正常输入与实际输出，队列输出按其保证的先后关系判断。

本包没有验证 VS Code／Xcode 界面调试、iOS UI 或设备行为。宏插件、进阶所有权和手动存储管理尚无完整专题实验。

官方入口：[Swift Package Manager](https://www.swift.org/documentation/package-manager/)。
