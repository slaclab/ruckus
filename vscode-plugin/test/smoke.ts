// Command-line smoke test of the project model (no VS Code needed):
//   node out/test/smoke.js <target dir>
import * as path from 'path';
import { loadProject, makeTarget } from '../src/core/project';

async function main() {
    const dir = path.resolve(process.argv[2] ?? '.');
    const proj = await loadProject(makeTarget(dir), {
        tclsh: process.env.TCLSH ?? 'tclsh',
        scannerScript: path.join(__dirname, '..', '..', 'resources', 'ruckus_scan.tcl'),
        extraEnv: {},
        vivadoVersion: '2024.2',
        timeoutMs: 60000,
    });
    const count = (pred: (c: string) => boolean) => proj.files.filter(f => pred(f.category)).length;
    console.log(`target   : ${proj.target.name} (${proj.backend})`);
    console.log(`part     : ${proj.part} arch=${proj.arch} version=${proj.version}`);
    console.log(`top dir  : ${proj.topDir}`);
    console.log(`nodes    : ${proj.nodes.size}, files: ${proj.files.length}, software: ${proj.software.length}`);
    console.log(`origins  : ${proj.origins.join(', ')}`);
    console.log(`hdl      : ${count(c => ['vhdl', 'verilog', 'systemverilog', 'header'].includes(c))}`);
    console.log(`xdc/ip   : ${count(c => c === 'constraint')} / ${count(c => c === 'ip')}`);
    console.log(`packages : ${proj.files.reduce((n, f) => n + f.packages.length, 0)}`);
    console.log(`tops     : ${proj.tops.map(t => `${t.fileset}=${t.value}`).join(', ')}`);
    console.log(`hooks    : ${proj.hooks.map(h => path.basename(h)).join(', ')}`);
    console.log(`problems : ${proj.problems.length}`);
    for (const p of proj.problems) { console.log(`   [${p.severity}] ${p.msg} (${p.file}:${p.line})`); }
    console.log(`make     : ${proj.makeTargets.map(t => t.name).join(' ')}`);
    console.log(`default  : ${proj.make.defaultGoal}`);
    console.log(`time     : ${proj.scanMs} ms`);
    for (const t of proj.makeTargets.slice(0, 40)) {
        console.log(`   ${t.name.padEnd(14)} ${t.group.padEnd(28)} ${t.description ?? ''}`);
    }
    if (process.argv.includes('--errors')) { console.log(proj.make.errors.join('\n')); }
}

main().catch(e => { console.error(e); process.exit(1); });
