#!/usr/bin/env node
// Claude Code Usage Monitor — HTTP server
// Runs as a launchd service, accessible at http://localhost:9119
// No npm dependencies — pure Node.js built-ins only

const http = require('http');
const fs   = require('fs');
const path = require('path');
const os   = require('os');

const PORT     = 9119;
const BASE_DIR = path.join(os.homedir(), '.claude');
const LOG_FILE = path.join(BASE_DIR, 'session-costs.log');

// ── Data helpers ─────────────────────────────────────────────────────────────

function readLog() {
  if (!fs.existsSync(LOG_FILE)) return [];
  const lines = fs.readFileSync(LOG_FILE, 'utf8').trim().split('\n');
  // Skip header
  return lines.slice(1).filter(Boolean).map(line => {
    const [date, time, session_id, project, cost, input_tokens, output_tokens,
           ctx_pct, five_h_end, five_h_delta, ...modelParts] = line.split(',');
    return {
      date, time, session_id, project,
      cost:           parseFloat(cost)         || 0,
      input_tokens:   parseInt(input_tokens)   || 0,
      output_tokens:  parseInt(output_tokens)  || 0,
      ctx_pct:        parseFloat(ctx_pct)      || 0,
      five_h_end:     parseFloat(five_h_end)   || 0,
      five_h_delta:   parseFloat(five_h_delta) || 0,
      model:          modelParts.join(',').trim() || 'unknown',
    };
  });
}

function readActiveSessions() {
  const files = fs.readdirSync(BASE_DIR).filter(f =>
    f.startsWith('session-stats-') && !f.endsWith('-start.json') && f.endsWith('.json')
  );
  const cutoff = Date.now() - 2 * 60 * 60 * 1000; // 2h
  const result = [];
  for (const f of files) {
    const fp = path.join(BASE_DIR, f);
    try {
      const stat = fs.statSync(fp);
      if (stat.mtimeMs < cutoff) continue;
      const data = JSON.parse(fs.readFileSync(fp, 'utf8'));
      const sid = data.session_id || f.replace('session-stats-', '').replace('.json', '');
      // Try to get start 5h%
      const startFp = path.join(BASE_DIR, `session-stats-${sid}-start.json`);
      let five_h_start = 0;
      if (fs.existsSync(startFp)) {
        try { five_h_start = JSON.parse(fs.readFileSync(startFp, 'utf8')).five_h_pct_start || 0; } catch {}
      }
      data.five_h_delta = Math.max(0, (data.five_h_pct || 0) - five_h_start);
      result.push(data);
    } catch {}
  }
  return result;
}

// ── HTML dashboard ────────────────────────────────────────────────────────────

function dashboardHTML() {
  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Claude Monitor</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
  :root {
    --bg:#0d1117;--bg2:#161b22;--bg3:#21262d;--border:#30363d;
    --text:#e6edf3;--muted:#7d8590;
    --cyan:#39d3f7;--green:#3fb950;--yellow:#d29922;
    --red:#f85149;--purple:#bc8cff;--blue:#58a6ff;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:var(--bg);color:var(--text);font-family:'SF Mono','Fira Code',monospace;font-size:13px}
  .header{background:var(--bg2);border-bottom:1px solid var(--border);padding:14px 24px;display:flex;justify-content:space-between;align-items:center;position:sticky;top:0;z-index:10}
  .header h1{font-size:15px;color:var(--cyan);font-weight:700}
  .header .meta{color:var(--muted);font-size:11px;display:flex;align-items:center;gap:12px}
  .dot{width:8px;height:8px;border-radius:50%;background:var(--green);display:inline-block;animation:pulse 2s infinite}
  @keyframes pulse{0%,100%{opacity:1}50%{opacity:.4}}
  .container{max-width:1400px;margin:0 auto;padding:20px}
  .cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:20px}
  .card{background:var(--bg2);border:1px solid var(--border);border-radius:8px;padding:14px}
  .card .label{color:var(--muted);font-size:10px;text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px}
  .card .value{font-size:22px;font-weight:700}
  .card .sub{color:var(--muted);font-size:10px;margin-top:4px}
  .section{background:var(--bg2);border:1px solid var(--border);border-radius:8px;margin-bottom:16px;overflow:hidden}
  .section-header{padding:10px 16px;border-bottom:1px solid var(--border);display:flex;justify-content:space-between;align-items:center}
  .section-header h3{font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:.5px}
  .active-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:0;padding:0}
  .active-card{padding:14px 16px;border-right:1px solid var(--border);border-bottom:1px solid var(--border)}
  .active-card:nth-child(n){border-right:1px solid var(--border)}
  .active-card .proj{font-weight:600;color:var(--cyan);margin-bottom:8px;font-size:13px}
  .active-card .sess{color:var(--muted);font-size:10px;margin-bottom:10px}
  .bar-row{display:flex;align-items:center;gap:8px;margin-bottom:6px;font-size:11px}
  .bar-row .bar-label{width:70px;color:var(--muted);flex-shrink:0}
  .bar-track{flex:1;height:6px;background:var(--bg3);border-radius:3px;overflow:hidden}
  .bar-fill{height:100%;border-radius:3px;transition:width .3s}
  .bar-row .bar-val{width:50px;text-align:right;color:var(--text)}
  .charts-grid{display:grid;grid-template-columns:1fr 1fr;gap:0}
  .chart-box{padding:16px;border-right:1px solid var(--border)}
  .chart-box:nth-child(2n){border-right:none}
  .chart-box:nth-child(n+3){border-top:1px solid var(--border)}
  .chart-box h3{font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;margin-bottom:12px}
  .chart-box canvas{max-height:220px}
  .filters{display:flex;gap:8px}
  .filters input,.filters select{background:var(--bg3);border:1px solid var(--border);color:var(--text);padding:4px 8px;border-radius:4px;font-family:inherit;font-size:12px;outline:none}
  table{width:100%;border-collapse:collapse}
  th{padding:8px 12px;text-align:left;color:var(--muted);font-size:11px;font-weight:500;border-bottom:1px solid var(--border);cursor:pointer;user-select:none;white-space:nowrap}
  th:hover{color:var(--text)}
  td{padding:7px 12px;border-bottom:1px solid var(--border);white-space:nowrap}
  tr:last-child td{border-bottom:none}
  tr:hover td{background:var(--bg3)}
  .pill{display:inline-block;padding:1px 7px;border-radius:99px;font-size:11px;font-weight:600}
  .pg{background:rgba(63,185,80,.15);color:var(--green)}
  .py{background:rgba(210,153,34,.15);color:var(--yellow)}
  .pr{background:rgba(248,81,73,.15);color:var(--red)}
  .mini-bar{display:inline-flex;align-items:center;gap:6px;font-size:11px}
  .mini-bar .track{width:50px;height:5px;background:var(--bg3);border-radius:3px;overflow:hidden;display:inline-block}
  .mini-bar .fill{height:100%;border-radius:3px}
  .empty-state{padding:32px;text-align:center;color:var(--muted)}
  @media(max-width:900px){.charts-grid{grid-template-columns:1fr}.chart-box{border-right:none;border-top:1px solid var(--border)}}
</style>
</head>
<body>

<div class="header">
  <h1>⚡ Claude Code — Usage Monitor</h1>
  <div class="meta">
    <span><span class="dot"></span> live</span>
    <span id="lastUpdate">cargando...</span>
    <span id="refreshTimer" style="color:var(--muted)"></span>
  </div>
</div>

<div class="container">
  <div class="cards" id="cards"></div>

  <div class="section">
    <div class="section-header"><h3>Sesiones activas</h3><span id="activeCount" style="color:var(--muted);font-size:11px"></span></div>
    <div class="active-grid" id="activeGrid"></div>
  </div>

  <div class="section">
    <div class="charts-grid">
      <div class="chart-box"><h3>Costo por día (30d)</h3><canvas id="cCost"></canvas></div>
      <div class="chart-box"><h3>% límite 5h por sesión (últimas 30)</h3><canvas id="cFiveH"></canvas></div>
      <div class="chart-box"><h3>Tokens por día — input + output (30d)</h3><canvas id="cTokens"></canvas></div>
      <div class="chart-box"><h3>Sesiones por proyecto</h3><canvas id="cProjects"></canvas></div>
    </div>
  </div>

  <div class="section">
    <div class="section-header">
      <h3>Historial de sesiones</h3>
      <div class="filters">
        <input type="text" id="filterText" placeholder="Filtrar..." oninput="renderTable()">
        <select id="filterPeriod" onchange="renderTable()">
          <option value="all">Todo</option>
          <option value="today">Hoy</option>
          <option value="week">Esta semana</option>
          <option value="month">Este mes</option>
        </select>
      </div>
    </div>
    <table>
      <thead><tr>
        <th onclick="sort('date')">Fecha</th>
        <th onclick="sort('time')">Hora</th>
        <th>Session</th>
        <th onclick="sort('project')">Proyecto</th>
        <th onclick="sort('cost')">Costo</th>
        <th onclick="sort('input_tokens')">In-tok</th>
        <th onclick="sort('output_tokens')">Out-tok</th>
        <th onclick="sort('ctx_pct')">Ctx%</th>
        <th onclick="sort('five_h_end')">5h acum</th>
        <th onclick="sort('five_h_delta')">5h sesión</th>
        <th>Modelo</th>
      </tr></thead>
      <tbody id="tableBody"></tbody>
    </table>
  </div>
</div>

<script>
let sessions = [], active = [], charts = {}, sortKey = 'date', sortDir = -1;
const TODAY      = () => new Date().toISOString().slice(0,10);
const WEEK_AGO   = () => new Date(Date.now()-7*24*3600*1000).toISOString().slice(0,10);
const MONTH_AGO  = () => new Date(Date.now()-30*24*3600*1000).toISOString().slice(0,10);

Chart.defaults.color = '#7d8590';
Chart.defaults.borderColor = '#30363d';
Chart.defaults.font.family = "'SF Mono','Fira Code',monospace";
Chart.defaults.font.size = 11;

async function fetchData() {
  const r = await fetch('/api/data');
  const d = await r.json();
  sessions = d.sessions;
  active   = d.active;
  document.getElementById('lastUpdate').textContent = 'actualizado: ' + new Date().toLocaleTimeString('es-CL');
  renderAll();
}

function renderAll() {
  renderCards();
  renderActive();
  renderCharts();
  renderTable();
}

function renderCards() {
  const d = sessions;
  const today = TODAY();
  const tc = d.reduce((s,r)=>s+r.cost,0);
  const td = d.filter(r=>r.date===today).reduce((s,r)=>s+r.cost,0);
  const tt = d.reduce((s,r)=>s+r.input_tokens+r.output_tokens,0);
  const t5 = d.reduce((s,r)=>s+r.five_h_delta,0);
  const tds = d.filter(r=>r.date===today).length;
  const avg5 = d.length ? t5/d.length : 0;
  const weekCost = d.filter(r=>r.date>=WEEK_AGO()).reduce((s,r)=>s+r.cost,0);

  const c5color = t5>100?'var(--red)':t5>50?'var(--yellow)':'var(--green)';
  document.getElementById('cards').innerHTML = \`
    <div class="card"><div class="label">Costo total</div><div class="value" style="color:var(--yellow)">\$\${tc.toFixed(3)}</div><div class="sub">\${d.length} sesiones</div></div>
    <div class="card"><div class="label">Hoy</div><div class="value" style="color:var(--green)">\$\${td.toFixed(3)}</div><div class="sub">\${tds} sesión(es)</div></div>
    <div class="card"><div class="label">Esta semana</div><div class="value" style="color:var(--blue)">\$\${weekCost.toFixed(3)}</div><div class="sub">\${d.filter(r=>r.date>=WEEK_AGO()).length} sesiones</div></div>
    <div class="card"><div class="label">Tokens totales</div><div class="value" style="color:var(--cyan)">\${(tt/1000).toFixed(0)}k</div><div class="sub">\${d.length?(tt/d.length/1000).toFixed(0):0}k prom/sesión</div></div>
    <div class="card"><div class="label">5h consumido total</div><div class="value" style="color:\${c5color}">\${t5.toFixed(1)}%</div><div class="sub">\${avg5.toFixed(1)}% prom/sesión</div></div>
    <div class="card"><div class="label">Activas ahora</div><div class="value" style="color:var(--purple)">\${active.length}</div><div class="sub">\${active.length?active.map(a=>a.cwd?a.cwd.split('/').pop():'?').join(', '):'ninguna'}</div></div>
  \`;
}

function barHTML(pct, color) {
  const w = Math.min(pct||0, 100);
  return \`<div class="mini-bar"><div class="track"><div class="fill" style="width:\${w}%;background:\${color}"></div></div>\${(pct||0).toFixed(1)}%</div>\`;
}

function renderActive() {
  const el = document.getElementById('activeGrid');
  document.getElementById('activeCount').textContent = active.length ? \`\${active.length} activa(s)\` : '';
  if (!active.length) {
    el.innerHTML = '<div class="empty-state">Sin sesiones activas en las últimas 2 horas</div>';
    return;
  }
  el.innerHTML = active.map(a => {
    const proj = a.cwd ? a.cwd.split('/').pop() : '?';
    const sid  = (a.session_id||'').slice(0,8);
    const cost = (a.cost_usd||0).toFixed(3);
    const tok  = Math.round(((a.total_input_tokens||0)+(a.total_output_tokens||0))/1000);
    const ctx  = a.ctx_used_pct||0;
    const five_h = a.five_h_pct||0;
    const delta  = a.five_h_delta||0;
    const ctxColor  = ctx>=80?'var(--red)':ctx>=50?'var(--yellow)':'var(--blue)';
    const fiveColor = five_h>=80?'var(--red)':five_h>=50?'var(--yellow)':'var(--green)';
    return \`
      <div class="active-card">
        <div class="proj">\${proj}</div>
        <div class="sess">\${sid} · \${a.model||''}</div>
        <div class="bar-row"><span class="bar-label">Costo</span><span style="color:var(--yellow);font-weight:600">\$\${cost}</span></div>
        <div class="bar-row"><span class="bar-label">Tokens</span><span style="color:var(--cyan)">\${tok}k</span></div>
        <div class="bar-row">
          <span class="bar-label">Ctx</span>
          <div class="bar-track"><div class="bar-fill" style="width:\${Math.min(ctx,100)}%;background:\${ctxColor}"></div></div>
          <span class="bar-val">\${ctx.toFixed(1)}%</span>
        </div>
        <div class="bar-row">
          <span class="bar-label">5h acum</span>
          <div class="bar-track"><div class="bar-fill" style="width:\${Math.min(five_h,100)}%;background:\${fiveColor}"></div></div>
          <span class="bar-val">\${five_h.toFixed(1)}%</span>
        </div>
        <div class="bar-row"><span class="bar-label">5h sesión</span><span style="color:var(--cyan);font-weight:600">+\${delta.toFixed(1)}%</span></div>
      </div>
    \`;
  }).join('');
}

function groupByDay(data, field) {
  const m = {};
  data.forEach(r => { m[r.date] = (m[r.date]||0) + r[field]; });
  return m;
}

function renderCharts() {
  const today30 = new Date(Date.now()-30*24*3600*1000).toISOString().slice(0,10);
  const d30 = sessions.filter(r => r.date >= today30);
  const days = [...new Set(d30.map(r=>r.date))].sort();

  const costByDay  = groupByDay(d30, 'cost');
  const inByDay    = groupByDay(d30, 'input_tokens');
  const outByDay   = groupByDay(d30, 'output_tokens');
  const last30sess = sessions.slice(-30);

  // Cost by day
  rebuildChart('cCost', {
    type: 'bar',
    data: { labels: days, datasets: [{ label: 'USD', data: days.map(d=>costByDay[d]||0), backgroundColor: 'rgba(57,211,247,.3)', borderColor: '#39d3f7', borderWidth: 1, borderRadius: 3 }] },
    options: { plugins:{legend:{display:false}}, scales:{x:{ticks:{maxRotation:45}}, y:{ticks:{callback:v=>'\$'+v.toFixed(2)}}} }
  });

  // 5h per session
  rebuildChart('cFiveH', {
    type: 'bar',
    data: {
      labels: last30sess.map(r=>r.date.slice(5)+' '+r.time),
      datasets: [{ label: '% 5h', data: last30sess.map(r=>r.five_h_delta),
        backgroundColor: last30sess.map(r=>r.five_h_delta>=20?'rgba(248,81,73,.4)':r.five_h_delta>=10?'rgba(210,153,34,.4)':'rgba(57,211,247,.3)'),
        borderColor:     last30sess.map(r=>r.five_h_delta>=20?'#f85149':r.five_h_delta>=10?'#d29922':'#39d3f7'),
        borderWidth:1, borderRadius:3 }]
    },
    options: { plugins:{legend:{display:false}}, scales:{x:{ticks:{maxRotation:45,maxTicksLimit:15}},y:{title:{display:true,text:'%'}}} }
  });

  // Tokens stacked
  rebuildChart('cTokens', {
    type: 'bar',
    data: { labels: days, datasets: [
      { label:'Input',  data: days.map(d=>(inByDay[d]||0)/1000),  backgroundColor:'rgba(88,166,255,.4)',  borderColor:'#58a6ff', borderWidth:1, borderRadius:3 },
      { label:'Output', data: days.map(d=>(outByDay[d]||0)/1000), backgroundColor:'rgba(188,140,255,.4)', borderColor:'#bc8cff', borderWidth:1, borderRadius:3 },
    ]},
    options: { plugins:{legend:{position:'top'}}, scales:{x:{stacked:true,ticks:{maxRotation:45}},y:{stacked:true,title:{display:true,text:'k tokens'}}} }
  });

  // Projects donut
  const byProj = {};
  sessions.forEach(r=>{ byProj[r.project]=(byProj[r.project]||0)+1; });
  const projKeys = Object.keys(byProj).sort((a,b)=>byProj[b]-byProj[a]).slice(0,10);
  const palette  = ['#39d3f7','#3fb950','#d29922','#f85149','#bc8cff','#f0883e','#58a6ff','#7d8590','#56d364','#e3b341'];
  rebuildChart('cProjects', {
    type: 'doughnut',
    data: { labels: projKeys, datasets: [{ data: projKeys.map(p=>byProj[p]), backgroundColor: palette.map(c=>c+'99'), borderColor: palette, borderWidth: 2 }] },
    options: { plugins:{legend:{position:'right',labels:{boxWidth:12}}}, cutout:'60%' }
  });
}

function rebuildChart(id, config) {
  if (charts[id]) { charts[id].destroy(); }
  charts[id] = new Chart(document.getElementById(id), config);
}

function sort(key) {
  sortKey === key ? sortDir *= -1 : (sortKey=key, sortDir=-1);
  renderTable();
}

function renderTable() {
  const today = TODAY();
  const period = document.getElementById('filterPeriod').value;
  const text   = document.getElementById('filterText').value.toLowerCase();
  let data = sessions.filter(r => {
    if (period==='today' && r.date!==today) return false;
    if (period==='week'  && r.date<WEEK_AGO())  return false;
    if (period==='month' && r.date<MONTH_AGO()) return false;
    if (text && !JSON.stringify(r).toLowerCase().includes(text)) return false;
    return true;
  }).sort((a,b) => {
    const [av,bv]=[a[sortKey],b[sortKey]];
    return typeof av==='string' ? sortDir*av.localeCompare(bv) : sortDir*(av-bv);
  });

  const tb = document.getElementById('tableBody');
  if (!data.length) { tb.innerHTML='<tr><td colspan="11" style="text-align:center;color:var(--muted);padding:24px">Sin datos</td></tr>'; return; }

  tb.innerHTML = data.map(r => {
    const cc = r.cost>1?'pr':r.cost>0.3?'py':'pg';
    const ctxC  = r.ctx_pct>=80?'#f85149':r.ctx_pct>=50?'#d29922':'#58a6ff';
    const fendC = r.five_h_end>=80?'#f85149':r.five_h_end>=50?'#d29922':'#3fb950';
    const fdC   = r.five_h_delta>=20?'#f85149':r.five_h_delta>=10?'#d29922':'#39d3f7';
    return \`<tr>
      <td style="color:var(--muted)">\${r.date}</td>
      <td style="color:var(--muted)">\${r.time}</td>
      <td style="color:var(--cyan)">\${r.session_id}</td>
      <td>\${r.project}</td>
      <td><span class="pill \${cc}">\$\${r.cost.toFixed(3)}</span></td>
      <td style="color:var(--muted)">\${(r.input_tokens/1000).toFixed(0)}k</td>
      <td style="color:var(--muted)">\${(r.output_tokens/1000).toFixed(0)}k</td>
      <td>\${barHTML(r.ctx_pct,ctxC)}</td>
      <td>\${barHTML(r.five_h_end,fendC)}</td>
      <td>\${barHTML(r.five_h_delta,fdC)}</td>
      <td style="color:var(--muted)">\${r.model}</td>
    </tr>\`;
  }).join('');
}

// Auto-refresh cada 30s con countdown
let countdown = 30;
function tick() {
  countdown--;
  document.getElementById('refreshTimer').textContent = \`próx. actualización: \${countdown}s\`;
  if (countdown <= 0) { countdown = 30; fetchData(); }
}

fetchData();
setInterval(tick, 1000);
</script>
</body>
</html>`;
}

// ── HTTP server ────────────────────────────────────────────────────────────────

const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];

  if (url === '/api/data') {
    try {
      const data = { sessions: readLog(), active: readActiveSessions() };
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify(data));
    } catch (e) {
      res.writeHead(500); res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }

  if (url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(dashboardHTML());
    return;
  }

  res.writeHead(404); res.end('Not found');
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Claude Monitor corriendo en http://localhost:${PORT}`);
});

server.on('error', err => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Puerto ${PORT} ocupado. ¿Ya está corriendo?`);
    process.exit(1);
  }
  console.error(err);
});
