# 模拟服务实现

`domain.js` 管理模拟行情、账户账本、会话、自选、预检查、委托和成交；金额按整数分处理。`server.js` 提供 HTTP 路由、WebSocket 快照与推送、HTML 静态入口和运行进程生命周期。

接口语义见[接口方案](../docs/api.md)，运行与检查见[服务入口](../README.md)。源码不依赖独立 Swift/Kotlin 实验工程。
