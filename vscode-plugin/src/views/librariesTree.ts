// "Libraries & Categories" view: cross-cutting views of the loaded project
// (submodules, VHDL libraries, packages, constraints, IPs, simulation, ...).

import * as path from 'path';
import * as vscode from 'vscode';
import { Category, LoadedFile, RuckusProject } from '../core/project';
import { CATEGORY_ICON, CATEGORY_LABEL, fileItem, matchesFilter, originLabel } from './common';

type Section = 'submodules' | 'libraries' | 'packages' | 'tops' | 'sim' | Category;

export type LibElement =
    | { t: 'section'; section: Section }
    | { t: 'group'; section: Section; key: string }
    | { t: 'package'; name: string; file: LoadedFile }
    | { t: 'top'; fileset: string; value: string; file: string; line: number }
    | { t: 'file'; file: LoadedFile; showDir: boolean };

const SECTIONS: { section: Section; label: string; icon: string; tip: string }[] = [
    { section: 'tops', label: 'Top Modules', icon: 'target', tip: 'set_property top ... statements' },
    { section: 'submodules', label: 'Libraries / Submodules', icon: 'library', tip: 'Files grouped by the repository / directory they come from' },
    { section: 'libraries', label: 'HDL Libraries (-lib)', icon: 'symbol-namespace', tip: 'VHDL library names given to loadSource -lib' },
    { section: 'packages', label: 'Packages', icon: 'symbol-package', tip: 'VHDL / SystemVerilog packages declared in loaded files' },
    { section: 'constraint', label: CATEGORY_LABEL.constraint, icon: CATEGORY_ICON.constraint, tip: 'loadConstraints (.xdc / .tcl)' },
    { section: 'ip', label: CATEGORY_LABEL.ip, icon: CATEGORY_ICON.ip, tip: 'loadIpCore (.xci / .xcix)' },
    { section: 'bd', label: CATEGORY_LABEL.bd, icon: CATEGORY_ICON.bd, tip: 'loadBlockDesign (.bd / .tcl)' },
    { section: 'zip', label: CATEGORY_LABEL.zip, icon: CATEGORY_ICON.zip, tip: 'loadZipIpCore' },
    { section: 'ncr', label: CATEGORY_LABEL.ncr, icon: CATEGORY_ICON.ncr, tip: 'loadNoCSolution' },
    { section: 'netlist', label: CATEGORY_LABEL.netlist, icon: CATEGORY_ICON.netlist, tip: '.dcp / .edif loaded with loadSource' },
    { section: 'memory', label: CATEGORY_LABEL.memory, icon: CATEGORY_ICON.memory, tip: '.mem / .coe / .dat' },
    { section: 'header', label: CATEGORY_LABEL.header, icon: CATEGORY_ICON.header, tip: '.vh / .svh' },
    { section: 'sim', label: 'Simulation Sources (sim_1)', icon: 'beaker', tip: 'loadSource -sim_only' },
    { section: 'software', label: CATEGORY_LABEL.software, icon: CATEGORY_ICON.software, tip: 'C/C++ next to loaded HDL, VITIS_SRC_PATH / SDK_SRC_PATH' },
];

export class LibrariesTreeProvider implements vscode.TreeDataProvider<LibElement> {
    private emitter = new vscode.EventEmitter<LibElement | undefined>();
    readonly onDidChangeTreeData = this.emitter.event;
    project?: RuckusProject;
    filter = '';
    showSim = true;

    refresh() { this.emitter.fire(undefined); }

    private all(): LoadedFile[] {
        const p = this.project;
        if (!p) { return []; }
        return [...p.files, ...p.software].filter(f => (this.showSim || !f.sim) && matchesFilter(f, this.filter));
    }

    private sectionFiles(s: Section): LoadedFile[] {
        const all = this.all();
        switch (s) {
            case 'submodules': case 'libraries': case 'packages': case 'tops': return all;
            case 'sim': return all.filter(f => f.sim && f.category !== 'software');
            default: return all.filter(f => f.category === s);
        }
    }

    private groups(s: Section): Map<string, LoadedFile[]> {
        const m = new Map<string, LoadedFile[]>();
        const add = (k: string, f: LoadedFile) => { if (!m.has(k)) { m.set(k, []); } m.get(k)!.push(f); };
        for (const f of this.sectionFiles(s)) {
            if (s === 'submodules') { add(f.origin, f); }
            else if (s === 'libraries') { if (f.category === 'vhdl') { add(f.lib || 'work', f); } }
            else { add(f.origin, f); }
        }
        return m;
    }

    getChildren(el?: LibElement): LibElement[] {
        const p = this.project;
        if (!p) { return []; }
        if (!el) {
            return SECTIONS.filter(s => this.sectionCount(s.section) > 0).map(s => ({ t: 'section', section: s.section }));
        }
        if (el.t === 'section') {
            const s = el.section;
            if (s === 'tops') {
                const tops = [...p.tops];
                if (!tops.some(t => t.fileset === 'sources_1')) {
                    tops.unshift({ fileset: 'sources_1', value: p.vars.PROJECT || p.target.name, file: p.target.makefile, line: 0 });
                }
                return tops.map(t => ({ t: 'top', ...t }));
            }
            if (s === 'packages') {
                return this.all().flatMap(f => f.packages.map(name => ({ name, file: f })))
                    .sort((a, b) => a.name.localeCompare(b.name))
                    .map(x => ({ t: 'package', ...x }));
            }
            const g = this.groups(s);
            // Flat list if everything comes from one origin
            if (s !== 'submodules' && s !== 'libraries' && g.size <= 1) {
                return this.sectionFiles(s).sort(byName).map(f => ({ t: 'file', file: f, showDir: true }));
            }
            return [...g.keys()].sort(originSort).map(key => ({ t: 'group', section: s, key }));
        }
        if (el.t === 'group') {
            return (this.groups(el.section).get(el.key) ?? []).sort(byName).map(f => ({ t: 'file', file: f, showDir: true }));
        }
        return [];
    }

    private sectionCount(s: Section): number {
        if (!this.project) { return 0; }
        if (s === 'tops') { return 1; }
        if (s === 'packages') { return this.all().reduce((n, f) => n + f.packages.length, 0); }
        if (s === 'libraries') { return this.all().filter(f => f.category === 'vhdl').length; }
        return this.sectionFiles(s).length;
    }

    getTreeItem(el: LibElement): vscode.TreeItem {
        const C = vscode.TreeItemCollapsibleState;
        const proj = this.project!;
        switch (el.t) {
            case 'section': {
                const def = SECTIONS.find(s => s.section === el.section)!;
                const it = new vscode.TreeItem(def.label, el.section === 'tops' ? C.Expanded : C.Collapsed);
                it.description = el.section === 'tops' ? '' : String(this.sectionCount(el.section));
                it.iconPath = new vscode.ThemeIcon(def.icon);
                it.tooltip = def.tip;
                it.id = `sec:${el.section}:${this.filter}`;
                return it;
            }
            case 'group': {
                const files = this.groups(el.section).get(el.key) ?? [];
                const label = el.section === 'libraries' ? el.key : originLabel(el.key);
                const it = new vscode.TreeItem(label, C.Collapsed);
                it.description = String(files.length);
                it.iconPath = new vscode.ThemeIcon(el.section === 'libraries' ? 'symbol-namespace' : el.key === 'target' ? 'target' : 'library');
                if (el.section === 'submodules') {
                    const dir = el.key === 'target' ? proj.target.dir : path.join(proj.modulesDir, el.key);
                    it.tooltip = dir;
                    it.resourceUri = vscode.Uri.file(dir);
                    it.contextValue = 'ruckus.dir';
                }
                it.id = `grp:${el.section}:${el.key}:${this.filter}`;
                return it;
            }
            case 'package': {
                const it = new vscode.TreeItem(el.name, C.None);
                it.description = `${path.basename(el.file.path)}${el.file.lib ? ' · ' + el.file.lib : ''}`;
                it.iconPath = new vscode.ThemeIcon('symbol-package');
                it.tooltip = el.file.path;
                it.resourceUri = vscode.Uri.file(el.file.path);
                it.contextValue = 'ruckus.file';
                it.command = { command: 'ruckus.openPackage', title: 'Open', arguments: [el.file.path, el.name] };
                return it;
            }
            case 'top': {
                const it = new vscode.TreeItem(el.value, C.None);
                it.description = el.fileset === 'sim_1' ? 'simulation (sim_1)' : 'synthesis (sources_1)';
                it.iconPath = new vscode.ThemeIcon(el.fileset === 'sim_1' ? 'beaker' : 'chip');
                it.command = { command: 'ruckus.openEntity', title: 'Open', arguments: [el.value] };
                it.tooltip = el.line ? `set_property top at ${el.file}:${el.line}` : 'Default: same name as the project (PROJECT)';
                return it;
            }
            case 'file':
                return fileItem(proj, el.file, el.showDir);
        }
    }
}

function byName(a: LoadedFile, b: LoadedFile) {
    return path.basename(a.path).localeCompare(path.basename(b.path));
}

function originSort(a: string, b: string) {
    const r = (o: string) => o === 'target' ? 0 : o === 'external' ? 3 : 1;
    return r(a) - r(b) || a.localeCompare(b);
}
