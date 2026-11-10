# 模拟服务文档

维护共享股票服务的数据、接口和运行约定。

- [股票接口与数据方案](api.md)：HTTP、WebSocket、身份、交易有效期、幂等、账本和重置。
- [服务运行](../README.md)：安装、启动、测试、端口和数据文件。
- [产品方案](../../../docs/product.md)：功能范围、交互和模拟交易规则。
- [HTML 原型](../../../prototype/README.md)：可操作流程与浏览器验证。

## Node.js 环境准备

运行服务需要 Node.js 22 或更新版本。先检查已有环境：

```bash
node --version
npm --version
```

已有环境可用时，后续按服务工程声明的版本核对。尚未安装时，可从 [Node.js 官方下载页](https://nodejs.org/en/download)选择当前 LTS 的 macOS 安装包，手动完成安装后重新打开终端检查上述命令；已有版本管理器时使用原管理方式。

工程已提供 package.json 和 package-lock.json。依赖安装与启动命令见服务入口；本轮安装了工程内依赖，未安装或重配本机 Node。
