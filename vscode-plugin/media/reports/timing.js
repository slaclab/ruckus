// "Timing" view: report_timing_summary of the implemented design.
/* global h, fmt, slackClass, persisted, onData, open, short, table, details, refreshButton, ago */
'use strict';

let state = { onlyFailing: persisted.get('onlyFailing', false), pathKind: persisted.get('pathKind', 'all'), pathQuery: persisted.get('pathQuery', '') };

function save() { for (const k of Object.keys(state)) { persisted.set(k, state[k]); } }

let model;
function render(msg) { model = msg; draw(); }

const ns = v => (v === undefined || v === null ? '' : `${v.toFixed(3)} ns`);

function tile(title, worst, total, failing, endpoints, worstLabel, totalLabel) {
    const bad = (worst !== undefined && worst < 0) || (failing || 0) > 0;
    return h('div.tile', { class: bad ? 'bad' : undefined },
        h('h4', title),
        h('div.big', { class: slackClass(worst) }, worst === undefined ? 'n/a' : ns(worst), bad ? ' ⨯' : worst !== undefined ? ' ✓' : ''),
        h('div.kv',
            h('span', worstLabel), h('span', { class: slackClass(worst) }, ns(worst)),
            h('span', totalLabel), h('span', { class: total < 0 ? 'neg' : undefined }, ns(total)),
            h('span', 'Failing endpoints'), h('span', { class: failing > 0 ? 'neg' : undefined }, fmt(failing, 0)),
            h('span', 'Total endpoints'), h('span', fmt(endpoints, 0))));
}

function slackCols(withTns) {
    const c = (title, key, tip) => ({ title, num: true, get: r => r[key], cls: r => slackClass(r[key]), tip });
    const n = (title, key, tip) => ({ title, num: true, get: r => r[key], digits: 0, cls: r => (r[key] > 0 ? 'neg' : 'dim'), tip });
    const cols = [c('WNS', 'wns', 'Worst negative slack (setup), ns'), c('TNS', 'tns', 'Total negative slack (setup), ns'), n('Fail', 'tnsFailing', 'Failing setup endpoints'),
        { title: 'Endp.', num: true, digits: 0, get: r => r.tnsTotal, cls: () => 'dim', tip: 'Setup endpoints' },
        c('WHS', 'whs', 'Worst hold slack, ns'), c('THS', 'ths', 'Total hold slack, ns'), n('Fail', 'thsFailing', 'Failing hold endpoints')];
    if (withTns) { cols.push(c('WPWS', 'wpws', 'Worst pulse width slack, ns'), c('TPWS', 'tpws', 'Total pulse width slack, ns'), n('Fail', 'tpwsFailing', 'Failing pulse width endpoints')); }
    return cols;
}

const isBad = r => [r.wns, r.tns, r.whs, r.ths, r.wpws, r.tpws].some(v => v !== undefined && v < 0) || r.tnsFailing > 0 || r.thsFailing > 0 || r.tpwsFailing > 0;

function draw() {
    const app = document.getElementById('app');
    app.textContent = '';
    if (!model || !model.project) { app.append(h('p.muted', 'No ruckus top level selected.')); return; }
    const r = model.data && model.data.report;
    const bar = h('div.toolbar',
        r ? h('span', { title: r.file }, h('a', { href: '#', onclick: e => { e.preventDefault(); open(r.file, 1); } }, r.file.split('/').pop())) : null,
        r ? h('span.muted', `${r.header.Design || ''} · ${r.header.Device || ''} · ${r.header['Tool Version'] ? r.header['Tool Version'].replace(/^Vivado v\.(\S+).*/, 'Vivado $1') : ''} · ${ago(r.mtime)}`) : null,
        h('span.spacer'),
        h('label', h('input', { type: 'checkbox', checked: state.onlyFailing, onchange: e => { state.onlyFailing = e.target.checked; save(); draw(); } }), ' Only failing'),
        refreshButton());
    app.append(bar);
    if (model.data && model.data.error) { app.append(h('p.neg', model.data.error)); return; }
    if (!r) {
        app.append(h('p.muted', model.project.backend === 'vivado' ?
            `No timing summary yet: run make bit (impl_1/<top>_timing_summary_routed.rpt is read).` :
            `Timing reports are only available for Vivado targets (${model.project.name} uses ${model.project.backend}).`));
        return;
    }
    const s = r.summary;
    app.append(h('div.banner', { class: r.met ? 'ok' : 'bad' }, r.met ? '✓ ' : '⨯ ', r.verdict || (r.met ? 'Timing met' : 'Timing not met')));
    app.append(h('div.tiles',
        tile('Setup', s.wns, s.tns, s.tnsFailing, s.tnsTotal, 'WNS', 'TNS'),
        tile('Hold', s.whs, s.ths, s.thsFailing, s.thsTotal, 'WHS', 'THS'),
        tile('Pulse Width', s.wpws, s.tpws, s.tpwsFailing, s.tpwsTotal, 'WPWS', 'TPWS')));

    // check_timing: only the checks that found something
    const checks = r.checks.filter(c => c.count > 0);
    if (checks.length) {
        app.append(details('checks', h('span', `Check Timing (${checks.length} issue${checks.length > 1 ? 's' : ''})`), table([
            { title: 'Check', get: c => c.name },
            { title: 'Count', num: true, digits: 0, get: c => c.count },
            { title: 'Description', get: c => c.detail.split('\n')[0], cls: c => (/\(HIGH\)/.test(c.detail) ? 'neg' : '') },
        ], checks), false));
        app.lastChild.className = 'sec';
    }

    // Intra-clock table, with generated clocks indented below their master
    const intra = state.onlyFailing ? r.intra.filter(isBad) : r.intra;
    const clockOf = new Map(r.clocks.map(c => [c.name, c]));
    const failingClocks = r.intra.filter(isBad).length;
    const intraTable = table([
        { title: 'Clock', get: c => h('span', { style: { paddingLeft: `${c.depth * 14}px` }, title: c.name }, short(c.name)) },
        { title: 'Period', num: true, get: c => clockOf.get(c.name) && clockOf.get(c.name).period, tip: 'ns' },
        { title: 'MHz', num: true, get: c => clockOf.get(c.name) && clockOf.get(c.name).freq },
        ...slackCols(true),
    ], intra, { rowCls: c => (isBad(c) ? 'bad' : undefined) });
    const ds = details('intra', h('span', `Intra-Clock (${r.intra.length} clocks`, failingClocks ? h('span.neg', `, ${failingClocks} failing`) : '', ')'), intra.length ? intraTable : h('p.muted', 'No failing clocks.'));
    ds.className = 'sec';
    app.append(ds);

    const pairCols = (withGroup) => [
        ...(withGroup ? [{ title: 'Path Group', get: c => c.group }] : []),
        { title: 'From', get: c => h('span', { title: c.from }, short(c.from, 40)) },
        { title: 'To', get: c => h('span', { title: c.to }, short(c.to, 40)) },
        ...slackCols(false),
    ];
    for (const [key, title, rows, g] of [['inter', 'Inter-Clock', r.inter, false], ['other', 'Other Path Groups', r.other, true]]) {
        if (!rows.length) { continue; }
        const shown = state.onlyFailing ? rows.filter(isBad) : rows;
        const bad = rows.filter(isBad).length;
        const d = details(key, h('span', `${title} (${rows.length}`, bad ? h('span.neg', `, ${bad} failing`) : '', ')'),
            shown.length ? table(pairCols(g), shown, { rowCls: c => (isBad(c) ? 'bad' : undefined) }) : h('p.muted', 'No failing paths.'), bad > 0);
        d.className = 'sec';
        app.append(d);
    }

    app.append(pathsSection(r));
}

function pathsSection(r) {
    const kinds = [...new Set(r.paths.map(p => p.kind).filter(Boolean))];
    const q = state.pathQuery.trim().toLowerCase();
    let paths = r.paths.filter(p => p.slack !== undefined && p.slack !== null);
    if (state.pathKind !== 'all') { paths = paths.filter(p => p.kind === state.pathKind); }
    if (state.onlyFailing) { paths = paths.filter(p => p.violated); }
    if (q) { paths = paths.filter(p => `${p.source} ${p.destination} ${p.fromClock} ${p.toClock} ${p.group}`.toLowerCase().includes(q)); }
    paths.sort((a, b) => a.slack - b.slack);
    const violated = r.paths.filter(p => p.violated).length;
    const LIMIT = 300;
    const search = h('input', {
        type: 'search', placeholder: 'Filter cells / clocks', value: state.pathQuery,
        oninput: e => { state.pathQuery = e.target.value; save(); clearTimeout(search._t); search._t = setTimeout(draw, 200); },
    });
    const body = h('div',
        h('div', { style: { display: 'flex', gap: '6px', margin: '4px 0' } },
            h('select', { onchange: e => { state.pathKind = e.target.value; save(); draw(); } },
                h('option', { value: 'all', selected: state.pathKind === 'all' }, 'All checks'),
                kinds.map(k => h('option', { value: k, selected: state.pathKind === k }, k))),
            search,
            h('span.muted', `${paths.length} path${paths.length === 1 ? '' : 's'}${paths.length > LIMIT ? ` (worst ${LIMIT} shown)` : ''} · report lists the worst ${r.header.Command && /-max_paths (\d+)/.test(r.header.Command) ? RegExp.$1 : 'N'} per clock pair`)),
        paths.length ? table([
            { title: 'Slack', num: true, get: p => p.slack, cls: p => slackClass(p.slack) },
            { title: 'Check', get: p => p.kind },
            { title: 'Source', get: p => h('span', { title: p.source }, short(p.source, 50)) },
            { title: 'Destination', get: p => h('span', { title: p.destination }, short(p.destination, 50)) },
            { title: 'Clocks', get: p => h('span', { title: `${p.fromClock} → ${p.toClock}` }, p.fromClock === p.toClock ? short(p.fromClock, 24) : `${short(p.fromClock, 20)} → ${short(p.toClock, 20)}`) },
            { title: 'Req.', num: true, get: p => p.requirement, tip: 'Requirement, ns' },
            { title: 'Data', num: true, get: p => p.dataDelay, tip: 'Data path delay, ns' },
            { title: 'Skew', num: true, get: p => p.skew, tip: 'Clock path skew, ns' },
            { title: 'Levels', get: p => p.logicLevels },
        ], paths.slice(0, LIMIT), { cls: 'click', rowCls: p => (p.violated ? 'bad' : undefined), onclick: p => open(r.file, p.line) })
            : h('p.muted', state.onlyFailing ? 'No violated paths.' : 'No paths.'));
    const d = details('paths', h('span', `Worst Paths (${r.paths.length}`, violated ? h('span.neg', `, ${violated} violated`) : '', ')'), body, violated > 0);
    d.className = 'sec';
    return d;
}

onData(render);
