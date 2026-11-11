// "Design Hierarchy" view: top-level entity/module and, recursively, the
// instances, generate blocks and processes inside it.

import * as path from 'path';
import * as vscode from 'vscode';
import { countInstances, Design, DesignUnit, Resolution } from '../core/hdl/elaborate';
import { GenItem, HdlItem, InstItem } from '../core/hdl/types';
import { LoadedFile } from '../core/project';
import { relTo } from './common';
import { openAt } from './projectTree';

export type DesignElement =
    | { t: 'top'; fileset: 'sources_1' | 'sim_1'; name: string; unit?: DesignUnit; key: string }
    | { t: 'inst'; inst: InstItem; ctx: LoadedFile; res: Resolution; sim: boolean; key: string; depth: number; parent?: DesignElement }
    | { t: 'gen'; gen: GenItem; ctx: LoadedFile; sim: boolean; key: string; depth: number; parent?: DesignElement }
    | { t: 'proc'; label: string; kind: string; desc: string; ctx: LoadedFile; line: number; key: string; parent?: DesignElement }
    | { t: 'message'; text: string; icon: string; key: string };

const MAX_DEPTH = 64;

export class DesignTreeProvider implements vscode.TreeDataProvider<DesignElement> {
    private emitter = new vscode.EventEmitter<DesignElement | undefined>();
    readonly onDidChangeTreeData = this.emitter.event;

    design?: Design;
    showProcesses = true;
    showGenerates = true;
    showPrimitives = true;
    showSim = true;
    /** User-selected top (overrides the ruckus.tcl / PROJECT one) */
    customTop?: { fileset: 'sources_1' | 'sim_1'; name: string };

    refresh() { this.emitter.fire(undefined); }

    getChildren(el?: DesignElement): DesignElement[] {
        const d = this.design;
        if (!d) { return []; }
        if (!el) {
            const tops = d.tops().filter(t => this.showSim || t.fileset === 'sources_1');
            if (this.customTop) {
                const sim = this.customTop.fileset === 'sim_1';
                const i = tops.findIndex(t => t.fileset === this.customTop!.fileset);
                const t = { fileset: this.customTop.fileset, name: this.customTop.name, unit: d.findUnit(this.customTop.name, sim) };
                if (i >= 0) { tops[i] = t; } else { tops.push(t); }
            }
            return tops.map(t => ({ t: 'top', ...t, key: `top:${t.fileset}:${t.name}` }));
        }
        if (el.t === 'top') {
            if (!el.unit) { return [{ t: 'message', text: `${el.name} not found among loaded files`, icon: 'warning', key: `${el.key}/missing` }]; }
            const b = d.body(el.unit);
            return this.items(b.items, b.file, el.fileset === 'sim_1', el.key, 1, el);
        }
        if (el.t === 'inst') {
            if (el.res.t !== 'unit') { return []; }
            if (el.depth >= MAX_DEPTH || this.isRecursive(el)) {
                return [{ t: 'message', text: 'recursive instantiation', icon: 'warning', key: `${el.key}/rec` }];
            }
            const b = d.body(el.res.unit, el.res.arch);
            return this.items(b.items, b.file, el.sim, el.key, el.depth + 1, el);
        }
        if (el.t === 'gen') {
            return this.items(el.gen.items, el.ctx, el.sim, el.key, el.depth, el);
        }
        return [];
    }

    private isRecursive(el: DesignElement & { t: 'inst' }): boolean {
        if (el.res.t !== 'unit') { return false; }
        const name = el.res.unit.name.toLowerCase();
        for (let p = el.parent; p; p = (p as { parent?: DesignElement }).parent) {
            if (p.t === 'inst' && p.res.t === 'unit' && p.res.unit.name.toLowerCase() === name) { return true; }
        }
        return false;
    }

    private items(items: HdlItem[], ctx: LoadedFile, sim: boolean, key: string, depth: number, parent: DesignElement): DesignElement[] {
        const d = this.design!;
        const out: DesignElement[] = [];
        let n = 0;
        for (const it of items) {
            const k = `${key}/${it.label || it.t + (n++)}@${it.line}`;
            if (it.t === 'inst') {
                const res = d.resolve(it, ctx, sim);
                if (!this.showPrimitives && res.t === 'primitive') { continue; }
                out.push({ t: 'inst', inst: it, ctx, res, sim, key: k, depth, parent });
            } else if (it.t === 'gen') {
                if (this.showGenerates) {
                    out.push({ t: 'gen', gen: it, ctx, sim, key: k, depth, parent });
                } else {
                    // Flatten: show the generate's content in place
                    out.push(...this.items(it.items, ctx, sim, k, depth, parent));
                }
            } else if (this.showProcesses) {
                out.push({ t: 'proc', label: it.label, kind: it.kind, desc: it.desc, ctx, line: it.line, key: k, parent });
            }
        }
        return out;
    }

    getParent(el: DesignElement): DesignElement | undefined {
        return (el as { parent?: DesignElement }).parent;
    }

    getTreeItem(el: DesignElement): vscode.TreeItem {
        const C = vscode.TreeItemCollapsibleState;
        const proj = this.design!.project;
        switch (el.t) {
            case 'message': {
                const it = new vscode.TreeItem(el.text, C.None);
                it.iconPath = new vscode.ThemeIcon(el.icon);
                it.id = el.key;
                return it;
            }
            case 'top': {
                const it = new vscode.TreeItem(el.name, C.Expanded);
                it.id = el.key;
                const sim = el.fileset === 'sim_1';
                it.description = `${sim ? 'simulation top' : 'synthesis top'}${el.unit ? ' · ' + path.basename(el.unit.file.path) : ''}`;
                it.iconPath = new vscode.ThemeIcon(sim ? 'beaker' : 'chip', new vscode.ThemeColor(sim ? 'charts.purple' : 'charts.blue'));
                if (el.unit) {
                    it.command = openAt(el.unit.file.path, el.unit.line);
                    it.tooltip = unitTooltip(proj, el.unit, this.design!);
                    it.contextValue = 'ruckus.designUnit';
                    it.resourceUri = vscode.Uri.file(el.unit.file.path);
                }
                return it;
            }
            case 'inst': {
                const i = el.inst;
                const r = el.res;
                let expandable = false;
                let icon = 'symbol-class', color: string | undefined;
                let kindText = '';
                if (r.t === 'unit') {
                    const b = this.design!.body(r.unit, r.arch);
                    expandable = b.items.some(x => x.t === 'inst' || x.t === 'gen' || (this.showProcesses && x.t === 'proc'));
                    icon = r.unit.lang === 'vhdl' ? 'symbol-class' : 'symbol-module';
                    kindText = r.unit.file.lib && r.unit.file.lib !== (el.ctx.lib || '') ? r.unit.file.lib : '';
                    if (r.unit.file.sim && !el.sim) { color = 'charts.yellow'; }
                } else if (r.t === 'ip') { icon = 'package'; color = 'charts.orange'; kindText = 'IP'; }
                else if (r.t === 'bd') { icon = 'type-hierarchy'; color = 'charts.orange'; kindText = 'block design'; }
                else if (r.t === 'netlist') { icon = 'circuit-board'; color = 'charts.orange'; kindText = 'netlist'; }
                else if (r.t === 'primitive') { icon = 'symbol-constant'; color = 'descriptionForeground'; kindText = r.lib; }
                else { icon = 'question'; color = 'problemsWarningIcon.foreground'; kindText = 'not found'; }
                const it = new vscode.TreeItem(i.label, expandable ? C.Collapsed : C.None);
                it.id = el.key;
                it.description = `${i.ref}${r.t === 'unit' && r.arch ? `(${r.arch})` : ''}${kindText ? ' · ' + kindText : ''}`;
                it.iconPath = new vscode.ThemeIcon(icon, color ? new vscode.ThemeColor(color) : undefined);
                it.tooltip = this.instTooltip(el);
                // Click: go to the definition; context menu offers the instantiation
                if (r.t === 'unit') {
                    it.command = openAt(r.unit.file.path, r.unit.line);
                    it.resourceUri = vscode.Uri.file(r.unit.file.path);
                } else if (r.t === 'ip' || r.t === 'bd') {
                    it.command = { command: 'vscode.open', title: 'Open', arguments: [vscode.Uri.file(r.file.path)] };
                } else {
                    it.command = openAt(el.ctx.path, i.line);
                }
                it.contextValue = r.t === 'unit' ? 'ruckus.designInst' : 'ruckus.designLeaf';
                return it;
            }
            case 'gen': {
                const g = el.gen;
                const n = countInstances(g.items);
                const label = g.label || (g.kind === 'else' ? 'else' : g.kind);
                const it = new vscode.TreeItem(label, g.items.length ? C.Collapsed : C.None);
                it.id = el.key;
                it.description = `${g.cond}${n ? ` · ${n} inst` : ''}`;
                it.iconPath = new vscode.ThemeIcon(g.kind === 'for' ? 'sync' : g.kind === 'block' ? 'symbol-namespace' : 'git-compare',
                    new vscode.ThemeColor('charts.green'));
                it.tooltip = `${g.kind} generate${g.label ? ' ' + g.label : ''}\n${g.cond}\n${relTo(proj, el.ctx.path)}:${g.line}\n\n` +
                    'Branches are shown unevaluated: generics are not elaborated.';
                it.command = openAt(el.ctx.path, g.line);
                it.contextValue = 'ruckus.designGen';
                return it;
            }
            case 'proc': {
                const it = new vscode.TreeItem(el.label || el.kind, C.None);
                it.id = el.key;
                it.description = `${el.label ? el.kind + ' ' : ''}${el.desc}`;
                it.iconPath = new vscode.ThemeIcon('symbol-event', new vscode.ThemeColor('charts.foreground'));
                it.tooltip = `${el.kind}${el.label ? ' ' + el.label : ''} ${el.desc}\n${relTo(proj, el.ctx.path)}:${el.line}`;
                it.command = openAt(el.ctx.path, el.line);
                it.contextValue = 'ruckus.designProc';
                return it;
            }
        }
    }

    private instTooltip(el: DesignElement & { t: 'inst' }): vscode.MarkdownString {
        const proj = this.design!.project;
        const i = el.inst, r = el.res;
        const md = new vscode.MarkdownString();
        md.appendMarkdown(`**${i.label}** : \`${i.refLib ? i.refLib + '.' : ''}${i.ref}${i.refArch ? `(${i.refArch})` : ''}\`  \n`);
        md.appendMarkdown(`instantiated (${i.via}) at \`${relTo(proj, el.ctx.path)}:${i.line}\`\n\n`);
        switch (r.t) {
            case 'unit': {
                const b = this.design!.body(r.unit, r.arch);
                md.appendMarkdown(`Defined in \`${relTo(proj, r.unit.file.path)}:${r.unit.line}\`` +
                    `${r.unit.file.lib ? ` (library **${r.unit.file.lib}**)` : ''}${b.arch ? `, architecture **${b.arch}**` : ''}  \n`);
                md.appendMarkdown(`${countInstances(b.items)} instance(s) inside\n\n`);
                if (r.unit.file.sim && !el.sim) { md.appendMarkdown('⚠ resolved to a **simulation-only** file\n\n'); }
                break;
            }
            case 'ip': md.appendMarkdown(`IP core: \`${relTo(proj, r.file.path)}\`\n\n`); break;
            case 'bd': md.appendMarkdown(`Block design: \`${relTo(proj, r.file.path)}\`\n\n`); break;
            case 'netlist': md.appendMarkdown(`Netlist / checkpoint: \`${relTo(proj, r.file.path)}\`\n\n`); break;
            case 'primitive': md.appendMarkdown(`Vendor primitive (${r.lib})\n\n`); break;
            case 'unresolved': md.appendMarkdown('⚠ **Not found** among the files loaded by ruckus.tcl\n\n'); break;
        }
        if (i.params) { md.appendCodeblock(i.params.replace(/,\s*/g, ',\n'), el.ctx.category === 'vhdl' ? 'vhdl' : 'systemverilog'); }
        return md;
    }
}

function unitTooltip(proj: import('../core/project').RuckusProject, u: DesignUnit, d: Design): vscode.MarkdownString {
    const md = new vscode.MarkdownString();
    const b = d.body(u);
    md.appendMarkdown(`**${u.kind} ${u.name}**  \n\`${relTo(proj, u.file.path)}:${u.line}\`${u.file.lib ? ` · library ${u.file.lib}` : ''}  \n`);
    if (b.arch) { md.appendMarkdown(`architecture **${b.arch}**${u.archs.length > 1 ? ` (of ${u.archs.map(a => a.name).join(', ')})` : ''}  \n`); }
    md.appendMarkdown(`${countInstances(b.items)} instance(s)`);
    return md;
}

/** Hierarchical path (top/inst/gen/...) of an element */
export function hierPath(el: DesignElement): string {
    const parts: string[] = [];
    for (let p: DesignElement | undefined = el; p; p = (p as { parent?: DesignElement }).parent) {
        if (p.t === 'top') { parts.push(p.name); }
        else if (p.t === 'inst') { parts.push(p.inst.label); }
        else if (p.t === 'gen') { parts.push(p.gen.label || p.gen.kind); }
        else if (p.t === 'proc') { parts.push(p.label || p.kind); }
    }
    return parts.reverse().join('/');
}
