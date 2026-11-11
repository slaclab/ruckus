// Shared helpers of the report webviews (plain browser JS, no build step).
/* exported vscode, h, fmt, slackClass, persisted, onData, short, table, details */
'use strict';

const vscode = acquireVsCodeApi();

/** h('div.cls', {attrs}, ...children) -> element */
function h(tag, attrs, ...kids) {
    const [name, ...cls] = tag.split('.');
    const el = document.createElement(name || 'div');
    if (cls.length) { el.className = cls.join(' '); }
    if (attrs && (typeof attrs !== 'object' || attrs instanceof Node || Array.isArray(attrs))) { kids.unshift(attrs); attrs = undefined; }
    for (const [k, v] of Object.entries(attrs || {})) {
        if (v === undefined || v === null || v === false) { continue; }
        if (k.startsWith('on')) { el.addEventListener(k.slice(2), v); }
        else if (k === 'style' && typeof v === 'object') { Object.assign(el.style, v); }
        else if (k === 'class') { el.className += (el.className ? ' ' : '') + v; }
        else { el.setAttribute(k, v === true ? '' : v); }
    }
    for (const k of kids.flat(Infinity)) {
        if (k === undefined || k === null || k === false) { continue; }
        el.appendChild(k instanceof Node ? k : document.createTextNode(String(k)));
    }
    return el;
}

function fmt(v, digits = 3) {
    if (v === undefined || v === null) { return ''; }
    return typeof v === 'number' ? (Number.isInteger(v) && digits !== 3 ? String(v) : v.toFixed(digits)) : String(v);
}

function slackClass(v) {
    if (v === undefined || v === null) { return ''; }
    return v < 0 ? 'neg' : 'pos';
}

/** Last path components of a long hierarchical name, the full one in the tooltip */
function short(s, max = 60) {
    if (!s || s.length <= max) { return s || ''; }
    const parts = s.split('/');
    let out = parts.pop();
    while (parts.length && out.length + parts[parts.length - 1].length + 1 < max - 2) { out = parts.pop() + '/' + out; }
    return '…/' + out;
}

/** UI state kept across panel hide/show and reloads */
const persisted = {
    get(key, def) { const s = vscode.getState() || {}; return key in s ? s[key] : def; },
    set(key, v) { vscode.setState({ ...(vscode.getState() || {}), [key]: v }); },
};

function onData(render) {
    window.addEventListener('message', e => { if (e.data && e.data.type === 'data') { render(e.data); } });
    vscode.postMessage({ type: 'ready' });
}

function open(file, line) { vscode.postMessage({ type: 'open', file, line }); }

/** Table from column specs {title, get(row) -> cell|element, cls(row)} */
function table(cols, rows, opts = {}) {
    return h('table.grid', { class: opts.cls },
        h('thead', h('tr', cols.map(c => h('th', { title: c.tip, class: c.num ? 'num' : undefined }, c.title)))),
        h('tbody', rows.map(r => h('tr', { class: opts.rowCls ? opts.rowCls(r) : undefined, onclick: opts.onclick ? () => opts.onclick(r) : undefined },
            cols.map(c => {
                const v = c.get(r);
                return h('td', { class: [c.num ? 'num' : '', c.cls ? c.cls(r) : ''].join(' ').trim() || undefined, title: c.title_ ? c.title_(r) : undefined },
                    v instanceof Node ? v : fmt(v, c.digits));
            })))));
}

/** Collapsible section whose open state is persisted under key */
function details(key, summary, body, defOpen = true) {
    const d = h('details', { open: persisted.get(`open:${key}`, defOpen) }, h('summary', summary), body);
    d.addEventListener('toggle', () => persisted.set(`open:${key}`, d.open));
    return d;
}

function refreshButton() {
    return h('button.icon', { title: 'Reload', onclick: () => vscode.postMessage({ type: 'refresh' }) }, '⟳');
}

function ago(ms) {
    const s = (Date.now() - ms) / 1000;
    if (s < 90) { return 'just now'; }
    if (s < 5400) { return `${Math.round(s / 60)} min ago`; }
    if (s < 129600) { return `${Math.round(s / 3600)} h ago`; }
    return new Date(ms).toLocaleString();
}
