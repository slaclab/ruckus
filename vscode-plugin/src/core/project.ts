// Ruckus project model: evaluates a target's Makefile + ruckus.tcl tree and
// turns the scanner output into a structured, categorised model.

import * as cp from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import { expandedVars, MakeRule, parseMakefile, ParsedMakefile } from './makefile';

export type LoadKind = 'source' | 'constraint' | 'ip' | 'bd' | 'zip' | 'ncr';

export type Category =
    | 'vhdl' | 'verilog' | 'systemverilog' | 'header'
    | 'netlist' | 'memory' | 'constraint' | 'ip' | 'bd' | 'zip' | 'ncr'
    | 'software' | 'other';

export interface LoadedFile {
    path: string;
    kind: LoadKind;
    category: Category;
    lib: string;
    sim: boolean;
    fileType: string;
    via: 'path' | 'dir' | 'add_files' | 'related';
    node: number;          // id of the ruckus.tcl node that loaded it
    file: string;          // ruckus.tcl that issued the load
    line: number;
    origin: string;        // library / submodule name the file belongs to
    packages: string[];    // VHDL / SV packages declared in the file
}

export interface RuckusNode {
    id: number;
    dir: string;
    parent: number;
    children: RuckusNode[];
    files: LoadedFile[];
    problems: Problem[];
    callFile: string;
    callLine: number;
    origin: string;
}

export interface Problem {
    node: number;
    msg: string;
    severity: 'error' | 'warning';
    file: string;
    line: number;
}

export interface TopSetting { fileset: string; value: string; file: string; line: number; }

export interface MakeTargetInfo extends MakeRule {
    group: string;         // label of the makefile that defines it
}

export interface RuckusTarget {
    name: string;
    dir: string;           // PROJ_DIR
    makefile: string;
}

export interface RuckusProject {
    target: RuckusTarget;
    topDir: string;
    topDirReal: string;
    pathAliases: [string, string][];   // [resolved dir, display prefix] for symlinked submodules
    ruckusDir: string;
    modulesDir: string;
    backend: string;       // vivado, ghdl, vcs, ...
    part: string;
    arch: string;
    version: string;
    vars: Record<string, string>;
    make: ParsedMakefile;
    makeTargets: MakeTargetInfo[];
    root?: RuckusNode;
    nodes: Map<number, RuckusNode>;
    files: LoadedFile[];
    software: LoadedFile[];
    hooks: string[];
    tops: TopSetting[];
    problems: Problem[];
    origins: string[];
    scanLog: string;
    scanMs: number;
}

export interface ScanOptions {
    tclsh: string;
    scannerScript: string;
    extraEnv: Record<string, string>;
    vivadoVersion: string;
    timeoutMs: number;
}

const EXT_CATEGORY: Record<string, Category> = {
    '.vhd': 'vhdl', '.vhdl': 'vhdl',
    '.v': 'verilog',
    '.sv': 'systemverilog',
    '.vh': 'header', '.svh': 'header',
    '.dcp': 'netlist', '.edif': 'netlist', '.edf': 'netlist',
    '.mem': 'memory', '.coe': 'memory', '.dat': 'memory',
    '.xdc': 'constraint',
    '.xci': 'ip', '.xcix': 'ip',
    '.bd': 'bd',
    '.zip': 'zip',
    '.ncr': 'ncr',
    '.c': 'software', '.cc': 'software', '.cpp': 'software', '.cxx': 'software',
    '.h': 'software', '.hh': 'software', '.hpp': 'software', '.hxx': 'software',
};

export const SOFTWARE_EXTS = ['.c', '.cc', '.cpp', '.cxx', '.h', '.hh', '.hpp', '.hxx', '.ld', '.s', '.S'];

export function categorize(file: string, kind: LoadKind): Category {
    if (kind === 'constraint') { return 'constraint'; }
    if (kind === 'ip') { return 'ip'; }
    if (kind === 'bd') { return 'bd'; }
    if (kind === 'zip') { return 'zip'; }
    if (kind === 'ncr') { return 'ncr'; }
    return EXT_CATEGORY[path.extname(file).toLowerCase()] ?? 'other';
}

// ---------------------------------------------------------------------------
// Target discovery
// ---------------------------------------------------------------------------

const SYSTEM_MK_RE = /^\s*-?include\s+.*\bsystem_([a-z_]+)\.mk\b/m;

/** A ruckus target is a directory with a ruckus.tcl and a Makefile including ruckus' system_*.mk */
export function isRuckusTarget(dir: string): boolean {
    const mk = path.join(dir, 'Makefile');
    if (!fs.existsSync(path.join(dir, 'ruckus.tcl')) || !fs.existsSync(mk)) { return false; }
    try {
        return SYSTEM_MK_RE.test(fs.readFileSync(mk, 'utf8'));
    } catch {
        return false;
    }
}

export function makeTarget(dir: string): RuckusTarget {
    return { name: path.basename(dir), dir, makefile: path.join(dir, 'Makefile') };
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

export async function loadProject(target: RuckusTarget, opts: ScanOptions): Promise<RuckusProject> {
    const t0 = Date.now();
    const baseEnv: Record<string, string | undefined> = { ...process.env, ...opts.extraEnv };
    // Make's PWD is the directory make was invoked in
    baseEnv.PWD = target.dir;
    const make = parseMakefile(target.makefile, baseEnv);
    const vars = expandedVars(make);

    const exported = expandedVars(make, true);
    const backend = detectBackend(make);
    const topDir = vars.TOP_DIR || path.resolve(target.dir, '..', '..');
    const modulesDir = vars.MODULES || path.join(topDir, 'submodules');
    const ruckusDir = vars.RUCKUS_DIR || path.join(modulesDir, 'ruckus');

    const env: Record<string, string> = {};
    for (const [k, v] of Object.entries(baseEnv)) { if (v !== undefined) { env[k] = v; } }
    Object.assign(env, exported, opts.extraEnv);
    env.PROJECT ||= target.name;
    env.PROJ_DIR ||= target.dir;
    env.TOP_DIR ||= topDir;
    env.MODULES ||= modulesDir;
    env.RUCKUS_DIR ||= ruckusDir;
    env.RUCKUS_PROC_TCL ||= path.join(ruckusDir, backend === 'vivado' ? 'vivado' : backend, 'proc.tcl');
    if (!env.VIVADO_VERSION) { env.VIVADO_VERSION = backend === 'vivado' ? opts.vivadoVersion : '-1.0'; }
    if (!env.OUT_DIR) { env.OUT_DIR = path.join(topDir, 'build', target.name); }

    let topDirReal = topDir;
    try { topDirReal = fs.realpathSync(topDir); } catch { /* keep */ }
    const proj: RuckusProject = {
        target, topDir, topDirReal, pathAliases: submoduleAliases(modulesDir, topDir), ruckusDir, modulesDir, backend,
        part: env.PRJ_PART ?? '',
        arch: '',
        version: env.PRJ_VERSION ?? '',
        vars: { ...vars, ...pick(env, ['PROJECT', 'PROJ_DIR', 'TOP_DIR', 'MODULES', 'RUCKUS_DIR', 'OUT_DIR']) },
        make,
        makeTargets: collectMakeTargets(make, target, topDir, ruckusDir),
        nodes: new Map(),
        files: [],
        software: [],
        hooks: [],
        tops: [],
        problems: [],
        origins: [],
        scanLog: '',
        scanMs: 0,
    };

    const originOf = await buildOriginResolver(target.dir, topDir, modulesDir);

    const { stdout, stderr, error } = await runScanner(opts, target.dir, env);
    proj.scanLog = stderr;
    if (error) {
        proj.problems.push({ node: 0, msg: error, severity: 'error', file: path.join(target.dir, 'ruckus.tcl'), line: 0 });
    }
    parseScanOutput(proj, stdout, originOf);

    await findPackages(proj.files);
    proj.software = await findSoftware(proj, originOf);
    proj.hooks = findHooks(target.dir);
    proj.origins = orderOrigins([...new Set([...proj.files, ...proj.software].map(f => f.origin))]);
    proj.scanMs = Date.now() - t0;
    return proj;
}

function submoduleAliases(modulesDir: string, topDir: string): [string, string][] {
    const out: [string, string][] = [];
    try {
        for (const e of fs.readdirSync(modulesDir)) {
            const d = path.join(modulesDir, e);
            const real = fs.realpathSync(d);
            if (real !== d) { out.push([real, path.relative(topDir, d)]); }
        }
    } catch { /* none */ }
    return out;
}

function pick(o: Record<string, string>, keys: string[]): Record<string, string> {
    const r: Record<string, string> = {};
    for (const k of keys) { if (o[k] !== undefined) { r[k] = o[k]; } }
    return r;
}

function detectBackend(make: ParsedMakefile): string {
    for (const f of make.files) {
        const m = /system_([a-z_]+)\.mk$/.exec(f);
        if (m && m[1] !== 'shared') {
            return m[1] === 'synopsys_dc' || m[1] === 'cadence_genus' ? m[1] : m[1].split('_')[0];
        }
    }
    return 'vivado';
}

function runScanner(opts: ScanOptions, projDir: string, env: Record<string, string>):
    Promise<{ stdout: string; stderr: string; error?: string }> {
    return new Promise(resolve => {
        cp.execFile(opts.tclsh, [opts.scannerScript, projDir], {
            cwd: projDir, env, maxBuffer: 256 * 1024 * 1024, timeout: opts.timeoutMs,
        }, (err, stdout, stderr) => {
            let error: string | undefined;
            if (err) {
                const e = err as NodeJS.ErrnoException & { killed?: boolean };
                if (e.code === 'ENOENT') {
                    error = `Cannot run '${opts.tclsh}': Tcl shell not found. Install tclsh or set "ruckus.tclsh".`;
                } else if (e.killed) {
                    error = `ruckus.tcl scan timed out after ${opts.timeoutMs} ms`;
                } else if (!stdout.includes('"t":"done"')) {
                    error = `ruckus.tcl scan failed: ${String(stderr || err.message).trim().split('\n').slice(-5).join(' | ')}`;
                }
            }
            resolve({ stdout, stderr, error });
        });
    });
}

function parseScanOutput(proj: RuckusProject, stdout: string, originOf: (p: string) => string) {
    const seen = new Set<string>();
    for (const line of stdout.split('\n')) {
        if (!line.startsWith('{')) { continue; }
        let ev: Record<string, unknown>;
        try { ev = JSON.parse(line); } catch { continue; }
        switch (ev.t) {
            case 'start':
                proj.arch = String(ev.arch ?? '');
                break;
            case 'enter': {
                const node: RuckusNode = {
                    id: ev.id as number, dir: String(ev.dir), parent: ev.parent as number,
                    children: [], files: [], problems: [],
                    callFile: String(ev.file ?? ''), callLine: (ev.line as number) ?? 0,
                    origin: originOf(String(ev.dir)),
                };
                proj.nodes.set(node.id, node);
                const parent = proj.nodes.get(node.parent);
                if (parent) { parent.children.push(node); } else if (!proj.root) { proj.root = node; }
                break;
            }
            case 'file': {
                const p = String(ev.path);
                const sim = ev.sim === 1 || ev.sim === '1';
                // Like Vivado, a file already in the project is not added again
                if (seen.has(p)) { break; }
                seen.add(p);
                const kind = ev.kind as LoadKind;
                const f: LoadedFile = {
                    path: p, kind, category: categorize(p, kind),
                    lib: String(ev.lib ?? ''), sim, fileType: String(ev.fileType ?? ''),
                    via: ev.via as LoadedFile['via'], node: ev.node as number,
                    file: String(ev.file ?? ''), line: (ev.line as number) ?? 0,
                    origin: originOf(p), packages: [],
                };
                proj.files.push(f);
                proj.nodes.get(f.node)?.files.push(f);
                break;
            }
            case 'problem': {
                const pr: Problem = {
                    node: ev.node as number, msg: String(ev.msg), severity: ev.severity === 'warning' ? 'warning' : 'error',
                    file: String(ev.file ?? ''), line: (ev.line as number) ?? 0,
                };
                proj.problems.push(pr);
                proj.nodes.get(pr.node)?.problems.push(pr);
                break;
            }
            case 'top':
                proj.tops.push({ fileset: String(ev.fileset), value: String(ev.value), file: String(ev.file ?? ''), line: (ev.line as number) ?? 0 });
                break;
        }
    }
}

// ---------------------------------------------------------------------------
// Origins: which library (submodule / shared / target) a file belongs to
// ---------------------------------------------------------------------------

async function buildOriginResolver(projDir: string, topDir: string, modulesDir: string): Promise<(p: string) => string> {
    const roots: { dir: string; name: string }[] = [];
    const add = (dir: string, name: string) => {
        roots.push({ dir, name });
        try {
            const real = fs.realpathSync(dir);
            if (real !== dir) { roots.push({ dir: real, name }); }
        } catch { /* ignore */ }
    };
    add(projDir, 'target');
    try {
        for (const e of await fs.promises.readdir(modulesDir, { withFileTypes: true })) {
            if (e.isDirectory() || e.isSymbolicLink()) { add(path.join(modulesDir, e.name), e.name); }
        }
    } catch { /* no submodules dir */ }
    add(topDir, '');
    // Longest prefix wins
    roots.sort((a, b) => b.dir.length - a.dir.length);
    return (p: string) => {
        for (const r of roots) {
            if (p === r.dir || p.startsWith(r.dir + path.sep)) {
                if (r.name !== '') { return r.name; }
                const rel = path.relative(r.dir, p).split(path.sep);
                // Files borrowed from a sibling target: "targets/<name>"
                if (rel[0] === 'targets' && rel.length > 2) { return `targets/${rel[1]}`; }
                return rel.length > 1 ? rel[0] : 'project';
            }
        }
        return 'external';
    };
}

function orderOrigins(origins: string[]): string[] {
    const rank = (o: string) => o === 'target' ? 0 : o === 'external' ? 3 : o === 'ruckus' ? 2 : 1;
    return origins.sort((a, b) => rank(a) - rank(b) || a.localeCompare(b));
}

// ---------------------------------------------------------------------------
// Packages, software, hooks
// ---------------------------------------------------------------------------

const VHDL_PKG_RE = /^\s*package\s+(?!body\b)(\w+)\s+is\b/gim;
const SV_PKG_RE = /^\s*package\s+(?:automatic\s+|static\s+)?(\w+)\s*;/gm;

async function findPackages(files: LoadedFile[]) {
    const todo = files.filter(f => f.category === 'vhdl' || f.category === 'systemverilog' || f.category === 'header');
    await mapLimit(todo, 32, async f => {
        try {
            const text = await fs.promises.readFile(f.path, 'latin1');
            const re = f.category === 'vhdl' ? VHDL_PKG_RE : SV_PKG_RE;
            re.lastIndex = 0;
            let m: RegExpExecArray | null;
            while ((m = re.exec(text)) !== null) { f.packages.push(m[1]); }
        } catch { /* unreadable */ }
    });
}

/**
 * C/C++ files that belong to the build but are not loaded by ruckus.tcl:
 *  - VITIS_SRC_PATH / SDK_SRC_PATH (MicroBlaze / embedded software)
 *  - siblings of loaded HDL files (DPI-C / VHPI simulation models)
 */
async function findSoftware(proj: RuckusProject, originOf: (p: string) => string): Promise<LoadedFile[]> {
    const out: LoadedFile[] = [];
    const seen = new Set<string>();
    const push = (p: string, node: number, file: string, line: number, sim: boolean, lib: string) => {
        if (seen.has(p)) { return; }
        seen.add(p);
        out.push({
            path: p, kind: 'source', category: 'software', lib, sim, fileType: '', via: 'related',
            node, file, line, origin: originOf(p), packages: [],
        });
    };
    for (const v of ['VITIS_SRC_PATH', 'SDK_SRC_PATH']) {
        const dir = proj.vars[v];
        if (!dir) { continue; }
        const mv = proj.make.vars.get(v);
        for (const p of await walk(dir, 6)) {
            if (SOFTWARE_EXTS.includes(path.extname(p))) { push(p, 0, mv?.file ?? '', mv?.line ?? 0, false, 'embedded'); }
        }
    }
    const dirs = new Map<string, LoadedFile>();
    for (const f of proj.files) {
        if (f.kind === 'source' && !dirs.has(path.dirname(f.path))) { dirs.set(path.dirname(f.path), f); }
    }
    await mapLimit([...dirs.entries()], 32, async ([d, f]) => {
        try {
            for (const e of await fs.promises.readdir(d)) {
                if (SOFTWARE_EXTS.includes(path.extname(e))) {
                    push(path.join(d, e), f.node, f.file, f.line, f.sim, f.sim ? 'simulation' : 'related');
                }
            }
        } catch { /* ignore */ }
    });
    out.sort((a, b) => a.path.localeCompare(b.path));
    return out;
}

function findHooks(projDir: string): string[] {
    const d = path.join(projDir, 'vivado');
    try {
        return fs.readdirSync(d).filter(f => f.endsWith('.tcl')).sort().map(f => path.join(d, f));
    } catch {
        return [];
    }
}

async function walk(dir: string, depth: number): Promise<string[]> {
    const out: string[] = [];
    if (depth < 0) { return out; }
    let entries: fs.Dirent[];
    try { entries = await fs.promises.readdir(dir, { withFileTypes: true }); } catch { return out; }
    for (const e of entries) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) {
            if (!e.name.startsWith('.')) { out.push(...await walk(p, depth - 1)); }
        } else {
            out.push(p);
        }
    }
    return out;
}

async function mapLimit<T>(items: T[], limit: number, fn: (t: T) => Promise<void>) {
    let i = 0;
    const worker = async () => { while (i < items.length) { await fn(items[i++]); } };
    await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
}

// ---------------------------------------------------------------------------
// Make targets
// ---------------------------------------------------------------------------

/** Descriptions of the standard ruckus make targets (fallback when no comment is present) */
export const RUCKUS_TARGET_DOCS: Record<string, string> = {
    target: 'Default build (set by the project, usually bit/prom)',
    all: 'Default target (alias for "target")',
    test: 'Print the Makefile environment variables',
    dir: 'Create the build directory',
    sources: 'Create the Vivado project and load all sources',
    gui: 'Open the Vivado project in GUI mode',
    bit: 'Vivado batch build: .bit file',
    mcs: 'Vivado batch build: .bit + .mcs files',
    prom: 'Vivado batch build: .bit + PROM image',
    pdi: 'Vivado batch build: .pdi (Versal)',
    syn: 'Vivado synthesis only',
    dcp: 'Vivado synthesis to a design checkpoint (.dcp)',
    interactive: 'Vivado Tcl shell with the ruckus environment',
    sdk: 'Open the Xilinx SDK GUI',
    vitis: 'Open the Vitis GUI',
    elf: 'Build the embedded .elf and merge it into the .bit',
    release: 'Generate and push a firmware release to GitHub',
    release_files: 'Generate the firmware release files (no push)',
    pyrogue: 'Generate the pyrogue.tar.gz file',
    yaml: 'Generate the CPSW yaml (cpsw.tar.gz)',
    xsim: 'Vivado XSIM simulation (batch)',
    vcs: 'Generate the VCS simulation scripts',
    msim: 'ModelSim/Questa simulation',
    batch: 'Vivado batch mode inside the project environment',
    clean: 'Remove the build directory',
    build: 'Build every target (top-level Makefile)',
};

function collectMakeTargets(make: ParsedMakefile, target: RuckusTarget, topDir: string, ruckusDir: string): MakeTargetInfo[] {
    const label = (f: string) => {
        if (f === target.makefile) { return 'Target'; }
        if (f.startsWith(ruckusDir + path.sep)) { return `ruckus/${path.relative(ruckusDir, f)}`; }
        if (f.startsWith(topDir + path.sep)) { return path.relative(topDir, f); }
        return f;
    };
    const byName = new Map<string, MakeTargetInfo>();
    for (const r of make.rules) {
        // Later definitions only add prerequisites; keep the first one with a description
        const prev = byName.get(r.name);
        const desc = r.description && !/^[-=#*\s]*$/.test(r.description) ? r.description : undefined;
        if (prev) {
            if (!prev.description && desc) { prev.description = desc; }
            continue;
        }
        // ruckus' own Makefiles use section banners rather than per-target comments
        const fromRuckus = r.file.startsWith(ruckusDir + path.sep);
        const description = fromRuckus ? (RUCKUS_TARGET_DOCS[r.name] ?? desc) : (desc ?? RUCKUS_TARGET_DOCS[r.name]);
        byName.set(r.name, { ...r, description, group: label(r.file) });
    }
    return [...byName.values()];
}
