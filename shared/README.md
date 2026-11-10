# 共享基础

维护两个原生股票 App 共用的接口、数据和开发工具说明。两端使用相同契约与模拟业务规则，各自实现平台状态、网络、存储和 UI。

- [Node mock 服务](services/README.md)：当前供 HTML 原型评估使用，后续原生端沿用的接口与数据方案仍可调整。
- [Codex 手动安装与配置](docs/codex-setup.md)：共用 CLI、配置范围及两端工具入口。
- [架构方案](../docs/architecture.md)：共享范围、职责和数据流建议。
