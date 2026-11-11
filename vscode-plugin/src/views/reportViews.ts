// Panel views (next to the terminal) showing the results of a build:
// "Log Report" (messages of the Vivado / simulator logs), "Timing"
// (report_timing_summary) and "Resources" (report_utilization).
// The views are webviews; their scripts are in media/reports/.

import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { hierUtilFile, logSources, routedCheckpoint, timingReportFile, utilizationFiles } from '../core/reports/locate';
import { readLog, Severity } from '../core/reports/messages';
import { readTimingSummary } from '../core/reports/timing';
import { readUtilization } from '../core/reports/utilization';
import { RuckusProject } from '../core/project';

export interface ReportHost {
    project(): RuckusProject | undefined;
    open(file: string, line: number): void;
    generateHierUtil(): void;
}

const POLL_MS = 3000;

abstract class ReportView implements vscode.WebviewViewProvider {
    private view?: vscode.WebviewView;
    private lastKey = '';

    constructor(protected ctx: vscode.ExtensionContext, protected host: ReportHost, private script: string) {}

    resolveWebviewView(view: vscode.WebviewView) {
        this.view = view;
        const media = vscode.Uri.joinPath(this.ctx.extensionUri, 'media', 'reports');
        view.webview.options = { enableScripts: true, localResourceRoots: [media] };
        view.webview.html = page(view.webview, media, this.script);
        view.webview.onDidReceiveMessage(m => this.onMessage(m));
        view.onDidChangeVisibility(() => { if (view.visible) { this.update(); } });
        // Builds write their logs/reports outside the VS Code file watcher (build/ is excluded): poll while visible
        const timer = setInterval(() => { if (view.visible) { this.update(); } }, POLL_MS);
        view.onDidDispose(() => { clearInterval(timer); this.view = undefined; });
    }

    /** Re-sends the data when the underlying files changed (or always with force) */
    update(force = false) {
        const v = this.view;
        if (!v) { return; }
        const p = this.host.project();
        const files = p ? this.files(p) : [];
        const key = `${p?.target.dir}|` + files.map(f => `${f}:${stamp(f)}`).join('|');
        if (!force && key === this.lastKey) { return; }
        this.lastKey = key;
        v.description = p?.target.name;
        let data: unknown;
        try { data = p ? this.data(p) : undefined; } catch (e) { data = { error: String(e) }; }
        v.webview.postMessage({ type: 'data', project: p ? { name: p.target.name, topDir: p.topDir, backend: p.backend } : undefined, data });
    }

    protected onMessage(m: { type: string; file?: string; line?: number }) {
        if (m.type === 'ready' || m.type === 'refresh') { this.update(true); }
        else if (m.type === 'open' && m.file) { this.host.open(m.file, m.line ?? 1); }
    }

    /** Files whose change triggers a refresh */
    protected abstract files(p: RuckusProject): string[];
    protected abstract data(p: RuckusProject): unknown;
}

function stamp(f: string): string {
    try { const s = fs.statSync(f); return `${s.mtimeMs}:${s.size}`; } catch { return '-'; }
}

function page(webview: vscode.Webview, media: vscode.Uri, script: string): string {
    const nonce = crypto.randomBytes(16).toString('hex');
    const u = (f: string) => webview.asWebviewUri(vscode.Uri.joinPath(media, f));
    return `<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src ${webview.cspSource} 'unsafe-inline'; script-src 'nonce-${nonce}';">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link href="${u('reports.css')}" rel="stylesheet">
</head><body><div id="app"><p class="muted">Loading…</p></div>
<script nonce="${nonce}" src="${u('common.js')}"></script>
<script nonce="${nonce}" src="${u(script)}"></script>
</body></html>`;
}

// ----------------------------------------------------------------------

const SEV_INDEX: Record<Severity, number> = { error: 0, critical: 1, warning: 2, info: 3, status: 4 };

export class LogReportView extends ReportView {
    constructor(ctx: vscode.ExtensionContext, host: ReportHost) { super(ctx, host, 'log.js'); }

    protected files(p: RuckusProject): string[] { return logSources(p).map(s => s.file); }

    protected data(p: RuckusProject) {
        return {
            sources: logSources(p).map(s => {
                const log = readLog(s.file);
                return {
                    id: s.id, label: s.label, file: s.file, mtime: s.mtime, defaultOn: s.defaultOn,
                    // Compact rows: [severity, id, text, file, line, logLine, step]
                    messages: (log?.messages ?? []).map(m => [SEV_INDEX[m.severity], m.id, m.text, m.file ?? '', m.line ?? 0, m.logLine, m.step]),
                };
            }),
        };
    }
}

export class TimingView extends ReportView {
    constructor(ctx: vscode.ExtensionContext, host: ReportHost) { super(ctx, host, 'timing.js'); }

    protected files(p: RuckusProject): string[] { const f = timingReportFile(p); return f ? [f] : []; }

    protected data(p: RuckusProject) {
        const f = timingReportFile(p);
        return { report: f ? readTimingSummary(f) : undefined };
    }
}

export class ResourceView extends ReportView {
    constructor(ctx: vscode.ExtensionContext, host: ReportHost) { super(ctx, host, 'resource.js'); }

    protected files(p: RuckusProject): string[] {
        const u = utilizationFiles(p);
        return [u.synth, u.impl, hierUtilFile(p), routedCheckpoint(p)].filter((x): x is string => !!x);
    }

    protected data(p: RuckusProject) {
        const u = utilizationFiles(p);
        const dcp = routedCheckpoint(p);
        let dcpMtime = 0;
        try { dcpMtime = dcp ? fs.statSync(dcp).mtimeMs : 0; } catch { /* gone */ }
        return {
            synth: u.synth ? readUtilization(u.synth) : undefined,
            impl: u.impl ? readUtilization(u.impl) : undefined,
            hier: u.hier ? readUtilization(u.hier) : undefined,
            checkpoint: dcp ? { file: dcp, name: path.basename(dcp), mtime: dcpMtime } : undefined,
            vivado: p.backend === 'vivado',
        };
    }

    protected onMessage(m: { type: string; file?: string; line?: number }) {
        if (m.type === 'generateHier') { this.host.generateHierUtil(); return; }
        super.onMessage(m);
    }
}
