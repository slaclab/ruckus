// Structural model extracted from HDL sources (no elaboration).

export interface InstItem {
    t: 'inst';
    label: string;          // instance label
    ref: string;            // instantiated unit name (without library)
    refLib: string;         // VHDL library prefix (entity surf.Foo -> surf), '' if none
    refArch: string;        // explicit architecture (entity work.Foo(rtl))
    via: 'entity' | 'component' | 'configuration' | 'module';
    line: number;           // 1-based
    params: string;         // generic map / #( ... ) text, whitespace collapsed
}

export interface GenItem {
    t: 'gen';
    label: string;          // generate / block label ('' if unnamed)
    kind: 'if' | 'elsif' | 'else' | 'for' | 'case' | 'block';
    cond: string;           // condition / range text
    line: number;
    items: HdlItem[];
}

export interface ProcItem {
    t: 'proc';
    label: string;          // process label, or '' if unnamed
    kind: string;           // process, always_ff, always, initial, ...
    desc: string;           // sensitivity list / event control
    line: number;
}

export type HdlItem = InstItem | GenItem | ProcItem;

export interface ParsedUnit {
    name: string;
    kind: 'entity' | 'module' | 'interface' | 'program' | 'udp';
    line: number;
    items?: HdlItem[];      // Verilog/SV: body; VHDL: in ParsedArch
}

export interface ParsedArch {
    name: string;
    of: string;             // entity name
    line: number;
    items: HdlItem[];
}

export interface ParsedConfig { name: string; of: string; line: number; }

export interface ParsedHdl {
    lang: 'vhdl' | 'verilog';
    units: ParsedUnit[];
    archs: ParsedArch[];
    configs: ParsedConfig[];
    usesUnisim: boolean;
}
