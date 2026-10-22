// "Make Targets" view: targets of the selected top level (mostly inherited
// from ruckus' system_*.mk) plus the firmware-level Makefile.

import * as path from 'path';
import * as vscode from 'vscode';
import { parseMakefile } from '../core/makefile';
import { MakeTargetInfo, RuckusProject } from '../core/project';
import { openAt } from './projectTree';

export type MakeElement =
    | { t: 'group'; label: string; items: MakeTargetInfo[]; cwd: string; icon: string; expanded: boolean }
    | { t: 'target'; target: MakeTargetInfo; cwd: string }
    | { t: 'vars' }
    | { t: 'var'; name: string; value: string };

export class MakeTreeProvider implements vscode.TreeDataProvider<MakeElement> {
    private emitter = new vscode.EventEmitter<MakeElement | undefined>();
    readonly onDidChangeTreeData = this.emitter.event;
    project?: RuckusProject;
    firmwareMakefile?: string;
    grouping: 'common' | 'makefile' = 'common';

    refresh() { this.emitter.fire(undefined); }

    getChildren(el?: MakeElement): MakeElement[] {
        const p = this.project;
        if (!p) { return []; }
        if (!el) {
            const cwd = p.target.dir;
            const out: MakeElement[] = [];
            if (this.grouping === 'common') {
                const common: string[] = vscode.workspace.getConfiguration('ruckus').get('commonMakeTargets') ?? [];
                const byName = new Map(p.makeTargets.map(t => [t.name, t]));
                const def = p.make.defaultGoal;
                const first = [def, ...common].filter((n, i, a): n is string => !!n && byName.has(n) && a.indexOf(n) === i);
                const rest = p.makeTargets.filter(t => !first.includes(t.name));
                out.push({ t: 'group', label: 'Common', items: first.map(n => byName.get(n)!), cwd, icon: 'star-full', expanded: true });
                if (rest.length) {
                    out.push({ t: 'group', label: 'Other', items: rest, cwd, icon: 'list-unordered', expanded: false });
                }
            } else {
                const groups = new Map<string, MakeTargetInfo[]>();
                for (const t of p.makeTargets) {
                    if (!groups.has(t.group)) { groups.set(t.group, []); }
                    groups.get(t.group)!.push(t);
                }
                for (const [g, items] of groups) {
                    out.push({ t: 'group', label: g, items, cwd, icon: g === 'Target' ? 'target' : 'file-code', expanded: true });
                }
            }
            if (this.firmwareMakefile) {
                const fw = parseMakefile(this.firmwareMakefile, { ...process.env, PWD: path.dirname(this.firmwareMakefile) });
                const items: MakeTargetInfo[] = fw.rules.map(r => ({ ...r, group: 'firmware/Makefile', description: r.description ?? FW_DOCS[r.name] }));
                if (items.length) {
                    out.push({ t: 'group', label: 'All Targets (firmware/Makefile)', items, cwd: path.dirname(this.firmwareMakefile), icon: 'layers', expanded: false });
                }
            }
            out.push({ t: 'vars' });
            return out;
        }
        if (el.t === 'group') {
            return el.items.map(target => ({ t: 'target', target, cwd: el.cwd }));
        }
        if (el.t === 'vars') {
            const keys = ['PROJECT', 'PRJ_PART', 'PRJ_VERSION', 'TOP_DIR', 'PROJ_DIR', 'OUT_DIR', 'IMAGES_DIR', 'RUCKUS_DIR', 'MODULES',
                'RELEASE', 'VIVADO_PROJECT_SIM', 'VIVADO_PROJECT_SIM_TIME', 'VITIS_SRC_PATH', 'SDK_SRC_PATH', 'GIT_BYPASS',
                'REMOVE_UNUSED_CODE', 'GEN_BIN_IMAGE', 'GEN_MCS_IMAGE', 'GEN_XSA_IMAGE', 'USE_XVC_DEBUG'];
            return keys.filter(k => p.vars[k] !== undefined && p.vars[k] !== '').map(k => ({ t: 'var', name: k, value: p.vars[k] }));
        }
        return [];
    }

    getTreeItem(el: MakeElement): vscode.TreeItem {
        const C = vscode.TreeItemCollapsibleState;
        switch (el.t) {
            case 'group': {
                const it = new vscode.TreeItem(el.label, el.expanded ? C.Expanded : C.Collapsed);
                it.iconPath = new vscode.ThemeIcon(el.icon);
                it.description = String(el.items.length);
                it.id = `mkgrp:${this.grouping}:${el.label}`;
                return it;
            }
            case 'target': {
                const t = el.target;
                const it = new vscode.TreeItem(t.name, C.None);
                const isDefault = this.project?.make.defaultGoal === t.name && el.cwd === this.project?.target.dir;
                it.description = `${isDefault ? '(default) ' : ''}${t.description ?? ''}`;
                it.iconPath = new vscode.ThemeIcon(ICONS[t.name] ?? 'gear');
                const md = new vscode.MarkdownString();
                md.appendMarkdown(`**make ${t.name}**\n\n`);
                if (t.description) { md.appendMarkdown(`${t.description}\n\n`); }
                if (t.prereqs) { md.appendMarkdown(`Prerequisites: \`${t.prereqs.length > 200 ? t.prereqs.slice(0, 200) + '…' : t.prereqs}\`\n\n`); }
                md.appendMarkdown(`Defined in \`${t.file}:${t.line}\`\n\nRuns in \`${el.cwd}\``);
                it.tooltip = md;
                it.contextValue = 'ruckus.makeTarget';
                it.command = openAt(t.file, t.line);
                it.id = `mk:${this.grouping}:${el.cwd}:${t.name}`;
                return it;
            }
            case 'vars': {
                const it = new vscode.TreeItem('Environment', C.Collapsed);
                it.iconPath = new vscode.ThemeIcon('symbol-variable');
                it.tooltip = 'Makefile variables as evaluated by the extension (not by make)';
                return it;
            }
            case 'var': {
                const it = new vscode.TreeItem(el.name, C.None);
                it.description = el.value;
                it.tooltip = `${el.name} = ${el.value}`;
                const v = this.project?.make.vars.get(el.name);
                if (v && v.line > 0) { it.command = openAt(v.file, v.line); }
                return it;
            }
        }
    }
}

const FW_DOCS: Record<string, string> = {
    all: 'Default (build)',
    build: 'Clean and build every target in TARGET_DIRS',
    clean: 'make clean in every target',
    test: 'Print TARGET_DIRS',
};

const ICONS: Record<string, string> = {
    target: 'play-circle', all: 'play-circle',
    bit: 'circuit-board', prom: 'circuit-board', mcs: 'circuit-board', pdi: 'circuit-board',
    syn: 'symbol-structure', dcp: 'archive',
    gui: 'window', interactive: 'terminal', batch: 'terminal',
    xsim: 'beaker', vcs: 'beaker', msim: 'beaker', sim: 'beaker',
    sdk: 'chip', vitis: 'chip', elf: 'chip',
    release: 'rocket', release_files: 'package',
    pyrogue: 'snake', yaml: 'file-code',
    clean: 'trash', test: 'list-flat', dir: 'folder', sources: 'files', build: 'tools',
};
