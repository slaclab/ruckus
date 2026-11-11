// Where a ruckus build leaves its logs and reports (no VS Code dependency).

import * as fs from 'fs';
import * as path from 'path';
import { RuckusProject } from '../project';

export interface BuildDirs { outDir: string; synDir: string; implDir: string; makeLogs: string; }

export function buildDirs(p: RuckusProject): BuildDirs {
    const outDir = p.vars.OUT_DIR || path.join(p.topDir, 'build', p.target.name);
    const prj = p.vars.VIVADO_PROJECT || `${p.vars.PROJECT || p.target.name}_project`;
    return {
        outDir,
        synDir: p.vars.SYN_DIR || path.join(outDir, `${prj}.runs`, 'synth_1'),
        implDir: p.vars.IMPL_DIR || path.join(outDir, `${prj}.runs`, 'impl_1'),
        makeLogs: path.join(p.topDir, 'build', 'logs'),
    };
}

function mtime(f: string): number {
    try { return fs.statSync(f).mtimeMs; } catch { return 0; }
}

/** Newest file of dir whose name matches re */
function newest(dir: string, re: RegExp): string | undefined {
    let names: string[] = [];
    try { names = fs.readdirSync(dir); } catch { return undefined; }
    const hits = names.filter(n => re.test(n)).map(n => path.join(dir, n));
    return hits.sort((a, b) => mtime(b) - mtime(a))[0];
}

export interface LogSource { id: string; label: string; file: string; mtime: number; defaultOn: boolean; }

/** Logs the "log report" can show, most relevant first */
export function logSources(p: RuckusProject): LogSource[] {
    const d = buildDirs(p);
    const out: LogSource[] = [];
    const add = (id: string, label: string, file: string | undefined, defaultOn: boolean) => {
        if (!file) { return; }
        const m = mtime(file);
        if (m) { out.push({ id, label, file, mtime: m, defaultOn }); }
    };
    if (p.backend === 'vivado') {
        add('vivado', 'Project (vivado.log)', path.join(d.outDir, 'vivado.log'), true);
        add('synth', 'Synthesis (synth_1)', path.join(d.synDir, 'runme.log'), true);
        add('impl', 'Implementation (impl_1)', path.join(d.implDir, 'runme.log'), true);
        // Out-of-context IP runs: <ip>_synth_1/runme.log
        const runs = path.dirname(d.synDir);
        let names: string[] = [];
        try { names = fs.readdirSync(runs); } catch { /* not built */ }
        for (const n of names.filter(x => /_synth_\d+$/.test(x) && x !== path.basename(d.synDir)).sort()) {
            add(`ooc:${n}`, `IP ${n.replace(/_synth_\d+$/, '')}`, path.join(runs, n, 'runme.log'), false);
        }
        for (const sim of ['xsim', 'vcs', 'msim']) {
            add(`make:${sim}`, `make ${sim}`, path.join(d.makeLogs, `${p.target.name}_${sim}.log`), false);
        }
    } else {
        // Other backends: the make output saved by the extension's tasks
        let names: string[] = [];
        try { names = fs.readdirSync(d.makeLogs); } catch { /* none */ }
        const mine = names.filter(n => n.startsWith(`${p.target.name}_`) && n.endsWith('.log'))
            .map(n => path.join(d.makeLogs, n)).sort((a, b) => mtime(b) - mtime(a));
        mine.forEach((f, i) => add(`make:${path.basename(f)}`, `make ${path.basename(f, '.log').slice(p.target.name.length + 1)}`, f, i === 0));
    }
    return out;
}

export function timingReportFile(p: RuckusProject): string | undefined {
    const d = buildDirs(p);
    return newest(d.implDir, /_timing_summary_(postroute_physopted|routed)\.rpt$/) ??
        newest(d.implDir, /_timing_summary_\w+\.rpt$/);
}

export interface UtilFiles { synth?: string; impl?: string; hier?: string; }

/** Hierarchical utilization report written by "Generate Hierarchical Utilization" (or by hand) */
export function hierUtilFile(p: RuckusProject): string {
    return path.join(buildDirs(p).outDir, `${p.vars.PROJECT || p.target.name}_utilization_hierarchical.rpt`);
}

export function utilizationFiles(p: RuckusProject): UtilFiles {
    const d = buildDirs(p);
    const hier = hierUtilFile(p);
    return {
        synth: newest(d.synDir, /_utilization_synth\.rpt$/),
        impl: newest(d.implDir, /_utilization_placed\.rpt$/),
        hier: mtime(hier) ? hier : undefined,
    };
}

/** Routed (or latest) checkpoint of impl_1, input of the hierarchical report */
export function routedCheckpoint(p: RuckusProject): string | undefined {
    const d = buildDirs(p);
    return newest(d.implDir, /_(postroute_physopt|routed)\.dcp$/) ?? newest(d.implDir, /_placed\.dcp$/);
}
