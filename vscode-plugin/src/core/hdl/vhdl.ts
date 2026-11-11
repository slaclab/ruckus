// Structural VHDL scanner: entities, architectures, instances (entity /
// component / configuration), generate statements, blocks and processes.

import { balancedParen, collapse, LineIndex, stripVhdl } from './text';
import { GenItem, HdlItem, ParsedArch, ParsedHdl } from './types';

const NOT = (words: string) => `(?:(?!\\b(?:${words})\\b)[^;])*`;

// Every alternative is wrapped in a capturing group so the matching one can be identified
const ALTS: [string, string][] = [
    ['end', String.raw`\bend\s+(generate|block|process|architecture|entity|package|configuration)\b`],
    ['instEntity', String.raw`\b(\w+)\s*:\s*entity\s+(\w+(?:\.\w+)?)(?:\s*\(\s*(\w+)\s*\))?`],
    ['instComponent', String.raw`\b(\w+)\s*:\s*component\s+(\w+(?:\.\w+)?)`],
    ['instConfig', String.raw`\b(\w+)\s*:\s*configuration\s+(\w+(?:\.\w+)?)`],
    ['ifGen', String.raw`\b(\w+)\s*:\s*if\b(${NOT('then|loop|generate')})\bgenerate\b`],
    ['forGen', String.raw`\b(\w+)\s*:\s*for\b(${NOT('loop|generate')})\bgenerate\b`],
    ['caseGen', String.raw`\b(\w+)\s*:\s*case\b(${NOT('is|generate')})\bgenerate\b`],
    ['elsifGen', String.raw`\belsif\b(${NOT('then|generate')})\bgenerate\b`],
    ['elseGen', String.raw`\belse\s+(?:\w+\s*:\s*)?generate\b`],
    ['process', String.raw`\b(?:(\w+)\s*:\s*)?(?:postponed\s+)?process\b(\s*\([^)]*\))?`],
    ['block', String.raw`\b(\w+)\s*:\s*block\b`],
    ['arch', String.raw`\barchitecture\s+(\w+)\s+of\s+(\w+)\s+is\b`],
    ['entity', String.raw`\bentity\s+(\w+)\s+is\b`],
    ['package', String.raw`\bpackage\s+(?:body\s+)?(\w+)\s+is\b`],
    ['config', String.raw`\bconfiguration\s+(\w+)\s+of\s+(\w+)\s+is\b`],
    ['instBare', String.raw`\b(\w+)\s*:\s*(\w+(?:\.\w+)*)\s+(?=(?:generic|port)\s+map\b)`],
];

const groupCount = (src: string) => new RegExp(src + '|').exec('')!.length - 1;
const OFFSETS: number[] = [];
{
    let k = 1;
    for (const [, src] of ALTS) { OFFSETS.push(k); k += 1 + groupCount(src); }
}
const SOURCE = ALTS.map(([, s]) => `(${s})`).join('|');

interface Frame { items: HdlItem[]; gen?: GenItem; kind: 'arch' | 'gen' | 'block'; }

export function parseVhdl(src: string): ParsedHdl {
    const text = stripVhdl(src);
    const li = new LineIndex(text);
    const res: ParsedHdl = { lang: 'vhdl', units: [], archs: [], configs: [], usesUnisim: false };
    const libRe = /\blibrary\s+([\w\s,]+);/gi;
    let lm: RegExpExecArray | null;
    while ((lm = libRe.exec(text)) !== null) {
        if (/\bunisim\b/i.test(lm[1])) { res.usesUnisim = true; }
    }

    let arch: ParsedArch | undefined;
    let stack: Frame[] = [];
    const top = () => stack[stack.length - 1];
    const re = new RegExp(SOURCE, 'gi');
    let m: RegExpExecArray | null;

    const params = (from: number): string => {
        const rest = text.slice(from, from + 20000);
        const gm = /^\s*generic\s+map\s*/i.exec(rest);
        if (!gm) { return ''; }
        const b = balancedParen(text, from + gm[0].length);
        if (!b) { return ''; }
        return collapse(src.slice(b.start + 1, b.end - 1).replace(/--.*$/gm, ''));
    };

    // Condition text from the original source (string literals intact, comments removed)
    const srcText = (k: number): string => {
        const start = m!.index;
        const raw = src.slice(start, start + m![0].length).replace(/--[^\n]*/g, ' ');
        return raw.replace(/^\s*(?:\w+\s*:\s*)?(?:if|for|case|elsif)\b/i, '').replace(/\bgenerate\s*$/i, '') || m![k];
    };

    while ((m = re.exec(text)) !== null) {
        let alt = 0;
        while (alt < ALTS.length && m[OFFSETS[alt]] === undefined) { alt++; }
        const g = (k: number) => m![OFFSETS[alt] + k] ?? '';
        const kind = ALTS[alt][0];
        const line = li.line(m.index + (m[0].length - m[0].trimStart().length));
        switch (kind) {
            case 'end': {
                const w = g(1).toLowerCase();
                if (w === 'generate') {
                    if (top()?.kind === 'gen') { stack.pop(); }
                } else if (w === 'block') {
                    if (top()?.kind === 'block') { stack.pop(); }
                } else if (w === 'architecture') {
                    arch = undefined; stack = [];
                }
                break;
            }
            case 'instEntity': case 'instComponent': case 'instConfig': case 'instBare': {
                if (!arch) { break; }
                const full = g(2);
                const dot = full.lastIndexOf('.');
                const lib = dot >= 0 ? full.slice(0, full.indexOf('.')) : '';
                top().items.push({
                    t: 'inst', label: g(1), ref: dot >= 0 ? full.slice(dot + 1) : full, refLib: lib,
                    refArch: kind === 'instEntity' ? g(3) : '',
                    via: kind === 'instEntity' ? 'entity' : kind === 'instConfig' ? 'configuration' : 'component',
                    line, params: params(m.index + m[0].length),
                });
                break;
            }
            case 'ifGen': case 'forGen': case 'caseGen': {
                if (!arch) { break; }
                const k = kind === 'ifGen' ? 'if' : kind === 'forGen' ? 'for' : 'case';
                const gen: GenItem = { t: 'gen', label: g(1), kind: k, cond: collapse(`${k} ${srcText(0)}`, 200), line, items: [] };
                top().items.push(gen);
                stack.push({ items: gen.items, gen, kind: 'gen' });
                break;
            }
            case 'elsifGen': case 'elseGen': {
                const t = top();
                if (!arch || t?.kind !== 'gen' || !t.gen || !['if', 'elsif'].includes(t.gen.kind)) { break; }
                stack.pop();
                const cond = kind === 'elseGen' ? 'else' : collapse(`elsif ${srcText(0).replace(/^\s*\w+\s*:/, '')}`, 200);
                const gen: GenItem = { t: 'gen', label: t.gen.label, kind: kind === 'elseGen' ? 'else' : 'elsif', cond, line, items: [] };
                top().items.push(gen);
                stack.push({ items: gen.items, gen, kind: 'gen' });
                break;
            }
            case 'process':
                if (!arch) { break; }
                top().items.push({ t: 'proc', label: g(1), kind: 'process', desc: collapse(g(2), 120), line });
                break;
            case 'block': {
                if (!arch) { break; }
                const gen: GenItem = { t: 'gen', label: g(1), kind: 'block', cond: 'block', line, items: [] };
                top().items.push(gen);
                stack.push({ items: gen.items, gen, kind: 'block' });
                break;
            }
            case 'arch':
                arch = { name: g(1), of: g(2), line, items: [] };
                res.archs.push(arch);
                stack = [{ items: arch.items, kind: 'arch' }];
                break;
            case 'entity':
                arch = undefined; stack = [];
                res.units.push({ name: g(1), kind: 'entity', line });
                break;
            case 'package':
                arch = undefined; stack = [];
                break;
            case 'config':
                arch = undefined; stack = [];
                res.configs.push({ name: g(1), of: g(2), line });
                break;
        }
    }
    return res;
}
