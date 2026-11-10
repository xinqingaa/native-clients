import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Market, fixture, cents, fee } from '../src/domain.js';

const demo = market => market.users.find(user => user.email === fixture.demo.email);
const input = (overrides = {}) => ({ instrumentId: 'HK.00700', side: 'BUY', limitPrice: '430.00', quantity: 100, ...overrides });
function submit(market, user, overrides = {}, key = crypto.randomUUID()) {
  const preview = market.preview(user, input(overrides));
  return market.submit(user, { previewId: preview.previewId, clientOrderId: key });
}
test('buy reserves cash and settles execution price and cumulative commission', () => {
  const market = new Market(), user = demo(market), initial = market.account(user);
  const order = submit(market, user);
  assert.equal(market.account(user).frozenCash, '43012.90');
  assert.equal(cents(market.account(user).availableCash), cents(initial.cash) - 4301290);
  market.tick({ movePrices: false });
  const filled = market.getOrder(user, order.id);
  assert.equal(filled.status, 'FILLED'); assert.equal(filled.averageFillPrice, '428.61');
  assert.equal(market.account(user).frozenCash, '0.00');
  assert.equal(cents(market.account(user).cash), cents(initial.cash) - 4286100 - fee(4286100));
  assert.equal(market.account(user).positions.find(position => position.instrumentId === 'HK.00700').quantity, 300);
});
test('partial fill then cancel preserves fills and releases only remaining reservation', () => {
  const market = new Market(), user = demo(market), initial = cents(market.account(user).cash);
  const order = submit(market, user, { quantity: 300 }); market.tick({ movePrices: false });
  assert.equal(market.getOrder(user, order.id).status, 'PARTIALLY_FILLED');
  assert.equal(market.getOrder(user, order.id).filledQuantity, 100);
  assert.ok(cents(market.account(user).frozenCash) > 0);
  market.cancel(user, order.id); market.cancel(user, order.id); market.tick({ movePrices: false });
  assert.equal(market.account(user).frozenCash, '0.00'); assert.equal(user.trades.length, 1);
  assert.equal(cents(market.account(user).availableCash), initial - 4286100 - fee(4286100));
});
test('client order id and preview both prevent duplicate orders', () => {
  const market = new Market(), user = demo(market), preview = market.preview(user, input());
  const body = { previewId: preview.previewId, clientOrderId: crypto.randomUUID() };
  const first = market.submit(user, body); market.tick({ movePrices: false });
  assert.equal(market.submit(user, body).id, first.id); assert.equal(user.orders.length, 1);
  assert.equal(user.trades.length, 1);
  assert.throws(() => market.submit(user, { ...body, clientOrderId: crypto.randomUUID() }), { code: 'PREVIEW_USED' });
  assert.throws(() => market.submit(user, { ...body, previewId: crypto.randomUUID() }), { code: 'IDEMPOTENCY_CONFLICT' });
});
test('preview expires and account funds are checked again on submit', () => {
  let time = Date.now(); const market = new Market({ now: () => time }), user = demo(market);
  const expired = market.preview(user, input()); time += 15001;
  assert.throws(() => market.submit(user, { previewId: expired.previewId, clientOrderId: crypto.randomUUID() }), { code: 'PREVIEW_EXPIRED' });
  const first = market.preview(user, input({ quantity: 300 })), second = market.preview(user, input({ quantity: 300 }));
  market.submit(user, { previewId: first.previewId, clientOrderId: crypto.randomUUID() });
  assert.throws(() => market.submit(user, { previewId: second.previewId, clientOrderId: crypto.randomUUID() }), { code: 'INSUFFICIENT_FUNDS' });
});
test('sell reservations prevent overselling and settlement reduces the position', () => {
  const market = new Market(), user = demo(market), initial = cents(market.account(user).cash);
  const order = submit(market, user, { side: 'SELL', limitPrice: '427.00', quantity: 200 });
  assert.equal(market.account(user).positions.find(position => position.instrumentId === 'HK.00700').availableQuantity, 0);
  assert.throws(() => market.preview(user, input({ side: 'SELL' })), { code: 'INSUFFICIENT_POSITION' });
  market.tick({ movePrices: false }); market.tick({ movePrices: false });
  assert.equal(market.getOrder(user, order.id).status, 'FILLED');
  assert.equal(cents(market.account(user).cash), initial + 4285900 * 2 - fee(4285900 * 2));
  assert.equal(market.account(user).positions.some(position => position.instrumentId === 'HK.00700'), false);
  assert.throws(() => market.cancel(user, order.id), { code: 'ORDER_TERMINAL' });
});
test('closed market blocks new orders and pauses existing fills', () => {
  const market = new Market(), user = demo(market), order = submit(market, user);
  market.marketStatus = 'CLOSED'; market.tick({ movePrices: false });
  assert.equal(market.getOrder(user, order.id).filledQuantity, 0);
  assert.throws(() => market.preview(user, input()), { code: 'MARKET_CLOSED' });
  market.marketStatus = 'OPEN'; market.tick({ movePrices: false }); assert.equal(market.getOrder(user, order.id).status, 'FILLED');
});
test('day order expires at simulated close even when it cannot cross', () => {
  let time = Date.now(); const market = new Market({ now: () => time }), user = demo(market);
  const order = submit(market, user, { limitPrice: '1.00' }); time = order.expiresAt;
  market.tick({ movePrices: false }); assert.equal(market.getOrder(user, order.id).status, 'EXPIRED');
  assert.equal(market.account(user).frozenCash, '0.00'); assert.equal(market.marketStatus, 'CLOSED');
});
test('account ownership, login, refresh rotation, and watchlist conflicts', () => {
  const market = new Market(), user = demo(market), other = market.register({ email: 'new@example.test', password: 'test-12345', name: '新用户' });
  const order = submit(market, user);
  assert.throws(() => market.getOrder(other, order.id), { code: 'ORDER_NOT_FOUND' });
  assert.equal(market.account(other).positions.length, 0);
  assert.throws(() => market.login({ email: fixture.demo.email, password: 'wrong' }), { code: 'INVALID_CREDENTIALS' });
  const session = market.login(fixture.demo), refreshed = market.refresh(session.refreshToken);
  assert.equal(market.authenticate(refreshed.accessToken).id, user.id);
  assert.throws(() => market.authenticate(session.accessToken), { code: 'SESSION_EXPIRED' });
  market.logout(refreshed.accessToken); assert.throws(() => market.authenticate(refreshed.accessToken), { code: 'SESSION_EXPIRED' });
  market.updateWatchlist(user, [], 1);
  assert.throws(() => market.updateWatchlist(user, ['HK.00700'], 1), { code: 'VERSION_CONFLICT' });
});
test('restart retains accounting and expires outstanding reservations', () => {
  const directory = mkdtempSync(join(tmpdir(), 'harbor-test-'));
  try {
    const stateFile = join(directory, 'state.json'), market = new Market({ stateFile }), user = demo(market);
    submit(market, user, { quantity: 300 }); market.tick({ movePrices: false }); const cash = market.account(user).cash;
    const restored = new Market({ stateFile }), restoredUser = demo(restored);
    assert.equal(restored.account(restoredUser).cash, cash); assert.equal(restored.account(restoredUser).frozenCash, '0.00');
    assert.equal(restoredUser.trades.length, 1); assert.equal(restored.orders(restoredUser).items[0].status, 'EXPIRED');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
test('daily current candle shares OHLC and volume with quote', () => {
  const market = new Market(); market.tick(); const quote = market.quote('HK.00700'), candle = market.candles('HK.00700').items.at(-1);
  assert.equal(candle.close, quote.price); assert.equal(candle.open, quote.open);
  assert.equal(candle.high, quote.high); assert.equal(candle.low, quote.low); assert.equal(candle.volume, quote.volume);
});
