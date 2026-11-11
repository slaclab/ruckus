// Design hierarchy: indexes every loaded HDL file and resolves instances to
// their definitions (entity/module, IP core, block design, netlist or
// vendor primitive). Children are resolved lazily, so huge libraries such as
// surf cost nothing until a branch is expanded.

import * as fs from 'fs';
import * as path from 'path';
import { LoadedFile, RuckusProject } from '../project';
import { parseVerilog } from './verilog';
import { parseVhdl } from './vhdl';
import { HdlItem, InstItem, ParsedHdl } from './types';

export interface DesignUnit {
    name: string;
    lang: 'vhdl' | 'verilog';
    kind: string;                     // entity, module, interface, ...
    file: LoadedFile;
    line: number;
    archs: { name: string; line: number; items: HdlItem[]; file: LoadedFile }[];
    items?: HdlItem[];                // Verilog body
}

export type Resolution =
    | { t: 'unit'; unit: DesignUnit; arch?: string }
    | { t: 'ip'; file: LoadedFile }
    | { t: 'bd'; file: LoadedFile }
    | { t: 'netlist'; file: LoadedFile }
    | { t: 'primitive'; lib: string }
    | { t: 'unresolved' };

/** Common Xilinx UNISIM / UNIMACRO primitives (also matched by pattern below) */
const XILINX_PRIMS = /^(IBUF\w*|OBUF\w*|IOBUF\w*|BUF\w*|IDDR\w*|ODDR\w*|IDELAY\w*|ODELAY\w*|ISERDES\w*|OSERDES\w*|MMCM\w*|PLL\w*|DCM\w*|BSCAN\w*|STARTUP\w*|ICAP\w*|FRAME_ECC\w*|DNA_PORT\w*|XADC|SYSMON\w*|GT\w*_(CHANNEL|COMMON)|GT\w+E\d|RAMB\w*|FIFO\d+\w*|DSP48\w*|DSP58\w*|SRL\w*|LUT\d\w*|FD[CPRSE]\w*|LD\w*|CARRY\w*|MUXF\w*|KEEPER|PULLUP|PULLDOWN|VCC|GND|URAM\w*|IBUFDS_GT\w*|OBUFDS_GT\w*|HPIO_\w*|BITSLICE\w*|RX_BITSLICE|TX_BITSLICE\w*|RIU_OR|EFUSE_USR|USR_ACCESS\w*|CFGLUT\w*|AND2B1L|OR2L|PS7|PS8|PS9|CMAC\w*|PCIE\w*|ILKN\w*|HBM\w*|XPM_\w+|xpm_\w+|SYSMONE\d|DCIRESET|IDELAYCTRL|ZHOLD_DELAY)$/;

export class Design {
    private parsed = new Map<string, ParsedHdl>();
    private units = new Map<string, DesignUnit[]>();          // lower-case name -> definitions
    private named = new Map<string, LoadedFile>();             // lower-case basename -> ip/bd/netlist file
    private configs = new Map<string, string>();               // configuration name -> entity name
    readonly parseMs: number;
    readonly errors: string[] = [];

    constructor(readonly project: RuckusProject) {
        const t0 = Date.now();
        for (const f of project.files) {
            if (f.category === 'ip' || f.category === 'bd' || f.category === 'netlist') {
                const base = path.basename(f.path, path.extname(f.path)).toLowerCase();
                if (!this.named.has(base)) { this.named.set(base, f); }
                if (f.category === 'bd') { this.named.set(`${base}_wrapper`, f); }
            }
            if (!['vhdl', 'verilog', 'systemverilog'].includes(f.category)) { continue; }
            const p = parseCached(f.path, f.category === 'vhdl', this.errors);
            if (!p) { continue; }
            this.parsed.set(f.path, p);
            for (const c of p.configs) { this.configs.set(c.name.toLowerCase(), c.of); }
            for (const u of p.units) {
                const du: DesignUnit = { name: u.name, lang: p.lang, kind: u.kind, file: f, line: u.line, archs: [], items: u.items };
                this.add(du);
            }
        }
        // Attach VHDL architectures to their entity (they may live in other files)
        for (const f of project.files) {
            const p = this.parsed.get(f.path);
            if (!p) { continue; }
            for (const a of p.archs) {
                const cands = this.units.get(a.of.toLowerCase())?.filter(u => u.lang === 'vhdl') ?? [];
                const u = cands.find(c => c.file.lib === f.lib) ?? cands[0];
                if (u) { u.archs.push({ name: a.name, line: a.line, items: a.items, file: f }); }
            }
        }
        this.parseMs = Date.now() - t0;
    }

    private add(u: DesignUnit) {
        const k = u.name.toLowerCase();
        if (!this.units.has(k)) { this.units.set(k, []); }
        this.units.get(k)!.push(u);
    }

    /** All entities/modules, for "select top" */
    allUnits(): DesignUnit[] {
        return [...this.units.values()].flat().filter(u => u.kind !== 'interface');
    }

    findUnit(name: string, preferSim = false): DesignUnit | undefined {
        const c = this.units.get(name.toLowerCase());
        if (!c?.length) { return undefined; }
        return c.find(u => u.file.sim === preferSim) ?? c[0];
    }

    /** Body items of a unit (selected architecture for VHDL) */
    body(u: DesignUnit, arch?: string): { items: HdlItem[]; file: LoadedFile; arch?: string } {
        if (u.lang === 'verilog') { return { items: u.items ?? [], file: u.file }; }
        if (!u.archs.length) { return { items: [], file: u.file }; }
        // Explicit architecture, else the most recently analyzed one (last in compile order)
        const a = (arch && u.archs.find(x => x.name.toLowerCase() === arch.toLowerCase())) || u.archs[u.archs.length - 1];
        return { items: a.items, file: a.file, arch: a.name };
    }

    resolve(inst: InstItem, ctx: LoadedFile, sim: boolean): Resolution {
        let key = inst.ref.toLowerCase();
        if (inst.via === 'configuration' && this.configs.has(key)) { key = this.configs.get(key)!.toLowerCase(); }
        const lib = inst.refLib.toLowerCase();
        if (lib === 'unisim' || lib === 'unimacro' || lib === 'xpm') { return { t: 'primitive', lib }; }
        let cands = this.units.get(key) ?? [];
        // VHDL: `entity work.X` means X in the library of the instantiating file
        if (cands.length && inst.via === 'entity' && lib) {
            const want = lib === 'work' ? (ctx.lib || 'work').toLowerCase() : lib;
            const inLib = cands.filter(u => (u.file.lib || 'work').toLowerCase() === want);
            if (inLib.length) { cands = inLib; }
        } else if (cands.length > 1) {
            const same = cands.filter(u => u.file.lib === ctx.lib);
            if (same.length) { cands = same; }
        }
        if (cands.length) {
            // Synthesis hierarchy prefers synthesis sources; sim hierarchy prefers sim models
            const u = cands.find(c => c.file.sim === sim) ?? cands[0];
            return { t: 'unit', unit: u, arch: inst.refArch || undefined };
        }
        const named = this.named.get(key);
        if (named) {
            return named.category === 'ip' ? { t: 'ip', file: named }
                : named.category === 'bd' ? { t: 'bd', file: named } : { t: 'netlist', file: named };
        }
        if (XILINX_PRIMS.test(inst.ref) || (this.parsed.get(ctx.path)?.usesUnisim && inst.via === 'component' && inst.ref === inst.ref.toUpperCase())) {
            return { t: 'primitive', lib: 'unisim' };
        }
        return { t: 'unresolved' };
    }

    /** Synthesis and simulation top units */
    tops(): { fileset: 'sources_1' | 'sim_1'; name: string; unit?: DesignUnit }[] {
        const p = this.project;
        const out: { fileset: 'sources_1' | 'sim_1'; name: string; unit?: DesignUnit }[] = [];
        const synth = p.tops.filter(t => t.fileset === 'sources_1').pop()?.value || p.vars.PROJECT || p.target.name;
        out.push({ fileset: 'sources_1', name: synth, unit: this.findUnit(synth, false) });
        const simTop = (p.vars.VIVADO_PROJECT_SIM || p.tops.filter(t => t.fileset === 'sim_1').pop()?.value);
        if (simTop) { out.push({ fileset: 'sim_1', name: simTop, unit: this.findUnit(simTop, true) }); }
        return out;
    }

    /** Units not instantiated anywhere (candidate tops), excluding packages-only files */
    roots(sim: boolean): DesignUnit[] {
        const used = new Set<string>();
        const walk = (items: HdlItem[]) => {
            for (const it of items) {
                if (it.t === 'inst') { used.add(it.ref.toLowerCase()); }
                else if (it.t === 'gen') { walk(it.items); }
            }
        };
        for (const u of this.allUnits()) {
            walk(u.items ?? []);
            for (const a of u.archs) { walk(a.items); }
        }
        return this.allUnits().filter(u => u.file.sim === sim && !used.has(u.name.toLowerCase()));
    }
}

// ---------------------------------------------------------------------------
// Parse cache (by path + mtime + size), shared across rescans
// ---------------------------------------------------------------------------
const cache = new Map<string, { key: string; parsed: ParsedHdl }>();

function parseCached(file: string, vhdl: boolean, errors: string[]): ParsedHdl | undefined {
    let st: fs.Stats;
    try { st = fs.statSync(file); } catch { return undefined; }
    const key = `${st.mtimeMs}:${st.size}`;
    const c = cache.get(file);
    if (c && c.key === key) { return c.parsed; }
    try {
        const text = fs.readFileSync(file, 'latin1');
        const parsed = vhdl ? parseVhdl(text) : parseVerilog(text);
        cache.set(file, { key, parsed });
        return parsed;
    } catch (e) {
        errors.push(`${file}: ${e instanceof Error ? e.message : e}`);
        return undefined;
    }
}

/** Count of instances in an item list (recursing into generates) */
export function countInstances(items: HdlItem[]): number {
    let n = 0;
    for (const it of items) {
        if (it.t === 'inst') { n++; }
        else if (it.t === 'gen') { n += countInstances(it.items); }
    }
    return n;
}
