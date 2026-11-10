import test from 'node:test';
import assert from 'node:assert/strict';
import WebSocket from 'ws';
import { createStockServer } from '../src/server.js';
import { fixture } from '../src/domain.js';

test('HTTP, two stream clients, private snapshots, reconnect, and account isolation', async () => {
  const application = createStockServer({ autoTick: false });
  await new Promise(resolve => application.server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${application.server.address().port}`;
  async function request(path, { method = 'GET', token, body } = {}) {
    const response = await fetch(`${origin}/api/v1${path}`, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body ? JSON.stringify(body) : undefined });
    return { status: response.status, ...(await response.json()) };
  }
  const sockets = [];
  async function connect() {
    const socket = new WebSocket(origin.replace('http', 'ws') + '/stream'); sockets.push(socket); const messages = [];
    socket.on('message', value => messages.push(JSON.parse(value.toString())));
    await new Promise(resolve => socket.once('open', resolve));
    return { socket, messages, async wait(predicate) {
      for (let attempt = 0; attempt < 50; attempt++) { const message = messages.find(predicate); if (message) return message; await new Promise(resolve => setTimeout(resolve, 10)); }
      throw new Error('Timed out waiting for websocket message');
    } };
  }
  try {
    assert.equal((await request('/account')).status, 401);
    assert.equal((await request('/auth/login', { method: 'POST', body: [] })).status, 400);
    assert.equal((await request('/instruments/HK.00700/candles?before=invalid')).status, 400);
    const session = (await request('/auth/login', { method: 'POST', body: fixture.demo })).data;
    const other = (await request('/auth/register', { method: 'POST', body: { email: 'isolated@example.test', password: 'strong-pass' } })).data;
    const first = await connect(), second = await connect();
    for (const client of [first, second]) {
      client.socket.send(JSON.stringify({ type: 'authenticate', accessToken: session.accessToken }));
      client.socket.send(JSON.stringify({ type: 'subscribe', topics: ['account', 'orders', 'quote:HK.00700'] }));
      await client.wait(message => message.type === 'snapshot' && message.topic === 'account');
    }
    application.tick(); await first.wait(message => message.type === 'event' && message.topic === 'account');
    application.tick(); await second.wait(message => message.topic === 'account' && message.sequence === 3);
    for (const client of [first, second]) assert.deepEqual(client.messages.filter(message => message.topic === 'account').map(message => message.sequence), [1, 2, 3]);
    const preview = (await request('/orders/previews', { method: 'POST', token: session.accessToken, body: { instrumentId: 'HK.00700', side: 'BUY', limitPrice: '440.00', quantity: 100 } })).data;
    const body = { previewId: preview.previewId, clientOrderId: crypto.randomUUID() };
    const submitted = await request('/orders', { method: 'POST', token: session.accessToken, body });
    assert.equal(submitted.status, 201);
    assert.equal((await request(`/orders/${submitted.data.id}`, { token: other.accessToken })).status, 404);
    application.tick();
    const recovered = await request(`/orders/by-client-id/${body.clientOrderId}`, { token: session.accessToken });
    assert.equal(recovered.data.status, 'FILLED');
    assert.equal((await request('/orders', { method: 'POST', token: session.accessToken, body })).data.id, submitted.data.id);
    first.socket.close(); const restored = await connect();
    restored.socket.send(JSON.stringify({ type: 'authenticate', accessToken: session.accessToken }));
    restored.socket.send(JSON.stringify({ type: 'subscribe', topics: ['orders'] }));
    const snapshot = await restored.wait(message => message.type === 'snapshot' && message.topic === 'orders');
    assert.equal(snapshot.data.items[0].status, 'FILLED');
    assert.equal((await request('/trades', { token: session.accessToken })).data.items.length, 1);
    const html = await fetch(origin); assert.equal(html.status, 200); assert.match(await html.text(), /Harbor/);
  } finally { sockets.forEach(socket => socket.terminate()); await application.close(); }
});
