# 原生客户端学习

基于已有的 Flutter 复杂客户端经验，通过两个独立的股票 App 学习 Swift、Kotlin 和原生平台。技术主线为 Swift + SwiftUI、Kotlin + Jetpack Compose，两个客户端使用 `shared/services` 的同一套 mock 接口。

学习从完整应用建立上下文：先评估产品和交互方案，再实现原生 App，开发中持续调整需求；能够看到整体运行关系后，再从代码和实际问题反推知识正文、查漏补缺。AI 承担实现工作，学习重点是读懂代码、理解状态与数据流、判断方案及其边界。

## 当前状态与入口

当前已提供港股模拟交易的产品草案、可交互 HTML 原型与共享 mock。产品、交互和接口方案仍待学习者评估，可以继续调整。`swift-app/` 和 `kotlin-app/` 目前仅有文档，尚未创建原生应用工程。

| 入口 | 用途 |
| --- | --- |
| [产品方案](docs/product.md) | 登录注册、自选、行情、交易与账户闭环的产品草案 |
| [交互原型](prototype/README.md) | 启动并评估界面、流程和模拟数据 |
| [接口方案](shared/services/docs/api.md) | 当前 mock 的 HTTP、WebSocket、数据和交易语义 |
| [架构方案](docs/architecture.md) | 后续双端建设的职责边界、状态和资源约定 |
| [Swift App 文档](swift-app/README.md) | Xcode 基本使用与 iOS 环境、Codex 配置 |
| [Kotlin App 文档](kotlin-app/README.md) | Android 环境与 Codex 配置；Studio 使用文档后续补充 |
| [知识索引](docs/README.md) | 保留的正文与九个能力域，按实际问题回查 |

体验原型需要 Node.js 22 或更新版本，在仓库根目录执行：

```bash
npm --prefix shared/services ci
npm --prefix shared/services start
```

打开 <http://127.0.0.1:4317>。服务配置、重置和测试见[服务说明](shared/services/README.md)。

## 已有经验与学习目标

已有 JavaScript、Dart 和 Flutter 基础，理解通用编程概念；实践涉及实时数据与共享订阅、请求竞争、导航和表单状态、K 线视口与高频更新、跨语言调用、资源所有权、缓存隔离以及构建发布。

这些经验用于认识问题、提出约束和评估方案。Swift 与 Kotlin 的语言语义、内存、任务、UI 更新和宿主生命周期仍需分别理解，不能根据名称相近直接套用 Flutter 判断。目标是能够沿真实源码解释一次操作怎样改变状态、发起工作、接收结果并结束资源。

## 推进方式

1. 评估产品、原型和 mock，明确本次要实现或调整的行为。
2. 在两个原生 App 中逐步完成登录、自选、行情、交易和账户闭环；实现次序随当前需求确定。
3. 在开发中阅读代码、微调需求、定位问题，并执行与改动相称的验证。
4. 完整应用形成后，从具体实现反推语言、平台和架构正文，沿知识索引查漏补缺；不必等全部功能结束才解决阻碍当前开发的机制问题。

不提前铺写整套正文，不维护独立语言实验或配套实验文档。需求变化自然进入开发过程，不设置固定的条件变更练习或模拟面试关卡。WebView、额外权限、后台执行和 Flutter/RN 混合开发后续按需要补充；前台断线恢复仍属于行情与交易本身的行为。

## 目录结构

```text
native-clients/
├── README.md
├── AGENTS.md
├── SPEC.md
├── WORKFLOW.md
├── docs/
│   ├── product.md             # 产品草案
│   ├── architecture.md        # 架构方案与实现状态
│   ├── ios/                   # 保留的 iOS 知识正文
│   └── android/               # 保留的 Android 知识正文
├── prototype/                 # HTML 交互原型
├── swift-app/                 # 目前仅文档，后续承载 SwiftUI App
├── kotlin-app/                # 目前仅文档，后续承载 Compose App
└── shared/
    ├── docs/                  # 共用工具配置
    └── services/              # 共享 Node mock
```

## 文档与协作

产品规则由产品文档维护，接口与数据语义由共享服务文档维护；架构文档维护双端共同设计，各 App 的 README 提供工具与后续运行入口。工程说明随实际实现增加，必要操作、设计或验证就近记录，不要求每个功能都另写一篇文档。

`docs/ios/` 与 `docs/android/` 的已有正文继续保留，作为参考与后续沉淀位置。九个能力域组织知识覆盖，不决定功能开发或阅读顺序。

[SPEC](SPEC.md)定义成果和完成依据，[WORKFLOW](WORKFLOW.md)说明推进过程，[AGENTS](AGENTS.md)维护长期协作规则。代码生成、工程运行和学习理解分别判断。
