// "Log Report" view: Vivado-like Messages window over the build logs.
/* global h, persisted, onData, open, refreshButton, ago, vscode */
'use strict';

const SEV = [
    { label: 'Errors', one: 'Error', icon: '⨯', def: true },
    { label: 'Critical Warnings', one: 'Critical Warning', icon: '!', def: true },
    { label: 'Warnings', one: 'Warning', icon: '⚠', def: true },
    { label: 'Info', one: 'Info', icon: 'i', def: false },
];
const PAGE = 200;

let state = {
    sev: persisted.get('sev', SEV.map(s => s.def)),
    sources: persisted.get('sources', null),      // {id: bool}; null = defaults
    query: persisted.get('query', ''),
    groupBy: persisted.get('groupBy', 'id'),
};
let model;

function save() { for (const k of Object.keys(state)) { persisted.set(k, state[k]); } }

function sourceOn(s) {
    if (state.sources && s.id in state.sources) { return state.sources[s.id]; }
    return s.defaultOn;
}

function render(msg) {
    model = msg;
    draw();
}

function matches(m, q) {
    if (!q) { return true; }
    const hay = `${m[1]} ${m[2]} ${m[3]}`.toLowerCase();
    return q.split(/\s+/).every(w => w.startsWith('-') ? w.length === 1 || !hay.includes(w.slice(1)) : hay.includes(w));
}

function draw() {
    const app = document.getElementById('app');
    app.textContent = '';
    if (!model || !model.project) { app.append(h('p.muted', 'No ruckus top level selected.')); return; }
    const sources = (model.data && model.data.sources) || [];
    const q = state.query.trim().toLowerCase();
    const counts = [0, 0, 0, 0];
    const shown = [];
    for (const s of sources) {
        if (!sourceOn(s)) { continue; }
        for (const m of s.messages) {
            if (m[0] > 3 || !matches(m, q)) { continue; }
            counts[m[0]]++;
            if (state.sev[m[0]]) { shown.push({ m, s }); }
        }
    }

    const search = h('input', {
        type: 'search', placeholder: 'Filter (words, -exclude)', value: state.query,
        oninput: e => { state.query = e.target.value; save(); clearTimeout(search._t); search._t = setTimeout(draw, 150); },
    });
    const bar = h('div.toolbar',
        SEV.map((s, i) => h('button.toggle', {
            class: state.sev[i] ? 'on' : undefined, title: `Show ${s.label.toLowerCase()}`, 'aria-pressed': String(state.sev[i]),
            onclick: () => { state.sev[i] = !state.sev[i]; save(); draw(); },
        }, h(`span.sev.sev${i}`, s.icon), ` ${s.label} `, h('span.count', String(counts[i])))),
        search,
        h('select', { title: 'Group by', onchange: e => { state.groupBy = e.target.value; save(); draw(); } },
            [['id', 'Group by message ID'], ['step', 'Group by step'], ['file', 'Group by source file'], ['none', 'No grouping']]
                .map(([v, l]) => h('option', { value: v, selected: state.groupBy === v }, l))),
        sourcePicker(sources),
        h('span.spacer'),
        refreshButton(),
    );
    app.append(bar);
    if (!sources.length) {
        app.append(h('p.muted', `No build logs yet for ${model.project.name}. Run `, h('code', 'make bit'), ' / ', h('code', 'make syn'),
            model.project.backend === 'vivado' ? ' (vivado.log and the synth_1 / impl_1 runme.log are read).' : ' from the Make Targets view (its output is saved to build/logs).'));
        return;
    }
    if (!shown.length) { app.append(h('p.muted', 'No messages match the current selection.')); return; }
    const list = h('div.list');
    if (state.groupBy === 'none') {
        appendMessages(list, shown, 0);
    } else {
        const groups = new Map();
        for (const x of shown) {
            const key = state.groupBy === 'id' ? `${x.m[0]}|${x.m[1]}` : state.groupBy === 'step' ? (x.s.label + (x.m[6] ? ` › ${x.m[6]}` : '')) : (x.m[3] || '(no source file)');
            if (!groups.has(key)) { groups.set(key, []); }
            groups.get(key).push(x);
        }
        let entries = [...groups];
        if (state.groupBy === 'id' || state.groupBy === 'file') {
            // Most severe first, then most frequent
            const worst = g => Math.min(...g.map(x => x.m[0]));
            entries.sort((a, b) => worst(a[1]) - worst(b[1]) || b[1].length - a[1].length || a[0].localeCompare(b[0]));
        }
        for (const [key, items] of entries) { list.append(group(key, items)); }
    }
    app.append(list);
}

function sourcePicker(sources) {
    const on = sources.filter(sourceOn).length;
    const d = h('details.srcpick', { style: { position: 'relative' } },
        h('summary', { class: 'muted', style: { cursor: 'pointer' } }, `Logs ${on}/${sources.length}`),
        h('div', { style: { position: 'absolute', zIndex: 3, padding: '6px', minWidth: '320px', background: 'var(--vscode-editorWidget-background)', border: '1px solid var(--vscode-editorWidget-border)' } },
            sources.map(s => h('label', { style: { display: 'block', whiteSpace: 'nowrap' }, title: s.file },
                h('input', {
                    type: 'checkbox', checked: sourceOn(s),
                    onchange: e => { state.sources = { ...(state.sources || {}), [s.id]: e.target.checked }; save(); draw(); },
                }),
                ` ${s.label} `, h('span.muted', `(${s.messages.filter(m => m[0] <= 3).length}, ${ago(s.mtime)})`), ' ',
                h('a', { href: '#', title: 'Open log', onclick: e => { e.preventDefault(); open(s.file, 1); } }, '↗')))));
    return d;
}

function group(key, items) {
    const worst = Math.min(...items.map(x => x.m[0]));
    let head;
    if (state.groupBy === 'id') {
        const id = items[0].m[1];
        head = [h(`span.sev.sev${worst}`, SEV[worst].icon), h('span.gid', id ? `[${id}]` : SEV[worst].one), h('span.count.muted', `(${items.length}) `), items[0].m[2]];
    } else {
        head = [h(`span.sev.sev${worst}`, SEV[worst].icon), h('span.gid', key), h('span.count.muted', `(${items.length})`)];
    }
    const openKey = `g:${state.groupBy}:${key}`;
    const d = h('details.group', { open: persisted.get(openKey, false) }, h('summary', { title: key }, head));
    let filled = false;
    const fill = () => { if (!filled && d.open) { filled = true; appendMessages(d, items, 0); } };
    d.addEventListener('toggle', () => { persisted.set(openKey, d.open); fill(); });
    fill();
    return d;
}

function appendMessages(parent, items, from) {
    const end = Math.min(items.length, from + PAGE);
    for (let i = from; i < end; i++) { parent.append(row(items[i])); }
    if (end < items.length) {
        const more = h('div.more', h('button', { onclick: () => { more.remove(); appendMessages(parent, items, end); } }, `Show ${Math.min(PAGE, items.length - end)} more (${items.length - end} left)`));
        parent.append(more);
    }
}

function row({ m, s }) {
    const [sev, id, text, file, line, logLine] = m;
    const base = file ? file.split('/').pop() : '';
    const showId = state.groupBy !== 'id' && id;
    return h('div.msg', {
        title: `${SEV[sev].one}${id ? ` [${id}]` : ''}\n${file ? `${file}:${line}\n` : ''}${s.file}:${logLine}\nClick: open source (or log). Alt+click: open the log line.`,
        onclick: e => { if (file && !e.altKey) { open(file, line); } else { open(s.file, logLine); } },
    },
    h(`span.sev.sev${sev}`, { 'aria-label': SEV[sev].one }, SEV[sev].icon),
    showId ? h('span.dim', `[${id}]`) : null,
    h('span.text', text),
    base ? h('span.loc', `${base}:${line}`) : h('span.src', `${s.label}:${logLine}`));
}

onData(render);
void vscode;
