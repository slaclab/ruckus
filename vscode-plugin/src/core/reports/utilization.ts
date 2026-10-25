// Parser of `report_utilization` text output: the flat report written by the
// synth/impl runs (<top>_utilization_{synth,placed}.rpt) and the
// `-hierarchical` one (Utilization by Hierarchy).

import { cachedParse, num, readPipeTable, reportHeader, Table } from './text';

export interface UtilRow {
    name: string;
    depth: number;
    used?: number;
    fixed?: number;
    available?: number;
    util?: number;           // percent
    cells: string[];
}

export interface UtilSection { title: string; header: string[]; rows: UtilRow[]; line: number; }

export interface HierNode {
    instance: string;
    module: string;
    depth: number;
    values: (number | undefined)[];
    children: HierNode[];
}

export interface UtilizationReport {
    file: string;
    mtime: number;
    header: Record<string, string>;
    stage: string;           // Design State (Synthesized, Fully Placed, Routed)
    sections: UtilSection[];
    /** `report_utilization -hierarchical` */
    hierarchy?: { columns: string[]; roots: HierNode[] };
}

function toSection(title: string, t: Table): UtilSection {
    const h = t.header.map(x => x.toLowerCase());
    const col = (name: string) => h.indexOf(name);
    const iUsed = col('used'), iFixed = col('fixed'), iAvail = col('available'), iUtil = col('util%');
    return {
        title, header: t.header, line: t.line,
        rows: t.rows.map(r => ({
            name: r.cells[0], depth: r.depth, cells: r.cells,
            used: num(r.cells[iUsed]), fixed: num(r.cells[iFixed]), available: num(r.cells[iAvail]),
            util: iUtil >= 0 ? (/^<\s*0\.01/.test(r.cells[iUtil]) ? 0.005 : num(r.cells[iUtil])) : undefined,
        })),
    };
}

export function parseUtilization(text: string, file: string, mtime: number): UtilizationReport {
    const lines = text.split(/\r?\n/);
    const header = reportHeader(lines);
    const rep: UtilizationReport = { file, mtime, header, stage: header['Design State'] ?? '', sections: [] };
    for (let i = 0; i < lines.length; i++) {
        // "N. Title" or "N.M Title" underlined with dashes, then a +---+ table
        const m = /^(\d+(?:\.\d+)*\.?)\s+(.+)$/.exec(lines[i]);
        if (!m || !/^-{3,}$/.test(lines[i + 1] ?? '')) { continue; }
        let b = i + 2;
        while (b < lines.length && !lines[b].trim()) { b++; }
        const t = readPipeTable(lines, b);
        if (!t) { continue; }
        if (/Utilization by Hierarchy/i.test(m[2])) {
            rep.hierarchy = hierarchy(t);
        } else {
            rep.sections.push(toSection(m[2].trim(), t));
        }
    }
    return rep;
}

function hierarchy(t: Table): { columns: string[]; roots: HierNode[] } {
    const roots: HierNode[] = [];
    const stack: HierNode[] = [];
    for (const r of t.rows) {
        const n: HierNode = {
            instance: r.cells[0], module: r.cells[1] ?? '', depth: r.depth,
            values: r.cells.slice(2).map(c => num(c)), children: [],
        };
        while (stack.length && stack[stack.length - 1].depth >= n.depth) { stack.pop(); }
        if (stack.length) { stack[stack.length - 1].children.push(n); } else { roots.push(n); }
        stack.push(n);
    }
    return { columns: t.header.slice(2), roots };
}

export function readUtilization(file: string): UtilizationReport | undefined {
    return cachedParse(file, parseUtilization);
}
