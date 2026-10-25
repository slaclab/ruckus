// Parser of `report_timing_summary` text output (<top>_timing_summary_routed.rpt).

import { cachedParse, num, readDashTable, reportHeader } from './text';

export interface SlackSummary {
    wns?: number; tns?: number; tnsFailing?: number; tnsTotal?: number;
    whs?: number; ths?: number; thsFailing?: number; thsTotal?: number;
    wpws?: number; tpws?: number; tpwsFailing?: number; tpwsTotal?: number;
}

export interface ClockInfo { name: string; depth: number; waveform: string; period?: number; freq?: number; }
export interface ClockSlack extends SlackSummary { name: string; depth: number; line: number; }
export interface InterClock extends SlackSummary { group?: string; from: string; to: string; line: number; }

export interface TimingPath {
    slack?: number;           // undefined: unconstrained (inf)
    violated: boolean;
    kind: string;             // Setup, Hold, Recovery, Removal, ...
    source: string;
    destination: string;
    group: string;
    requirement?: number;
    dataDelay?: number;
    logicLevels: string;
    skew?: number;
    fromClock: string;
    toClock: string;
    line: number;
}

export interface CheckItem { name: string; count: number; detail: string; }

export interface TimingReport {
    file: string;
    mtime: number;
    header: Record<string, string>;
    summary: SlackSummary;
    met: boolean;
    verdict: string;          // "All user specified timing constraints are met." / "Timing constraints are not met."
    clocks: ClockInfo[];
    intra: ClockSlack[];
    inter: InterClock[];
    other: InterClock[];
    paths: TimingPath[];
    checks: CheckItem[];
}

const SUMMARY_KEYS: [string, keyof SlackSummary][] = [
    ['WNS(ns)', 'wns'], ['TNS(ns)', 'tns'], ['TNS Failing Endpoints', 'tnsFailing'], ['TNS Total Endpoints', 'tnsTotal'],
    ['WHS(ns)', 'whs'], ['THS(ns)', 'ths'], ['THS Failing Endpoints', 'thsFailing'], ['THS Total Endpoints', 'thsTotal'],
    ['WPWS(ns)', 'wpws'], ['TPWS(ns)', 'tpws'], ['TPWS Failing Endpoints', 'tpwsFailing'], ['TPWS Total Endpoints', 'tpwsTotal'],
];

function slacks(header: string[], cells: string[]): SlackSummary {
    const s: SlackSummary = {};
    for (const [h, k] of SUMMARY_KEYS) {
        const i = header.indexOf(h);
        if (i >= 0) { s[k] = num(cells[i]); }
    }
    return s;
}

/** Index of the first line of a `| Title` section (the dashed table header follows) */
function section(lines: string[], title: string): number {
    for (let i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('| ') && lines[i].slice(2).trim() === title && lines[i + 1]?.startsWith('| -')) { return i; }
    }
    return -1;
}

function tableAfter(lines: string[], start: number) {
    if (start < 0) { return undefined; }
    for (let i = start + 2; i < Math.min(lines.length, start + 30); i++) {
        if (/^\s*-+(\s+-+)*\s*$/.test(lines[i + 1] ?? '') && lines[i].trim() && !/^-+$/.test(lines[i].trim())) {
            return readDashTable(lines, i);
        }
    }
    return undefined;
}

export function parseTimingSummary(text: string, file: string, mtime: number): TimingReport {
    const lines = text.split(/\r?\n/);
    const rep: TimingReport = {
        file, mtime, header: reportHeader(lines), summary: {}, met: true, verdict: '',
        clocks: [], intra: [], inter: [], other: [], paths: [], checks: [],
    };

    // check_timing items: "N. checking <name> (<count>)" followed by their description
    for (let i = 0; i < lines.length && i < 400; i++) {
        const m = /^\d+\. checking (\w+) \((\d+)\)$/.exec(lines[i]);
        if (m && /^-+$/.test(lines[i + 1] ?? '')) {
            const detail: string[] = [];
            for (let j = i + 2; j < lines.length && !/^\d+\. checking/.test(lines[j]) && !lines[j].startsWith('----'); j++) {
                if (lines[j].trim()) { detail.push(lines[j].trim()); }
            }
            rep.checks.push({ name: m[1], count: Number(m[2]), detail: detail.join('\n') });
        }
    }

    const ds = section(lines, 'Design Timing Summary');
    const dt = tableAfter(lines, ds);
    if (dt?.rows[0]) { rep.summary = slacks(dt.header, dt.rows[0].cells); }
    for (let i = ds; i >= 0 && i < Math.min(lines.length, ds + 20); i++) {
        if (/constraints are (not )?met|There are no user specified timing constraints/.test(lines[i])) { rep.verdict = lines[i].trim(); break; }
    }
    const neg = (v?: number) => v !== undefined && v < 0;
    rep.met = !(neg(rep.summary.wns) || neg(rep.summary.whs) || neg(rep.summary.wpws) || /not met/.test(rep.verdict));

    const cs = tableAfter(lines, section(lines, 'Clock Summary'));
    for (const r of cs?.rows ?? []) {
        rep.clocks.push({ name: r.cells[0], depth: r.depth, waveform: r.cells[1] ?? '', period: num(r.cells[2]), freq: num(r.cells[3]) });
    }
    const it = tableAfter(lines, section(lines, 'Intra Clock Table'));
    for (const r of it?.rows ?? []) {
        rep.intra.push({ name: r.cells[0], depth: r.depth, line: 0, ...slacks(it!.header, r.cells) });
    }
    const inter = (title: string, out: InterClock[], withGroup: boolean) => {
        const t = tableAfter(lines, section(lines, title));
        for (const r of t?.rows ?? []) {
            const c = r.cells;
            const o = withGroup ? 1 : 0;
            out.push({ group: withGroup ? c[0] : undefined, from: c[o], to: c[o + 1], line: 0, ...slacks(t!.header, c) });
        }
    };
    inter('Inter Clock Table', rep.inter, false);
    inter('Other Path Groups Table', rep.other, true);

    // Timing details: "From Clock:" / "To Clock:" blocks, then "Slack" paragraphs
    const details = section(lines, 'Timing Details');
    let fromClock = '', toClock = '', group = '';
    let cur: TimingPath | undefined;
    const field = (l: string, key: string) => l.startsWith(`  ${key}:`) ? l.slice(key.length + 3).trim() : undefined;
    for (let i = Math.max(0, details); details >= 0 && i < lines.length; i++) {
        const l = lines[i];
        if (l.startsWith('Path Group:')) { group = l.slice(11).trim(); continue; }
        if (l.startsWith('From Clock:')) { fromClock = l.slice(11).trim(); toClock = fromClock; continue; }
        if (l.startsWith('  To Clock:')) { toClock = l.slice(11).trim(); continue; }
        if (l.startsWith('Clock Name:')) { fromClock = toClock = l.slice(11).trim(); continue; }
        const sm = /^Slack(?: \((MET|VIOLATED)\))?\s*:\s*(\S+)/.exec(l);
        if (sm) {
            const slack = sm[2] === 'inf' ? undefined : num(sm[2].replace(/ns$/, ''));
            cur = {
                slack, violated: sm[1] === 'VIOLATED' || (slack !== undefined && slack < 0), kind: '',
                source: '', destination: '', group, logicLevels: '', fromClock, toClock, line: i + 1,
            };
            rep.paths.push(cur);
            continue;
        }
        if (!cur) { continue; }
        let v: string | undefined;
        if ((v = field(l, 'Source')) !== undefined) { cur.source = v; }
        else if ((v = field(l, 'Destination')) !== undefined) { cur.destination = v; }
        else if ((v = field(l, 'Path Group')) !== undefined) { cur.group = v; }
        else if ((v = field(l, 'Path Type')) !== undefined) { cur.kind = v.replace(/\s*\(.*$/, ''); }
        else if ((v = field(l, 'Requirement')) !== undefined) { cur.requirement = num(v.split(/\s/)[0].replace(/ns$/, '')); }
        else if ((v = field(l, 'Data Path Delay')) !== undefined) { cur.dataDelay = num(v.split(/\s/)[0].replace(/ns$/, '')); }
        else if ((v = field(l, 'Logic Levels')) !== undefined) { cur.logicLevels = v; }
        else if ((v = field(l, 'Clock Path Skew')) !== undefined) { cur.skew = num(v.split(/\s/)[0].replace(/ns$/, '')); }
    }
    return rep;
}

export function readTimingSummary(file: string): TimingReport | undefined {
    return cachedParse(file, parseTimingSummary);
}
