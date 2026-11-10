# 股票共享 mock 服务

为[海港产品](../../docs/product.md)提供会话、自选、行情、K 线、资金流向、账户、委托与成交，通过 HTTP 和 WebSocket 供后续原生 App 使用。业务语义见[接口方案](docs/api.md)，源码分工见[src](src/README.md)。

## 运行

需要 Node.js 22 或更新版本。本轮实际使用 Node.js 24.12.0，依赖通过 package-lock.json 锁定；没有安装全局工具。仓库根目录执行：

```bash
npm --prefix shared/services ci
npm --prefix shared/services start
```

健康检查入口为 <http://127.0.0.1:4317/api/v1/health>。根路径提供静态预览入口，使用方式见[原型说明](../../prototype/README.md)。服务默认只监听本机回环地址，Ctrl+C 结束运行。端口占用时换一个端口：

```bash
STOCK_PORT=4318 npm --prefix shared/services start
```

`STOCK_STATE_FILE` 可以指定独立数据文件的绝对路径；默认保存于 `shared/services/.data/state.json`，已经由仓库现有规则忽略。服务重启保留账户账本，但使未完成委托到期并释放冻结，行情和模拟市场时钟重新开始。具体语义见接口方案。

## 数据与重置

演示账号 `demo@harbor.app`，密码 `Harbor2026!`。也可以注册独立的模拟账户，初始现金相同、初始持仓为空。固定证券、演示持仓与初始现金见[market.json](fixtures/market.json)。

登录取得服务访问凭据后，调用 `POST /api/v1/dev/reset` 重置服务账户。重置清空当前用户交易并恢复初始自选与资金，不影响其他账户和全局报价。市场休市/恢复控制影响所有用户，仅演示账号可操作。当前可控状态见[场景说明](scenarios/README.md)。

## 检查

仓库根目录执行：

```bash
npm --prefix shared/services test
```

自动化检查覆盖资金冻结与成交结算、部分成交撤单、幂等提交、确认过期、重复卖出防护、日终、账户隔离、会话轮换、自选冲突、重启恢复、当前日 K 一致性，以及 HTTP / 双连接 WebSocket / 重连快照集成。

当前是本地单进程模拟服务，采用整数分记账和原子文件替换保存小规模数据。没有接入真实券商或交易所，没有多进程事务、完整撮合队列和长期交易历史分页。服务的验证不能证明原生生命周期、设备或真实金融系统行为。
