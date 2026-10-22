// Minimal GNU Make reader.
//
// Evaluates just enough of a ruckus target Makefile (variables, include,
// conditionals, a handful of functions) to recover the exported environment
// (TOP_DIR, PRJ_PART, ...) and the list of rules, without running `make`
// (ruckus Makefiles call `vivado -version`, create build/ symlinks, etc.).

import * as fs from 'fs';
import * as path from 'path';

export interface MakeVar {
    name: string;
    value: string;          // raw for recursive vars, expanded for simple vars
    recursive: boolean;
    exported: boolean;
    file: string;
    line: number;
}

export interface MakeRule {
    name: string;
    prereqs: string;
    file: string;
    line: number;
    description?: string;   // first line of the comment block above the rule
    comment?: string;       // full comment block
    phony: boolean;
}

export interface ParsedMakefile {
    cwd: string;
    vars: Map<string, MakeVar>;
    rules: MakeRule[];
    files: string[];        // all makefiles read, in order
    defaultGoal?: string;
    errors: string[];
}

interface CondFrame { active: boolean; taken: boolean; parentActive: boolean; }

const ASSIGN_RE = /^(?:(export|override|private)\s+)*([^\s:#=?+!]+)\s*(:::=|::=|:=|\?=|\+=|!=|=)\s*(.*)$/s;

export function parseMakefile(makefile: string, env: Record<string, string | undefined> = {}): ParsedMakefile {
    const cwd = path.dirname(path.resolve(makefile));
    const p = new MakeReader(cwd, env);
    p.read(path.resolve(makefile));
    p.finish();
    return p.result;
}

class MakeReader {
    result: ParsedMakefile;
    private phony = new Set<string>();
    private exportAll = false;

    constructor(cwd: string, private env: Record<string, string | undefined>) {
        this.result = { cwd, vars: new Map(), rules: [], files: [], errors: [] };
        this.setVar('PWD', cwd, false, false, '<env>', 0);
        this.setVar('CURDIR', cwd, false, false, '<env>', 0);
    }

    finish() {
        for (const r of this.result.rules) {
            r.phony = this.phony.has(r.name);
        }
        const dg = this.result.vars.get('.DEFAULT_GOAL');
        if (dg) {
            this.result.defaultGoal = this.expand(dg.value).trim() || this.result.defaultGoal;
        }
    }

    private setVar(name: string, value: string, recursive: boolean, exported: boolean, file: string, line: number) {
        const prev = this.result.vars.get(name);
        this.result.vars.set(name, {
            name, value, recursive,
            exported: exported || (prev?.exported ?? false) || this.exportAll,
            file, line,
        });
    }

    isDefined(name: string): boolean {
        const v = this.result.vars.get(name);
        if (v) { return v.value !== ''; }
        return !!this.env[name];
    }

    getVar(name: string, depth: number): string {
        const v = this.result.vars.get(name);
        if (v) {
            return v.recursive ? this.expand(v.value, depth + 1) : v.value;
        }
        return this.env[name] ?? '';
    }

    // Expanded value of every variable (make's view, before export filtering)
    read(file: string, depth = 0) {
        if (depth > 32) { this.result.errors.push(`include depth exceeded at ${file}`); return; }
        let text: string;
        try {
            text = fs.readFileSync(file, 'utf8');
        } catch (e) {
            this.result.errors.push(`cannot read ${file}`);
            return;
        }
        this.result.files.push(file);
        const lines = logicalLines(text);
        const conds: CondFrame[] = [];
        const active = () => conds.length === 0 || conds[conds.length - 1].active;
        let comment: string[] = [];
        let inDefine: { name: string; body: string[]; line: number; exported: boolean } | undefined;

        for (const { text: raw, line } of lines) {
            if (inDefine) {
                if (/^\s*endef\b/.test(raw)) {
                    if (active()) {
                        this.setVar(inDefine.name, inDefine.body.join('\n'), true, inDefine.exported, file, inDefine.line);
                    }
                    inDefine = undefined;
                } else {
                    inDefine.body.push(raw);
                }
                continue;
            }
            // Recipe lines
            if (raw.startsWith('\t')) { continue; }

            const trimmed = raw.trim();
            if (trimmed === '') { comment = []; continue; }
            if (trimmed.startsWith('#')) {
                const c = trimmed.replace(/^#+/, '').replace(/#+$/, '').trim();
                if (c !== '') { comment.push(c); }
                continue;
            }
            const stmt = stripComment(raw).trim();
            if (stmt === '') { continue; }

            // Conditionals
            const cm = /^(ifdef|ifndef|ifeq|ifneq)\b\s*(.*)$/.exec(stmt);
            if (cm) {
                const parentActive = active();
                const v = parentActive ? this.evalCond(cm[1], cm[2]) : false;
                conds.push({ active: parentActive && v, taken: v, parentActive });
                continue;
            }
            const em = /^else\b\s*(.*)$/.exec(stmt);
            if (em) {
                const top = conds[conds.length - 1];
                if (!top) { continue; }
                const rest = em[1].trim();
                const sub = /^(ifdef|ifndef|ifeq|ifneq)\b\s*(.*)$/.exec(rest);
                if (top.taken || !top.parentActive) {
                    top.active = false;
                } else if (sub) {
                    const v = this.evalCond(sub[1], sub[2]);
                    top.active = v;
                    top.taken = v;
                } else {
                    top.active = true;
                    top.taken = true;
                }
                continue;
            }
            if (/^endif\b/.test(stmt)) { conds.pop(); continue; }
            if (!active()) { comment = []; continue; }

            // define blocks
            const dm = /^(?:(export|override)\s+)*define\s+(\S+)/.exec(stmt);
            if (dm) {
                inDefine = { name: dm[2], body: [], line, exported: stmt.startsWith('export') };
                continue;
            }

            // include
            const im = /^(-?include|sinclude)\s+(.*)$/.exec(stmt);
            if (im) {
                const optional = im[1] !== 'include';
                for (const f of this.expand(im[2]).split(/\s+/).filter(Boolean)) {
                    const abs = path.resolve(this.result.cwd, f);
                    if (fs.existsSync(abs)) {
                        this.read(abs, depth + 1);
                    } else if (!optional) {
                        this.result.errors.push(`${path.basename(file)}:${line}: included file not found: ${f}`);
                    }
                }
                comment = [];
                continue;
            }

            // export / unexport without assignment
            const xm = /^(export|unexport)(?:\s+(.*))?$/.exec(stmt);
            if (xm && !/[=]/.test(xm[2] ?? '')) {
                const names = this.expand(xm[2] ?? '').split(/\s+/).filter(Boolean);
                if (names.length === 0) { this.exportAll = xm[1] === 'export'; }
                for (const n of names) {
                    const v = this.result.vars.get(n);
                    if (v) { v.exported = xm[1] === 'export'; }
                    else if (xm[1] === 'export') { this.setVar(n, this.env[n] ?? '', false, true, file, line); }
                }
                continue;
            }
            if (/^undefine\s+/.test(stmt)) {
                for (const n of this.expand(stmt.replace(/^undefine\s+/, '')).split(/\s+/).filter(Boolean)) {
                    this.result.vars.delete(n);
                }
                continue;
            }

            // Rules (checked before assignments so `a : b=c` style target vars are seen as rules)
            const rule = splitRule(stmt);
            if (rule) {
                const rhs = rule.rhs;
                // Target-specific variable assignment: `xsim gui : export FOO := bar`
                if (/^\s*(?:export\s+|override\s+|private\s+)*[A-Za-z_][A-Za-z0-9_.]*\s*(?::::=|::=|:=|\?=|\+=|!=|=)/.test(rhs)) {
                    comment = [];
                    continue;
                }
                const names = this.expand(rule.lhs).split(/\s+/).filter(Boolean);
                const prereqs = this.expand(rhs.split(';')[0]).trim();
                if (names[0] === '.PHONY') {
                    for (const n of prereqs.split(/\s+/).filter(Boolean)) { this.phony.add(n); }
                    continue;
                }
                const desc = comment.length > 0 ? comment[0] : undefined;
                for (const n of names) {
                    if (n.includes('%') || n.startsWith('.') || n.includes('/')) { continue; }
                    this.result.rules.push({
                        name: n, prereqs, file, line,
                        description: desc, comment: comment.length ? comment.join('\n') : undefined,
                        phony: false,
                    });
                    if (!this.result.defaultGoal) { this.result.defaultGoal = n; }
                }
                comment = [];
                continue;
            }

            // Variable assignments
            const am = ASSIGN_RE.exec(stmt);
            if (am) {
                const exported = /^\s*(?:override\s+)?export\b/.test(stmt) || /\bexport\s+/.test(stmt.slice(0, stmt.indexOf(am[2])));
                const name = this.expand(am[2]);
                const op = am[3];
                const value = am[4].trim();
                switch (op) {
                    case '=':
                        this.setVar(name, value, true, exported, file, line);
                        break;
                    case ':=': case '::=': case ':::=':
                        this.setVar(name, this.expand(value), false, exported, file, line);
                        break;
                    case '?=':
                        if (!this.result.vars.has(name) && this.env[name] === undefined) {
                            this.setVar(name, value, true, exported, file, line);
                        } else if (exported) {
                            const v = this.result.vars.get(name);
                            if (v) { v.exported = true; }
                        }
                        break;
                    case '+=': {
                        const prev = this.result.vars.get(name);
                        if (prev) {
                            const add = prev.recursive ? value : this.expand(value);
                            this.setVar(name, prev.value ? `${prev.value} ${add}` : add, prev.recursive, exported, file, line);
                        } else {
                            this.setVar(name, value, true, exported, file, line);
                        }
                        break;
                    }
                    case '!=':
                        // shell assignment: not evaluated
                        this.setVar(name, '', false, exported, file, line);
                        break;
                }
                comment = [];
                continue;
            }
            comment = [];
        }
    }

    private evalCond(kind: string, arg: string): boolean {
        if (kind === 'ifdef' || kind === 'ifndef') {
            const name = this.expand(arg.trim());
            const d = this.isDefined(name);
            return kind === 'ifdef' ? d : !d;
        }
        const args = parseCondArgs(arg);
        if (!args) { return false; }
        const a = this.expand(args[0]).trim();
        const b = this.expand(args[1]).trim();
        return kind === 'ifeq' ? a === b : a !== b;
    }

    expand(s: string, depth = 0): string {
        if (depth > 50 || !s.includes('$')) { return s; }
        let out = '';
        let i = 0;
        while (i < s.length) {
            const c = s[i];
            if (c !== '$') { out += c; i++; continue; }
            const n = s[i + 1];
            if (n === undefined) { out += c; break; }
            if (n === '$') { out += '$'; i += 2; continue; }
            if (n === '(' || n === '{') {
                const close = n === '(' ? ')' : '}';
                let lvl = 1, j = i + 2;
                for (; j < s.length; j++) {
                    if (s[j] === n) { lvl++; }
                    else if (s[j] === close) { lvl--; if (lvl === 0) { break; } }
                }
                const inner = s.slice(i + 2, j);
                out += this.evalRef(inner, depth);
                i = j + 1;
                continue;
            }
            out += this.getVar(n, depth);
            i += 2;
        }
        return out;
    }

    private evalRef(inner: string, depth: number): string {
        const fm = /^([a-z-]+)[\s]+([\s\S]*)$/.exec(inner);
        if (fm && FUNCTIONS.has(fm[1])) {
            return this.callFunction(fm[1], fm[2], depth);
        }
        // Substitution reference $(VAR:a=b)
        const sm = /^([^:]+):([^=]*)=(.*)$/.exec(inner);
        if (sm) {
            const val = this.getVar(this.expand(sm[1], depth), depth);
            const from = this.expand(sm[2], depth);
            const to = this.expand(sm[3], depth);
            return words(val).map(w => patsubst(from.includes('%') ? from : `%${from}`, to.includes('%') ? to : `%${to}`, w)).join(' ');
        }
        return this.getVar(this.expand(inner, depth), depth);
    }

    private callFunction(name: string, argStr: string, depth: number): string {
        const rawArgs = splitArgs(argStr);
        const arg = (k: number) => this.expand(rawArgs[k] ?? '', depth + 1);
        const cwd = this.result.cwd;
        switch (name) {
            case 'abspath':
                return words(arg(0)).map(w => path.resolve(cwd, w)).join(' ');
            case 'realpath':
                return words(arg(0)).map(w => { try { return fs.realpathSync(path.resolve(cwd, w)); } catch { return ''; } }).filter(Boolean).join(' ');
            case 'notdir':
                return words(arg(0)).map(w => w.endsWith('/') ? '' : path.basename(w)).join(' ');
            case 'dir':
                return words(arg(0)).map(w => w.includes('/') ? w.slice(0, w.lastIndexOf('/') + 1) : './').join(' ');
            case 'basename':
                return words(arg(0)).map(w => { const e = path.extname(w); return e ? w.slice(0, -e.length) : w; }).join(' ');
            case 'suffix':
                return words(arg(0)).map(w => path.extname(w)).filter(Boolean).join(' ');
            case 'addprefix':
                return words(arg(1)).map(w => arg(0) + w).join(' ');
            case 'addsuffix':
                return words(arg(1)).map(w => w + arg(0)).join(' ');
            case 'subst':
                return arg(2).split(arg(0)).join(arg(1));
            case 'patsubst':
                return words(arg(2)).map(w => patsubst(arg(0), arg(1), w)).join(' ');
            case 'strip':
                return words(arg(0)).join(' ');
            case 'findstring':
                return arg(1).includes(arg(0)) ? arg(0) : '';
            case 'filter': {
                const pats = words(arg(0));
                return words(arg(1)).filter(w => pats.some(p => patMatch(p, w) !== undefined)).join(' ');
            }
            case 'filter-out': {
                const pats = words(arg(0));
                return words(arg(1)).filter(w => !pats.some(p => patMatch(p, w) !== undefined)).join(' ');
            }
            case 'firstword':
                return words(arg(0))[0] ?? '';
            case 'lastword': {
                const w = words(arg(0));
                return w[w.length - 1] ?? '';
            }
            case 'word':
                return words(arg(1))[parseInt(arg(0), 10) - 1] ?? '';
            case 'words':
                return String(words(arg(0)).length);
            case 'sort':
                return [...new Set(words(arg(0)))].sort().join(' ');
            case 'if':
                return arg(0).trim() !== '' ? arg(1) : arg(2);
            case 'or':
                for (let k = 0; k < rawArgs.length; k++) { const v = arg(k).trim(); if (v) { return v; } }
                return '';
            case 'and': {
                let v = '';
                for (let k = 0; k < rawArgs.length; k++) { v = arg(k).trim(); if (!v) { return ''; } }
                return v;
            }
            case 'wildcard':
                return words(arg(0)).filter(w => !/[*?[]/.test(w) && fs.existsSync(path.resolve(cwd, w))).join(' ');
            case 'origin': {
                const n = arg(0);
                if (this.result.vars.has(n)) { return 'file'; }
                return this.env[n] !== undefined ? 'environment' : 'undefined';
            }
            case 'value': {
                const v = this.result.vars.get(arg(0));
                return v ? v.value : (this.env[arg(0)] ?? '');
            }
            // Not evaluated: shell, foreach, call, eval, info, warning, error, ...
            default:
                return '';
        }
    }
}

const FUNCTIONS = new Set([
    'abspath', 'realpath', 'notdir', 'dir', 'basename', 'suffix', 'addprefix', 'addsuffix',
    'subst', 'patsubst', 'strip', 'findstring', 'filter', 'filter-out', 'firstword', 'lastword',
    'word', 'words', 'sort', 'if', 'or', 'and', 'wildcard', 'origin', 'value',
    'shell', 'foreach', 'call', 'eval', 'info', 'warning', 'error', 'flavor', 'join', 'wordlist', 'file', 'let',
]);

function words(s: string): string[] {
    return s.split(/\s+/).filter(Boolean);
}

function patMatch(pat: string, w: string): string | undefined {
    const k = pat.indexOf('%');
    if (k < 0) { return pat === w ? '' : undefined; }
    const pre = pat.slice(0, k), suf = pat.slice(k + 1);
    if (w.length >= pre.length + suf.length && w.startsWith(pre) && w.endsWith(suf)) {
        return w.slice(pre.length, w.length - suf.length);
    }
    return undefined;
}

function patsubst(pat: string, rep: string, w: string): string {
    const stem = patMatch(pat, w);
    if (stem === undefined) { return w; }
    return rep.includes('%') ? rep.replace('%', stem) : rep;
}

// Split function arguments on top-level commas
function splitArgs(s: string): string[] {
    const out: string[] = [];
    let lvl = 0, cur = '';
    for (const c of s) {
        if (c === '(' || c === '{') { lvl++; }
        else if (c === ')' || c === '}') { lvl--; }
        if (c === ',' && lvl === 0) { out.push(cur); cur = ''; continue; }
        cur += c;
    }
    out.push(cur);
    return out;
}

function parseCondArgs(s: string): [string, string] | undefined {
    s = s.trim();
    if (s.startsWith('(')) {
        const inner = s.slice(1, s.lastIndexOf(')'));
        const parts = splitArgs(inner);
        if (parts.length >= 2) { return [parts[0], parts.slice(1).join(',')]; }
        return undefined;
    }
    const m = /^(["'])(.*?)\1\s+(["'])(.*?)\3/.exec(s);
    return m ? [m[2], m[4]] : undefined;
}

// Remove a trailing `# comment` (not escaped, not inside $(...))
function stripComment(s: string): string {
    let lvl = 0;
    for (let i = 0; i < s.length; i++) {
        const c = s[i];
        if (c === '\\') { i++; continue; }
        if (c === '(' || c === '{') { lvl++; }
        else if (c === ')' || c === '}') { lvl--; }
        else if (c === '#' && lvl <= 0) { return s.slice(0, i); }
    }
    return s;
}

// Detect `targets : prereqs` at top level (not part of an assignment operator)
function splitRule(s: string): { lhs: string; rhs: string } | undefined {
    let lvl = 0;
    for (let i = 0; i < s.length; i++) {
        const c = s[i];
        if (c === '(' || c === '{') { lvl++; continue; }
        if (c === ')' || c === '}') { lvl--; continue; }
        if (lvl > 0) { continue; }
        if (c === '=') { return undefined; }
        if (c === ':') {
            if (s[i + 1] === '=' || (s[i + 1] === ':' && (s[i + 2] === '=' || (s[i + 2] === ':' && s[i + 3] === '=')))) {
                return undefined;
            }
            const lhs = s.slice(0, i);
            if (/^\s*(export|override|unexport)\b/.test(lhs)) { return undefined; }
            const rhs = s.slice(s[i + 1] === ':' ? i + 2 : i + 1);
            return { lhs, rhs };
        }
    }
    return undefined;
}

function logicalLines(text: string): { text: string; line: number }[] {
    const raw = text.split(/\r?\n/);
    const out: { text: string; line: number }[] = [];
    for (let i = 0; i < raw.length; i++) {
        const start = i + 1;
        let l = raw[i];
        while (l.endsWith('\\') && i + 1 < raw.length) {
            l = l.slice(0, -1) + ' ' + raw[++i].replace(/^\s+/, '');
        }
        out.push({ text: l, line: start });
    }
    return out;
}

// All variables, expanded, as an environment block
export function expandedVars(pm: ParsedMakefile, onlyExported = false): Record<string, string> {
    const r = new MakeReader(pm.cwd, {});
    // Reuse the variables of the parsed result
    (r as unknown as { result: ParsedMakefile }).result = pm;
    const out: Record<string, string> = {};
    for (const v of pm.vars.values()) {
        if (onlyExported && !v.exported) { continue; }
        if (v.name === 'PWD' || v.name === 'CURDIR') { continue; }
        out[v.name] = v.recursive ? r.expand(v.value) : v.value;
    }
    return out;
}

export function expandValue(pm: ParsedMakefile, s: string): string {
    const r = new MakeReader(pm.cwd, {});
    (r as unknown as { result: ParsedMakefile }).result = pm;
    return r.expand(s);
}
