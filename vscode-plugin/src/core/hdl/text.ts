// Text helpers shared by the HDL parsers. The strip functions blank out
// comments and string literals while preserving every character offset and
// newline, so regex/token positions map 1:1 to the original source.

function blank(s: string, a: number, b: number): string {
    return s.slice(a, b).replace(/[^\n]/g, ' ');
}

export function stripVhdl(s: string): string {
    const parts: string[] = [];
    const n = s.length;
    let i = 0, start = 0;
    while (i < n) {
        const c = s.charCodeAt(i);
        let j = -1;
        if (c === 45 /* - */ && s.charCodeAt(i + 1) === 45) {
            j = s.indexOf('\n', i);
            if (j < 0) { j = n; }
        } else if (c === 47 /* / */ && s.charCodeAt(i + 1) === 42 /* * */) {
            j = s.indexOf('*/', i + 2);
            j = j < 0 ? n : j + 2;
        } else if (c === 34 /* " */) {
            j = i + 1;
            while (j < n && s.charCodeAt(j) !== 34 && s.charCodeAt(j) !== 10) { j++; }
            j = Math.min(n, j + 1);
        } else if (c === 39 /* ' */ && s.charCodeAt(i + 2) === 39) {
            j = i + 3;  // character literal such as '"' or '-'
        }
        if (j < 0) { i++; continue; }
        parts.push(s.slice(start, i), blank(s, i, j));
        i = start = j;
    }
    parts.push(s.slice(start));
    return parts.join('');
}

export function stripVerilog(s: string): string {
    const parts: string[] = [];
    const n = s.length;
    let i = 0, start = 0;
    while (i < n) {
        const c = s.charCodeAt(i);
        let j = -1;
        if (c === 47 /* / */ && s.charCodeAt(i + 1) === 47) {
            j = s.indexOf('\n', i);
            if (j < 0) { j = n; }
        } else if (c === 47 && s.charCodeAt(i + 1) === 42) {
            j = s.indexOf('*/', i + 2);
            j = j < 0 ? n : j + 2;
        } else if (c === 34 /* " */) {
            j = i + 1;
            while (j < n && s.charCodeAt(j) !== 34 && s.charCodeAt(j) !== 10) {
                j += s.charCodeAt(j) === 92 /* \ */ ? 2 : 1;
            }
            j = Math.min(n, j + 1);
        } else if (c === 40 /* ( */ && s.charCodeAt(i + 1) === 42 && s.charCodeAt(i + 2) !== 41 /* ) */) {
            // (* attribute *), but not @(*)
            j = s.indexOf('*)', i + 2);
            j = j < 0 ? n : j + 2;
        }
        if (j < 0) { i++; continue; }
        parts.push(s.slice(start, i), blank(s, i, j));
        i = start = j;
    }
    parts.push(s.slice(start));
    return parts.join('');
}

export class LineIndex {
    private starts: number[] = [0];
    constructor(text: string) {
        for (let i = 0; i < text.length; i++) {
            if (text.charCodeAt(i) === 10) { this.starts.push(i + 1); }
        }
    }
    /** 1-based line of a character offset */
    line(offset: number): number {
        let lo = 0, hi = this.starts.length - 1;
        while (lo < hi) {
            const mid = (lo + hi + 1) >> 1;
            if (this.starts[mid] <= offset) { lo = mid; } else { hi = mid - 1; }
        }
        return lo + 1;
    }
}

/** Text of the balanced (...) group starting at or after `from` (stripped text), or undefined */
export function balancedParen(text: string, from: number): { start: number; end: number } | undefined {
    const open = text.indexOf('(', from);
    if (open < 0) { return undefined; }
    let depth = 0;
    for (let i = open; i < text.length; i++) {
        const c = text.charCodeAt(i);
        if (c === 40) { depth++; }
        else if (c === 41) { depth--; if (depth === 0) { return { start: open, end: i + 1 }; } }
    }
    return undefined;
}

export function collapse(s: string, max = 600): string {
    const r = s.replace(/\s+/g, ' ').trim();
    return r.length > max ? r.slice(0, max) + ' …' : r;
}
