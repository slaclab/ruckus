// Messages (ERROR / CRITICAL WARNING / WARNING / INFO) of Vivado, GHDL,
// Icarus Verilog and Verilator logs.

import { cachedParse } from './text';

export type Severity = 'error' | 'critical' | 'warning' | 'info' | 'status';

export interface LogMessage {
    severity: Severity;
    id: string;              // Vivado message id, e.g. "Synth 8-6014"
    text: string;
    file?: string;           // source location the message refers to
    line?: number;
    logFile: string;
    logLine: number;         // 1-based
    step: string;            // synth_design, place_design, ...
}

export interface LogInfo { file: string; mtime: number; messages: LogMessage[]; }

const VIVADO = /^(ERROR|CRITICAL WARNING|WARNING|INFO): \[([^\]]+)\] (.*)$/;
const VIVADO_NOID = /^(ERROR|CRITICAL WARNING|WARNING): (.*)$/;
const GHDL = /^([^\s:]+\.vhdl?):(\d+):(\d+):(?:(error|warning|note):)?\s*(.*)$/;
const IVERILOG = /^([^\s:]+\.s?vh?):(\d+):\s+(error|warning|sorry):\s+(.*)$/;
const VERILATOR = /^%(Error|Warning)(?:-([A-Z0-9_]+))?: (?:([^\s:]+):(\d+):(?:\d+:)? )?(.*)$/;

const SEV: Record<string, Severity> = {
    'ERROR': 'error', 'CRITICAL WARNING': 'critical', 'WARNING': 'warning', 'INFO': 'info',
    error: 'error', sorry: 'error', warning: 'warning', note: 'info', Error: 'error', Warning: 'warning',
};

/** Trailing "[/abs/file.vhd:123]" source location of Vivado messages */
function location(text: string): { text: string; file?: string; line?: number } {
    const m = /\s*\[(\/[^\]:]+):(\d+)\]\s*$/.exec(text);
    if (!m) { return { text: text.trim() }; }
    return { text: text.slice(0, m.index).trim(), file: m[1], line: Number(m[2]) };
}

export function parseLog(text: string, file: string, mtime: number): LogInfo {
    const lines = text.split(/\r?\n/);
    const out: LogMessage[] = [];
    let step = '';
    for (let i = 0; i < lines.length; i++) {
        const l = lines[i];
        const cmd = /^Command: (\w+)/.exec(l);
        if (cmd) { step = cmd[1]; continue; }
        let m: RegExpExecArray | null;
        if ((m = VIVADO.exec(l))) {
            const loc = location(m[3]);
            out.push({ severity: SEV[m[1]], id: m[2], ...loc, logFile: file, logLine: i + 1, step });
        } else if ((m = VIVADO_NOID.exec(l))) {
            const loc = location(m[2]);
            out.push({ severity: SEV[m[1]], id: '', ...loc, logFile: file, logLine: i + 1, step });
        } else if ((m = GHDL.exec(l))) {
            out.push({ severity: m[4] ? SEV[m[4]] : 'error', id: 'ghdl', text: m[5], file: m[1], line: Number(m[2]), logFile: file, logLine: i + 1, step });
        } else if ((m = IVERILOG.exec(l))) {
            out.push({ severity: SEV[m[3]], id: 'iverilog', text: m[4], file: m[1], line: Number(m[2]), logFile: file, logLine: i + 1, step });
        } else if ((m = VERILATOR.exec(l))) {
            out.push({ severity: SEV[m[1]], id: m[2] ? `verilator ${m[2]}` : 'verilator', text: m[5], file: m[3], line: m[4] ? Number(m[4]) : undefined, logFile: file, logLine: i + 1, step });
        }
    }
    return { file, mtime, messages: out };
}

export function readLog(file: string): LogInfo | undefined {
    return cachedParse(file, parseLog);
}
