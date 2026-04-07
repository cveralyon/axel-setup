#!/usr/bin/env bash
# session-dashboard-gen.sh
# Generates a self-contained HTML dashboard from session-costs.log
# Usage: bash ~/.claude/session-dashboard-gen.sh [--open]

LOG_FILE="$HOME/.claude/session-costs.log"
OUT_FILE="$HOME/.claude/session-dashboard.html"
OPEN_AFTER="${1:-}"

if [ ! -f "$LOG_FILE" ]; then
  echo "No hay datos todavía en $LOG_FILE"
  exit 1
fi

# Convert CSV to JSON array
JSON_DATA=$(tail -n +2 "$LOG_FILE" | awk -F',' '
NF >= 10 {
  gsub(/"/, "\\\"", $4)
  gsub(/"/, "\\\"", $11)
  printf "{\"date\":\"%s\",\"time\":\"%s\",\"session_id\":\"%s\",\"project\":\"%s\",\"cost\":%s,\"input_tokens\":%s,\"output_tokens\":%s,\"ctx_pct\":%s,\"five_h_end\":%s,\"five_h_delta\":%s,\"model\":\"%s\"}",
    $1,$2,$3,$4,
    ($5+0),($6+0),($7+0),($8+0),($9+0),($10+0),
    ($11 == "" ? "unknown" : $11)
  printf ","
}' | sed 's/,$//')

GENERATED_AT=$(date '+%Y-%m-%d %H:%M:%S')

cat > "$OUT_FILE" << HTMLEOF
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Claude Code — Usage Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
  :root {
    --bg: #0d1117; --bg2: #161b22; --bg3: #21262d;
    --border: #30363d; --text: #e6edf3; --muted: #7d8590;
    --cyan: #39d3f7; --green: #3fb950; --yellow: #d29922;
    --red: #f85149; --purple: #bc8cff; --orange: #f0883e;
    --blue: #58a6ff;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: 'SF Mono', 'Fira Code', monospace; font-size: 13px; }
  .header { background: var(--bg2); border-bottom: 1px solid var(--border); padding: 16px 24px; display: flex; justify-content: space-between; align-items: center; }
  .header h1 { font-size: 16px; color: var(--cyan); font-weight: 600; }
  .header .meta { color: var(--muted); font-size: 11px; }
  .container { max-width: 1400px; margin: 0 auto; padding: 24px; }
  .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin-bottom: 24px; }
  .card { background: var(--bg2); border: 1px solid var(--border); border-radius: 8px; padding: 16px; }
  .card .label { color: var(--muted); font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px; }
  .card .value { font-size: 24px; font-weight: 700; }
  .card .sub { color: var(--muted); font-size: 11px; margin-top: 4px; }
  .charts { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 24px; }
  .charts.full { grid-template-columns: 1fr; }
  .chart-box { background: var(--bg2); border: 1px solid var(--border); border-radius: 8px; padding: 16px; }
  .chart-box h3 { font-size: 12px; color: var(--muted); margin-bottom: 12px; text-transform: uppercase; letter-spacing: 0.5px; }
  .chart-box canvas { max-height: 240px; }
  .table-box { background: var(--bg2); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; margin-bottom: 24px; }
  .table-header { padding: 12px 16px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
  .table-header h3 { font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.5px; }
  .filters { display: flex; gap: 8px; }
  .filters input, .filters select { background: var(--bg3); border: 1px solid var(--border); color: var(--text); padding: 4px 8px; border-radius: 4px; font-family: inherit; font-size: 12px; outline: none; }
  table { width: 100%; border-collapse: collapse; }
  th { padding: 8px 12px; text-align: left; color: var(--muted); font-size: 11px; font-weight: 500; border-bottom: 1px solid var(--border); cursor: pointer; user-select: none; white-space: nowrap; }
  th:hover { color: var(--text); }
  td { padding: 8px 12px; border-bottom: 1px solid var(--border); white-space: nowrap; }
  tr:last-child td { border-bottom: none; }
  tr:hover td { background: var(--bg3); }
  .pill { display: inline-block; padding: 2px 8px; border-radius: 99px; font-size: 11px; font-weight: 600; }
  .pill-green { background: rgba(63,185,80,.15); color: var(--green); }
  .pill-yellow { background: rgba(210,153,34,.15); color: var(--yellow); }
  .pill-red { background: rgba(248,81,73,.15); color: var(--red); }
  .bar-mini { display: inline-block; height: 6px; border-radius: 3px; vertical-align: middle; }
  .text-muted { color: var(--muted); }
  .text-cyan { color: var(--cyan); }
  .text-green { color: var(--green); }
  .text-yellow { color: var(--yellow); }
  .text-red { color: var(--red); }
  @media (max-width: 900px) { .charts { grid-template-columns: 1fr; } }
</style>
</head>
<body>

<div class="header">
  <h1>⚡ Claude Code — Usage Dashboard</h1>
  <div class="meta">generado: $GENERATED_AT &nbsp;|&nbsp; <a href="#" onclick="location.reload()" style="color:var(--cyan);text-decoration:none">regenerar</a></div>
</div>

<div class="container">

  <!-- Cards -->
  <div class="cards" id="cards"></div>

  <!-- Charts row 1 -->
  <div class="charts">
    <div class="chart-box">
      <h3>Costo por día (últimos 30 días)</h3>
      <canvas id="chartCostByDay"></canvas>
    </div>
    <div class="chart-box">
      <h3>% límite de 5h consumido — por sesión (últimas 30)</h3>
      <canvas id="chartFiveH"></canvas>
    </div>
  </div>

  <!-- Charts row 2 -->
  <div class="charts">
    <div class="chart-box">
      <h3>Tokens por día (in + out, miles)</h3>
      <canvas id="chartTokens"></canvas>
    </div>
    <div class="chart-box">
      <h3>Sesiones por proyecto</h3>
      <canvas id="chartProjects"></canvas>
    </div>
  </div>

  <!-- Table -->
  <div class="table-box">
    <div class="table-header">
      <h3>Todas las sesiones</h3>
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
    <table id="sessionsTable">
      <thead>
        <tr>
          <th onclick="sortTable('date')">Fecha ↕</th>
          <th onclick="sortTable('time')">Hora ↕</th>
          <th>Session</th>
          <th onclick="sortTable('project')">Proyecto ↕</th>
          <th onclick="sortTable('cost')">Costo ↕</th>
          <th onclick="sortTable('input_tokens')">In-tok ↕</th>
          <th onclick="sortTable('output_tokens')">Out-tok ↕</th>
          <th onclick="sortTable('ctx_pct')">Ctx% ↕</th>
          <th onclick="sortTable('five_h_end')">5h-acum ↕</th>
          <th onclick="sortTable('five_h_delta')">5h-sesión ↕</th>
          <th>Modelo</th>
        </tr>
      </thead>
      <tbody id="tableBody"></tbody>
    </table>
  </div>

</div>

<script>
const RAW = [${JSON_DATA}];
let sortKey = 'date', sortDir = -1;

const TODAY = new Date().toISOString().slice(0,10);
const WEEK_AGO = new Date(Date.now() - 7*24*3600*1000).toISOString().slice(0,10);
const MONTH_AGO = new Date(Date.now() - 30*24*3600*1000).toISOString().slice(0,10);

Chart.defaults.color = '#7d8590';
Chart.defaults.borderColor = '#30363d';
Chart.defaults.font.family = "'SF Mono', 'Fira Code', monospace";
Chart.defaults.font.size = 11;

function filteredData() {
  const period = document.getElementById('filterPeriod').value;
  const text = document.getElementById('filterText').value.toLowerCase();
  return RAW.filter(r => {
    if (period === 'today' && r.date !== TODAY) return false;
    if (period === 'week' && r.date < WEEK_AGO) return false;
    if (period === 'month' && r.date < MONTH_AGO) return false;
    if (text && !JSON.stringify(r).toLowerCase().includes(text)) return false;
    return true;
  });
}

function sortTable(key) {
  if (sortKey === key) sortDir *= -1; else { sortKey = key; sortDir = -1; }
  renderTable();
}

function costPill(cost) {
  if (cost > 1) return \`<span class="pill pill-red">\$\${cost.toFixed(3)}</span>\`;
  if (cost > 0.3) return \`<span class="pill pill-yellow">\$\${cost.toFixed(3)}</span>\`;
  return \`<span class="pill pill-green">\$\${cost.toFixed(3)}</span>\`;
}

function miniBar(pct, color) {
  const w = Math.min(pct, 100);
  return \`<span class="bar-mini" style="width:\${w}px;background:\${color}"></span> \${pct.toFixed(1)}%\`;
}

function fiveHColor(pct) {
  if (pct >= 20) return '#f85149';
  if (pct >= 10) return '#d29922';
  return '#39d3f7';
}

function renderTable() {
  const data = filteredData().sort((a,b) => {
    let av = a[sortKey], bv = b[sortKey];
    if (typeof av === 'string') return sortDir * av.localeCompare(bv);
    return sortDir * (av - bv);
  });

  const tbody = document.getElementById('tableBody');
  if (!data.length) { tbody.innerHTML = '<tr><td colspan="11" style="text-align:center;color:var(--muted);padding:24px">Sin datos</td></tr>'; return; }

  tbody.innerHTML = data.map(r => \`
    <tr>
      <td class="text-muted">\${r.date}</td>
      <td class="text-muted">\${r.time}</td>
      <td class="text-cyan">\${r.session_id}</td>
      <td>\${r.project}</td>
      <td>\${costPill(r.cost)}</td>
      <td class="text-muted">\${(r.input_tokens/1000).toFixed(0)}k</td>
      <td class="text-muted">\${(r.output_tokens/1000).toFixed(0)}k</td>
      <td>\${miniBar(r.ctx_pct, '#58a6ff')}</td>
      <td>\${miniBar(r.five_h_end, r.five_h_end >= 80 ? '#f85149' : r.five_h_end >= 50 ? '#d29922' : '#3fb950')}</td>
      <td>\${miniBar(r.five_h_delta, fiveHColor(r.five_h_delta))}</td>
      <td class="text-muted">\${r.model}</td>
    </tr>
  \`).join('');
}

function renderCards() {
  const data = RAW;
  const totalCost = data.reduce((s,r) => s+r.cost, 0);
  const totalSess = data.length;
  const totalTok = data.reduce((s,r) => s+r.input_tokens+r.output_tokens, 0);
  const total5h = data.reduce((s,r) => s+r.five_h_delta, 0);
  const todayData = data.filter(r => r.date === TODAY);
  const todayCost = todayData.reduce((s,r) => s+r.cost, 0);
  const avg5h = totalSess > 0 ? total5h/totalSess : 0;

  document.getElementById('cards').innerHTML = \`
    <div class="card">
      <div class="label">Costo total</div>
      <div class="value text-yellow">\$\${totalCost.toFixed(3)}</div>
      <div class="sub">en \${totalSess} sesiones</div>
    </div>
    <div class="card">
      <div class="label">Hoy</div>
      <div class="value text-green">\$\${todayCost.toFixed(3)}</div>
      <div class="sub">\${todayData.length} sesión(es)</div>
    </div>
    <div class="card">
      <div class="label">Tokens totales</div>
      <div class="value text-cyan">\${(totalTok/1000).toFixed(0)}k</div>
      <div class="sub">\${(totalTok/totalSess/1000).toFixed(0)}k promedio/ses</div>
    </div>
    <div class="card">
      <div class="label">5h consumido total</div>
      <div class="value \${total5h > 100 ? 'text-red' : total5h > 50 ? 'text-yellow' : 'text-green'}">\${total5h.toFixed(1)}%</div>
      <div class="sub">\${avg5h.toFixed(1)}% promedio/sesión</div>
    </div>
    <div class="card">
      <div class="label">Sesiones esta semana</div>
      <div class="value text-purple">\${data.filter(r=>r.date>=WEEK_AGO).length}</div>
      <div class="sub">\$\${data.filter(r=>r.date>=WEEK_AGO).reduce((s,r)=>s+r.cost,0).toFixed(3)} esta semana</div>
    </div>
  \`;
}

function groupBy(data, key, val, agg='sum') {
  const m = {};
  data.forEach(r => {
    const k = r[key];
    if (!m[k]) m[k] = 0;
    m[k] += r[val];
  });
  return m;
}

function renderCharts() {
  const last30days = RAW.filter(r => r.date >= new Date(Date.now()-30*24*3600*1000).toISOString().slice(0,10));
  const byDay = groupBy(last30days, 'date', 'cost');
  const dayLabels = Object.keys(byDay).sort();

  // Cost by day
  new Chart(document.getElementById('chartCostByDay'), {
    type: 'bar',
    data: {
      labels: dayLabels,
      datasets: [{
        label: 'Costo USD',
        data: dayLabels.map(d => byDay[d]),
        backgroundColor: 'rgba(57,211,247,0.3)',
        borderColor: '#39d3f7',
        borderWidth: 1,
        borderRadius: 3,
      }]
    },
    options: { plugins: { legend: { display: false } }, scales: { x: { ticks: { maxRotation: 45 } } } }
  });

  // 5h delta per session (last 30)
  const last30 = RAW.slice(-30);
  new Chart(document.getElementById('chartFiveH'), {
    type: 'bar',
    data: {
      labels: last30.map(r => r.date.slice(5)+' '+r.time),
      datasets: [{
        label: '% 5h esta sesión',
        data: last30.map(r => r.five_h_delta),
        backgroundColor: last30.map(r => r.five_h_delta >= 20 ? 'rgba(248,81,73,0.4)' : r.five_h_delta >= 10 ? 'rgba(210,153,34,0.4)' : 'rgba(57,211,247,0.3)'),
        borderColor: last30.map(r => r.five_h_delta >= 20 ? '#f85149' : r.five_h_delta >= 10 ? '#d29922' : '#39d3f7'),
        borderWidth: 1,
        borderRadius: 3,
      }]
    },
    options: { plugins: { legend: { display: false } }, scales: { x: { ticks: { maxRotation: 45, maxTicksLimit: 15 } }, y: { title: { display: true, text: '%' } } } }
  });

  // Tokens by day
  const tokByDay = {};
  last30days.forEach(r => {
    if (!tokByDay[r.date]) tokByDay[r.date] = { in: 0, out: 0 };
    tokByDay[r.date].in += r.input_tokens / 1000;
    tokByDay[r.date].out += r.output_tokens / 1000;
  });
  new Chart(document.getElementById('chartTokens'), {
    type: 'bar',
    data: {
      labels: dayLabels,
      datasets: [
        { label: 'Input', data: dayLabels.map(d => tokByDay[d]?.in || 0), backgroundColor: 'rgba(88,166,255,0.4)', borderColor: '#58a6ff', borderWidth: 1, borderRadius: 3 },
        { label: 'Output', data: dayLabels.map(d => tokByDay[d]?.out || 0), backgroundColor: 'rgba(188,140,255,0.4)', borderColor: '#bc8cff', borderWidth: 1, borderRadius: 3 },
      ]
    },
    options: { plugins: { legend: { position: 'top' } }, scales: { x: { stacked: true, ticks: { maxRotation: 45 } }, y: { stacked: true, title: { display: true, text: 'k tokens' } } } }
  });

  // Sessions by project (donut)
  const byProj = {};
  RAW.forEach(r => { byProj[r.project] = (byProj[r.project]||0) + 1; });
  const projLabels = Object.keys(byProj).sort((a,b) => byProj[b]-byProj[a]).slice(0,10);
  const palette = ['#39d3f7','#3fb950','#d29922','#f85149','#bc8cff','#f0883e','#58a6ff','#7d8590','#56d364','#e3b341'];
  new Chart(document.getElementById('chartProjects'), {
    type: 'doughnut',
    data: {
      labels: projLabels,
      datasets: [{ data: projLabels.map(p => byProj[p]), backgroundColor: palette.map(c => c+'99'), borderColor: palette, borderWidth: 2 }]
    },
    options: { plugins: { legend: { position: 'right', labels: { boxWidth: 12 } } }, cutout: '60%' }
  });
}

// Init
renderCards();
renderCharts();
renderTable();
</script>
</body>
</html>
HTMLEOF

echo "Dashboard generado: $OUT_FILE"

# Open in browser if requested
if [ "$OPEN_AFTER" = "--open" ] || [ "$OPEN_AFTER" = "-o" ]; then
  open "$OUT_FILE"
  echo "Abriendo en el browser..."
fi
