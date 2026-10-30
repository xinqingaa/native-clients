# 原生客户端学习

基于已有的 Flutter 复杂客户端开发经验，系统学习 Swift、Kotlin 与 iOS、Android 原生工程能力，支持跨端与原生结合的混合开发。技术主线为 Swift + SwiftUI、Kotlin + Jetpack Compose，学习围绕客户端的原理、机制、架构、实现与验证展开。

文档贯穿学习过程，应用工程、独立语言实验、图示和诊断产物为正文提供实现与验证依据。业务场景按当前问题选择，优先取材于已有 Flutter 实践。

## 已有经验与学习起点

已有实践涉及实时数据与共享订阅、请求竞争与迟到结果、复杂导航和表单状态保留、K 线视口与高频更新、跨语言调用与资源所有权，以及缓存隔离、启动和构建发布。这些经历提供问题认识、工程约束和设计判断，原生实现与运行证据随本项目的学习逐步形成。

已有 JavaScript、Dart 等语言基础，理解常见语言概念。原生实践随实际需求穿插开展，借助 AI 可以编写代码，阅读原生代码也能理解大部分内容；Swift、Kotlin 的具体特性及原生平台机制仍需系统学习。

本次学习从已有基础出发，重点建立各语言的特性、标准库、运行机制与原生客户端模型，再将这些认识用于跨端与原生协作。问题和业务要求可以相近，语言、内存、任务、UI 与宿主生命周期的语义需要分别说明和核验。

必要背景直接描述在本项目中，各篇核心正文能够独立恢复主要理解，工程文档提供具体实现和验证入口。

## 目录结构

主要目录如下，各目录通过自身的 README 提供入口。工程配置、源码和测试随对应主题逐步建立；当前以 [Xcode 使用与调试](ios/docs/project-started.md)建立操作入口，从 [iOS 01 Swift 语言与运行机制](docs/ios/01-language-runtime-concurrency.md)和 [Swift 基础实验](swift-core/docs/02-basics-and-functions.md)开始学习；[EngineeringLab 工程基础实验](ios/docs/engineering-foundations.md)配合第 07 篇。

```text
native-clients/
├── README.md
├── AGENTS.md
├── SPEC.md
├── WORKFLOW.md
├── docs/
│   ├── README.md
│   ├── ios/                   # iOS 九篇核心正文
│   └── android/               # Android 九篇核心正文
├── swift-core/                # 独立 Swift 语言实验
│   ├── Sources/
│   ├── Tests/
│   └── docs/
├── kotlin-core/               # 独立 Kotlin/JVM 语言实验
│   ├── src/
│   └── docs/
├── ios/                       # Swift + SwiftUI 应用工程
│   └── docs/
├── android/                   # Kotlin + Compose 应用工程
│   └── docs/
└── shared/
    ├── docs/                  # 共用工具的安装与配置说明
    └── services/              # 共用 Node mock 服务
        ├── src/
        ├── fixtures/
        ├── scenarios/
        └── docs/
```

## 目录入口

| 目录 | 职责 |
| --- | --- |
| [docs](docs/README.md) | 九个能力域的知识结构与双端核心正文 |
| [swift-core](swift-core/README.md) | 独立 Swift 语言学习与机制实验 |
| [kotlin-core](kotlin-core/README.md) | 独立 Kotlin/JVM 语言学习与机制实验 |
| [ios](ios/README.md) | Swift + SwiftUI 应用工程及具体实现文档 |
| [android](android/README.md) | Kotlin + Compose 应用工程及具体实现文档 |
| [shared](shared/README.md) | 双端共用的工具配置、模拟服务与场景基础 |

## 推进方式

九个能力域保证知识覆盖，四个阶段控制学习深度。同一套正文随实验、实现和验证持续完善。

1. **建立运行模型**：理解工程、构建、启动、页面、任务、状态更新与资源结束的完整链路。
2. **掌握核心机制**：从完整问题出发，深入语言运行时、并发、生命周期、UI、状态和数据，核对已有判断在原生环境中的成立条件。
3. **形成架构与平台能力**：组合代表性场景，处理模块协作、依赖、共享资源、系统能力与互操作。
4. **深化诊断与交付**：固定运行条件，通过性能分析、故障验证、测试和构建产物核对工程判断与实际效果。

语言主题通过特性介绍与独立实验建立理解；应用主题从具体问题进入平台机制与设计判断，通过实现和运行核对结论。网络与服务端行为统一由 [Node mock 服务](shared/services/README.md)模拟；系统生命周期与平台行为在对应运行环境中验证。

## 文档分工

根目录 `docs/` 解释语言特性、平台机制、架构判断、取舍与重要边界。语言工程的 `docs/` 维护具体写法、示例代码与独立实验，应用工程的 `docs/` 维护当前实现设计、配置、源码入口、运行步骤和实际验证结果。具体内容归属见 [核心知识入口](docs/README.md)，编写规则见 [AGENTS](AGENTS.md)。

## 协作与成果约定

| 文档 | 职责 |
| --- | --- |
| [SPEC](SPEC.md) | 定义学习单元、成果形式与完成依据 |
| [WORKFLOW](WORKFLOW.md) | 说明学习任务从问题到验证和沉淀的推进过程 |
| [AGENTS](AGENTS.md) | 规定资料核验、写作、实现、验证和编辑的长期规则 |
