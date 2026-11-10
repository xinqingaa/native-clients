# Kotlin App 文档

本目录是后续 Kotlin + Jetpack Compose 港股模拟交易 App 的归属，目前仅维护准备文档，没有 Gradle 工程、应用源码或构建入口。先评估产品和原型，再根据确认后的范围建立原生工程。

## 工具入口

- [Android 开发环境与 Codex 配置](docs/codex-setup.md)：Android Studio、JDK、SDK、Emulator、Android skills 和 IDE MCP 的手动准备与验证。

Android Studio 基本使用文档由学习者后续补充，目前没有对应教程，不创建占位链接。

## 方案与知识

- [产品草案](../docs/product.md)与[交互原型](../prototype/README.md)：等待评估，可调整。
- [架构方案](../docs/architecture.md)：双端职责和状态、资源建议，尚未在原生端实现。
- [接口方案](../shared/services/docs/api.md)与[共享服务](../shared/services/README.md)：当前原型使用的 mock。
- [Android 知识正文](../docs/android/README.md)：保留已有 Kotlin 正文与知识规划。

原生工程建立时再选择兼容的 JDK、Gradle、AGP、Kotlin、Compose 和 SDK 版本，提供工程 Wrapper 及准确的运行说明。环境工具存在不等于应用已构建、安装或运行。
