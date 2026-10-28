# 原生客户端学习

基于已有的 Flutter 复杂客户端开发经验，系统补充 iOS 与 Android 原生工程能力。技术主线为 Swift + SwiftUI、Kotlin + Jetpack Compose，学习围绕客户端的原理、机制、架构、实现与验证展开。

文档贯穿学习过程，应用工程、独立语言实验、图示和诊断产物为正文提供实现与验证依据。业务场景按当前问题选择，优先取材于已有 Flutter 实践。

## 目录结构

主要目录如下，各目录通过自身的 README 提供入口。工程配置、源码和测试随对应主题逐步建立。

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
| [shared](shared/README.md) | 双端共用的模拟服务与场景基础 |

## 推进方式

九个能力域保证知识覆盖，四个阶段控制学习深度。同一套正文随实验、实现和验证持续完善。

1. **建立运行模型**：理解工程、构建、启动、页面、任务、状态更新与资源结束的完整链路。
2. **掌握核心机制**：深入语言运行时、并发、生命周期、UI、状态和数据。
3. **形成架构与平台能力**：处理模块协作、依赖、共享资源、系统能力与互操作。
4. **深化诊断与交付**：通过性能分析、故障验证、测试和构建产物核对工程判断。

每个主题沿“理解问题 → 解释机制 → 实现或实验 → 制造异常 → 验证并修正文档”推进。网络与服务端行为统一由 [Node mock 服务](shared/services/README.md)模拟；系统生命周期与平台行为在对应运行环境中验证。

## 文档分工

根目录 `docs/` 解释平台原理、机制、架构、取舍与失败边界，并保留必要的示例和验证方法。各工程的 `docs/` 维护具体语法、实现设计、配置、运行步骤和验证结果。

## 协作与成果约定

| 文档 | 职责 |
| --- | --- |
| [SPEC](SPEC.md) | 定义学习单元、成果形式与完成依据 |
| [WORKFLOW](WORKFLOW.md) | 说明学习任务从问题到验证和沉淀的推进过程 |
| [AGENTS](AGENTS.md) | 规定资料核验、写作、实现、验证和编辑的长期规则 |
