import * as path from 'path';
import * as vscode from 'vscode';
import { Category, LoadedFile, RuckusProject } from '../core/project';

export const CATEGORY_LABEL: Record<Category, string> = {
    vhdl: 'VHDL',
    verilog: 'Verilog',
    systemverilog: 'SystemVerilog',
    header: 'Verilog/SV Headers',
    netlist: 'Netlists / Checkpoints',
    memory: 'Memory Init Files',
    constraint: 'Constraints',
    ip: 'IP Cores',
    bd: 'Block Designs',
    zip: 'Zipped IP Repositories',
    ncr: 'NoC Solutions',
    software: 'C / C++ (MicroBlaze, DPI-C, VHPI)',
    other: 'Other',
};

export const CATEGORY_ICON: Record<Category, string> = {
    vhdl: 'symbol-class',
    verilog: 'symbol-module',
    systemverilog: 'symbol-module',
    header: 'symbol-file',
    netlist: 'circuit-board',
    memory: 'symbol-array',
    constraint: 'symbol-ruler',
    ip: 'package',
    bd: 'type-hierarchy',
    zip: 'file-zip',
    ncr: 'radio-tower',
    software: 'code',
    other: 'file',
};

export const CATEGORY_ORDER: Category[] = [
    'vhdl', 'verilog', 'systemverilog', 'header', 'constraint', 'ip', 'bd', 'zip', 'ncr',
    'netlist', 'memory', 'software', 'other',
];

export function originLabel(o: string): string {
    if (o === 'target') { return 'Top Level (target)'; }
    if (o === 'external') { return 'External'; }
    return o;
}

export function relTo(proj: RuckusProject, p: string): string {
    // tclsh reports resolved paths (e.g. /private/tmp on macOS, symlinked submodules)
    for (const base of [proj.topDir, proj.topDirReal]) {
        const r = path.relative(base, p);
        if (!r.startsWith('..') && !path.isAbsolute(r)) { return r; }
    }
    for (const [real, shown] of proj.pathAliases) {
        if (p === real || p.startsWith(real + path.sep)) { return path.join(shown, path.relative(real, p)); }
    }
    return p;
}

/** Tree item for a loaded file */
export function fileItem(proj: RuckusProject, f: LoadedFile, showDir: boolean): vscode.TreeItem {
    const it = new vscode.TreeItem(vscode.Uri.file(f.path), vscode.TreeItemCollapsibleState.None);
    it.label = path.basename(f.path);
    const tags: string[] = [];
    // Vivado only applies -lib to VHDL files
    if (f.lib && (f.category === 'vhdl' || f.via === 'related')) { tags.push(f.lib); }
    if (f.sim) { tags.push('sim'); }
    if (f.fileType) { tags.push(f.fileType); }
    if (f.via === 'related') { tags.push('not loaded'); }
    if (showDir) { tags.push(path.dirname(relTo(proj, f.path))); }
    it.description = tags.join(' · ');
    const md = new vscode.MarkdownString(undefined, true);
    md.appendMarkdown(`**${path.basename(f.path)}**  \n`);
    md.appendMarkdown(`\`${f.path}\`\n\n`);
    md.appendMarkdown(`| | |\n|---|---|\n`);
    md.appendMarkdown(`| Type | ${CATEGORY_LABEL[f.category]} |\n`);
    md.appendMarkdown(`| Fileset | ${f.kind === 'constraint' ? 'constrs_1' : f.sim ? 'sim_1' : 'sources_1'} |\n`);
    if (f.lib) { md.appendMarkdown(`| Library | ${f.lib} |\n`); }
    md.appendMarkdown(`| Origin | ${originLabel(f.origin)} |\n`);
    if (f.packages.length) { md.appendMarkdown(`| Packages | ${f.packages.join(', ')} |\n`); }
    if (f.file) {
        md.appendMarkdown(`| Loaded by | ${f.via === 'related' ? '(sibling of) ' : ''}\`${relTo(proj, f.file)}:${f.line}\` (${f.via === 'dir' ? '-dir' : f.via === 'path' ? '-path' : f.via}) |\n`);
    }
    it.tooltip = md;
    it.contextValue = 'ruckus.file';
    it.command = { command: 'vscode.open', title: 'Open', arguments: [vscode.Uri.file(f.path)] };
    if (f.category === 'netlist' || f.category === 'zip') {
        it.command = { command: 'revealFileInOS', title: 'Reveal', arguments: [vscode.Uri.file(f.path)] };
    }
    return it;
}

export function matchesFilter(f: LoadedFile, filter: string): boolean {
    if (!filter) { return true; }
    const name = path.basename(f.path).toLowerCase();
    const terms = filter.toLowerCase().split(/\s+/).filter(Boolean);
    return terms.every(t => {
        if (t.startsWith('lib:')) { return f.lib.toLowerCase() === t.slice(4); }
        if (t.startsWith('ext:')) { return path.extname(f.path).toLowerCase() === '.' + t.slice(4).replace(/^\./, ''); }
        if (t === 'sim') { return f.sim; }
        if (t === '!sim') { return !f.sim; }
        if (t.startsWith('pkg:')) { return f.packages.some(p => p.toLowerCase().includes(t.slice(4))); }
        return name.includes(t) || f.packages.some(p => p.toLowerCase().includes(t));
    });
}
