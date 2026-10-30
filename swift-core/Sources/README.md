# Swift 实验源码

五个 Demo 目录各是一个 executable target，组内源文件承接不同子例。入口与选择参数见[包 README](../README.md#学习分组)，每篇实验文档就近链接对应源码。

SwiftCore 共享库提供命令行选择与行为实验的辅助对象：

- [ExperimentSelection.swift](SwiftCore/ExperimentSelection.swift)：选择整组、子例和列出名称，输入错误时给出提示。
- [Practice.swift](SwiftCore/Practice.swift)：公开纯函数，用于观察普通跨模块调用。
- [AsyncGate.swift](SwiftCore/AsyncGate.swift)：一次性闸门，显式控制任务到达和恢复，故意不响应取消。
- [ReservationExperiment.swift](SwiftCore/ReservationExperiment.swift)：复现 actor 跨挂起点检查失效，并对比恢复后复核。

命令行选择只负责实验入口，不参与被观察的语言机制。故意编译失败的 Diagnostics 位于 Sources 外，分别由类型与并发两篇实验说明。
