# 股票 mock 接口与数据方案

本契约描述当前已实现的共享 mock，仍是可调整的接口方案，尚未冻结为原生端最终契约；调整时同步服务、接口文档与受影响的产品规则。

本契约对应[产品方案](../../../docs/product.md)与当前[服务实现](../src/server.js)。Swift/Kotlin App 按此契约接入。运行入口见[服务 README](../README.md)。当前为 v1 本地 mock，核对日期 2026-11-10。

## 公共约定

HTTP 根路径为 `/api/v1`，JSON 使用 camelCase，成功响应为 `{ data, meta: { requestId, serverTime, epoch } }`，失败为 `{ error: { code, message }, meta: { serverTime, epoch } }`。字段表以下文及实现为准；业务错误与 HTTP 状态分别处理。

时间统一为 Unix 毫秒数。`serverTime` 使用服务实际时钟，决定会话、确认有效期和提交先后；`marketTime` 是从固定模拟交易日开始推进的市场时钟，显示行情并决定模拟日终。`asOf` 是该报价最后更新的实际服务时间，休市时不随 GET 请求刷新。两套时间各有用途，客户端不能用模拟市场时间计算确认倒计时。

金额与价格采用十进制字符串，币种 HKD。当前只支持两位小数；服务内以整数分记账。数量为整数股，股票使用 `HK.00700` 等稳定证券 ID，代码 `00700` 不单独充当全市场身份。

需要身份的请求使用 `Authorization: Bearer <accessToken>`。全部账户与订单查询从会话推导用户归属，不接受客户端指定账户 ID 访问他人数据。开发控制接口也需要登录，市场状态切换限演示账户。

服务启动生成新的 `epoch`。同一 epoch 内，账户 `version` 只随业务账本变化，自选 `version` 随列表变化；报价 `version` 随价格更新，账户 `valuationVersion` 随市场 tick 推进。服务重启后的行情版本不可与旧 epoch 直接比较。

## 身份

| 方法与路径 | 输入 | 返回 |
| --- | --- | --- |
| `POST /auth/register` | `email, password, name?` | 新会话，201 |
| `POST /auth/login` | `email, password` | 会话 |
| `POST /auth/refresh` | `refreshToken` | 轮换后的会话 |
| `GET /auth/me` | 访问凭据 | `id, email, name` |
| `POST /auth/logout` | 访问凭据 | `loggedOut: true` |

会话为 `userId, accessToken, refreshToken, expiresAt, refreshExpiresAt, user, serverTime`。访问有效期 8 小时，刷新有效期 7 天；刷新令原访问/刷新凭据失效。退出只注销当前会话。注册密码使用带随机盐的 scrypt 保存，运行数据仅保存在已忽略的 `.data/`；这些本地模拟凭据不用于真实服务。

## 证券与行情

| 方法与路径 | 参数 | 返回 |
| --- | --- | --- |
| `GET /health` | 无 | `status, epoch` |
| `GET /instruments` | `query?`：名称、代码、英文或行业 | `items: Instrument[]` |
| `GET /quotes` | `ids?`：逗号分隔证券 ID，不传为全部 | `items: Quote[]` |
| `GET /market` | 无 | 市场状态、时钟、模拟指数 |
| `GET /instruments/{id}/candles` | `period=1m\|1d\|1w\|1mo`, `before?`, `limit?` | 历史与当前柱 |
| `GET /instruments/{id}/funds` | `range=1d\|5d\|20d` | 资金流向 |

这些行情入口公开可读。证券资料包括 `id, symbol, name, englishName, sector, market, currency, lotSize, tickSize`，以及固定种子 `price, previousClose`。显示实时价格应读取 Quote，不能把证券种子价格当作实时行情。

Quote 字段如下：

| 字段 | 类型与含义 |
| --- | --- |
| `instrumentId, currency` | 证券身份、币种 |
| `price, previousClose, change, changePercent` | 十进制字符串；changePercent 的 `2.00` 表示 2% |
| `bid, ask` | 模拟买一、卖一 |
| `open, high, low` | 当前模拟日 OHLC 的其余字段 |
| `volume` | 整数股 |
| `turnover` | 十进制成交金额 |
| `asOf, marketTime, serverTime` | 最后报价实际时间、模拟报价时间、响应实际时间 |
| `marketStatus, version` | `OPEN/CLOSED`、报价版本 |

K 线返回 `instrumentId, period, items, nextBefore, version, marketTime`。每根包含 `time, open, high, low, close, volume, complete`。`before` 为排他上界，直接传上次的 `nextBefore`；默认 90 根，最多 180 根。当前柱 `complete=false`，推送会替换相同 time 的柱；历史以 time 合并。

周/月使用固定 7/30 天模拟桶，历史不包含真实休市日历；分时为分钟合成序列。当前日柱与报价 OHLC、volume 一致。行情历史长期分页、自然周/月聚合与数据源修订另行扩展契约。

资金返回 `instrumentId, range, buy, sell, net, categories: [{name, net}], version`。金额为 HKD，按模拟成交额与涨跌幅计算，具体口径见产品文档。市场指数返回 `indices: [{name, value, changePercent}]`，属于合成展示。

## 自选与账户

| 方法与路径 | 输入 | 返回 |
| --- | --- | --- |
| `GET /watchlist` | 无 | `instrumentIds, version` |
| `PUT /watchlist` | 完整 `instrumentIds` 与已读 `version` | 新列表与新版本 |
| `GET /account` | 无 | 账户汇总与全部持仓 |

自选采用完整列表替换实现添加、删除与排序，空数组有效、最多 50 只、不能重复。版本不匹配返回 409 `VERSION_CONFLICT`，客户端重读后由用户决定是否再改。

账户字段为 `currency, cash, availableCash, frozenCash, marketValue, totalAssets, unrealizedPnL, dailyPnL, positions, version, valuationVersion, serverTime`。持仓字段为 `instrumentId, quantity, availableQuantity, averageCost, cost, marketValue, unrealizedPnL, dailyPnL`。

`dailyPnL` 仅为当前持仓相对昨收的浮动，不包含完整已实现盈亏和日内现金流。`averageCost` 四舍五入到分用于显示；成本累计采用 `cost`，不能通过已取整均价反推账本。

## 下单、委托与成交

### 预检查与提交

`POST /orders/previews` 接收：

```json
{
  "instrumentId": "HK.00700",
  "side": "BUY",
  "limitPrice": "430.00",
  "quantity": 100
}
```

`side` 只接受 BUY/SELL，限价 1.00–10,000.00，数量 100–100,000 且为 100 的整数倍。返回 `previewId, instrumentId, side, limitPrice, quantity, notional, estimatedFee, estimatedTotal, expiresAt, serverTime, timeInForce, quote`。买单 total 含费用，卖单 total 扣费用。确认 15 秒后过期，尚未冻结资金或持仓。

`POST /orders` 接收 `previewId, clientOrderId`，成功返回 Order 和 201。客户端订单标识为 8–100 位字母、数字或连字符，建议 UUID。提交只引用服务端确认内容，不接受提交阶段修改价格或数量。

同一用户、同一 clientOrderId、同一 previewId 的重试返回原委托当前状态，即使确认已过期也可恢复已受理委托。相同 clientOrderId 换 previewId 返回 `IDEMPOTENCY_CONFLICT`；相同 previewId 换 clientOrderId 返回 `PREVIEW_USED`。

接收时再次核对可用资金、可卖持仓、市场与有效期。当前单进程内同步完成冻结、委托创建与状态持久化，随后发布账户和委托快照；测试不代表具备多进程数据库事务能力。

### 查询与撤单

| 方法与路径 | 返回或行为 |
| --- | --- |
| `GET /orders` | `items: Order[], version`，新委托在前 |
| `GET /orders/{id}` | 当前用户委托详情 |
| `GET /orders/by-client-id/{clientOrderId}` | 提交结果恢复 |
| `POST /orders/{id}/cancel` | 撤销剩余数量并释放冻结 |
| `GET /trades` | `items: Trade[], version`，新成交在前 |

Order 包括 `id, clientOrderId, instrumentId, side, limitPrice, quantity, filledQuantity, averageFillPrice, fee, status, createdAt, updatedAt, expiresAt, timeInForce`。`marketCreatedAt, marketUpdatedAt, marketExpiresAt` 为对应的模拟市场时间，用于界面显示；实际有效期判断使用 expiresAt。未成交均价为 null。状态为 OPEN、PARTIALLY_FILLED、FILLED、CANCELED、EXPIRED。

Trade 包括 `id, orderId, instrumentId, side, quantity, price, notional, fee, executedAt, marketExecutedAt`，最后两项分别为实际服务时间和模拟市场显示时间。每条 fee 是本次成交增加的费用，Order.fee 是累计费用。

已经撤销的委托重复撤单返回当前状态，其他终态撤单返回 `ORDER_TERMINAL`。撤单与成交按服务实际处理先后决定，客户端更新真实返回状态，不假定点击撤单后已成交部分可以逆转。

委托列表和成交列表当前返回账户全部历史，没有游标分页；mock 规模有限。需要长历史时再增加分页、筛选和留存规则。

### 提交结果不明

客户端确认前生成 clientOrderId，发送前保存待确认的两个标识。网络超时后先按 clientOrderId 查询：查到即恢复；暂时未查到时可重试相同提交，不能直接生成新标识创建另一笔。已明确收到过期且未受理错误时才移除待确认记录。

## WebSocket

连接 `/stream`，与 HTTP 共用端口。服务首先发送 `{type:"hello", epoch, serverTime, heartbeatInterval:20000}`。客户端登录后先发送 `{type:"authenticate", accessToken}`，成功收到 `{type:"authenticated"}`。访问凭据不放进 URL。

| 客户端消息 | 语义 |
| --- | --- |
| `{type:"subscribe", topics:[...]}` | 添加订阅；每个主题立即返回完整 snapshot |
| `{type:"unsubscribe", topics:[...]}` | 移除订阅 |
| `{type:"ping"}` | 返回 pong 与 serverTime |

支持以下主题：

| topic | 身份 | data |
| --- | --- | --- |
| `market` | 公开 | 市场汇总 |
| `quote:HK.00700` | 公开 | 单证券 Quote |
| `candles:HK.00700:1d` | 公开 | 最近 90 根 K 线 |
| `funds:HK.00700:1d` | 公开 | 单证券资金流向 |
| `watchlist` | 需要登录 | 当前用户自选完整快照 |
| `account` | 需要登录 | 当前用户账户完整快照 |
| `orders` | 需要登录 | 当前用户委托完整列表与 version |

服务消息统一为：

```json
{
  "type": "snapshot",
  "eventId": "uuid",
  "topic": "orders",
  "sequence": 1,
  "epoch": "server-epoch",
  "serverTime": 1790000000000,
  "data": { "items": [], "version": 1 }
}
```

后续更新为 `type:"event"`，目前也携带完整数据，减少第一版增量合并复杂度。sequence 在**单连接、单 topic**内连续递增，不用于不同连接间比较。每次订阅的 snapshot 是新接收基线；服务端在同一事件循环内建立快照与订阅，客户端以该快照衔接后续事件。

发现序号缺口、epoch 改变或重连后，重新订阅获取 snapshot。没有历史事件重放或至少一次投递保证；通过快照恢复最新状态。账户和委托消息可先后到达，客户端可按其共同 version 等待同版数据；不把两个消息的到达视为原子 UI 更新。

私有主题每次发送前重新校验访问凭据，失效发 error 并以 4001 关闭连接。客户端刷新凭据后重连或重新认证。原生端的重连退避与超时阈值在接入时确定；20 秒心跳由 hello 消息告知。

## 开发控制与重置

`POST /dev/reset` 恢复当前用户初始现金、自选与持仓，清空其委托和成交，作废未提交确认。演示账户恢复演示持仓，新账户仍为空持仓。该操作不重置其他用户与全局行情。

`POST /dev/market` 接收 `{status:"OPEN"}` 或 CLOSED，仅演示账户可用，影响所有用户。CLOSED 暂停新委托和撮合，仍允许查询与撤单；实际模拟日终由 tick 决定并使活动委托到期。

重启服务恢复用户、会话、自选和交易账本；行情回到固定种子，新 epoch 开始，所有活动委托到期释放冻结，内存确认丢弃。市场时钟重新从 10:36 开始。全新数据环境使用另一个 `STOCK_STATE_FILE`；删除运行数据应先停止服务并确认本地数据可丢弃。

## 主要错误

| HTTP | code | 客户端处理 |
| --- | --- | --- |
| 400 | INVALID_EMAIL / WEAK_PASSWORD / INVALID_PRICE / INVALID_QUANTITY / INVALID_SIDE | 修正输入 |
| 401 | INVALID_CREDENTIALS / SESSION_EXPIRED | 修正凭据、刷新或重新登录 |
| 403 | FORBIDDEN | 当前用户无开发控制权限 |
| 404 | INSTRUMENT_NOT_FOUND / ORDER_NOT_FOUND | 核对身份，订单按恢复规则处理 |
| 409 | EMAIL_EXISTS / VERSION_CONFLICT | 登录已有账户或重读自选 |
| 409 | MARKET_CLOSED / PREVIEW_EXPIRED / PREVIEW_USED | 解释当前状态，核对原提交 |
| 409 | IDEMPOTENCY_CONFLICT / ORDER_TERMINAL | 保留原委托事实，停止错误重试 |
| 400 | INSUFFICIENT_FUNDS / INSUFFICIENT_POSITION | 更新账户并调整交易 |
| 413 / 500 | BODY_TOO_LARGE / INTERNAL_ERROR | 调整请求或提示重试；提交按查单恢复 |

接口设计与服务验证只覆盖当前本地模拟条件；尚不包含真实券商、交易所、原生权限或后台运行的验证。
