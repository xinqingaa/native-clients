# Swift 01｜独立工程与最小实验

本文说明如何在不依赖 iOS App 的情况下运行一个 Swift Package。它用于隔离 Swift 代码、模块和测试的关系；iOS 应用中的工程对象和 Xcode 操作见 [Xcode 使用与调试](../../ios/docs/project-started.md)，平台工具链见 [iOS 07｜工程基础与工具链](../../docs/ios/07-engineering-foundations.md)。

## 工程结构

```text
swift-core/
├── Package.swift
├── Sources/SwiftCore/Practice.swift
├── Sources/BasicsDemo/main.swift
├── Tests/SwiftCoreTests/PracticeTests.swift
└── docs/
```

- `Package.swift` 描述 package 名称、library product、源码 target 和测试 target。
- `Sources/SwiftCore` 中的代码编译为 `SwiftCore` module。
- `Tests/SwiftCoreTests` 通过 `@testable import SwiftCore` 访问启用测试支持的模块。
- `Sources/BasicsDemo` 是独立可执行 target，通过普通 `import SwiftCore` 使用公开方法；[基础语言单元](02-basics-and-functions.md)说明运行方式。
- 独立 Swift package 没有 `@main` 的 iOS App 入口；它由 Swift Package Manager 驱动构建和测试。

`Practice.remaining` 是一个最小的纯函数：它接收已完成数量和总数量，返回剩余数量。它没有 UI、Bundle、任务或平台资源，适合先观察模块和测试的基本关系。

## 从仓库根目录运行

```bash
swift build --package-path swift-core
swift test --package-path swift-core
```

预期 `swift build` 返回成功，`swift test` 运行 `remainingUsesTheDifferenceBetweenTotalAndCompleted` 并通过。构建产物进入被忽略的 `swift-core/.build`，不应把它当作源码提交。

也可以进入目录后运行：

```bash
cd swift-core
swift build
swift test
```

两种方式使用同一个 `Package.swift`。命令成功只证明当前工具链完成了对应阶段；它不证明 iOS App 可以启动，也不证明 SwiftUI 页面行为正确。

## 阅读一个跨模块调用

测试文件的导入让测试模块可以查找 SwiftCore 声明。`Practice` 和 `remaining` 使用 `public`，使 BasicsDemo 等普通消费模块能够调用。当前测试使用 `@testable import SwiftCore`，可以访问启用测试支持的模块中的 internal 声明，因此只移除 `public` 不足以复现跨模块不可访问。要观察普通消费方的边界，应将测试中的导入临时改为 `import SwiftCore`，并移除被调用类型或方法的 `public`，再运行测试；预期出现访问级别诊断。完成后恢复这两处修改。

这个实验只验证访问控制和测试模块边界。它不把 `precondition` 当作用户输入校验方案，也不替代 iOS 工程中对资源、安装和启动的验证。

## 当前实验的完成依据

- 能指出 `Package.swift`、源码 target 和测试 target 的关系。
- 能运行 `swift build` 和 `swift test`。
- 能区分普通 `import` 的公开 API 边界与 `@testable import` 对 internal 声明的访问。
- 能区分 Swift package 的构建测试与 iOS App 的安装启动。

