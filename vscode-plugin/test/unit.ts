// Unit tests (no VS Code, no Vivado; needs tclsh): node out/test/unit.js
// Fixtures: trimmed Vivado 2026.1 reports/logs of Simple-10GbE-RUDP-KCU105-Example
// (paths anonymized) and small ruckus.tcl trees.
import * as assert from 'assert';
import * as path from 'path';
import { parseSetupScript } from '../src/core/buildEnv';
import { loadProject, makeTarget } from '../src/core/project';
import { readLog } from '../src/core/reports/messages';
import { readTimingSummary } from '../src/core/reports/timing';
import { readUtilization } from '../src/core/reports/utilization';

const FIX = path.join(__dirname, '..', '..', 'test', 'fixtures');
const tests: [string, () => void | Promise<void>][] = [];
const test = (name: string, fn: () => void | Promise<void>) => tests.push([name, fn]);

test('timing summary', () => {
    const t = readTimingSummary(path.join(FIX, 'reports', 'timing_summary_routed.rpt'))!;
    assert.strictEqual(t.met, true);
    assert.match(t.verdict, /constraints are met/);
    assert.deepStrictEqual([t.summary.wns, t.summary.tnsTotal, t.summary.whs, t.summary.wpws, t.summary.tpwsTotal], [0.579, 150679, 0.004, 0.252, 53333]);
    assert.strictEqual(t.intra.length, 6);
    // Generated clocks keep their depth; empty cells stay undefined
    const tx = t.intra.find(c => c.name === 'txClockGt')!;
    assert.deepStrictEqual([tx.depth, tx.wns, tx.tnsTotal], [3, 1.227, 35773]);
    const gt = t.intra.find(c => c.name === 'rxoutclk_out[0]_1')!;
    assert.deepStrictEqual([gt.depth, gt.wns, gt.wpws], [2, undefined, 0.265]);
    assert.strictEqual(t.clocks.find(c => c.name === 'ethClkP')!.period, 6.4);
    assert.deepStrictEqual(t.other.map(o => o.group), ['**async_default**', '**async_default**', '**default**']);
    assert.deepStrictEqual(t.checks.filter(c => c.count).map(c => [c.name, c.count]),
        [['no_clock', 536], ['unconstrained_internal_endpoints', 1061], ['no_input_delay', 4], ['no_output_delay', 11]]);
    const p = t.paths[0];
    assert.deepStrictEqual([p.slack, p.violated, p.kind, p.requirement, p.fromClock, p.group], [0.579, false, 'Setup', 6.4, 'ethClkP', 'ethClkP']);
    assert.match(p.destination, /r_reg\[appSsiMaster\]\[data\]\[3\]\/D$/);
    assert.deepStrictEqual([t.paths[1].kind, t.paths[1].slack], ['Hold', 0.004]);
    // Unconstrained paths: slack "inf"
    const inf = t.paths.find(x => x.slack === undefined)!;
    assert.strictEqual(inf.group, '(none)');
});

test('utilization (flat)', () => {
    const u = readUtilization(path.join(FIX, 'reports', 'utilization_placed.rpt'))!;
    assert.strictEqual(u.stage, 'Fully Placed');
    assert.strictEqual(u.sections.length, 12);
    const luts = u.sections[0].rows[0];
    assert.deepStrictEqual([luts.name, luts.used, luts.available, luts.util, luts.depth], ['CLB LUTs', 35767, 242400, 14.76, 0]);
    const dram = u.sections[0].rows.find(r => r.name === 'LUT as Distributed RAM')!;
    assert.deepStrictEqual([dram.depth, dram.used, dram.available], [2, 954, undefined]);
    assert.ok(u.sections.find(s => s.title === 'BLOCKRAM')!.rows.length > 0);
    assert.strictEqual(u.sections.find(s => s.title === 'Black Boxes')!.rows.length, 0);
});

test('utilization (hierarchical)', () => {
    const h = readUtilization(path.join(FIX, 'reports', 'utilization_hierarchical.rpt'))!.hierarchy!;
    assert.deepStrictEqual(h.columns, ['Total LUTs', 'Logic LUTs', 'LUTRAMs', 'SRLs', 'FFs', 'RAMB36', 'RAMB18', 'URAM', 'DSP Blocks']);
    const top = h.roots[0];
    assert.deepStrictEqual([h.roots.length, top.instance, top.module, top.values[0], top.values[4], top.values[8]],
        [1, 'Simple10GbeRudpKcu105Example', '(top)', 35767, 51152, 22]);
    assert.deepStrictEqual(top.children.map(c => c.instance), ['(Simple10GbeRudpKcu105Example)', 'U_App', 'U_Core', 'dbg_hub', 'u_ila_0']);
    const app = top.children[1];
    assert.deepStrictEqual([app.module, app.children.map(c => c.instance)], ['App', ['(U_Mem)', 'U_AppTx', 'U_XBAR']]);
});

test('Vivado logs', () => {
    const synth = readLog(path.join(FIX, 'reports', 'synth_runme.txt'))!.messages;
    const w = synth.find(x => x.severity === 'warning')!;
    assert.deepStrictEqual([w.id, w.line, w.step, path.basename(w.file!)], ['Synth 8-6014', 500, 'synth_design', 'AxiLiteCrossbar.vhd']);
    assert.strictEqual(w.text, 'Unused sequential element r_reg[sAxiWriteSlaves][0][wready] was removed.');
    const impl = readLog(path.join(FIX, 'reports', 'impl_runme.txt'))!.messages;
    const count = (s: string) => impl.filter(x => x.severity === s).length;
    assert.deepStrictEqual([count('error'), count('critical'), count('warning')], [0, 10, 3]);
    assert.deepStrictEqual([...new Set(impl.map(x => x.step))], ['', 'open_checkpoint', 'opt_design']);
    assert.ok(impl.filter(x => x.severity === 'critical').every(x => x.step === 'opt_design'));
});

test('GHDL log: runtime report/assert severities', () => {
    const m = readLog(path.join(FIX, 'reports', 'ghdl_run.txt'))!.messages;
    assert.deepStrictEqual(m.map(x => [x.line, x.severity]), [[45, 'info'], [50, 'warning'], [55, 'error'], [12, 'error'], [13, 'warning']]);
    assert.strictEqual(m[2].text, 'broken');
});

test('setup script parsing', () => {
    const fixed = parseSetupScript(path.join(FIX, 'setup', 'fixed.sh'));
    assert.deepStrictEqual(fixed, { defaultVersion: '2026.1', installRoots: ['/opt/Xilinx'], takesVersionArg: false });
    const arg = parseSetupScript(path.join(FIX, 'setup', 'arg.sh'));
    assert.deepStrictEqual(arg, { defaultVersion: undefined, installRoots: ['/opt/Xilinx/Vivado'], takesVersionArg: true });
});

test('ruckus.tcl scan', async () => {
    process.env.RUCKUS_TEST_TOKEN = 'secret';
    const dir = path.join(FIX, 'scan', 'firmware', 'targets', 'Scan');
    const p = await loadProject(makeTarget(dir), {
        tclsh: process.env.TCLSH ?? 'tclsh', scannerScript: path.join(__dirname, '..', '..', 'resources', 'ruckus_scan.tcl'),
        extraEnv: {}, vivadoVersion: '2024.2', timeoutMs: 60000,
    });
    delete process.env.RUCKUS_TEST_TOKEN;
    const rel = (f: string) => path.relative(dir, f);
    const files = p.files.map(f => rel(f.path));
    // source -encoding works and a helper_proc.tcl under a "ruckus" path is not skipped
    assert.ok(files.includes('helper/Helper.vhd'), 'helper_proc.tcl sourced');
    // *TOKEN* variables are withheld like in system_shared.mk
    assert.ok(files.includes('tok/Tok_0.vhd') && !files.includes('tok/Tok_1.vhd'), 'TOKEN variable hidden');
    // clock format/scan work although unknown, package and source are stubbed
    assert.ok(files.includes('clock/Clock_1970.vhd'), 'clock format/scan');
    // exit aborts the rest of stop/ruckus.tcl and is reported, the parent continues
    assert.ok(!p.files.some(f => f.lib === 'never'), 'nothing loaded after exit');
    assert.ok(files.includes('sub/Sub.vhd'));
    const probs = p.problems.map(x => `${x.severity} ${rel(x.file)}:${x.line} ${x.msg}`);
    assert.ok(probs.some(x => x.startsWith('error stop/ruckus.tcl:1 exit -1')), probs.join('\n'));
    assert.ok(probs.some(x => x.startsWith('warning ruckus.tcl:3 loadSource: -dir "rtl" is relative')), probs.join('\n'));
    assert.strictEqual(probs.length, 2, probs.join('\n'));
});

(async () => {
    let failed = 0;
    for (const [name, fn] of tests) {
        try { await fn(); console.log(`ok   ${name}`); } catch (e) { failed++; console.log(`FAIL ${name}\n${e instanceof Error ? e.message : e}`); }
    }
    console.log(`${tests.length - failed}/${tests.length} passed`);
    process.exit(failed ? 1 : 0);
})();
