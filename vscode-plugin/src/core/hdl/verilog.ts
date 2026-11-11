// Structural Verilog / SystemVerilog scanner: modules, instances, generate
// blocks (if/for/case + named begin blocks) and always/initial processes.

import { collapse, LineIndex, stripVerilog } from './text';
import { GenItem, HdlItem, ParsedHdl, ParsedUnit } from './types';

interface Tok { v: string; pos: number; }

const KEYWORDS = new Set(`
alias always always_comb always_ff always_latch and assert assign assume automatic before begin bind bins binsof
bit break buf bufif0 bufif1 byte case casex casez cell chandle checker class clocking cmos config const constraint
context continue cover covergroup coverpoint cross deassign default defparam design disable dist do edge else end
endcase endchecker endclass endclocking endconfig endfunction endgenerate endgroup endinterface endmodule endpackage
endprimitive endprogram endproperty endspecify endsequence endtable endtask enum event eventually expect export
extends extern final first_match for force foreach forever fork forkjoin function generate genvar global highz0
highz1 if iff ifnone ignore_bins illegal_bins implements implies import incdir include initial inout input inside
instance int integer interconnect interface intersect join join_any join_none large let liblist library local
localparam logic longint macromodule matches medium modport module nand negedge nettype new nexttime nmos nor
noshowcancelled not notif0 notif1 null or output package packed parameter pmos posedge primitive priority program
property protected pull0 pull1 pulldown pullup pulsestyle_ondetect pulsestyle_onevent pure rand randc randcase
randsequence rcmos real realtime ref reg reject_on release repeat restrict return rnmos rpmos rtran rtranif0
rtranif1 s_always s_eventually s_nexttime s_until s_until_with scalared sequence shortint shortreal showcancelled
signed small soft solve specify specparam static string strong strong0 strong1 struct super supply0 supply1
sync_accept_on sync_reject_on table tagged task this throughout time timeprecision timeunit tran tranif0 tranif1
tri tri0 tri1 triand trior trireg type typedef union unique unique0 unsigned until until_with untyped use uwire var
vectored virtual void wait wait_order wand weak weak0 weak1 while wildcard wire with within wor xnor xor
`.split(/\s+/).filter(Boolean));

const GATES = new Set('and nand or nor xor xnor buf not bufif0 bufif1 notif0 notif1 nmos pmos cmos tran tranif0 tranif1 pullup pulldown'.split(' '));
const PROCS = new Set(['always', 'always_ff', 'always_comb', 'always_latch', 'initial', 'final']);

function tokenize(text: string): Tok[] {
    const toks: Tok[] = [];
    const re = /\\\S+|`?[A-Za-z_][\w$]*(?:::[A-Za-z_][\w$]*)*|\d+'[sS]?[bodhBODH][\w?]+|'[sS]?[bodhBODH][\w?]+|\d[\w.]*|#|@|[()[\]{};:,.=?]|\S/g;
    let m: RegExpExecArray | null;
    while ((m = re.exec(text)) !== null) { toks.push({ v: m[0], pos: m.index }); }
    return toks;
}

const isIdent = (v: string | undefined) => !!v && /^(?:\\\S+|[A-Za-z_][\w$]*)$/.test(v) && !KEYWORDS.has(v);

/** Index just after the group opened at toks[i] ('(' '[' '{') */
function skipGroup(toks: Tok[], i: number): number {
    const open = toks[i].v, close = open === '(' ? ')' : open === '[' ? ']' : '}';
    let d = 0;
    for (let k = i; k < toks.length; k++) {
        if (toks[k].v === open) { d++; }
        else if (toks[k].v === close) { d--; if (d === 0) { return k + 1; } }
    }
    return toks.length;
}

interface Frame { items: HdlItem[]; kind: 'module' | 'gen' | 'begin' | 'case' | 'other'; gen?: GenItem; single?: boolean; }

export function parseVerilog(src: string): ParsedHdl {
    const text = stripVerilog(src);
    const li = new LineIndex(text);
    const toks = tokenize(text);
    const res: ParsedHdl = { lang: 'verilog', units: [], archs: [], configs: [], usesUnisim: false };
    const n = toks.length;
    let unit: ParsedUnit | undefined;
    let stack: Frame[] = [];
    const top = () => stack[stack.length - 1];
    const line = (k: number) => li.line(toks[k].pos);
    const cut = (a: number, b: number) => collapse(src.slice(toks[a].pos, b < n ? toks[b].pos : src.length).replace(/\/\/[^\n]*|\/\*[\s\S]*?\*\//g, ' '), 200);

    // A pending if/for/case at module level becomes a generate item; it owns the next begin/end or statement
    let pendingGen: GenItem | undefined;
    const pushGen = (g: GenItem) => {
        top().items.push(g);
        pendingGen = g;
    };
    // Close single-statement generate frames after a statement ends
    const closeSingles = () => {
        while (stack.length > 1 && top().single) { stack.pop(); }
    };

    let i = 0;
    while (i < n) {
        const v = toks[i].v;

        // Preprocessor directives: skip to end of line
        if (v.startsWith('`')) {
            const ln = line(i);
            i++;
            while (i < n && line(i) === ln) { i++; }
            continue;
        }

        if (!unit) {
            if (v === 'module' || v === 'macromodule' || v === 'interface' || v === 'program' || v === 'primitive') {
                let k = i + 1;
                while (k < n && (toks[k].v === 'automatic' || toks[k].v === 'static')) { k++; }
                if (toks[k] && isIdent(toks[k].v)) {
                    unit = {
                        name: toks[k].v,
                        kind: v === 'interface' ? 'interface' : v === 'program' ? 'program' : v === 'primitive' ? 'udp' : 'module',
                        line: line(i), items: [],
                    };
                    res.units.push(unit);
                    stack = [{ items: unit.items!, kind: 'module' }];
                    // skip header up to ';'
                    k++;
                    while (k < n && toks[k].v !== ';') { k = toks[k].v === '(' || toks[k].v === '[' ? skipGroup(toks, k) : k + 1; }
                    i = k + 1;
                    continue;
                }
            }
            i++;
            continue;
        }

        if (/^end(module|interface|program|primitive)$/.test(v)) {
            unit = undefined; stack = []; pendingGen = undefined;
            i++;
            continue;
        }
        // Skip function/task/class/etc. bodies entirely
        const skipTo: Record<string, string> = {
            function: 'endfunction', task: 'endtask', class: 'endclass', covergroup: 'endgroup', property: 'endproperty',
            sequence: 'endsequence', clocking: 'endclocking', specify: 'endspecify', checker: 'endchecker', table: 'endtable',
        };
        if (skipTo[v] && !(v === 'property' && toks[i - 1]?.v === 'assert')) {
            const end = skipTo[v];
            let k = i + 1;
            while (k < n && toks[k].v !== end) { k++; }
            i = k + 1;
            continue;
        }
        if (v === 'generate' || v === 'endgenerate') { i++; continue; }
        // `label :` prefix (SV labelled statements); the label is picked up by look-behind
        if (isIdent(v) && toks[i + 1]?.v === ':' && top().kind !== 'case') { i += 2; continue; }

        // Processes: record and skip their statement
        if (PROCS.has(v)) {
            const start = i;
            let k = i + 1;
            let desc = '';
            if (toks[k]?.v === '@') {
                const a = k;
                k = toks[k + 1]?.v === '(' ? skipGroup(toks, k + 1) : k + 2;
                desc = cut(a, k);
            }
            let label = '';
            // always begin : name
            if (toks[k]?.v === 'begin' && toks[k + 1]?.v === ':' && isIdent(toks[k + 2]?.v)) { label = toks[k + 2].v; }
            // name : always ...
            if (!label && toks[start - 1]?.v === ':' && isIdent(toks[start - 2]?.v)) { label = toks[start - 2].v; }
            top().items.push({ t: 'proc', label, kind: v, desc, line: line(start) });
            i = skipStatement(toks, k);
            closeSingles();
            continue;
        }

        // Generate constructs (module-level if/for/case)
        if (v === 'if' || v === 'for' || v === 'case') {
            const ln = line(i);
            let k = i + 1;
            if (toks[k]?.v === '(') { k = skipGroup(toks, k); }
            let label = '';
            if (toks[i - 1]?.v === ':' && isIdent(toks[i - 2]?.v)) { label = toks[i - 2].v; }
            const g: GenItem = { t: 'gen', label, kind: v as GenItem['kind'], cond: cut(i, k), line: ln, items: [] };
            if (v === 'case') {
                top().items.push(g);
                stack.push({ items: g.items, kind: 'case', gen: g });
                pendingGen = undefined;
                i = k;
                continue;
            }
            pushGen(g);
            i = k;
            continue;
        }
        if (v === 'else') {
            // attach to the last generate if
            const items = top().items;
            const last = [...items].reverse().find(x => x.t === 'gen') as GenItem | undefined;
            const isElseIf = toks[i + 1]?.v === 'if';
            let k = i + 1;
            let cond = 'else';
            if (isElseIf) {
                k = i + 2;
                if (toks[k]?.v === '(') { k = skipGroup(toks, k); }
                cond = cut(i, k);
            }
            const g: GenItem = { t: 'gen', label: last?.label ?? '', kind: isElseIf ? 'elsif' : 'else', cond, line: line(i), items: [] };
            pushGen(g);
            i = k;
            continue;
        }
        if (v === 'endcase') {
            if (top().kind === 'case') { stack.pop(); }
            i++;
            closeSingles();
            continue;
        }
        if (top().kind === 'case' && (v === 'default' || (toks[i + 1]?.v === ':' && !pendingGen))) {
            // case item:  VALUE : <stmt>
            let k = i;
            while (k < n && toks[k].v !== ':') { k = toks[k].v === '(' ? skipGroup(toks, k) : k + 1; }
            const g: GenItem = { t: 'gen', label: '', kind: 'if', cond: cut(i, k), line: line(i), items: [] };
            pushGen(g);
            i = k + 1;
            continue;
        }

        if (v === 'begin') {
            let k = i + 1;
            let label = '';
            if (toks[k]?.v === ':' && isIdent(toks[k + 1]?.v)) { label = toks[k + 1].v; k += 2; }
            if (pendingGen) {
                if (label) { pendingGen.label = label; }
                stack.push({ items: pendingGen.items, kind: 'gen', gen: pendingGen });
                pendingGen = undefined;
            } else if (label) {
                const g: GenItem = { t: 'gen', label, kind: 'block', cond: 'begin', line: line(i), items: [] };
                top().items.push(g);
                stack.push({ items: g.items, kind: 'begin', gen: g });
            } else {
                stack.push({ items: top().items, kind: 'other' });
            }
            i = k;
            continue;
        }
        if (v === 'end') {
            if (stack.length > 1) { stack.pop(); }
            i++;
            if (toks[i]?.v === ':' && isIdent(toks[i + 1]?.v)) { i += 2; }
            closeSingles();
            continue;
        }

        // A pending generate without begin owns exactly one statement
        if (pendingGen && v !== ';') {
            stack.push({ items: pendingGen.items, kind: 'gen', gen: pendingGen, single: true });
            pendingGen = undefined;
        }

        // Instances:  [label :] Type [#(...)] name [range] ( ... ) [, name2 (...)] ;
        if (isIdent(v) || GATES.has(v)) {
            let k = i + 1;
            let params = '';
            if (toks[k]?.v === '#') {
                const a = k + 1;
                k = toks[k + 1]?.v === '(' ? skipGroup(toks, k + 1) : k + 2;
                params = a < k ? collapse(src.slice(toks[a].pos + 1, toks[k - 1].pos), 600) : '';
            }
            const insts: { name: string; at: number }[] = [];
            while (isIdent(toks[k]?.v)) {
                const at = k;
                k++;
                while (toks[k]?.v === '[') { k = skipGroup(toks, k); }
                if (toks[k]?.v !== '(') { break; }
                k = skipGroup(toks, k);
                insts.push({ name: toks[at].v, at });
                if (toks[k]?.v === ',') { k++; continue; }
                break;
            }
            if (insts.length && toks[k]?.v === ';' && !GATES.has(v)) {
                for (const it of insts) {
                    top().items.push({ t: 'inst', label: it.name, ref: v.replace(/^\\/, ''), refLib: '', refArch: '', via: 'module', line: line(i), params });
                }
                i = k + 1;
                closeSingles();
                continue;
            }
        }

        // Anything else: skip to the end of the statement
        if (v === ';') { i++; closeSingles(); continue; }
        i = skipStatement(toks, i);
        closeSingles();
    }
    return res;
}

/** Skips a statement starting at i (begin..end block, or up to ';'); returns the index after it */
function skipStatement(toks: Tok[], i: number): number {
    const n = toks.length;
    if (toks[i]?.v === 'begin' || toks[i]?.v === 'fork') {
        let d = 0;
        for (let k = i; k < n; k++) {
            const v = toks[k].v;
            if (v === 'begin' || v === 'fork') { d++; }
            else if (v === 'end' || v === 'join' || v === 'join_any' || v === 'join_none') {
                d--;
                if (d === 0) {
                    k++;
                    if (toks[k]?.v === ':') { k += 2; }
                    return k;
                }
            } else if (/^end(module|interface|program)$/.test(v)) { return k; }
        }
        return n;
    }
    // single statement: may itself be if/case/for with nested begin..end
    let k = i;
    while (k < n) {
        const v = toks[k].v;
        if (v === '(' || v === '[' || v === '{') { k = skipGroup(toks, k); continue; }
        if (v === 'begin' || v === 'fork') { return skipStatementTail(toks, skipStatement(toks, k)); }
        if (v === 'case' || v === 'casex' || v === 'casez' || v === 'randcase') {
            let d = 0;
            for (; k < n; k++) {
                if (/^(case|casex|casez|randcase)$/.test(toks[k].v)) { d++; }
                else if (toks[k].v === 'endcase') { d--; if (d === 0) { return skipStatementTail(toks, k + 1); } }
            }
            return n;
        }
        if (v === ';') { return skipStatementTail(toks, k + 1); }
        if (/^end(module|interface|program)$/.test(v)) { return k; }
        k++;
    }
    return n;
}

/** After an if-branch statement, also consume a following `else` branch */
function skipStatementTail(toks: Tok[], k: number): number {
    if (toks[k]?.v === 'else') { return skipStatement(toks, k + 1); }
    return k;
}
