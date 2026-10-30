# Swift 语言与实验文档

系统组织 Swift 语法、标准库与独立实验。已经能运行 EngineeringLab 时，先读基础类型与函数，再按需要认识 Package；不要求先理解全部构建配置。

| 入口 | 内容与当前状态 |
| --- | --- |
| [Swift 01｜独立工程与最小实验](01-project-and-run.md) | Package、源码与测试模块的操作入口 |
| [Swift 02｜基础类型、函数与控制流](02-basics-and-functions.md) | 当前首批语言基础：变量、参数、返回、Optional、分支、数组遍历和同步闭包；有可运行 BasicsDemo |

后续按先修关系展开：集合与字符串 API → 类型、初始化与方法 → 协议和泛型 → 闭包与捕获 → 错误、编码解码 → 内存和并发。当前已完成的文档见上表，其余完整示例随后补充；目录中的其他源码草稿不自动列为已交付或已验证。

[iOS 01](../../docs/ios/01-language-runtime-concurrency.md)解释 Swift 语言特性、运行时与并发，提供知识结构、语义和机制边界；本目录按对应主题详细说明语法、API、代码示例和独立验证；[iOS 工程教程](../../ios/docs/project-started.md)负责 EngineeringLab 的日志与断点。这里的 Swift 01、02 是语言单元编号，与九篇平台正文编号分属不同目录。

示例入口见 [Sources](../Sources/README.md)，已有行为测试见 [Tests](../Tests/README.md)。每个实验记录输入、预期和真实观察，独立程序不替代应用生命周期或设备验证。
