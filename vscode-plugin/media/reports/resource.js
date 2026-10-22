// "Resources" view: report_utilization of the synthesized / implemented design,
// and the hierarchical utilization when it has been generated.
/* global h, fmt, persisted, onData, open, table, details, refreshButton, ago, vscode */
'use strict';

let state = { tab: persisted.get('tab', 'impl'), expanded: persisted.get('expanded', {}), hierQuery: persisted.get('hierQuery', '') };
function save() { for (const k of Object.keys(state)) { persisted.set(k, state[k]); } }

let model;
function render(msg) { model = msg; draw(); }

// 100% of a 1-of-1 site (DNA_PORT, STARTUPE2) is normal: only over-utilization is an error
function meterClass(u) { return u > 100 ? 'full' : u >= 80 ? 'high' : ''; }

function draw() {
    const app = document.getElementById('app');
    app.textContent = '';
    if (!model || !model.project) { app.append(h('p.muted', 'No ruckus top level selected.')); return; }
    const d = model.data || {};
    if (d.error) { app.append(h('p.neg', d.error)); return; }
    const tabs = [['impl', 'Implementation', d.impl], ['synth', 'Synthesis', d.synth], ['hier', 'Hierarchy', d.hier]];
    if (!tabs.some(t => t[0] === state.tab && (t[2] || t[0] === 'hier'))) { state.tab = d.impl ? 'impl' : d.synth ? 'synth' : 'hier'; }
    const rep = state.tab === 'hier' ? d.hier : d[state.tab];
    app.append(h('div.toolbar',
        h('div.tabs', tabs.map(([id, label, r]) => h('button.toggle', {
            class: state.tab === id ? 'on' : undefined, disabled: !r && id !== 'hier', 'aria-pressed': String(state.tab === id),
            title: r ? `${r.file}\n${ago(r.mtime)}` : id === 'hier' ? 'Utilization per instance' : 'Not available yet',
            onclick: () => { state.tab = id; save(); draw(); },
        }, label))),
        rep ? h('a', { href: '#', title: rep.file, onclick: e => { e.preventDefault(); open(rep.file, 1); } }, rep.file.split('/').pop()) : null,
        rep ? h('span.muted', `${rep.header.Device || ''} · ${rep.stage || ''} · ${ago(rep.mtime)}`) : null,
        h('span.spacer'), refreshButton()));
    if (!d.vivado) { app.append(h('p.muted', `Utilization reports are only available for Vivado targets (${model.project.name} uses ${model.project.backend}).`)); return; }
    if (state.tab === 'hier') { drawHier(app, d); return; }
    if (!rep) { app.append(h('p.muted', 'No utilization report yet: run make syn or make bit.')); return; }
    drawFlat(app, rep);
}

/** Headline resources: top-level rows with an "Available" count */
function drawFlat(app, rep) {
    const head = [];
    const seen = new Set();
    for (const s of rep.sections) {
        for (const r of s.rows) {
            if (r.depth === 0 && r.available > 0 && r.used !== undefined && !seen.has(r.name)) {
                seen.add(r.name);
                if (r.used > 0 || /LUT|Register|RAM|DSP|IOB|BUFG/i.test(r.name)) { head.push(r); }
            }
        }
    }
    head.sort((a, b) => (b.util || 0) - (a.util || 0));
    const top = head.filter(r => r.used > 0);
    app.append(h('div.meters', top.map(r => {
        const u = r.util !== undefined ? r.util : 100 * r.used / r.available;
        return [
            h('span', r.name),
            h('div.meter', { class: meterClass(u), title: `${fmt(r.used, 0)} / ${fmt(r.available, 0)}` }, h('div', { style: { width: `${Math.min(100, Math.max(u, u > 0 ? 0.8 : 0))}%` } })),
            h('span', { class: u > 100 ? 'neg' : undefined, style: { textAlign: 'right' } }, `${u < 0.01 ? '<0.01' : u.toFixed(2)}%`, u > 100 ? ' ⨯' : ''),
            h('span.muted', `${fmt(r.used, 0)} / ${fmt(r.available, 0)}`),
        ];
    })));
    for (const s of rep.sections) {
        if (!s.rows.length) { continue; }
        const cols = s.header.map((t, i) => ({
            title: t, num: i > 0 && s.rows.some(r => /^[<\d.\- ]+$/.test(r.cells[i] || '') && r.cells[i]),
            get: r => (i === 0 ? h('span', { style: { paddingLeft: `${r.depth * 14}px` } }, r.cells[0]) : r.cells[i]),
            cls: r => (i === 0 && r.depth === 0 ? '' : i > 0 && /util/i.test(t) && Number(r.cells[i]) > 100 ? 'neg' : ''),
        }));
        const sec = details(`flat:${s.title}`, `${s.title} (${s.rows.length})`, table(cols, s.rows), false);
        sec.className = 'sec';
        app.append(sec);
    }
}

function drawHier(app, d) {
    const ck = d.checkpoint;
    const stale = d.hier && ck && ck.mtime > d.hier.mtime;
    const gen = h('button', { class: d.hier ? undefined : 'primary', disabled: !ck, onclick: () => vscode.postMessage({ type: 'generateHier' }) },
        d.hier ? 'Regenerate' : 'Generate hierarchical utilization');
    app.append(h('p', { class: 'muted' }, gen, ' ',
        ck ? `Runs Vivado in batch mode on ${ck.name} (${ago(ck.mtime)}): report_utilization -hierarchical.` :
            'Needs an implemented design (impl_1 routed checkpoint): run make bit first.',
        stale ? h('span.neg', ' The report is older than the checkpoint.') : ''));
    if (!d.hier || !d.hier.hierarchy) { return; }
    const { columns, roots } = d.hier.hierarchy;
    const totals = roots[0] ? roots[0].values : [];
    const q = state.hierQuery.trim().toLowerCase();
    const search = h('input', {
        type: 'search', placeholder: 'Find instance / module', value: state.hierQuery,
        oninput: e => { state.hierQuery = e.target.value; save(); clearTimeout(search._t); search._t = setTimeout(draw, 200); },
    });
    app.append(h('div', { style: { display: 'flex', gap: '6px', alignItems: 'center' } }, search,
        h('button', { onclick: () => { state.expanded = {}; save(); draw(); } }, 'Collapse all'),
        h('span.muted', 'Bars: share of the design total. Click a row to expand.')));

    const matchesDeep = n => !q || `${n.instance} ${n.module}`.toLowerCase().includes(q) || n.children.some(matchesDeep);
    const tbody = h('tbody');
    const walk = (n, path, depth) => {
        if (!matchesDeep(n)) { return; }
        const key = path;
        const hasKids = n.children.length > 0;
        const isOpen = q ? true : (key in state.expanded ? state.expanded[key] : depth < 1);
        const self = /^\(.*\)$/.test(n.instance);
        tbody.append(h('tr', {
            onclick: hasKids ? () => { state.expanded[key] = !isOpen; save(); draw(); } : undefined,
        },
        h('td.inst', { style: { paddingLeft: `${4 + depth * 14}px` }, title: path },
            h('span.tw', hasKids ? (isOpen ? '▾' : '▸') : ''), h('span', { class: self ? 'dim' : undefined }, n.instance)),
        h('td.dim', n.module),
        n.values.map((v, i) => {
            const share = totals[i] ? (v || 0) / totals[i] : 0;
            return h('td.num.cellbar', { title: totals[i] ? `${(100 * share).toFixed(1)}% of ${columns[i]}` : undefined },
                v === undefined ? '' : fmt(v, 0), share > 0 ? h('i', { style: { width: `${Math.max(2, 100 * share)}%` } }) : null);
        })));
        if (isOpen) { for (const c of n.children) { walk(c, `${path}/${c.instance}`, depth + 1); } }
    };
    for (const r of roots) { walk(r, r.instance, 0); }
    app.append(h('table.tree', h('thead', h('tr', h('th', 'Instance'), h('th', 'Module'), columns.map(c => h('th.num', c)))), tbody));
}

onData(render);
