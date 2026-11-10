import { randomUUID, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';
import { readFileSync, existsSync, mkdirSync, writeFileSync, renameSync } from 'node:fs';
import { dirname } from 'node:path';

export const fixture = JSON.parse(readFileSync(new URL('../fixtures/market.json', import.meta.url)));
export class DomainError extends Error {
  constructor(code, message, status = 400) { super(message); this.code = code; this.status = status; }
}
const fail = (code, message, status) => { throw new DomainError(code, message, status); };
export function cents(value) {
  if (typeof value !== 'string' || !/^\d{1,9}(\.\d{1,2})?$/.test(value)) fail('INVALID_PRICE', '请输入有效价格，最多两位小数');
  const [whole, decimal = ''] = value.split('.');
  return Number(whole) * 100 + Number(decimal.padEnd(2, '0'));
}
export const money = value => (value / 100).toFixed(2);
export const fee = notional => notional === 0 ? 0 : Math.max(100, Math.ceil(notional * 3 / 10000));
const hashPassword = (password, salt) => scryptSync(password, salt, 32).toString('hex');
const secret = () => randomBytes(32).toString('hex');
const baseMarketTime = Date.parse(fixture.marketTimeOrigin);

export class Market {
  constructor({ stateFile = null, now = () => Date.now() } = {}) {
    this.now = now; this.startedAt = now(); this.stateFile = stateFile;
    this.epoch = randomUUID(); this.tickNumber = 0; this.marketStatus = 'OPEN';
    this.users = []; this.sessions = []; this.previews = new Map();
    this.quotes = new Map(fixture.instruments.map((item, index) => [item.id, {
      price: cents(item.price), previousClose: cents(item.previousClose), open: cents(item.previousClose),
      high: Math.max(cents(item.price), cents(item.previousClose)) + 55,
      low: Math.min(cents(item.price), cents(item.previousClose)) - 38,
      volume: 12000000 + index * 1739000, turnover: (12000000 + index * 1739000) * cents(item.price), version: 1,
      asOf: now(), marketTime: baseMarketTime,
    }]));
    if (stateFile && existsSync(stateFile)) {
      const stored = JSON.parse(readFileSync(stateFile, 'utf8'));
      if (stored.schemaVersion !== 1) throw new Error('Unsupported mock state schema');
      this.users = stored.users; this.sessions = stored.sessions;
      // Market quotes restart from fixtures. Close outstanding day orders and release their reservations.
      for (const user of this.users) for (const order of user.orders) if (this.isActive(order)) {
        order.status = 'EXPIRED'; order.reservedCents = 0; order.updatedAt = this.now(); order.marketUpdatedAt = this.marketTime(); user.version++;
      }
    }
    if (!this.users.some(user => user.email === fixture.demo.email)) this.register(fixture.demo, true);
    this.save();
  }
  marketTime() { return baseMarketTime + (this.now() - this.startedAt); }
  save() {
    if (!this.stateFile) return;
    mkdirSync(dirname(this.stateFile), { recursive: true });
    writeFileSync(`${this.stateFile}.tmp`, JSON.stringify({ schemaVersion: 1, users: this.users, sessions: this.sessions }));
    renameSync(`${this.stateFile}.tmp`, this.stateFile);
  }
  register(input, demo = false) {
    const email = String(input.email || '').trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) fail('INVALID_EMAIL', '请输入有效邮箱');
    if (typeof input.password !== 'string' || input.password.length < 8 || input.password.length > 128) fail('WEAK_PASSWORD', '密码需为 8–128 位');
    if (this.users.some(user => user.email === email)) fail('EMAIL_EXISTS', '该邮箱已注册', 409);
    const salt = secret();
    const user = { id: randomUUID(), email, name: String(input.name || email.split('@')[0]).slice(0, 30), salt,
      passwordHash: hashPassword(input.password, salt), version: 1, cashCents: cents(fixture.initialCash),
      watchlist: fixture.instruments.slice(0, 6).map(item => item.id), watchlistVersion: 1,
      positions: demo ? fixture.positions.map(position => ({ instrumentId: position.instrumentId, quantity: position.quantity,
        costCents: cents(position.averageCost) * position.quantity })) : [], orders: [], trades: [] };
    this.users.push(user); this.save(); return user;
  }
  login({ email, password }) {
    const user = this.users.find(item => item.email === String(email || '').trim().toLowerCase());
    if (!user || typeof password !== 'string' || password.length > 128 || !timingSafeEqual(Buffer.from(user.passwordHash, 'hex'), Buffer.from(hashPassword(password, user.salt), 'hex'))) fail('INVALID_CREDENTIALS', '邮箱或密码错误', 401);
    return this.session(user);
  }
  session(user) {
    const session = { userId: user.id, accessToken: secret(), refreshToken: secret(), expiresAt: this.now() + 8 * 3600000, refreshExpiresAt: this.now() + 7 * 86400000 };
    this.sessions.push(session); this.save(); return { ...session, user: this.profile(user), serverTime: this.now() };
  }
  refresh(token) {
    const session = this.sessions.find(item => item.refreshToken === token && item.refreshExpiresAt > this.now());
    if (!session) fail('SESSION_EXPIRED', '登录已过期，请重新登录', 401);
    this.sessions = this.sessions.filter(item => item !== session);
    return this.session(this.users.find(user => user.id === session.userId));
  }
  authenticate(token) {
    const session = this.sessions.find(item => item.accessToken === token && item.expiresAt > this.now());
    if (!session) fail('SESSION_EXPIRED', '登录已过期，请重新登录', 401);
    return this.users.find(user => user.id === session.userId);
  }
  logout(token) { this.sessions = this.sessions.filter(item => item.accessToken !== token); this.save(); }
  profile(user) { return { id: user.id, email: user.email, name: user.name }; }
  instrument(id) {
    const item = fixture.instruments.find(item => item.id === id);
    if (!item) fail('INSTRUMENT_NOT_FOUND', '股票不存在', 404);
    return { ...item, market: 'HK', currency: 'HKD', tickSize: '0.01' };
  }
  instruments(query = '') {
    const term = query.trim().toLowerCase();
    return fixture.instruments.filter(item => [item.name, item.symbol, item.englishName, item.sector].some(value => value.toLowerCase().includes(term))).map(item => this.instrument(item.id));
  }
  quote(id) {
    this.instrument(id); const quote = this.quotes.get(id);
    return { instrumentId: id, currency: 'HKD', price: money(quote.price), previousClose: money(quote.previousClose),
      change: money(quote.price - quote.previousClose), changePercent: ((quote.price / quote.previousClose - 1) * 100).toFixed(2),
      bid: money(Math.max(1, quote.price - 1)), ask: money(quote.price + 1), open: money(quote.open), high: money(quote.high), low: money(quote.low),
      volume: quote.volume, turnover: money(quote.turnover), marketTime: quote.marketTime, asOf: quote.asOf, serverTime: this.now(),
      marketStatus: this.marketStatus, version: quote.version };
  }
  summary() {
    const changes = fixture.instruments.map(item => Number(this.quote(item.id).changePercent));
    const mean = changes.reduce((sum, value) => sum + value, 0) / changes.length;
    return { market: 'HK', currency: 'HKD', marketStatus: this.marketStatus, marketTime: this.marketTime(), serverTime: this.now(),
      indices: [{ name: '恒生指数', value: (26415.09 * (1 + mean / 100)).toFixed(2), changePercent: mean.toFixed(2) },
        { name: '恒生科技', value: (5872.18 * (1 + mean * 1.34 / 100)).toFixed(2), changePercent: (mean * 1.34).toFixed(2) },
        { name: '国企指数', value: (9238.44 * (1 + mean * .79 / 100)).toFixed(2), changePercent: (mean * .79).toFixed(2) }] };
  }
  candles(id, period = '1d', before = null, limit = 90) {
    if (!['1m', '1d', '1w', '1mo'].includes(period)) fail('INVALID_PERIOD', '不支持的 K 线周期');
    if (before !== null && (!Number.isFinite(Number(before)) || before === '')) fail('INVALID_TIME', '历史时间上界无效');
    this.instrument(id); const quote = this.quotes.get(id);
    const count = Math.min(180, Math.max(1, Number(limit) || 90));
    const duration = { '1m': 60000, '1d': 86400000, '1w': 7 * 86400000, '1mo': 30 * 86400000 }[period];
    const origin = Math.floor(baseMarketTime / duration) * duration;
    const current = Math.max(0, Math.floor((this.marketTime() - origin) / duration));
    const end = before === null ? current : Math.min(current, Math.ceil((Number(before) - origin) / duration) - 1);
    const seed = Number(id.slice(-5)) % 37;
    const priceAt = index => Math.max(100, Math.round(cents(this.instrument(id).price) * (1 + .052 * Math.sin((index + seed) * .13) + .019 * Math.sin((index + seed) * .71))));
    const offset = priceAt(0) - cents(this.instrument(id).price);
    const items = Array.from({ length: count }, (_, index) => {
      const step = end - count + index + 1, open = period === '1d' && step === current ? quote.open : priceAt(step - 1) - offset;
      const close = step === current ? quote.price : priceAt(step) - offset;
      if (period === '1d' && step === current) return { time: origin + step * duration, open: money(quote.open), close: money(quote.price), high: money(quote.high), low: money(quote.low), volume: quote.volume, complete: false };
      return { time: origin + step * duration, open: money(open), close: money(close),
        high: money(Math.max(open, close) + 10 + Math.abs(step * 17 % 90)), low: money(Math.max(1, Math.min(open, close) - 10 - Math.abs(step * 11 % 70))),
        volume: 130000 + Math.abs((step + seed) * 13103 % 900000), complete: step < current };
    });
    return { instrumentId: id, period, items, nextBefore: items[0].time, version: quote.version, marketTime: this.marketTime() };
  }
  funds(id, range = '1d') {
    if (!['1d', '5d', '20d'].includes(range)) fail('INVALID_RANGE', '不支持的统计范围');
    const quote = this.quote(id); const days = Number.parseInt(range); const total = Math.round(Number(quote.turnover) * 100 * .37 * days);
    const buyRatio = .50 + Math.max(-.12, Math.min(.12, Number(quote.changePercent) / 30));
    const buy = Math.round(total * buyRatio), sell = total - buy;
    return { instrumentId: id, range, buy: money(buy), sell: money(sell), net: money(buy - sell),
      categories: ['大单', '中单', '小单'].map((name, index) => ({ name, net: money(Math.round((buy - sell) * [.57, .28, .15][index])) })), version: quote.version };
  }
  watchlist(user) { return { instrumentIds: user.watchlist, version: user.watchlistVersion }; }
  updateWatchlist(user, ids, version) {
    if (version !== user.watchlistVersion) fail('VERSION_CONFLICT', '自选已变化，请刷新后重试', 409);
    if (!Array.isArray(ids) || ids.length > 50 || new Set(ids).size !== ids.length) fail('INVALID_WATCHLIST', '自选列表格式错误');
    ids.forEach(id => this.instrument(id)); user.watchlist = ids; user.watchlistVersion++; this.save(); return this.watchlist(user);
  }
  isActive(order) { return ['OPEN', 'PARTIALLY_FILLED'].includes(order.status); }
  account(user) {
    const frozen = user.orders.filter(order => this.isActive(order) && order.side === 'BUY').reduce((sum, order) => sum + order.reservedCents, 0);
    const positions = user.positions.filter(position => position.quantity > 0).map(position => {
      const price = this.quotes.get(position.instrumentId).price;
      const reserved = user.orders.filter(order => this.isActive(order) && order.side === 'SELL' && order.instrumentId === position.instrumentId).reduce((sum, order) => sum + order.quantity - order.filledQuantity, 0);
      return { instrumentId: position.instrumentId, quantity: position.quantity, availableQuantity: position.quantity - reserved,
        averageCost: money(Math.round(position.costCents / position.quantity)), cost: money(position.costCents), marketValue: money(price * position.quantity),
        unrealizedPnL: money(price * position.quantity - position.costCents), dailyPnL: money((price - this.quotes.get(position.instrumentId).previousClose) * position.quantity) };
    });
    const marketValue = positions.reduce((sum, position) => sum + cents(position.marketValue), 0);
    return { currency: 'HKD', cash: money(user.cashCents), availableCash: money(user.cashCents - frozen), frozenCash: money(frozen), marketValue: money(marketValue),
      totalAssets: money(user.cashCents + marketValue), unrealizedPnL: money(positions.reduce((sum, position) => sum + Number(position.unrealizedPnL) * 100, 0)),
      dailyPnL: money(positions.reduce((sum, position) => sum + Number(position.dailyPnL) * 100, 0)),
      positions, version: user.version, valuationVersion: this.tickNumber, serverTime: this.now() };
  }
  validateOrder(user, input) {
    const instrument = this.instrument(input.instrumentId);
    if (this.marketStatus !== 'OPEN') fail('MARKET_CLOSED', '市场休市，暂不能提交委托', 409);
    if (!['BUY', 'SELL'].includes(input.side)) fail('INVALID_SIDE', '请选择买入或卖出');
    const priceCents = cents(input.limitPrice);
    if (priceCents < 100 || priceCents > 1000000) fail('INVALID_PRICE', '模拟价格范围为 1.00–10,000.00 HKD');
    if (!Number.isInteger(input.quantity) || input.quantity < instrument.lotSize || input.quantity > 100000 || input.quantity % instrument.lotSize) fail('INVALID_QUANTITY', `数量需为 ${instrument.lotSize} 股的整数倍，最多 100,000 股`);
    const notionalCents = priceCents * input.quantity, feeCents = fee(notionalCents); const account = this.account(user);
    if (input.side === 'BUY' && notionalCents + feeCents > cents(account.availableCash)) fail('INSUFFICIENT_FUNDS', '可用资金不足');
    if (input.side === 'SELL' && input.quantity > (account.positions.find(position => position.instrumentId === input.instrumentId)?.availableQuantity || 0)) fail('INSUFFICIENT_POSITION', '可卖数量不足');
    return { instrumentId: input.instrumentId, side: input.side, limitPrice: money(priceCents), quantity: input.quantity,
      priceCents, notionalCents, feeCents };
  }
  preview(user, input) {
    const order = this.validateOrder(user, input); const id = randomUUID();
    const preview = { id, userId: user.id, ...order, expiresAt: this.now() + 15000 };
    this.previews.set(id, preview);
    for (const [key, value] of this.previews) if (value.expiresAt <= this.now()) this.previews.delete(key);
    return { previewId: id, instrumentId: order.instrumentId, side: order.side, limitPrice: order.limitPrice, quantity: order.quantity,
      notional: money(order.notionalCents), estimatedFee: money(order.feeCents), estimatedTotal: money(order.notionalCents + (order.side === 'BUY' ? order.feeCents : -order.feeCents)),
      expiresAt: preview.expiresAt, serverTime: this.now(), timeInForce: 'DAY', quote: this.quote(order.instrumentId) };
  }
  submit(user, input) {
    if (typeof input.clientOrderId !== 'string' || !/^[a-zA-Z0-9-]{8,100}$/.test(input.clientOrderId)) fail('INVALID_CLIENT_ORDER_ID', '缺少有效的客户端订单标识');
    const existing = user.orders.find(order => order.clientOrderId === input.clientOrderId);
    if (existing) {
      if (existing.previewId !== input.previewId) fail('IDEMPOTENCY_CONFLICT', '同一订单标识不能用于另一笔确认', 409);
      return this.publicOrder(existing);
    }
    const preview = this.previews.get(input.previewId);
    if (!preview || preview.userId !== user.id || preview.expiresAt <= this.now()) fail('PREVIEW_EXPIRED', '确认已过期，请重新预检查', 409);
    if (user.orders.some(order => order.previewId === input.previewId)) fail('PREVIEW_USED', '该确认已提交，请查询原委托', 409);
    const details = this.validateOrder(user, preview);
    const order = { ...details, id: randomUUID(), clientOrderId: input.clientOrderId, previewId: input.previewId,
      status: 'OPEN', filledQuantity: 0, filledNotionalCents: 0, paidFeeCents: 0,
      reservedCents: details.side === 'BUY' ? details.notionalCents + details.feeCents : 0,
      createdAt: this.now(), updatedAt: this.now(), expiresAt: this.now() + Math.max(0, Date.parse('2026-11-10T08:00:00Z') - this.marketTime()), timeInForce: 'DAY' };
    order.marketCreatedAt = this.marketTime(); order.marketUpdatedAt = this.marketTime(); order.marketExpiresAt = Date.parse('2026-11-10T08:00:00Z');
    user.orders.unshift(order); user.version++; this.save(); return this.publicOrder(order);
  }
  publicOrder(order) {
    return { id: order.id, clientOrderId: order.clientOrderId, instrumentId: order.instrumentId, side: order.side,
      limitPrice: order.limitPrice, quantity: order.quantity, filledQuantity: order.filledQuantity,
      averageFillPrice: order.filledQuantity ? money(Math.round(order.filledNotionalCents / order.filledQuantity)) : null,
      fee: money(order.paidFeeCents), status: order.status, createdAt: order.createdAt, updatedAt: order.updatedAt,
      expiresAt: order.expiresAt, timeInForce: order.timeInForce, marketCreatedAt: order.marketCreatedAt, marketUpdatedAt: order.marketUpdatedAt, marketExpiresAt: order.marketExpiresAt };
  }
  orders(user) { return { items: user.orders.map(order => this.publicOrder(order)), version: user.version }; }
  getOrder(user, id, byClientId = false) {
    const order = user.orders.find(order => (byClientId ? order.clientOrderId : order.id) === id);
    if (!order) fail('ORDER_NOT_FOUND', '未找到该委托', 404);
    return this.publicOrder(order);
  }
  cancel(user, id) {
    const order = user.orders.find(order => order.id === id);
    if (!order) fail('ORDER_NOT_FOUND', '未找到该委托', 404);
    if (order.status === 'CANCELED') return this.publicOrder(order);
    if (!this.isActive(order)) fail('ORDER_TERMINAL', '委托已结束，不能撤单', 409);
    order.status = 'CANCELED'; order.reservedCents = 0; order.updatedAt = this.now(); order.marketUpdatedAt = this.marketTime(); user.version++; this.save(); return this.publicOrder(order);
  }
  tick({ movePrices = true } = {}) {
    this.tickNumber++;
    if (this.marketTime() >= Date.parse('2026-11-10T08:00:00Z')) this.marketStatus = 'CLOSED';
    if (this.marketStatus === 'OPEN' && movePrices) for (const [index, item] of fixture.instruments.entries()) {
      const quote = this.quotes.get(item.id);
      const change = Math.round(Math.sin(this.tickNumber * .73 + index * 1.91) * Math.max(1, quote.price * .00012));
      quote.price = Math.max(100, quote.price + change); quote.high = Math.max(quote.high, quote.price); quote.low = Math.min(quote.low, quote.price);
      const volume = (1 + (this.tickNumber + index) % 9) * 100; quote.volume += volume; quote.turnover += volume * quote.price; quote.version++; quote.asOf = this.now(); quote.marketTime = this.marketTime();
    }
    let dirty = false;
    for (const user of this.users) for (const order of user.orders) {
      if (!this.isActive(order)) continue;
      if (this.now() >= order.expiresAt) { order.status = 'EXPIRED'; order.reservedCents = 0; order.updatedAt = this.now(); order.marketUpdatedAt = this.marketTime(); user.version++; dirty = true; continue; }
      if (this.marketStatus !== 'OPEN') continue;
      const quote = this.quotes.get(order.instrumentId), execution = quote.price + (order.side === 'BUY' ? 1 : -1);
      if (order.side === 'BUY' ? execution > order.priceCents : execution < order.priceCents) continue;
      const quantity = Math.min(order.quantity - order.filledQuantity, 100), notional = quantity * execution;
      const incrementFee = fee(order.filledNotionalCents + notional) - order.paidFeeCents;
      let position = user.positions.find(position => position.instrumentId === order.instrumentId);
      if (order.side === 'BUY') {
        user.cashCents -= notional + incrementFee; order.reservedCents -= notional + incrementFee;
        if (!position) { position = { instrumentId: order.instrumentId, quantity: 0, costCents: 0 }; user.positions.push(position); }
        position.quantity += quantity; position.costCents += notional + incrementFee;
      } else {
        const removedCost = quantity === position.quantity ? position.costCents : Math.round(position.costCents * quantity / position.quantity);
        position.quantity -= quantity; position.costCents -= removedCost; user.cashCents += notional - incrementFee;
      }
      order.filledQuantity += quantity; order.filledNotionalCents += notional; order.paidFeeCents += incrementFee;
      order.status = order.filledQuantity === order.quantity ? 'FILLED' : 'PARTIALLY_FILLED';
      if (order.status === 'FILLED') order.reservedCents = 0;
      order.updatedAt = this.now(); order.marketUpdatedAt = this.marketTime(); user.version++; dirty = true;
      user.trades.unshift({ id: randomUUID(), orderId: order.id, instrumentId: order.instrumentId, side: order.side, quantity,
        price: money(execution), notional: money(notional), fee: money(incrementFee), executedAt: this.now(), marketExecutedAt: this.marketTime() });
    }
    if (dirty) this.save();
  }
  reset(user) {
    user.cashCents = cents(fixture.initialCash); user.orders = []; user.trades = [];
    user.positions = user.email === fixture.demo.email ? fixture.positions.map(position => ({ instrumentId: position.instrumentId, quantity: position.quantity, costCents: cents(position.averageCost) * position.quantity })) : [];
    user.watchlist = fixture.instruments.slice(0, 6).map(item => item.id); user.watchlistVersion++; user.version++;
    for (const [id, preview] of this.previews) if (preview.userId === user.id) this.previews.delete(id);
    this.save(); return this.account(user);
  }
}
