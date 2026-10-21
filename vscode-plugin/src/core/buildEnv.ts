// Build environment helpers (no VS Code dependency): locating the firmware
// setup script (e.g. setup_env_slac.sh), the Vivado versions it can select,
// and the log files produced by a build.

import * as fs from 'fs';
import * as path from 'path';

export interface SetupScriptInfo {
    /** VIVADO_VERSION the script uses when called without arguments */
    defaultVersion?: string;
    /** Directories containing one sub-directory per Vivado version (from `.../$VIVADO_VERSION/...` paths) */
    installRoots: string[];
    /** The script reads its first argument ($1), so the selected version is passed to it */
    takesVersionArg: boolean;
}

const VERSION_RE = /^\d{4}\.\d+$/;

/** Looks for setup_env_slac.sh (or another setup_env*.sh) in dir and up to `levels` parents */
export function findSetupScript(dir: string, levels = 3): string | undefined {
    let d = dir;
    for (let i = 0; i <= levels; i++) {
        let names: string[] = [];
        try { names = fs.readdirSync(d); } catch { /* unreadable */ }
        const hits = names.filter(n => /^setup_env.*\.sh$/.test(n)).sort((a, b) =>
            Number(b === 'setup_env_slac.sh') - Number(a === 'setup_env_slac.sh') || a.localeCompare(b));
        if (hits.length) { return path.join(d, hits[0]); }
        const up = path.dirname(d);
        if (up === d) { break; }
        d = up;
    }
    return undefined;
}

export function parseSetupScript(file: string): SetupScriptInfo {
    let text = '';
    try { text = fs.readFileSync(file, 'utf8'); } catch { return { installRoots: [], takesVersionArg: false }; }
    const lines = text.split('\n').filter(l => !/^\s*#/.test(l));
    let defaultVersion: string | undefined;
    const roots = new Set<string>();
    for (const l of lines) {
        const m = /^\s*(?:export\s+)?VIVADO_VERSION=["']?(\d{4}\.\d+)/.exec(l);
        if (m && !defaultVersion) { defaultVersion = m[1]; }
        const p = /(\/[^\s"'$;]*\/)\$\{?VIVADO_VERSION\}?/.exec(l);
        if (p) { roots.add(p[1].replace(/\/+$/, '')); }
        // Hard-coded install: source /.../xilinx/2026.1/Vivado/2026.1/settings64.sh
        const s = /(\/[^\s"'$;]*)\/settings64\.sh/.exec(l);
        const parts = s ? s[1].split('/') : [];
        const i = parts.findIndex(x => VERSION_RE.test(x));
        if (i > 0) {
            if (!defaultVersion) { defaultVersion = parts[i]; }
            roots.add(parts.slice(0, i).join('/'));
        }
    }
    const takesVersionArg = lines.some(l => /\$\{?1\b|\$@|\$\*/.test(l));
    return { defaultVersion, installRoots: [...roots], takesVersionArg };
}

const COMMON_ROOTS = ['/opt/Xilinx/Vivado', '/tools/Xilinx/Vivado', '/opt/Xilinx', '/tools/Xilinx'];

/** Vivado versions installed under the given roots (newest first) */
export function listVivadoVersions(roots: string[]): string[] {
    const found = new Set<string>();
    for (const r of [...roots, ...COMMON_ROOTS]) {
        let names: string[] = [];
        try { names = fs.readdirSync(r); } catch { continue; }
        for (const n of names) { if (VERSION_RE.test(n)) { found.add(n); } }
    }
    return [...found].sort(compareVersions);
}

export function compareVersions(a: string, b: string): number {
    const [a1, a2] = a.split('.').map(Number);
    const [b1, b2] = b.split('.').map(Number);
    return b1 - a1 || b2 - a2;
}

export interface LogFile { file: string; mtime: number; size: number }

/** *.log files below dir (bounded walk), most recently modified first */
export function findLogs(dir: string, maxDepth = 6, limit = 60): LogFile[] {
    const out: LogFile[] = [];
    let visited = 0;
    const walk = (d: string, depth: number) => {
        if (visited++ > 5000) { return; }
        let ents: fs.Dirent[] = [];
        try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
        for (const e of ents) {
            const p = path.join(d, e.name);
            if (e.isDirectory()) {
                // Vivado caches and generated IP output hold thousands of irrelevant files
                if (depth < maxDepth && !/^\.Xil$|\.(cache|ip_user_files|gen|hw)$/.test(e.name)) { walk(p, depth + 1); }
            } else if (e.name.endsWith('.log')) {
                try {
                    const st = fs.statSync(p);
                    out.push({ file: p, mtime: st.mtimeMs, size: st.size });
                } catch { /* vanished */ }
            }
        }
    };
    walk(dir, 0);
    return out.sort((a, b) => b.mtime - a.mtime).slice(0, limit);
}

/**
 * Vivado installation directory ($XILINX_VIVADO: the one holding data/vhdl/src).
 * Tried in order: explicit setting, the environment, the settings64.sh sourced by
 * the setup script, then <install root>/<version> layouts.
 */
export function findVivadoInstall(explicit: string, setupScript: string | undefined, version: string): string | undefined {
    const ok = (d: string | undefined) => !!d && fs.existsSync(path.join(d, 'data', 'vhdl', 'src', 'unisims'));
    if (explicit) { return ok(explicit) ? explicit : undefined; }
    if (ok(process.env.XILINX_VIVADO)) { return process.env.XILINX_VIVADO; }
    const cands: string[] = [];
    const roots: string[] = [];
    let defVersion: string | undefined;
    if (setupScript) {
        const info = parseSetupScript(setupScript);
        defVersion = info.defaultVersion;
        roots.push(...info.installRoots);
        let text = '';
        try { text = fs.readFileSync(setupScript, 'utf8'); } catch { /* unreadable */ }
        for (const l of text.split('\n').filter(x => !/^\s*#/.test(x))) {
            const m = /(\/[^\s"';]*)\/settings64\.sh/.exec(l);
            if (m) { cands.push(m[1].replace(/\$\{?VIVADO_VERSION\}?/g, version || defVersion || '')); }
        }
    }
    const v = version || defVersion;
    for (const r of [...roots, ...COMMON_ROOTS]) {
        const vs = v ? [v] : listVivadoVersions([r]);
        for (const x of vs) {
            cands.push(path.join(r, x), path.join(r, x, 'Vivado'), path.join(r, 'Vivado', x), path.join(r, x, 'Vivado', x));
        }
    }
    return cands.find(ok);
}

/** vhdl_ls.toml library entries for the Vivado simulation libraries (component declarations + primitives) */
export function vivadoVhdlLibraries(vivado: string): Record<string, string[]> {
    const src = path.join(vivado, 'data', 'vhdl', 'src');
    const libs: Record<string, string[]> = {};
    const add = (lib: string, files: string[]) => {
        const f = files.filter(x => x.includes('*') ? fs.existsSync(path.dirname(x)) : fs.existsSync(x));
        if (f.length) { libs[lib] = f; }
    };
    add('unisim', [path.join(src, 'unisims', 'unisim_VPKG.vhd'), path.join(src, 'unisims', 'unisim_VCOMP.vhd')]);
    add('unimacro', [path.join(src, 'unimacro', '*.vhd')]);
    // XPM macros are SystemVerilog: only their VHDL component declarations exist
    add('xpm', [path.join(vivado, 'data', 'ip', 'xpm', 'xpm_VCOMP.vhd')]);
    return libs;
}
