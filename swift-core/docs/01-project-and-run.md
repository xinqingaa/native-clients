# Swift 01｜独立工程与最小实验

本文说明如何在不依赖 iOS App 的情况下运行一个 Swift Package。它用于隔离 Swift 代码、模块和测试的关系；iOS 应用中的工程对象和 Xcode 操作见 [iOS 工程入门](../../ios/docs/project-started.md)，平台工具链见 [iOS 01｜工程基础与工具链](../../docs/ios/01-engineering-foundations.md)。

## 工程结构

```text
swift-core/
├── Package.swift
├── Sources/SwiftCore/Practice.swift
├── Tests/SwiftCoreTests/PracticeTests.swift
└── docs/
```

- `Package.swift` 描述 package 名称、library product、源码 target 和测试 target。
- `Sources/SwiftCore` 中的代码编译为 `SwiftCore` module。
- `Tests/SwiftCoreTests` 通过 `import SwiftCore` 使用模块中的公开 API。
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

测试文件中的 `import SwiftCore` 让测试模块可以查找 `SwiftCore` 的声明。`Practice` 和 `remaining` 使用 `public`，因为它们要被另一个模块调用。把 `public` 临时改为默认访问级别，再运行 `swift test`，应看到测试模块无法访问该声明；恢复后重新测试。

这个实验只验证访问控制和测试模块边界。它不把 `precondition` 当作用户输入校验方案，也不替代 iOS 工程中对资源、安装和启动的验证。

## 当前实验的完成依据

- 能指出 `Package.swift`、源码 target 和测试 target 的关系。
- 能运行 `swift build` 和 `swift test`。
- 能解释为什么测试需要 `import SwiftCore` 和 `public`。
- 能区分 Swift package 的构建测试与 iOS App 的安装启动。

