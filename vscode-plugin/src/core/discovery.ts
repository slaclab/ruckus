// Finds ruckus top levels (targets) in a directory tree.

import * as fs from 'fs';
import * as path from 'path';
import { isRuckusTarget, makeTarget, RuckusTarget } from './project';

export async function findTargets(roots: string[], maxDepth: number, exclude: string[]): Promise<RuckusTarget[]> {
    const skip = new Set(exclude);
    const out: RuckusTarget[] = [];
    const visit = async (dir: string, depth: number) => {
        if (isRuckusTarget(dir)) {
            out.push(makeTarget(dir));
            return;
        }
        if (depth >= maxDepth) { return; }
        let entries: fs.Dirent[];
        try { entries = await fs.promises.readdir(dir, { withFileTypes: true }); } catch { return; }
        await Promise.all(entries
            .filter(e => e.isDirectory() && !skip.has(e.name) && !e.name.startsWith('.'))
            .map(e => visit(path.join(dir, e.name), depth + 1)));
    };
    for (const r of roots) { await visit(r, 0); }
    out.sort((a, b) => a.dir.localeCompare(b.dir));
    return out;
}

/** Nearest enclosing ruckus target of a path, if any */
export function enclosingTarget(p: string): RuckusTarget | undefined {
    let d = p;
    try { if (!fs.statSync(d).isDirectory()) { d = path.dirname(d); } } catch { return undefined; }
    for (let i = 0; i < 6; i++) {
        if (isRuckusTarget(d)) { return makeTarget(d); }
        const up = path.dirname(d);
        if (up === d) { break; }
        d = up;
    }
    return undefined;
}

/** Firmware-level Makefile (one directory above targets/) that iterates over TARGET_DIRS */
export function firmwareMakefile(topDir: string): string | undefined {
    const mk = path.join(topDir, 'Makefile');
    try {
        if (fs.readFileSync(mk, 'utf8').includes('TARGET_DIRS')) { return mk; }
    } catch { /* none */ }
    return undefined;
}
