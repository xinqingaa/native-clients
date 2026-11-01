# iOS 核心正文

按[九个能力域](../README.md#九篇核心正文大纲)组织，主线为 Swift + SwiftUI，并覆盖必要的 UIKit 协作。

## 当前入口

| 正文 | 配套实践 | 当前状态 |
| --- | --- | --- |
| [01｜Swift 语言特性、运行时与并发](01-language-runtime-concurrency.md) | [Swift 实验目录](../../swift-core/docs/README.md) | 已调整正文表达；五组可执行入口与五篇实验文档，编译诊断归入对应主题 |
| [02｜SwiftUI 页面、应用运行与生命周期](02-app-lifecycle.md) | [EngineeringLab 页面实验](../../ios/docs/swiftui-pages-and-state.md) | 应用与页面声明、页面生命周期、状态存续、前后台与内存；三篇实验提供代码与运行观察 |
| [03｜SwiftUI 更新、布局、渲染与交互](03-ui-rendering-interaction.md) | [第三章运行与阅读入口](../../ios/docs/swiftui-ui-lab.md)、[五组教程](../../ios/docs/README.md#第三章配套实验) | 正文按能力与机制重写；实验从基础用法递进到对照与组合，实际验证范围见各教程 |
| [07｜工程基础与工具链](07-engineering-foundations.md) | [EngineeringLab 工程实验](../../ios/docs/engineering-foundations.md) | 已有正文与实验，具体未验证部分以工程记录为准 |

## 阅读与推进

从 01 认识 Swift，再按主题运行对应实验。独立语言示例可直接在终端运行，入口见 [Swift 运行说明](../../swift-core/README.md)。

进入 02 后，以 Xcode 和 Simulator 运行 EngineeringLab，沿正文就近进入对应实验。基本操作查阅已有的 [Xcode 使用与调试](../../ios/docs/project-started.md)；依赖、配置和构建产物的系统学习留到 07。

03 承接身份与状态存续，通过“UI 与交互”入口观察更新、布局、导航和适配。可以先读当前主题正文，再按运行入口从局部状态、布局、输入与动画进入导航和适配实验；iPhone Duo 的新区域与 arrangement 能力单独标注系统条件。

后续按宿主、UI、架构、数据和系统协作推进，再进入诊断与交付，尚未建立的正文见统一大纲。九篇编号组织知识，四阶段沿用根 README；具体运行结果在工程文档中记录，学习掌握由实际解释与操作检验。
