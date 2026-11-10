const $ = selector => document.querySelector(selector);
const all = selector => [...document.querySelectorAll(selector)];
const esc = value => String(value ?? '').replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]));
const icon = name => `<svg class="icon" aria-hidden="true"><use href="#i-${name}"/></svg>`;
const format = (value, digits = 2) => Number(value || 0).toLocaleString('en-US', { minimumFractionDigits: digits, maximumFractionDigits: digits });
const signed = value => `${Number(value) > 0 ? '+' : ''}${format(value)}`;
const color = value => Number(value) >= 0 ? 'up' : 'down';
const compact = value => Math.abs(Number(value)) >= 1e8 ? `${format(Number(value) / 1e8)} 亿` : Math.abs(Number(value)) >= 1e4 ? `${format(Number(value) / 1e4)} 万` : format(value);
const clock = timestamp => new Date(timestamp).toLocaleTimeString('zh-CN', { timeZone: 'Asia/Hong_Kong', hour12: false });
const date = timestamp => new Date(timestamp).toLocaleDateString('zh-CN', { timeZone: 'Asia/Hong_Kong', month: '2-digit', day: '2-digit' });
const orderTime = order => order.marketCreatedAt || order.createdAt;
const tradeTime = trade => trade.marketExecutedAt || trade.executedAt;
const labels = { OPEN: '待成交', PARTIALLY_FILLED: '部分成交', FILLED: '全部成交', CANCELED: '已撤单', EXPIRED: '已到期' };
const active = order => ['OPEN', 'PARTIALLY_FILLED'].includes(order.status);
const persistedSession = (() => { try { return JSON.parse(localStorage.getItem('harbor.session')); } catch { return null; } })();
const state = { route: 'watch', session: persistedSession, instruments: [], quotes: new Map(), watchlist: [], watchVersion: 0,
  selected: 'HK.00700', period: '1d', fundRange: '1d', candles: [], funds: null, account: null, orders: [], trades: [], summary: null,
  side: 'BUY', limitPrice: '', quantity: 100, mobileDetail: false, orderTab: 'active', sector: '全部', authMode: 'login',
  socket: null, connected: false, paused: false, reconnectAttempt: 0, sequences: new Map(), subscribed: new Set(),
  preview: null, previewClientId: null, submitting: false, selectedOrder: null, serverOffset: 0, chartCount: 55, chartOffset: 0, hover: null, candleVersion: 0, fundVersion: 0 };
let refreshPromise, reconnectTimer, heartbeatTimer, resizeObserver, chartDrag, detailsGeneration = 0, searchGeneration = 0;
function toast(message, error = false) {
  const element = document.createElement('div'); element.className = `toast${error ? ' error' : ''}`; element.textContent = message;
  $('#toasts').append(element); setTimeout(() => element.remove(), 4500);
}
const run = callback => (...args) => Promise.resolve().then(() => callback(...args)).catch(error => toast(error.message || '操作失败，请重试', true));
function saveSession(session) { state.session = session; if (session) localStorage.setItem('harbor.session', JSON.stringify(session)); else localStorage.removeItem('harbor.session'); }
async function api(path, { method = 'GET', body, retry = true } = {}) {
  const response = await fetch(`/api/v1${path}`, { method, headers: { 'Content-Type': 'application/json', ...(state.session ? { Authorization: `Bearer ${state.session.accessToken}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(10000) });
  const result = await response.json();
  if (result.meta?.serverTime) state.serverOffset = result.meta.serverTime - Date.now();
  if (response.status === 401 && state.session && retry && !['/auth/login','/auth/register','/auth/refresh'].includes(path)) {
    try {
      if (!refreshPromise) refreshPromise = api('/auth/refresh', { method: 'POST', body: { refreshToken: state.session.refreshToken }, retry: false }).then(session => { saveSession(session); return session; }).finally(() => { refreshPromise = null; });
      await refreshPromise; if (state.socket?.readyState === WebSocket.OPEN) state.socket.send(JSON.stringify({ type: 'authenticate', accessToken: state.session.accessToken }));
      return api(path, { method, body, retry: false });
    } catch (error) { if (error.code === 'SESSION_EXPIRED') { await logout(false); showAuth(); } throw error; }
  }
  if (!response.ok) { const error = new Error(result.error?.message || '请求失败'); error.code = result.error?.code; error.status = response.status; throw error; }
  return result.data;
}
function instrument(id = state.selected) { return state.instruments.find(item => item.id === id); }
function quote(id = state.selected) { return state.quotes.get(id); }
function requireLogin() { if (state.session) return true; showAuth(); return false; }
function summaryRow(label, value, className = '') { return `<div class="summary-row"><span>${label}</span><strong class="${className}">${value}</strong></div>`; }
function empty(title, description, action = '去看行情', route = 'watch') { return `<div class="empty-state">${icon('wallet')}<h3>${title}</h3><p>${description}</p><button class="button secondary small" data-route="${route}">${action}${icon('arrow')}</button></div>`; }
function renderProfile() {
  const user = state.session?.user;
  $('#profile-name').textContent = user?.name || '欢迎来到海港'; $('#profile-subtitle').textContent = user ? '港股模拟账户' : '登录或创建账户';
  $('#avatar').textContent = user?.name?.[0] || 'H'; $('#mobile-profile').textContent = user?.name?.[0] || 'H';
  $('#login-button').hidden = !!user; $('#mobile-profile').hidden = !user;
  $('#watch-count').textContent = state.watchlist.length;
}
function renderHeading(title, subtitle, action = '') { return `<div class="page-heading"><div><h1>${title}</h1><p>${subtitle}</p></div><div class="page-heading-actions"><span class="date-label">2026.11.10 · 星期二</span>${action}</div></div>`; }
function sparkline(index, percent) {
  const points = Array.from({ length: 22 }, (_, step) => `${step * 3.5},${22 - (Math.sin(step * .72 + index) * 3 + step * .55 + index * 2)}`).join(' ');
  return `<svg class="sparkline ${color(percent)}" viewBox="0 0 76 28" aria-hidden="true"><polyline points="${points}" fill="none" stroke="currentColor" stroke-width="1.3"/></svg>`;
}
function indexCards() {
  return `<div class="index-grid">${(state.summary?.indices || []).map((item, index) => `<div class="index-card"><div class="index-label">${item.name}<span class="mini-tag">HK</span></div><div class="index-value"><strong class="numeric">${format(item.value)}</strong><span class="${color(item.changePercent)} numeric">${signed(item.changePercent)}%</span></div>${sparkline(index, item.changePercent)}</div>`).join('')}<div class="index-card"><div class="index-label">账户总资产 <span class="mini-tag">HKD</span></div><div class="index-value"><strong class="numeric" id="index-assets">${state.account ? format(state.account.totalAssets) : '— —'}</strong></div></div></div>`;
}
function stockRows() {
  if (!state.watchlist.length) return `<div class="empty-state"><h3>留意你的第一只股票</h3><p>搜索感兴趣的公司，加入自选。</p><button class="button secondary small" data-action="search">${icon('plus')}添加股票</button></div>`;
  return state.watchlist.map((id, index) => {
    const item = instrument(id), value = quote(id); if (!item || !value) return '';
    return `<div class="stock-row ${id === state.selected ? 'selected' : ''}" data-select="${id}" role="button" tabindex="0" aria-label="查看${esc(item.name)}行情"><span class="stock-monogram">${esc(item.name[0])}</span><span class="stock-name"><strong>${esc(item.name)}</strong><small>${item.symbol} · HK</small></span><span class="stock-price ${color(value.change)} numeric"><strong>${format(value.price)}</strong><small>${signed(value.changePercent)}%</small></span>${state.session ? `<span class="row-tools"><button class="icon-button" data-move="${id}" ${index === 0 ? 'disabled' : ''} aria-label="上移${esc(item.name)}" title="上移">↑</button><button class="icon-button" data-remove="${id}" aria-label="移除${esc(item.name)}" title="移除">×</button></span>` : ''}</div>`;
  }).join('');
}
function marketWorkspace() {
  const item = instrument(), value = quote();
  return `${renderHeading('自选行情', '熟悉的公司，值得持续关注。', `<button class="button secondary small" data-action="search">${icon('plus')}添加自选</button>`)}<div id="indices">${indexCards()}</div><div class="market-layout ${state.mobileDetail ? 'detail-open' : ''}">
    <section class="panel watch-panel"><div class="panel-heading"><h2>我的自选<small>${state.watchlist.length}</small></h2><button class="icon-button" data-action="search" aria-label="添加自选">${icon('plus')}</button></div><div class="watch-table-header"><span>名称 / 代码</span><span>最新价 / 涨跌幅</span></div><div id="watch-rows">${stockRows()}</div><div class="watch-footer">${icon('clock')}${state.session ? '自选列表已同步至账户' : '<button data-action="login">登录，同步你的自选</button>'}</div></section>
    <div class="detail-column"><button class="mobile-back" data-action="back">${icon('arrow')}返回自选</button><section class="panel quote-panel"><div class="quote-heading"><h2>${esc(item.name)}</h2><span>${item.symbol} · 港股</span><button class="icon-button star-button ${state.watchlist.includes(item.id) ? 'on' : ''}" data-star="${item.id}" aria-label="${state.watchlist.includes(item.id) ? '移出自选' : '加入自选'}">${icon('star')}</button></div><div class="quote-primary numeric ${color(value.change)}"><strong id="quote-price">${format(value.price)}</strong><span id="quote-change">${signed(value.change)} (${signed(value.changePercent)}%)</span><small>HKD</small></div><dl class="quote-meta" id="quote-meta">${quoteMeta(value)}</dl><div class="chart-toolbar">${[['1m','分时'],['1d','日 K'],['1w','周 K'],['1mo','月 K']].map(([period,label]) => `<button data-period="${period}" class="period-button ${state.period === period ? 'active' : ''}">${label}</button>`).join('')}<button class="history-button" data-action="history">更早行情</button><button class="icon-button" data-zoom="out" aria-label="缩小图表">−</button><button class="icon-button" data-zoom="in" aria-label="放大图表">+</button></div><div class="chart-legend" id="chart-legend"><span class="ma5">MA 5</span><span class="ma20">MA 20</span><span>成交量</span></div><div class="chart-stage"><canvas id="chart" aria-label="${esc(item.name)}行情图，可拖动查看历史，使用加减按钮缩放"></canvas><div id="chart-tooltip" class="chart-tooltip"></div></div><div class="chart-help"><span>拖动查看历史 · 滚轮缩放</span><strong id="quote-updated">${clock(value.marketTime)} 更新</strong></div></section>
      <section class="panel flow-panel"><div class="panel-heading"><h2>资金流向<small>HKD</small></h2><div class="flow-tabs">${[['1d','今日'],['5d','5 日'],['20d','20 日']].map(([range,label]) => `<button data-fund-range="${range}" class="${state.fundRange === range ? 'active' : ''}">${label}</button>`).join('')}</div></div><div class="flow-content" id="flow-content">${flowContent()}</div></section></div>
    <aside class="ticket-column"><section class="panel ticket-panel"><div class="ticket-top"><h2>快捷交易</h2><span>模拟账户</span></div><div class="segmented trade-sides"><button data-side="BUY" class="${state.side === 'BUY' ? 'active' : ''}">买入</button><button data-side="SELL" class="${state.side === 'SELL' ? 'active' : ''}">卖出</button></div><div class="ticket-symbol"><strong>${esc(item.name)}</strong><small>${item.symbol}</small></div><label>委托价格<div class="input-with-unit"><input id="limit-price" aria-label="委托价格" type="text" inputmode="decimal" value="${esc(state.limitPrice)}"><span>HKD</span></div><span class="input-helper"><span>限价委托 · 当日有效</span><button data-action="use-price">使用对手价</button></span></label><label>委托数量<div class="input-with-unit"><input id="quantity" aria-label="委托数量" type="number" inputmode="numeric" min="100" max="100000" step="100" value="${state.quantity}"><span>股</span></div><span class="input-helper"><span>每手 ${item.lotSize} 股</span><span id="ticket-lots">${format(state.quantity / item.lotSize, 0)} 手</span></span><div class="quantity-shortcuts">${[100,200,500,1000].map(quantity => `<button data-quantity="${quantity}">${quantity}</button>`).join('')}</div></label><div id="ticket-summary" class="ticket-summary">${ticketSummary()}</div><button class="button ticket-submit ${state.side === 'SELL' ? 'sell' : ''}" id="preview-button">${state.session ? `预览${state.side === 'BUY' ? '买入' : '卖出'}` : '登录后交易'}${icon('arrow')}</button><p class="ticket-footnote">提交前确认费用与有效期。委托受理后，可在交易页面跟踪成交。</p></section><section class="panel account-preview"><h3>账户概览</h3><div id="account-preview-content">${accountPreview()}</div><a href="#assets">查看我的资产${icon('arrow')}</a></section></aside></div>`;
}
function quoteMeta(value) { return [['今开',format(value.open)],['最高',format(value.high)],['成交量',compact(value.volume)+' 股'],['昨收',format(value.previousClose)],['最低',format(value.low)],['成交额',compact(value.turnover)]].map(([label,text]) => `<div><dt>${label}</dt><dd class="numeric">${text}</dd></div>`).join(''); }
function flowContent() {
  const funds = state.funds; if (!funds) return '<p class="muted">资金流向加载中…</p>';
  const ratio = Number(funds.buy) / (Number(funds.buy) + Number(funds.sell)) * 100;
  return `<div class="flow-total"><strong class="numeric ${color(funds.net)}">${Number(funds.net) >= 0 ? '+' : ''}${compact(funds.net)}</strong><small>净流入</small></div><div class="flow-bar"><span style="width:${ratio}%"></span><span></span></div><div class="flow-labels"><span>流入 <span class="up numeric">${compact(funds.buy)}</span></span><span>流出 <span class="down numeric">${compact(funds.sell)}</span></span></div><div class="flow-categories">${funds.categories.map(category => `<div><small>${category.name}净流入</small><strong class="numeric ${color(category.net)}">${Number(category.net) > 0 ? '+' : ''}${compact(category.net)}</strong></div>`).join('')}</div>`;
}
function ticketSummary() {
  const notional = Number(state.limitPrice || 0) * Number(state.quantity || 0), commission = notional > 0 ? Math.max(1, Math.ceil(notional * 100 * .0003) / 100) : 0;
  const available = state.side === 'BUY' ? `${format(state.account?.availableCash)} HKD` : `${format(state.account?.positions.find(item => item.instrumentId === state.selected)?.availableQuantity, 0)} 股`;
  return summaryRow(state.side === 'BUY' ? '可用资金' : '可卖数量', state.session ? available : '登录后查看') + summaryRow('预估费用', `${format(commission)} HKD`) + summaryRow(state.side === 'BUY' ? '预估支出' : '预估收入', `${format(notional + (state.side === 'BUY' ? commission : -commission))} HKD`);
}
function accountPreview() { return summaryRow('可用资金', state.account ? format(state.account.availableCash) : '—') + summaryRow('冻结资金', state.account ? format(state.account.frozenCash) : '—') + summaryRow('持仓市值', state.account ? format(state.account.marketValue) : '—'); }
function marketView() {
  const items = state.instruments.filter(item => state.sector === '全部' || item.sector === state.sector);
  return `${renderHeading('市场发现', '放眼港股，找到你的下一份关注。', `<button class="button secondary small" data-action="search">${icon('search')}搜索股票</button>`)}<div id="indices">${indexCards()}</div><div class="market-filter">${['全部','互联网','科技','金融','能源'].map(sector => `<button data-sector="${sector}" class="${state.sector === sector ? 'active' : ''}">${sector}</button>`).join('')}</div><div class="market-discovery" id="discovery-cards">${items.map(item => {
    const value = quote(item.id); return `<button class="discovery-card" data-select="${item.id}"><span class="stock-monogram">${esc(item.name[0])}</span><h3>${esc(item.name)}</h3><small>${item.symbol} · ${esc(item.englishName)}</small><div class="discovery-price ${color(value.change)} numeric"><strong>${format(value.price)}</strong><span>${signed(value.changePercent)}%</span></div><div class="tag">${esc(item.sector)} <span style="float:right">查看行情 ↗</span></div></button>`;
  }).join('')}</div>`;
}
function pendingKey() { return `harbor.pending.${state.session?.user?.id}`; }
function pendingOrder() { try { return JSON.parse(localStorage.getItem(pendingKey())); } catch { return null; } }
function ordersView() {
  const title = renderHeading('交易委托', '从委托到成交，每一步都清晰。');
  if (!state.session) return title + `<section class="panel">${empty('登录后查看交易', '你的委托、成交与账户记录，会在这里同步。', '登录 / 注册', 'login')}</section>`;
  const pending = state.orders.filter(active), completed = state.orders.filter(order => order.status === 'FILLED');
  return title + `${pendingOrder() ? '<div class="expiry">有一笔提交尚待确认。<button class="button secondary small" data-action="recover-order">查询 / 重试原提交</button></div>' : ''}<div class="order-card-strip"><div class="stat-card"><small>当前委托</small><strong>${pending.length}<span class="muted" style="font-size:12px"> 笔</span></strong><p>实时跟踪受理与成交</p></div><div class="stat-card"><small>已完成委托</small><strong>${completed.length}<span class="muted" style="font-size:12px"> 笔</span></strong><p>以服务端成交结果为准</p></div><div class="stat-card"><small>冻结资金 · HKD</small><strong style="font-size:22px">${format(state.account?.frozenCash)}</strong><p>剩余委托结束后释放</p></div></div><section class="panel table-panel"><div class="table-tabs">${[['active','当前委托'],['all','全部委托'],['trades','成交明细']].map(([tab,label]) => `<button data-order-tab="${tab}" class="${state.orderTab === tab ? 'active' : ''}">${label}</button>`).join('')}</div><div id="orders-table">${ordersTable()}</div></section>`;
}
function ordersTable() {
  if (state.orderTab === 'trades') {
    if (!state.trades.length) return empty('还没有成交记录', '委托成交后，可以在这里查看价格、数量和费用。');
    return `<div class="table-scroll"><table class="data-table"><thead><tr><th>股票</th><th>方向</th><th>成交价格</th><th>成交数量</th><th>费用</th><th>成交时间</th></tr></thead><tbody>${state.trades.map(trade => `<tr><td><strong>${esc(instrument(trade.instrumentId).name)}</strong><small>${instrument(trade.instrumentId).symbol}</small></td><td class="${trade.side === 'BUY' ? 'up' : 'down'}">${trade.side === 'BUY' ? '买入' : '卖出'}</td><td>${format(trade.price)}</td><td>${format(trade.quantity,0)}</td><td>${format(trade.fee)}</td><td>${date(tradeTime(trade))} ${clock(tradeTime(trade))}</td></tr>`).join('')}</tbody></table></div>`;
  }
  const orders = state.orderTab === 'active' ? state.orders.filter(active) : state.orders;
  if (!orders.length) return empty(state.orderTab === 'active' ? '暂无待成交委托' : '你的第一笔交易，从关注开始', '选择一只股票，在行情页面发起模拟买卖。');
  return `<div class="table-scroll"><table class="data-table"><thead><tr><th>股票</th><th>方向</th><th>委托价 / 均价</th><th>成交 / 委托</th><th>状态</th><th>操作</th></tr></thead><tbody>${orders.map(order => `<tr><td><button data-order="${order.id}" style="text-align:left;padding:0"><strong>${esc(instrument(order.instrumentId).name)}</strong><small>${instrument(order.instrumentId).symbol} · ${clock(orderTime(order))}</small></button></td><td class="${order.side === 'BUY' ? 'up' : 'down'}">${order.side === 'BUY' ? '买入' : '卖出'}</td><td>${format(order.limitPrice)}<small>${order.averageFillPrice ? format(order.averageFillPrice) : '—'}</small></td><td>${format(order.filledQuantity,0)} / ${format(order.quantity,0)}</td><td><span class="status-pill ${order.status}">${labels[order.status]}</span></td><td>${active(order) ? `<button class="button secondary small" data-cancel="${order.id}">撤单</button>` : `<button class="button secondary small" data-order="${order.id}">详情</button>`}</td></tr>`).join('')}</tbody></table></div>`;
}
function assetsView() {
  const title = renderHeading('我的资产', '看清每一份持有，也看清每一次变化。');
  if (!state.account) return title + `<section class="panel">${empty('让资产一目了然', '登录后查看模拟资金与持仓。', '登录 / 注册', 'login')}</section>`;
  const account = state.account;
  return `${title}<section class="assets-hero"><div class="assets-total"><small>总资产 · 港股模拟账户</small><h2 class="numeric">${format(account.totalAssets)}<span>HKD</span></h2><p>持仓今日浮动 <span class="numeric ${color(account.dailyPnL)}">${signed(account.dailyPnL)} HKD</span></p></div><div class="assets-sub"><div><small>可用资金</small><strong class="numeric">${format(account.availableCash)}</strong></div><div><small>冻结资金</small><strong class="numeric">${format(account.frozenCash)}</strong></div><div><small>持仓市值</small><strong class="numeric">${format(account.marketValue)}</strong></div><div><small>持仓浮盈亏</small><strong class="numeric ${color(account.unrealizedPnL)}">${signed(account.unrealizedPnL)}</strong></div></div></section><section class="panel table-panel"><div class="panel-heading" style="padding-left:0;padding-right:0"><h2>我的持仓<small>${account.positions.length} 只股票</small></h2><span class="muted" style="font-size:10px">HKD</span></div>${account.positions.length ? `<div class="table-scroll"><table class="data-table"><thead><tr><th>股票</th><th>持仓 / 可卖</th><th>现价 / 成本</th><th>持仓市值</th><th>浮盈亏</th><th>操作</th></tr></thead><tbody>${account.positions.map(position => `<tr><td><button style="text-align:left;padding:0" data-select="${position.instrumentId}"><strong>${esc(instrument(position.instrumentId).name)}</strong><small>${instrument(position.instrumentId).symbol}</small></button></td><td>${format(position.quantity,0)}<small>${format(position.availableQuantity,0)} 可卖</small></td><td>${format(quote(position.instrumentId).price)}<small>${format(position.averageCost)}</small></td><td>${format(position.marketValue)}</td><td class="${color(position.unrealizedPnL)}">${signed(position.unrealizedPnL)}</td><td><button class="button secondary small" data-sell="${position.instrumentId}">卖出</button></td></tr>`).join('')}</tbody></table></div>` : empty('暂时没有持仓', '第一笔买入成交后，你的持仓将在这里显示。')}</section>`;
}
function render() {
  resizeObserver?.disconnect();
  all('[data-route]').forEach(button => button.classList.toggle('active', button.dataset.route === state.route));
  $('#route-label').textContent = { watch: '自选行情', market: '市场发现', orders: '交易委托', assets: '我的资产' }[state.route];
  $('#main').innerHTML = state.route === 'watch' ? marketWorkspace() : state.route === 'market' ? marketView() : state.route === 'orders' ? ordersView() : assetsView();
  renderProfile(); setupChart(); updateConnection();
}
function updateLive() {
  if ($('#indices')) $('#indices').innerHTML = indexCards();
  if (state.route === 'watch') {
    $('#watch-rows').innerHTML = stockRows();
    const value = quote();
    $('#quote-price').textContent = format(value.price); $('#quote-change').textContent = `${signed(value.change)} (${signed(value.changePercent)}%)`;
    $('.quote-primary').className = `quote-primary numeric ${color(value.change)}`; $('#quote-meta').innerHTML = quoteMeta(value);
    $('#quote-updated').textContent = `${clock(value.marketTime)} 更新`;
    $('#ticket-summary').innerHTML = ticketSummary(); $('#account-preview-content').innerHTML = accountPreview();
    if (state.funds) $('#flow-content').innerHTML = flowContent();
    const button = $('#preview-button'); button.disabled = state.summary?.marketStatus !== 'OPEN';
    if (state.summary?.marketStatus === 'CLOSED') button.textContent = '市场休市';
    else button.innerHTML = `${state.session ? `预览${state.side === 'BUY' ? '买入' : '卖出'}` : '登录后交易'}${icon('arrow')}`;
    drawChart();
  }
  if (state.route === 'assets' && state.account) $('#main').innerHTML = assetsView();
  if (state.route === 'market') {
    all('.discovery-card').forEach(card => { const value = quote(card.dataset.select); card.querySelector('.discovery-price').className = `discovery-price numeric ${color(value.change)}`; card.querySelector('.discovery-price strong').textContent = format(value.price); card.querySelector('.discovery-price>span').textContent = `${signed(value.changePercent)}%`; });
  }
  if (state.summary) { $('#market-clock').textContent = `香港时间 ${clock(state.summary.marketTime)}`; $('#market-status-footer').textContent = state.summary.marketStatus === 'OPEN' ? '交易中' : '休市'; }
  if ($('#order-dialog').open) renderOrderDetails();
}
function route(name) { if (name === 'login') { showAuth(); return; } state.route = name; state.mobileDetail = false; location.hash = name; render(); }
async function selectStock(id, side = 'BUY') {
  state.selected = id; state.side = side; state.limitPrice = side === 'BUY' ? quote(id).ask : quote(id).bid;
  state.quantity = 100; state.chartOffset = 0; state.hover = null; state.candles = []; state.funds = null; state.candleVersion = 0; state.fundVersion = 0;
  state.route = 'watch'; state.mobileDetail = true; location.hash = 'watch'; render(); syncSubscriptions(); await loadDetails();
}
async function loadDetails() {
  const generation = ++detailsGeneration, id = state.selected, period = state.period, range = state.fundRange;
  const [candles, funds] = await Promise.all([api(`/instruments/${id}/candles?period=${period}`), api(`/instruments/${id}/funds?range=${range}`)]);
  if (generation !== detailsGeneration) return;
  mergeCandles(candles); if (funds.version >= state.fundVersion) { state.funds = funds; state.fundVersion = funds.version; } updateLive();
}
function mergeCandles(result) {
  if (result.instrumentId !== state.selected || result.period !== state.period) return;
  const map = new Map(state.candles.map(item => [item.time,item])); result.items.forEach(item => { if (!(map.has(item.time) && result.version < state.candleVersion)) map.set(item.time,item); });
  state.candleVersion = Math.max(state.candleVersion, result.version);
  state.candles = [...map.values()].sort((a,b) => a.time-b.time).slice(-540);
}
async function loadPrivate() {
  const userId = state.session?.user?.id;
  const [watchlist, account, orders, trades] = await Promise.all([api('/watchlist'),api('/account'),api('/orders'),api('/trades')]);
  if (state.session?.user?.id !== userId) return;
  state.watchlist = watchlist.instrumentIds; state.watchVersion = watchlist.version; state.account = account; state.orders = orders.items; state.trades = trades.items;
}
function showAuth(mode = 'login') {
  state.authMode = mode; $('#auth-title').textContent = mode === 'login' ? '欢迎回到海港' : '开启你的投资旅程';
  $('#name-field').hidden = mode !== 'register'; $('#auth-submit').textContent = mode === 'login' ? '登录账户' : '创建账户';
  $('#auth-error').textContent = ''; all('[data-auth-mode]').forEach(button => button.classList.toggle('active',button.dataset.authMode===mode));
  if (!$('#auth-dialog').open) $('#auth-dialog').showModal();
}
async function finishLogin(session) {
  saveSession(session); await loadPrivate(); $('#auth-dialog').close(); render(); connectStream(); toast(`欢迎${session.user.name}，账户已同步`);
  if (pendingOrder()) toast('有一笔待确认提交，请到交易委托页面同步');
}
async function logout(remote = true) {
  if (remote && state.session) await api('/auth/logout', { method:'POST' });
  saveSession(null); state.account = null; state.orders = []; state.trades = []; state.watchlist = state.instruments.slice(0,6).map(item=>item.id); state.watchVersion = 0;
  $('#settings-dialog').close(); state.preview = null; $('#preview-dialog').close(); render(); connectStream();
}
async function updateWatchlist(ids) {
  if (!requireLogin()) return;
  try { const result = await api('/watchlist',{method:'PUT',body:{instrumentIds:ids,version:state.watchVersion}}); state.watchlist=result.instrumentIds; state.watchVersion=result.version; render(); }
  catch(error) { if(error.code==='VERSION_CONFLICT'){await loadPrivate();render();} throw error; }
}
async function showSearch() { $('#search-dialog').showModal(); $('#stock-search').value=''; await searchStocks(''); $('#stock-search').focus(); }
async function searchStocks(query) {
  const generation = ++searchGeneration; const result = await api(`/instruments?query=${encodeURIComponent(query)}`); if (generation!==searchGeneration) return;
  $('#search-results').innerHTML = result.items.length ? result.items.map(item => `<div class="search-result"><button data-search-select="${item.id}"><span class="stock-monogram">${esc(item.name[0])}</span><span><strong>${esc(item.name)}</strong><small>${item.symbol} · ${esc(item.englishName)}</small></span><span class="search-price ${color(quote(item.id).change)}">${format(quote(item.id).price)}</span></button><button class="icon-button star-button ${state.watchlist.includes(item.id)?'on':''}" data-search-star="${item.id}" aria-label="${state.watchlist.includes(item.id)?'移出':'加入'}${esc(item.name)}自选">${icon('star')}</button></div>`).join('') : '<div class="empty-state">没有找到相关股票，试试名称、代码或行业。</div>';
}
function pendingSave(value) { if (value) localStorage.setItem(pendingKey(),JSON.stringify(value)); else localStorage.removeItem(pendingKey()); }
async function showPreview() {
  if(!requireLogin())return;
  if(pendingOrder()){toast('先在交易委托页确认上一笔提交结果',true);route('orders');return;}
  const button=$('#preview-button');button.disabled=true;
  try {
    state.preview=await api('/orders/previews',{method:'POST',body:{instrumentId:state.selected,side:state.side,limitPrice:state.limitPrice,quantity:Number(state.quantity)}});
    state.previewClientId=crypto.randomUUID();renderPreview();$('#preview-dialog').showModal();
  } finally { if(button.isConnected)button.disabled=false; }
}
function renderPreview() {
  const preview=state.preview; const item=instrument(preview.instrumentId);
  $('#preview-content').innerHTML=`<span class="review-direction ${preview.side==='SELL'?'sell':''}">${preview.side==='BUY'?'买入':'卖出'} · 限价委托</span><h2>${esc(item.name)} <small class="muted" style="font-size:13px">${item.symbol}</small></h2><div class="review-amount numeric">${format(preview.estimatedTotal)} <small>HKD · 预估${preview.side==='BUY'?'支出':'收入'}</small></div><div class="review-rows">${summaryRow('委托价格',`${format(preview.limitPrice)} HKD`)}${summaryRow('委托数量',`${format(preview.quantity,0)} 股`)}${summaryRow('委托金额',`${format(preview.notional)} HKD`)}${summaryRow('预估费用',`${format(preview.estimatedFee)} HKD`)}${summaryRow('委托有效期','模拟交易日结束前')}</div><div class="expiry">${icon('clock')}<span id="preview-expiry">确认信息有效期 15 秒</span></div><p id="preview-error" class="form-error" role="alert"></p><button id="confirm-order" class="button accent full">确认${preview.side==='BUY'?'买入':'卖出'}</button><p class="dialog-footnote">费用按最终成交金额计算；受理不代表已成交。</p>`;updatePreviewExpiry();
}
function updatePreviewExpiry() {
  if(!state.preview||!$('#preview-dialog').open)return;
  const seconds=Math.max(0,Math.ceil((state.preview.expiresAt-Date.now()-state.serverOffset)/1000));
  const text=$('#preview-expiry'),button=$('#confirm-order');if(!text||!button)return;
  text.textContent=seconds>0?`请在 ${seconds} 秒内确认，超时后需重新预览`:'确认信息已过期，请关闭后重新预览';
  if(!pendingOrder()&&!state.submitting)button.disabled=seconds===0;
}
async function submitPreview() {
  if(state.submitting)return;
  state.submitting=true;const button=$('#confirm-order');button.disabled=true;button.textContent='正在提交…';
  const pending={previewId:state.preview.previewId,clientOrderId:state.previewClientId};pendingSave(pending);
  try { const order=await api('/orders',{method:'POST',body:pending});pendingSave(null);$('#preview-dialog').close();await loadPrivate();route('orders');toast(`委托已受理 · ${labels[order.status]}`); }
  catch(error) {
    if(error.status){pendingSave(null);$('#preview-error').textContent=error.message;button.textContent='请关闭后重新预览';}
    else {$('#preview-error').textContent='提交结果尚未确认，请查询或重试原提交。';button.textContent='查询 / 重试原提交';button.dataset.recover='true';button.disabled=false;}
  } finally {state.submitting=false;}
}
async function recoverOrder(retrySubmission=true) {
  const pending=pendingOrder();if(!pending)return;
  let order;
  try{order=await api(`/orders/by-client-id/${pending.clientOrderId}`);}
  catch(error){if(error.code!=='ORDER_NOT_FOUND')throw error;if(!retrySubmission)return;try{order=await api('/orders',{method:'POST',body:pending});}catch(submitError){if(submitError.code==='PREVIEW_EXPIRED'){pendingSave(null);$('#preview-dialog').close();render();toast('原提交未受理且确认已过期，可以重新下单');return;}throw submitError;}}
  pendingSave(null);$('#preview-dialog').close();await loadPrivate();route('orders');toast(`委托已确认 · ${labels[order.status]}`);
}
function renderOrderDetails() {
  const order=state.orders.find(order=>order.id===state.selectedOrder);if(!order)return;
  $('#order-content').innerHTML=`<h2>${esc(instrument(order.instrumentId).name)}</h2><p><span class="status-pill ${order.status}">${labels[order.status]}</span> <span class="${order.side==='BUY'?'up':'down'}">${order.side==='BUY'?'买入':'卖出'}</span></p><div class="review-rows">${summaryRow('委托价格',`${format(order.limitPrice)} HKD`)}${summaryRow('委托数量',`${format(order.quantity,0)} 股`)}${summaryRow('已成交',`${format(order.filledQuantity,0)} 股`)}${summaryRow('成交均价',order.averageFillPrice?`${format(order.averageFillPrice)} HKD`:'—')}${summaryRow('累计费用',`${format(order.fee)} HKD`)}${summaryRow('委托时间',`${date(orderTime(order))} ${clock(orderTime(order))}`)}${summaryRow('有效期至',`${date(order.marketExpiresAt || order.expiresAt)} ${clock(order.marketExpiresAt || order.expiresAt)}`)}</div><p class="dialog-footnote">委托编号 ${esc(order.id.slice(0,8))}</p>${active(order)?`<button class="button secondary full" data-cancel="${order.id}">撤销剩余委托</button>`:''}`;
}
async function cancelOrder(id) {const order=await api(`/orders/${id}/cancel`,{method:'POST'});await loadPrivate();if(state.route==='orders')render();renderOrderDetails();toast(`${instrument(order.instrumentId).name}剩余委托已撤销`);}
function desiredTopics(){return new Set(['market',...state.instruments.map(item=>`quote:${item.id}`),`candles:${state.selected}:${state.period}`,`funds:${state.selected}:${state.fundRange}`,...(state.session?['account','orders','watchlist']:[])]);}
function syncSubscriptions(){
  if(state.socket?.readyState!==WebSocket.OPEN)return;
  const desired=desiredTopics(),remove=[...state.subscribed].filter(topic=>!desired.has(topic)),add=[...desired].filter(topic=>!state.subscribed.has(topic));
  if(remove.length)state.socket.send(JSON.stringify({type:'unsubscribe',topics:remove}));
  if(add.length)state.socket.send(JSON.stringify({type:'subscribe',topics:add}));state.subscribed=desired;
}
function updateConnection(){
  $('#connection').classList.toggle('offline',!state.connected);$('#connection span').textContent=state.connected?'实时连接':state.paused?'推送已暂停':'连接恢复中';
  if($('#toggle-stream'))$('#toggle-stream').textContent=state.paused?'恢复推送':'暂停推送';
  if($('#toggle-market'))$('#toggle-market').textContent=state.summary?.marketStatus==='OPEN'?'切换休市':'恢复交易';
}
function connectStream(){
  clearTimeout(reconnectTimer);clearInterval(heartbeatTimer);
  if(state.socket){state.socket.onclose=null;state.socket.close();}
  state.connected=false;state.subscribed=new Set();state.sequences.clear();state.candleVersion=0;state.fundVersion=0;if(state.paused){updateConnection();return;}
  const socket=new WebSocket(`${location.protocol==='https:'?'wss':'ws'}://${location.host}/stream`);state.socket=socket;let lastMessage=Date.now();
  socket.onopen=()=>{state.connected=true;state.reconnectAttempt=0;updateConnection();if(state.session)socket.send(JSON.stringify({type:'authenticate',accessToken:state.session.accessToken}));syncSubscriptions();heartbeatTimer=setInterval(()=>{if(Date.now()-lastMessage>45000){socket.close();return;}if(socket.readyState===WebSocket.OPEN)socket.send(JSON.stringify({type:'ping'}));},20000);};
  socket.onmessage=run(async event=>{
    if(socket!==state.socket)return;
    lastMessage=Date.now();const message=JSON.parse(event.data);
    if(message.type==='error'){if(message.code==='SESSION_EXPIRED'){await api('/account');connectStream();}else toast(message.message,true);return;}
    if(!['snapshot','event'].includes(message.type))return;
    const previous=state.sequences.get(message.topic);
    if(message.type==='event'&&previous&&(previous.epoch!==message.epoch||message.sequence!==previous.sequence+1)){socket.send(JSON.stringify({type:'subscribe',topics:[message.topic]}));return;}
    state.sequences.set(message.topic,{sequence:message.sequence,epoch:message.epoch});
    const data=message.data;
    if(message.topic==='market')state.summary=data;
    else if(message.topic.startsWith('quote:'))state.quotes.set(data.instrumentId,data);
    else if(message.topic.startsWith('candles:'))mergeCandles(data);
    else if(message.topic===`funds:${state.selected}:${state.fundRange}`&&data.version>=state.fundVersion){state.funds=data;state.fundVersion=data.version;}
    else if(message.topic==='account')state.account=data;
    else if(message.topic==='watchlist'){if(data.version!==state.watchVersion){state.watchlist=data.instrumentIds;state.watchVersion=data.version;renderProfile();if(state.route==='watch')render();}}
    else if(message.topic==='orders'){
      const changed=JSON.stringify(state.orders)!==JSON.stringify(data.items);state.orders=data.items;
      if(changed){const trades=await api('/trades');if(socket!==state.socket)return;state.trades=trades.items;if(state.route==='orders')render();}
    }
    updateLive();
  });
  socket.onclose=()=>{state.connected=false;clearInterval(heartbeatTimer);updateConnection();if(!state.paused)reconnectTimer=setTimeout(connectStream,Math.min(12000,700*2**state.reconnectAttempt++));};
  socket.onerror=()=>socket.close();
}
function setupChart(){
  const canvas=$('#chart');if(!canvas)return;
  resizeObserver=new ResizeObserver(drawChart);resizeObserver.observe(canvas.parentElement);
  canvas.addEventListener('pointerdown',event=>{chartDrag={x:event.clientX,offset:state.chartOffset};canvas.setPointerCapture(event.pointerId);});
  canvas.addEventListener('pointermove',event=>{
    const rect=canvas.getBoundingClientRect();state.hover={x:event.clientX-rect.left,y:event.clientY-rect.top};
    if(chartDrag){state.chartOffset=Math.max(0,Math.min(state.candles.length-state.chartCount,chartDrag.offset+Math.round((event.clientX-chartDrag.x)/(rect.width/state.chartCount))));state.hover=null;}
    drawChart();
  });
  const release=()=>{chartDrag=null;};canvas.addEventListener('pointerup',release);canvas.addEventListener('pointercancel',release);
  canvas.addEventListener('pointerleave',()=>{state.hover=null;drawChart();});
  canvas.addEventListener('wheel',event=>{event.preventDefault();state.chartCount=Math.max(24,Math.min(120,state.chartCount+(event.deltaY>0?5:-5)));state.chartOffset=Math.min(state.chartOffset,Math.max(0,state.candles.length-state.chartCount));drawChart();},{passive:false});drawChart();
}
function drawChart(){
  const canvas=$('#chart');if(!canvas)return;const rect=canvas.getBoundingClientRect();if(!rect.width)return;
  const ratio=devicePixelRatio||1;canvas.width=Math.round(rect.width*ratio);canvas.height=Math.round(rect.height*ratio);const ctx=canvas.getContext('2d');ctx.scale(ratio,ratio);
  const width=rect.width,height=rect.height,right=49,plotWidth=width-right,priceHeight=height*.68,volumeTop=height*.76,bottom=height-19;
  const end=Math.max(1,state.candles.length-state.chartOffset),start=Math.max(0,end-state.chartCount),items=state.candles.slice(start,end);if(!items.length){ctx.fillStyle='#7d8999';ctx.font='11px sans-serif';ctx.fillText('行情加载中…',20,100);return;}
  const min=Math.min(...items.map(item=>Number(item.low))),max=Math.max(...items.map(item=>Number(item.high))),padding=(max-min)*.12||1;
  const y=value=>9+(max+padding-Number(value))/(max-min+padding*2)*(priceHeight-17),step=plotWidth/items.length,x=index=>(index+.5)*step;
  ctx.font='9px -apple-system, sans-serif';ctx.lineWidth=.6;
  for(let index=0;index<5;index++){const top=9+(priceHeight-17)*index/4;ctx.strokeStyle='#2c323b';ctx.beginPath();ctx.moveTo(0,top);ctx.lineTo(plotWidth,top);ctx.stroke();ctx.fillStyle='#748190';ctx.fillText(format(max+padding-(max-min+padding*2)*index/4),plotWidth+7,top+3);}
  const maxVolume=Math.max(...items.map(item=>item.volume));
  items.forEach((item,index)=>{const up=Number(item.close)>=Number(item.open),shade=up?'#ec7a83':'#4fc09c';ctx.strokeStyle=shade;ctx.fillStyle=shade;
    if(state.period!=='1m'){ctx.beginPath();ctx.moveTo(x(index),y(item.high));ctx.lineTo(x(index),y(item.low));ctx.stroke();ctx.fillRect(x(index)-Math.max(1.2,step*.27),Math.min(y(item.open),y(item.close)),Math.max(2.4,step*.54),Math.max(1.3,Math.abs(y(item.open)-y(item.close))));}
    ctx.globalAlpha=.55;ctx.fillRect(x(index)-step*.27,bottom-(item.volume/maxVolume)*(bottom-volumeTop),Math.max(1.5,step*.54),(item.volume/maxVolume)*(bottom-volumeTop));ctx.globalAlpha=1;
  });
  if(state.period==='1m'){
    const gradient=ctx.createLinearGradient(0,0,0,priceHeight);gradient.addColorStop(0,'#efb76b35');gradient.addColorStop(1,'#efb76b00');ctx.beginPath();items.forEach((item,index)=>index?ctx.lineTo(x(index),y(item.close)):ctx.moveTo(x(index),y(item.close)));ctx.lineTo(x(items.length-1),priceHeight);ctx.lineTo(x(0),priceHeight);ctx.closePath();ctx.fillStyle=gradient;ctx.fill();ctx.beginPath();items.forEach((item,index)=>index?ctx.lineTo(x(index),y(item.close)):ctx.moveTo(x(index),y(item.close)));ctx.strokeStyle='#efb76b';ctx.lineWidth=1.5;ctx.stroke();
  }else for(const [window,shade]of [[5,'#cead6e'],[20,'#a59cd5']]){
    ctx.beginPath();ctx.strokeStyle=shade;ctx.lineWidth=1;let begun=false;
    items.forEach((item,index)=>{const globalIndex=start+index;if(globalIndex<window-1)return;const average=state.candles.slice(globalIndex-window+1,globalIndex+1).reduce((sum,item)=>sum+Number(item.close),0)/window;if(!begun){ctx.moveTo(x(index),y(average));begun=true;}else ctx.lineTo(x(index),y(average));});ctx.stroke();
  }
  ctx.fillStyle='#69798c';ctx.fillText('VOL',0,volumeTop-6);ctx.strokeStyle='#303640';ctx.lineWidth=.5;ctx.beginPath();ctx.moveTo(0,priceHeight+8);ctx.lineTo(plotWidth,priceHeight+8);ctx.stroke();
  [0,Math.floor(items.length/2),items.length-1].forEach(index=>{const label=state.period==='1m'?clock(items[index].time).slice(0,5):date(items[index].time);ctx.fillText(label,Math.max(0,Math.min(plotWidth-35,x(index)-15)),height-3);});
  const last=items.at(-1);ctx.setLineDash([3,4]);ctx.strokeStyle=Number(last.close)>=Number(last.open)?'#d1737b':'#4ea78d';ctx.beginPath();ctx.moveTo(0,y(last.close));ctx.lineTo(plotWidth,y(last.close));ctx.stroke();ctx.setLineDash([]);
  const tooltip=$('#chart-tooltip');tooltip.style.display='none';
  if(state.hover&&state.hover.x<plotWidth&&state.hover.y<priceHeight){
    const index=Math.max(0,Math.min(items.length-1,Math.floor(state.hover.x/step))),item=items[index];ctx.strokeStyle='#687588';ctx.setLineDash([3,3]);ctx.beginPath();ctx.moveTo(x(index),0);ctx.lineTo(x(index),bottom);ctx.moveTo(0,state.hover.y);ctx.lineTo(plotWidth,state.hover.y);ctx.stroke();ctx.setLineDash([]);
    tooltip.style.display='block';tooltip.style.left=`${state.hover.x>plotWidth/2?8:Math.min(plotWidth-126,state.hover.x+13)}px`;tooltip.style.top='12px';tooltip.innerHTML=`${date(item.time)} ${state.period==='1m'?clock(item.time):''}<br>开 ${format(item.open)}　收 ${format(item.close)}<br>高 ${format(item.high)}　低 ${format(item.low)}<br>量 ${compact(item.volume)} 股`;
  }
}
document.addEventListener('click',run(async event=>{
  const button=event.target.closest('button,a,[data-select]');if(!button)return;
  if(button.hasAttribute('data-close')){button.closest('dialog').close();return;}
  if(button.dataset.route){route(button.dataset.route);return;}
  if(button.dataset.action){const action=button.dataset.action;
    if(action==='search')await showSearch();if(action==='login')showAuth();if(action==='back'){state.mobileDetail=false;render();}
    if(action==='use-price'){state.limitPrice=state.side==='BUY'?quote().ask:quote().bid;$('#limit-price').value=state.limitPrice;$('#ticket-summary').innerHTML=ticketSummary();}
    if(action==='history'){const result=await api(`/instruments/${state.selected}/candles?period=${state.period}&before=${state.candles[0]?.time||''}`);mergeCandles(result);state.chartOffset=Math.min(state.chartOffset+55,Math.max(0,state.candles.length-state.chartCount));drawChart();toast('已载入更早行情，拖动可返回最新');}
    if(action==='recover-order')await recoverOrder();return;
  }
  if(button.dataset.remove){await updateWatchlist(state.watchlist.filter(id=>id!==button.dataset.remove));toast('已移出自选');return;}
  if(button.dataset.move){const ids=[...state.watchlist],index=ids.indexOf(button.dataset.move);if(index>0){[ids[index-1],ids[index]]=[ids[index],ids[index-1]];await updateWatchlist(ids);}return;}
  if(button.dataset.star||button.dataset.searchStar){const id=button.dataset.star||button.dataset.searchStar;if(!requireLogin())return;await updateWatchlist(state.watchlist.includes(id)?state.watchlist.filter(item=>item!==id):[...state.watchlist,id]);if($('#search-dialog').open)await searchStocks($('#stock-search').value);return;}
  if(button.dataset.select){await selectStock(button.dataset.select);return;}
  if(button.dataset.searchSelect){$('#search-dialog').close();await selectStock(button.dataset.searchSelect);return;}
  if(button.dataset.sell){await selectStock(button.dataset.sell,'SELL');return;}
  if(button.dataset.period){state.period=button.dataset.period;state.candles=[];state.candleVersion=0;state.chartOffset=0;render();syncSubscriptions();await loadDetails();return;}
  if(button.dataset.fundRange){state.fundRange=button.dataset.fundRange;state.funds=null;state.fundVersion=0;render();syncSubscriptions();await loadDetails();return;}
  if(button.dataset.side){state.side=button.dataset.side;state.limitPrice=state.side==='BUY'?quote().ask:quote().bid;render();return;}
  if(button.dataset.quantity){state.quantity=Number(button.dataset.quantity);$('#quantity').value=state.quantity;$('#ticket-lots').textContent=`${state.quantity/100} 手`;$('#ticket-summary').innerHTML=ticketSummary();return;}
  if(button.dataset.zoom){state.chartCount=Math.max(24,Math.min(120,state.chartCount+(button.dataset.zoom==='out'?10:-10)));state.chartOffset=Math.min(state.chartOffset,Math.max(0,state.candles.length-state.chartCount));drawChart();return;}
  if(button.dataset.orderTab){state.orderTab=button.dataset.orderTab;render();return;}
  if(button.dataset.sector){state.sector=button.dataset.sector;render();return;}
  if(button.dataset.authMode){showAuth(button.dataset.authMode);return;}
  if(button.dataset.order){state.selectedOrder=button.dataset.order;renderOrderDetails();$('#order-dialog').showModal();return;}
  if(button.dataset.cancel){await cancelOrder(button.dataset.cancel);return;}
  if(button.id==='confirm-order'){if(button.dataset.recover)await recoverOrder();else await submitPreview();return;}
  if(button.id==='preview-button'){await showPreview();return;}
}));
document.addEventListener('keydown',event=>{if((event.metaKey||event.ctrlKey)&&event.key==='k'){event.preventDefault();run(showSearch)();}if((event.key==='Enter'||event.key===' ')&&event.target.matches('[data-select][role=button]')){event.preventDefault();run(()=>selectStock(event.target.dataset.select))();}});
document.addEventListener('input',event=>{if(event.target.id==='limit-price')state.limitPrice=event.target.value;if(event.target.id==='quantity'){state.quantity=Number(event.target.value);$('#ticket-lots').textContent=`${format(state.quantity/100,1)} 手`;}if(['limit-price','quantity'].includes(event.target.id))$('#ticket-summary').innerHTML=ticketSummary();});
$('#auth-form').addEventListener('submit',async event=>{event.preventDefault();const fields=new FormData(event.target),button=$('#auth-submit');button.disabled=true;$('#auth-error').textContent='';try{const session=await api(`/auth/${state.authMode}`,{method:'POST',body:Object.fromEntries(fields),retry:false});await finishLogin(session);}catch(error){$('#auth-error').textContent=error.message;}finally{button.disabled=false;}});
$('#demo-login').addEventListener('click',run(async()=>{const button=$('#demo-login');button.disabled=true;try{await finishLogin(await api('/auth/login',{method:'POST',body:{email:'demo@harbor.app',password:'Harbor2026!'},retry:false}));}finally{button.disabled=false;}}));
$('#login-button').addEventListener('click',()=>showAuth());$('#profile-button').addEventListener('click',()=>state.session?$('#settings-dialog').showModal():showAuth());$('#mobile-profile').addEventListener('click',()=>$('#settings-dialog').showModal());$('#search-button').addEventListener('click',run(showSearch));
let searchTimer;$('#stock-search').addEventListener('input',event=>{clearTimeout(searchTimer);searchTimer=setTimeout(run(()=>searchStocks(event.target.value)),150);});
$('#settings-button').addEventListener('click',()=>{$('#settings-dialog').showModal();updateConnection();});$('#logout-button').addEventListener('click',run(()=>logout()));
$('#toggle-stream').addEventListener('click',()=>{state.paused=!state.paused;connectStream();toast(state.paused?'推送已暂停，当前显示最后一次数据':'正在重新连接并同步数据');});
$('#toggle-market').addEventListener('click',run(async()=>{if(!requireLogin())return;state.summary=await api('/dev/market',{method:'POST',body:{status:state.summary.marketStatus==='OPEN'?'CLOSED':'OPEN'}});updateConnection();toast(state.summary.marketStatus==='OPEN'?'模拟市场已恢复交易':'模拟市场已休市');}));
let resetArmed=false;$('#reset-account').addEventListener('click',run(async()=>{if(!requireLogin())return;if(!resetArmed){resetArmed=true;$('#reset-account').textContent='再次点击确认';setTimeout(()=>{resetArmed=false;$('#reset-account').textContent='重置账户';},4000);return;}await api('/dev/reset',{method:'POST'});pendingSave(null);await loadPrivate();render();toast('账户已恢复初始状态');resetArmed=false;$('#reset-account').textContent='重置账户';}));
for(const dialog of all('dialog'))dialog.addEventListener('click',event=>{if(event.target===dialog){const rect=dialog.getBoundingClientRect();if(event.clientX<rect.left||event.clientX>rect.right||event.clientY<rect.top||event.clientY>rect.bottom)dialog.close();}});
window.addEventListener('hashchange',()=>{const name=location.hash.slice(1);if(['watch','market','orders','assets'].includes(name)&&state.route!==name){state.route=name;state.mobileDetail=false;render();}});
setInterval(updatePreviewExpiry,250);
async function bootstrap(){
  const [instruments,quotes,summary]=await Promise.all([api('/instruments'),api('/quotes'),api('/market')]);
  state.instruments=instruments.items;state.quotes=new Map(quotes.items.map(item=>[item.instrumentId,item]));state.summary=summary;
  state.watchlist=state.instruments.slice(0,6).map(item=>item.id);state.limitPrice=quote().ask;
  if(state.session){try{state.session.user=await api('/auth/me');await loadPrivate();}catch(error){if(error.status===401)saveSession(null);else throw error;}}
  if(['watch','market','orders','assets'].includes(location.hash.slice(1)))state.route=location.hash.slice(1);
  render();await loadDetails();connectStream();
}
bootstrap().catch(error=>{$('#main').innerHTML=`<div class="initial-error"><h2>暂时无法连接市场</h2><p>${esc(error.message)}</p><button class="button secondary" id="reload-button">重新连接</button></div>`;$('#reload-button').onclick=()=>location.reload();});
