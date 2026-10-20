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
    try { text = fs.readFileSync(file, 'utf8'); } catch { return { installRoots: [] }; }
    const lines = text.split('\n').filter(l => !/^\s*#/.test(l));
    let defaultVersion: string | undefined;
    const roots = new Set<string>();
    for (const l of lines) {
        const m = /^\s*(?:export\s+)?VIVADO_VERSION=["']?(\d{4}\.\d+)/.exec(l);
        if (m && !defaultVersion) { defaultVersion = m[1]; }
        const p = /(\/[^\s"'$;]*\/)\$\{?VIVADO_VERSION\}?/.exec(l);
        if (p) { roots.add(p[1].replace(/\/+$/, '')); }
    }
    return { defaultVersion, installRoots: [...roots] };
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
