import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { WebSocketServer, WebSocket } from 'ws';
import { Market, DomainError } from './domain.js';

const serviceRoot = fileURLToPath(new URL('../', import.meta.url));
const prototypeRoot = fileURLToPath(new URL('../../../prototype/', import.meta.url));

export function createStockServer({ stateFile = null, autoTick = true, now } = {}) {
  const market = new Market({ stateFile, now });
  const connections = new Set();
  const wss = new WebSocketServer({ noServer: true, maxPayload: 65536 });
  const tokenOf = request => String(request.headers.authorization || '').replace(/^Bearer /, '');
  const json = (response, status, body) => {
    response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }); response.end(JSON.stringify(body));
  };
  const readBody = async request => {
    let text = '';
    for await (const chunk of request) { text += chunk; if (Buffer.byteLength(text) > 65536) throw new DomainError('BODY_TOO_LARGE', '请求体过大', 413); }
    let parsed;
    try { parsed = text ? JSON.parse(text) : {}; } catch { throw new DomainError('INVALID_JSON', 'JSON 格式错误'); }
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) throw new DomainError('INVALID_JSON', 'JSON 请求体必须是对象');
    return parsed;
  };
  const privateTopics = new Set(['account', 'orders', 'watchlist']);
  function topicData(topic, user) {
    if (privateTopics.has(topic)) {
      if (!user) throw new DomainError('AUTH_REQUIRED', '请先登录', 401);
      if (topic === 'account') return market.account(user);
      if (topic === 'orders') return market.orders(user);
      return market.watchlist(user);
    }
    if (topic === 'market') return market.summary();
    const [kind, id, period] = topic.split(':');
    if (kind === 'quote') return market.quote(id);
    if (kind === 'candles') return market.candles(id, period);
    if (kind === 'funds') return market.funds(id, period);
    throw new DomainError('INVALID_TOPIC', '订阅主题不存在');
  }
  function sendTopic(connection, topic, type = 'event') {
    let user;
    if (privateTopics.has(topic)) user = market.authenticate(connection.token);
    const sequence = (connection.sequences.get(topic) || 0) + 1; connection.sequences.set(topic, sequence);
    const data = topicData(topic, user);
    connection.socket.send(JSON.stringify({ type, eventId: randomUUID(), topic, sequence, epoch: market.epoch, serverTime: market.now(), data }));
  }
  // Sequence belongs to one connection/topic. A snapshot establishes a fresh baseline.
  function publish() {
    for (const connection of connections) {
      if (connection.socket.readyState !== WebSocket.OPEN) continue;
      for (const topic of connection.topics) {
        try { sendTopic(connection, topic); } catch (error) {
          connection.socket.send(JSON.stringify({ type: 'error', code: error.code || 'INTERNAL_ERROR', message: error.message }));
          if (error.status === 401) { connection.socket.close(4001, 'Session expired'); break; }
        }
      }
    }
  }
  const server = http.createServer(async (request, response) => {
    try {
      const url = new URL(request.url, 'http://localhost'); const path = url.pathname;
      if (!path.startsWith('/api/')) {
        const assets = { '/': ['index.html', 'text/html'], '/index.html': ['index.html', 'text/html'] };
        if (request.method !== 'GET' || !assets[path]) { response.writeHead(404); response.end('Not found'); return; }
        const [name, type] = assets[path]; const contents = await readFile(resolve(prototypeRoot, name));
        response.writeHead(200, { 'Content-Type': `${type}; charset=utf-8`, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' }); response.end(contents); return;
      }
      const method = request.method; const body = ['POST', 'PUT'].includes(method) ? await readBody(request) : {};
      const publicPath = ['/api/v1/health', '/api/v1/auth/login', '/api/v1/auth/register', '/api/v1/auth/refresh', '/api/v1/instruments', '/api/v1/quotes', '/api/v1/market'];
      const isPublic = publicPath.includes(path) || /^\/api\/v1\/instruments\/[^/]+\/(candles|funds)$/.test(path);
      const user = isPublic ? null : market.authenticate(tokenOf(request));
      let data; let status = 200;
      if (method === 'GET' && path === '/api/v1/health') data = { status: 'ok', epoch: market.epoch };
      else if (method === 'POST' && path === '/api/v1/auth/login') data = market.login(body);
      else if (method === 'POST' && path === '/api/v1/auth/register') { data = market.session(market.register(body)); status = 201; }
      else if (method === 'POST' && path === '/api/v1/auth/refresh') data = market.refresh(body.refreshToken);
      else if (method === 'POST' && path === '/api/v1/auth/logout') { market.logout(tokenOf(request)); data = { loggedOut: true }; }
      else if (method === 'GET' && path === '/api/v1/auth/me') data = market.profile(user);
      else if (method === 'GET' && path === '/api/v1/instruments') data = { items: market.instruments(url.searchParams.get('query') || '') };
      else if (method === 'GET' && path === '/api/v1/quotes') data = { items: (url.searchParams.get('ids')?.split(',').filter(Boolean) || market.instruments().map(item => item.id)).map(id => market.quote(id)) };
      else if (method === 'GET' && path === '/api/v1/market') data = market.summary();
      else if (method === 'GET' && /^\/api\/v1\/instruments\/[^/]+\/candles$/.test(path)) data = market.candles(decodeURIComponent(path.split('/')[4]), url.searchParams.get('period') || '1d', url.searchParams.get('before'), url.searchParams.get('limit'));
      else if (method === 'GET' && /^\/api\/v1\/instruments\/[^/]+\/funds$/.test(path)) data = market.funds(decodeURIComponent(path.split('/')[4]), url.searchParams.get('range') || '1d');
      else if (method === 'GET' && path === '/api/v1/watchlist') data = market.watchlist(user);
      else if (method === 'PUT' && path === '/api/v1/watchlist') { data = market.updateWatchlist(user, body.instrumentIds, body.version); publish(); }
      else if (method === 'GET' && path === '/api/v1/account') data = market.account(user);
      else if (method === 'POST' && path === '/api/v1/orders/previews') data = market.preview(user, body);
      else if (method === 'POST' && path === '/api/v1/orders') { data = market.submit(user, body); status = 201; publish(); }
      else if (method === 'GET' && path === '/api/v1/orders') data = market.orders(user);
      else if (method === 'GET' && path.startsWith('/api/v1/orders/by-client-id/')) data = market.getOrder(user, decodeURIComponent(path.slice('/api/v1/orders/by-client-id/'.length)), true);
      else if (method === 'GET' && /^\/api\/v1\/orders\/[^/]+$/.test(path)) data = market.getOrder(user, decodeURIComponent(path.split('/')[4]));
      else if (method === 'POST' && /^\/api\/v1\/orders\/[^/]+\/cancel$/.test(path)) { data = market.cancel(user, decodeURIComponent(path.split('/')[4])); publish(); }
      else if (method === 'GET' && path === '/api/v1/trades') data = { items: user.trades, version: user.version };
      else if (method === 'POST' && path === '/api/v1/dev/reset') { data = market.reset(user); publish(); }
      else if (method === 'POST' && path === '/api/v1/dev/market') {
        if (user.email !== 'demo@harbor.app') throw new DomainError('FORBIDDEN', '仅演示账户可切换共享市场', 403);
        if (!['OPEN', 'CLOSED'].includes(body.status)) throw new DomainError('INVALID_MARKET_STATUS', '无效市场状态');
        market.marketStatus = body.status; data = market.summary(); publish();
      }
      else throw new DomainError('NOT_FOUND', '接口不存在', 404);
      json(response, status, { data, meta: { requestId: randomUUID(), serverTime: market.now(), epoch: market.epoch } });
    } catch (error) {
      if (!(error instanceof DomainError)) console.error(error);
      json(response, error.status || 500, { error: { code: error.code || 'INTERNAL_ERROR', message: error instanceof DomainError ? error.message : '服务异常' }, meta: { serverTime: market.now(), epoch: market.epoch } });
    }
  });
  server.on('upgrade', (request, socket, head) => {
    if (new URL(request.url, 'http://localhost').pathname !== '/stream') { socket.destroy(); return; }
    wss.handleUpgrade(request, socket, head, websocket => wss.emit('connection', websocket));
  });
  wss.on('connection', socket => {
    const connection = { socket, token: null, topics: new Set(), sequences: new Map() }; connections.add(connection);
    socket.send(JSON.stringify({ type: 'hello', epoch: market.epoch, serverTime: market.now(), heartbeatInterval: 20000 }));
    socket.on('message', buffer => {
      try {
        const message = JSON.parse(buffer.toString());
        if (message.type === 'authenticate') { market.authenticate(message.accessToken); connection.token = message.accessToken; socket.send(JSON.stringify({ type: 'authenticated' })); }
        else if (message.type === 'subscribe') {
          if (!Array.isArray(message.topics) || message.topics.length > 40) throw new DomainError('INVALID_TOPICS', '订阅列表格式错误');
          for (const topic of message.topics) { topicData(topic, privateTopics.has(topic) ? market.authenticate(connection.token) : null); connection.topics.add(topic); sendTopic(connection, topic, 'snapshot'); }
        } else if (message.type === 'unsubscribe') {
          if (!Array.isArray(message.topics)) throw new DomainError('INVALID_TOPICS', '订阅列表格式错误');
          message.topics.forEach(topic => connection.topics.delete(topic));
        } else if (message.type === 'ping') socket.send(JSON.stringify({ type: 'pong', serverTime: market.now() }));
        else throw new DomainError('INVALID_MESSAGE', '未知消息类型');
      } catch (error) { socket.send(JSON.stringify({ type: 'error', code: error.code || 'INVALID_MESSAGE', message: error instanceof DomainError ? error.message : '消息格式错误' })); }
    });
    socket.on('close', () => connections.delete(connection));
    socket.on('error', () => connections.delete(connection));
  });
  const tick = () => { market.tick(); publish(); };
  const timer = autoTick ? setInterval(tick, 1500) : null;
  return { server, market, publish, tick, async close() {
    clearInterval(timer); for (const connection of connections) connection.socket.terminate(); wss.close();
    if (server.listening) await new Promise(resolve => server.close(resolve));
  } };
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  const application = createStockServer({ stateFile: process.env.STOCK_STATE_FILE || resolve(serviceRoot, '.data/state.json') });
  const port = Number(process.env.STOCK_PORT || 4317), host = process.env.STOCK_HOST || '127.0.0.1';
  application.server.listen(port, host, () => console.log(`Harbor prototype: http://${host}:${port}`));
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, async () => { await application.close(); process.exit(0); });
}
