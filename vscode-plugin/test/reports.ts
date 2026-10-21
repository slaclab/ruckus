// Command-line test of the report parsers (no VS Code needed):
//   node out/test/reports.js <timing.rpt> <utilization.rpt> [<hier.rpt>] [<log>...]
import { readLog } from '../src/core/reports/messages';
import { readTimingSummary } from '../src/core/reports/timing';
import { readUtilization } from '../src/core/reports/utilization';

const [timing, util, hier, ...logs] = process.argv.slice(2);
if (timing) {
    const t0 = Date.now();
    const t = readTimingSummary(timing)!;
    console.log(`timing   : ${Date.now() - t0} ms, met=${t.met} "${t.verdict}"`);
    console.log(`summary  : ${JSON.stringify(t.summary)}`);
    console.log(`clocks   : ${t.clocks.length} intra: ${t.intra.length} inter: ${t.inter.length} other: ${t.other.length} paths: ${t.paths.length} checks: ${t.checks.length}`);
    for (const c of t.intra.slice(0, 6)) { console.log(`   ${'  '.repeat(c.depth)}${c.name.slice(-30)} wns=${c.wns} whs=${c.whs} wpws=${c.wpws} tot=${c.tnsTotal}`); }
    for (const c of t.other.slice(0, 3)) { console.log(`   ${c.group} ${c.from.slice(-20)} -> ${c.to.slice(-20)} wns=${c.wns} whs=${c.whs}`); }
    const p = t.paths[0];
    console.log(`path0    : ${JSON.stringify({ ...p, source: p.source.slice(-40), destination: p.destination.slice(-40), fromClock: p.fromClock.slice(-20), toClock: p.toClock.slice(-20) })}`);
    for (const c of t.checks.filter(c => c.count)) { console.log(`   check ${c.name} (${c.count}): ${c.detail.split('\n')[0]}`); }
}
if (util) {
    const u = readUtilization(util)!;
    console.log(`util     : stage=${u.stage} sections=${u.sections.map(s => `${s.title}(${s.rows.length})`).join(', ')}`);
    for (const r of u.sections[0].rows.slice(0, 5)) { console.log(`   ${'  '.repeat(r.depth)}${r.name} used=${r.used} avail=${r.available} util=${r.util}`); }
}
if (hier) {
    const h = readUtilization(hier)!;
    const n = h.hierarchy!.roots[0];
    console.log(`hier     : cols=${h.hierarchy!.columns.join('|')}`);
    console.log(`   ${n.instance} (${n.module}) ${n.values.join(',')} children=${n.children.map(c => c.instance).join(',')}`);
    const c = n.children[1];
    console.log(`   ${c.instance} (${c.module}) children=${c.children.map(x => x.instance).join(',')}`);
}
for (const l of logs) {
    const t0 = Date.now();
    const m = readLog(l)!;
    const c: Record<string, number> = {};
    for (const x of m.messages) { c[x.severity] = (c[x.severity] ?? 0) + 1; }
    console.log(`log      : ${l.split('/').slice(-2).join('/')} ${Date.now() - t0} ms ${JSON.stringify(c)} steps=${[...new Set(m.messages.map(x => x.step))].join(',')}`);
    console.log(`   ${JSON.stringify(m.messages.find(x => x.file))}`);
}
