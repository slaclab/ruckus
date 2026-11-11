// Helpers to read the fixed-width tables of Vivado text reports (.rpt).

import * as fs from 'fs';

export interface Table {
    header: string[];
    rows: TableRow[];
    line: number;          // 1-based line of the header
}

export interface TableRow {
    cells: string[];
    depth: number;         // indentation level of the first cell (2 spaces per level)
}

/** Cached file read: re-reads only when size or mtime change */
const cache = new Map<string, { mtime: number; size: number; value: unknown }>();

export function cachedParse<T>(file: string, parse: (text: string, file: string, mtime: number) => T): T | undefined {
    let st: fs.Stats;
    try { st = fs.statSync(file); } catch { return undefined; }
    const c = cache.get(file);
    if (c && c.mtime === st.mtimeMs && c.size === st.size) { return c.value as T; }
    let text: string;
    try { text = fs.readFileSync(file, 'latin1'); } catch { return undefined; }
    const value = parse(text, file, st.mtimeMs);
    cache.set(file, { mtime: st.mtimeMs, size: st.size, value });
    return value;
}

/** `| Key : Value` lines of the report banner */
export function reportHeader(lines: string[]): Record<string, string> {
    const out: Record<string, string> = {};
    for (let i = 0; i < Math.min(lines.length, 20); i++) {
        const m = /^\|\s*([A-Za-z][\w ]*?)\s*:\s*(.*?)\s*$/.exec(lines[i]);
        if (m) { out[m[1]] = m[2]; }
    }
    return out;
}

/**
 * Whitespace-aligned table: a header line followed by a line of dash runs that
 * give the column extents. Cells can be empty, values are left- or
 * right-aligned and long first-column names overflow their dashes, so every
 * token is assigned to the column it overlaps most. Stops at the first blank line.
 */
export function readDashTable(lines: string[], headerIdx: number): Table | undefined {
    const dashes = lines[headerIdx + 1];
    if (!dashes || !/^\s*-+(\s+-+)*\s*$/.test(dashes)) { return undefined; }
    const cols: [number, number][] = [];
    const re = /-+/g;
    let m: RegExpExecArray | null;
    while ((m = re.exec(dashes)) !== null) { cols.push([m.index, m.index + m[0].length]); }
    const split = (l: string): string[] => {
        const cells = cols.map(() => '');
        const tok = /\{[^}]*\}|\S+/g;
        let t: RegExpExecArray | null;
        while ((t = tok.exec(l)) !== null) {
            const a = t.index, b = a + t[0].length;
            let best = -1, bestOv = -1, bestDist = Infinity;
            cols.forEach(([s, e], i) => {
                const ov = Math.min(b, e) - Math.max(a, s);
                const dist = ov > 0 ? 0 : Math.min(Math.abs(a - e), Math.abs(s - b));
                if (ov > bestOv || (ov <= 0 && bestOv <= 0 && dist < bestDist)) { best = i; bestOv = ov; bestDist = dist; }
            });
            cells[best] = cells[best] ? `${cells[best]} ${t[0]}` : t[0];
        }
        return cells;
    };
    const header = split(lines[headerIdx]);
    // Header words of a column are spread over its width: rebuild from the header line
    cols.forEach(([s], i) => {
        const end = i + 1 < cols.length ? cols[i + 1][0] : undefined;
        header[i] = lines[headerIdx].slice(s, end).trim() || header[i];
    });
    const rows: TableRow[] = [];
    for (let i = headerIdx + 2; i < lines.length; i++) {
        const l = lines[i];
        if (!l.trim()) { break; }
        rows.push({ cells: split(l), depth: Math.floor((l.length - l.trimStart().length) / 2) });
    }
    return { header, rows, line: headerIdx + 1 };
}

/** `+----+----+` / `| a | b |` table starting at the first border line */
export function readPipeTable(lines: string[], borderIdx: number): Table | undefined {
    const isBorder = (l: string | undefined) => !!l && /^\+[-+=]+\+\s*$/.test(l);
    if (!isBorder(lines[borderIdx])) { return undefined; }
    const cellsOf = (l: string) => l.trim().replace(/^\|/, '').replace(/\|$/, '').split('|');
    let i = borderIdx + 1;
    if (!lines[i]?.startsWith('|')) { return undefined; }
    const header = cellsOf(lines[i]).map(c => c.trim());
    i++;
    // Multi-line headers are rare; skip to the border closing the header
    while (i < lines.length && !isBorder(lines[i])) {
        cellsOf(lines[i]).forEach((c, k) => { if (c.trim()) { header[k] = `${header[k] ?? ''} ${c.trim()}`.trim(); } });
        i++;
    }
    const rows: TableRow[] = [];
    for (i++; i < lines.length; i++) {
        const l = lines[i];
        if (isBorder(l)) { if (isBorder(lines[i + 1]) || !lines[i + 1]?.startsWith('|')) { break; } continue; }
        if (!l.startsWith('|')) { break; }
        const raw = cellsOf(l);
        const first = raw[0] ?? '';
        // "| " is the cell padding; the rest of the leading blanks is the indentation
        const lead = first.length - first.trimStart().length - 1;
        rows.push({ cells: raw.map(c => c.trim()), depth: Math.max(0, Math.floor(lead / 2)) });
    }
    return { header, rows, line: borderIdx + 2 };
}

/** Number of a report cell ('' / 'n/a' / 'inf' -> undefined) */
export function num(s: string | undefined): number | undefined {
    if (s === undefined) { return undefined; }
    const t = s.replace(/^<|\*$/g, '').trim();
    if (!t || !/^-?\d+(\.\d+)?$/.test(t)) { return undefined; }
    return Number(t);
}
