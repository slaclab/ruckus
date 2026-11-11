// Prints the design hierarchy of a target from the command line:
//   node out/test/hierarchy.js <target dir> [depth] [--sim] [--procs]
import * as path from 'path';
import { Design } from '../src/core/hdl/elaborate';
import { HdlItem } from '../src/core/hdl/types';
import { LoadedFile, loadProject, makeTarget } from '../src/core/project';

async function main() {
    const dir = path.resolve(process.argv[2] ?? '.');
    const depth = parseInt(process.argv[3] ?? '3', 10);
    const sim = process.argv.includes('--sim');
    const procs = process.argv.includes('--procs');
    const proj = await loadProject(makeTarget(dir), {
        tclsh: 'tclsh', scannerScript: path.join(__dirname, '..', '..', 'resources', 'ruckus_scan.tcl'),
        extraEnv: {}, vivadoVersion: '2024.2', timeoutMs: 60000,
    });
    const d = new Design(proj);
    const stats = { inst: 0, unresolved: new Map<string, number>() };
    const print = (items: HdlItem[], ctx: LoadedFile, ind: string, lvl: number) => {
        for (const it of items) {
            if (it.t === 'proc') {
                if (procs) { console.log(`${ind}~ ${it.label || '(process)'} ${it.kind} ${it.desc}`); }
                continue;
            }
            if (it.t === 'gen') {
                console.log(`${ind}[${it.label || it.kind}] ${it.cond}`);
                print(it.items, ctx, ind + '  ', lvl);
                continue;
            }
            stats.inst++;
            const r = d.resolve(it, ctx, sim);
            let tag: string = r.t;
            if (r.t === 'unit') { tag = `${r.unit.file.lib || 'work'}:${path.basename(r.unit.file.path)}`; }
            if (r.t === 'unresolved') { stats.unresolved.set(it.ref, (stats.unresolved.get(it.ref) ?? 0) + 1); }
            console.log(`${ind}${it.label} : ${it.refLib ? it.refLib + '.' : ''}${it.ref}  <${tag}>  @${it.line}`);
            if (r.t === 'unit' && lvl < depth) {
                const b = d.body(r.unit, r.arch);
                print(b.items, b.file, ind + '  ', lvl + 1);
            }
        }
    };
    console.log(`parsed in ${d.parseMs} ms, ${d.allUnits().length} units, errors=${d.errors.length}`);
    for (const t of d.tops()) {
        if (sim !== (t.fileset === 'sim_1')) { continue; }
        console.log(`TOP ${t.fileset}: ${t.name} ${t.unit ? path.basename(t.unit.file.path) : '(not found)'}`);
        if (t.unit) { const b = d.body(t.unit); print(b.items, b.file, '  ', 1); }
    }
    console.log(`instances=${stats.inst} unresolved=${JSON.stringify([...stats.unresolved])}`);
}
main().catch(e => { console.error(e); process.exit(1); });
