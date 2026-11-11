// "Project" view: the ruckus.tcl load hierarchy (or files grouped by origin).

import * as path from 'path';
import * as vscode from 'vscode';
import { Category, LoadedFile, Problem, RuckusNode, RuckusProject } from '../core/project';
import { CATEGORY_ICON, CATEGORY_LABEL, CATEGORY_ORDER, fileItem, matchesFilter, originLabel, relTo } from './common';

export type ProjectElement =
    | { t: 'summary' }
    | { t: 'node'; node: RuckusNode }
    | { t: 'file'; file: LoadedFile; showDir: boolean }
    | { t: 'problems' }
    | { t: 'problem'; problem: Problem }
    | { t: 'hooks' }
    | { t: 'hook'; path: string }
    | { t: 'origin'; origin: string }
    | { t: 'originCat'; origin: string; category: Category }
    | { t: 'software' }
    | { t: 'message'; text: string };

export class ProjectTreeProvider implements vscode.TreeDataProvider<ProjectElement> {
    private emitter = new vscode.EventEmitter<ProjectElement | undefined>();
    readonly onDidChangeTreeData = this.emitter.event;

    project?: RuckusProject;
    loading = false;
    grouping: 'hierarchy' | 'origin' = 'hierarchy';
    filter = '';
    showSim = true;

    refresh() { this.emitter.fire(undefined); }

    private visible(f: LoadedFile): boolean {
        return (this.showSim || !f.sim) && matchesFilter(f, this.filter);
    }

    /** Files of a node and its descendants that pass the filter */
    private countDeep(n: RuckusNode): number {
        let c = n.files.filter(f => this.visible(f)).length;
        for (const ch of n.children) { c += this.countDeep(ch); }
        return c;
    }

    getChildren(el?: ProjectElement): ProjectElement[] {
        const proj = this.project;
        if (!el) {
            if (this.loading && !proj) { return [{ t: 'message', text: 'Scanning ruckus.tcl tree...' }]; }
            if (!proj) { return []; }
            const out: ProjectElement[] = [{ t: 'summary' }];
            if (proj.problems.length) { out.push({ t: 'problems' }); }
            if (this.grouping === 'hierarchy') {
                if (proj.root) { out.push({ t: 'node', node: proj.root }); }
                if (proj.software.some(f => this.visible(f))) { out.push({ t: 'software' }); }
            } else {
                for (const o of proj.origins) {
                    if ([...proj.files, ...proj.software].some(f => f.origin === o && this.visible(f))) {
                        out.push({ t: 'origin', origin: o });
                    }
                }
            }
            if (proj.hooks.length) { out.push({ t: 'hooks' }); }
            return out;
        }
        switch (el.t) {
            case 'node': {
                const kids: ProjectElement[] = el.node.children
                    .filter(c => !this.filter || this.countDeep(c) > 0)
                    .map(c => ({ t: 'node', node: c }));
                const files = el.node.files.filter(f => this.visible(f)).sort(fileOrder);
                return [...kids, ...files.map(f => ({ t: 'file', file: f, showDir: false }) as ProjectElement)];
            }
            case 'problems':
                return (proj?.problems ?? []).map(p => ({ t: 'problem', problem: p }));
            case 'hooks':
                return (proj?.hooks ?? []).map(h => ({ t: 'hook', path: h }));
            case 'software':
                return (proj?.software ?? []).filter(f => this.visible(f)).map(f => ({ t: 'file', file: f, showDir: true }));
            case 'origin': {
                const cats = new Set([...proj!.files, ...proj!.software]
                    .filter(f => f.origin === el.origin && this.visible(f)).map(f => f.category));
                return CATEGORY_ORDER.filter(c => cats.has(c)).map(c => ({ t: 'originCat', origin: el.origin, category: c }));
            }
            case 'originCat':
                return [...proj!.files, ...proj!.software]
                    .filter(f => f.origin === el.origin && f.category === el.category && this.visible(f))
                    .sort((a, b) => path.basename(a.path).localeCompare(path.basename(b.path)))
                    .map(f => ({ t: 'file', file: f, showDir: true }));
            default:
                return [];
        }
    }

    getTreeItem(el: ProjectElement): vscode.TreeItem {
        const proj = this.project!;
        const C = vscode.TreeItemCollapsibleState;
        switch (el.t) {
            case 'message': {
                const it = new vscode.TreeItem(el.text, C.None);
                it.iconPath = new vscode.ThemeIcon('loading~spin');
                return it;
            }
            case 'summary': {
                const it = new vscode.TreeItem(proj.target.name, C.None);
                const sim = proj.tops.find(t => t.fileset === 'sim_1');
                it.description = [proj.part, proj.arch, proj.backend].filter(Boolean).join(' · ');
                it.iconPath = new vscode.ThemeIcon('target');
                const md = new vscode.MarkdownString();
                md.appendMarkdown(`**${proj.target.name}**\n\n`);
                md.appendMarkdown(`| | |\n|---|---|\n`);
                md.appendMarkdown(`| Part | ${proj.part || '?'} |\n| Architecture | ${proj.arch || '?'} |\n`);
                md.appendMarkdown(`| Version | ${proj.version || '?'} |\n| Backend | ${proj.backend} |\n`);
                md.appendMarkdown(`| Synthesis top | ${proj.tops.find(t => t.fileset === 'sources_1')?.value ?? proj.target.name} |\n`);
                if (sim) { md.appendMarkdown(`| Simulation top | ${sim.value} |\n`); }
                md.appendMarkdown(`| ruckus.tcl files | ${proj.nodes.size} |\n| Loaded files | ${proj.files.length} |\n`);
                md.appendMarkdown(`| Scan time | ${proj.scanMs} ms |\n`);
                it.tooltip = md;
                it.command = { command: 'ruckus.showInfo', title: 'Info' };
                it.contextValue = 'ruckus.summary';
                return it;
            }
            case 'node': {
                const n = el.node;
                const isRoot = n.id === proj.root?.id;
                const label = isRoot ? 'ruckus.tcl' : nodeLabel(proj, n);
                const it = new vscode.TreeItem(label, isRoot ? C.Expanded : C.Collapsed);
                it.resourceUri = vscode.Uri.file(path.join(n.dir, 'ruckus.tcl'));
                const total = this.countDeep(n);
                it.description = `${isRoot ? relTo(proj, n.dir) + ' · ' : ''}${total} file${total === 1 ? '' : 's'}${n.problems.length ? ` · ⚠ ${n.problems.length}` : ''}`;
                it.iconPath = new vscode.ThemeIcon(n.problems.length ? 'warning' : isRoot ? 'root-folder' : n.origin === n.dir ? 'library' : 'folder-library');
                it.tooltip = `${path.join(n.dir, 'ruckus.tcl')}\n${n.callFile ? `loaded by ${relTo(proj, n.callFile)}:${n.callLine}` : 'top level'}`;
                it.contextValue = 'ruckus.node';
                it.command = { command: 'vscode.open', title: 'Open', arguments: [vscode.Uri.file(path.join(n.dir, 'ruckus.tcl'))] };
                it.id = `node:${n.id}:${this.filter}`;
                return it;
            }
            case 'file': {
                const it = fileItem(proj, el.file, el.showDir);
                it.id = `file:${el.file.node}:${el.file.path}:${this.grouping}:${this.filter}`;
                return it;
            }
            case 'problems': {
                const it = new vscode.TreeItem('Load Problems', C.Expanded);
                it.description = String(proj.problems.length);
                it.iconPath = new vscode.ThemeIcon('error', new vscode.ThemeColor('problemsErrorIcon.foreground'));
                return it;
            }
            case 'problem': {
                const p = el.problem;
                const it = new vscode.TreeItem(p.msg, C.None);
                it.description = p.file ? `${relTo(proj, p.file)}:${p.line}` : '';
                it.iconPath = new vscode.ThemeIcon(p.severity === 'error' ? 'error' : 'warning');
                it.tooltip = p.msg;
                if (p.file) {
                    it.command = openAt(p.file, p.line);
                }
                return it;
            }
            case 'hooks': {
                const it = new vscode.TreeItem('Vivado Hook Scripts', C.Collapsed);
                it.description = `${proj.hooks.length} · vivado/`;
                it.iconPath = new vscode.ThemeIcon('plug');
                it.tooltip = 'Project-supplied Tcl scripts that ruckus runs at fixed points of the Vivado flow';
                return it;
            }
            case 'hook': {
                const it = new vscode.TreeItem(vscode.Uri.file(el.path), C.None);
                it.description = HOOK_DOCS[path.basename(el.path)] ?? '';
                it.command = { command: 'vscode.open', title: 'Open', arguments: [vscode.Uri.file(el.path)] };
                it.contextValue = 'ruckus.hook';
                return it;
            }
            case 'software': {
                const it = new vscode.TreeItem('C / C++ (not loaded by ruckus.tcl)', C.Collapsed);
                it.description = String(proj.software.filter(f => this.visible(f)).length);
                it.iconPath = new vscode.ThemeIcon('code');
                it.tooltip = 'C/C++ files next to loaded HDL (DPI-C / VHPI simulation models) and VITIS_SRC_PATH / SDK_SRC_PATH (MicroBlaze)';
                return it;
            }
            case 'origin': {
                const n = [...proj.files, ...proj.software].filter(f => f.origin === el.origin && this.visible(f)).length;
                const it = new vscode.TreeItem(originLabel(el.origin), el.origin === 'target' ? C.Expanded : C.Collapsed);
                it.description = `${n} files`;
                it.iconPath = new vscode.ThemeIcon(el.origin === 'target' ? 'target' : 'library');
                it.id = `origin:${el.origin}:${this.filter}`;
                return it;
            }
            case 'originCat': {
                const n = [...proj.files, ...proj.software].filter(f => f.origin === el.origin && f.category === el.category && this.visible(f)).length;
                const it = new vscode.TreeItem(CATEGORY_LABEL[el.category], C.Collapsed);
                it.description = String(n);
                it.iconPath = new vscode.ThemeIcon(CATEGORY_ICON[el.category]);
                it.id = `origincat:${el.origin}:${el.category}:${this.filter}`;
                return it;
            }
        }
    }

    getParent(el: ProjectElement): ProjectElement | undefined {
        if (el.t === 'node' && this.project) {
            const p = this.project.nodes.get(el.node.parent);
            return p ? { t: 'node', node: p } : undefined;
        }
        return undefined;
    }
}

export const HOOK_DOCS: Record<string, string> = {
    'sources.tcl': 'after sources are loaded',
    'project_setup.tcl': 'after project creation',
    'properties.tcl': 'project properties',
    'pre_synthesis.tcl': 'before synthesis',
    'post_synthesis.tcl': 'after synthesis',
    'post_route.tcl': 'after route (if timing met)',
    'post_build.tcl': 'after the build',
    'promgen.tcl': 'PROM generation settings',
    'messages.tcl': 'message severity overrides',
};

function nodeLabel(proj: RuckusProject, n: RuckusNode): string {
    const parent = proj.nodes.get(n.parent);
    if (parent && n.dir.startsWith(parent.dir + path.sep)) {
        return path.relative(parent.dir, n.dir);
    }
    // Jump to another tree (e.g. TOP_DIR/submodules/surf): show path from TOP_DIR
    return relTo(proj, n.dir);
}

const CAT_RANK = new Map(CATEGORY_ORDER.map((c, i) => [c, i]));

function fileOrder(a: LoadedFile, b: LoadedFile): number {
    return Number(a.sim) - Number(b.sim)
        || (CAT_RANK.get(a.category)! - CAT_RANK.get(b.category)!)
        || path.basename(a.path).localeCompare(path.basename(b.path));
}

export function openAt(file: string, line: number): vscode.Command {
    const l = Math.max(0, line - 1);
    return {
        command: 'vscode.open', title: 'Open',
        arguments: [vscode.Uri.file(file), { selection: new vscode.Range(l, 0, l, 0) } as vscode.TextDocumentShowOptions],
    };
}
