import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { findLogs, findSetupScript, findVivadoInstall, listVivadoVersions, parseSetupScript, vivadoVhdlLibraries } from './core/buildEnv';
import { enclosingTarget, findTargets, firmwareMakefile } from './core/discovery';
import { isRuckusTarget, loadProject, makeTarget, MakeTargetInfo, RuckusProject, RuckusTarget } from './core/project';
import { Design, DesignUnit } from './core/hdl/elaborate';
import { relTo } from './views/common';
import { hierUtilFile, routedCheckpoint } from './core/reports/locate';
import { LogReportView, ReportHost, ResourceView, TimingView } from './views/reportViews';
import { DesignElement, DesignTreeProvider, hierPath } from './views/designTree';
import { LibrariesTreeProvider } from './views/librariesTree';
import { MakeElement, MakeTreeProvider } from './views/makeTree';
import { ProjectElement, ProjectTreeProvider } from './views/projectTree';

const STATE_KEY = 'ruckus.selectedTarget';
const TASK_TYPE = 'ruckus';

let project: RuckusProject | undefined;
let design: Design | undefined;
let target: RuckusTarget | undefined;
let output: vscode.OutputChannel;
let diagnostics: vscode.DiagnosticCollection;
let status: vscode.StatusBarItem;
let vivadoStatus: vscode.StatusBarItem;
let scanSeq = 0;

export function activate(ctx: vscode.ExtensionContext) {
    output = vscode.window.createOutputChannel('Ruckus');
    diagnostics = vscode.languages.createDiagnosticCollection('ruckus');
    status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 50);
    status.command = 'ruckus.selectTarget';
    vivadoStatus = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 49);
    vivadoStatus.command = 'ruckus.selectVivadoVersion';
    ctx.subscriptions.push(output, diagnostics, status, vivadoStatus);

    const projectTree = new ProjectTreeProvider();
    const libTree = new LibrariesTreeProvider();
    const makeTree = new MakeTreeProvider();
    const designTree = new DesignTreeProvider();
    const cfg = () => vscode.workspace.getConfiguration('ruckus');
    projectTree.grouping = cfg().get('grouping', 'hierarchy');
    projectTree.showSim = libTree.showSim = designTree.showSim = cfg().get('showSimFiles', true);
    designTree.showProcesses = cfg().get('design.showProcesses', true);
    designTree.showGenerates = cfg().get('design.showGenerates', true);
    designTree.showPrimitives = cfg().get('design.showPrimitives', true);

    const projectView = vscode.window.createTreeView('ruckus.project', { treeDataProvider: projectTree, showCollapseAll: true });
    const libView = vscode.window.createTreeView('ruckus.libraries', { treeDataProvider: libTree, showCollapseAll: true });
    const makeView = vscode.window.createTreeView('ruckus.make', { treeDataProvider: makeTree, showCollapseAll: true });
    const designView = vscode.window.createTreeView('ruckus.design', { treeDataProvider: designTree, showCollapseAll: true });
    ctx.subscriptions.push(projectView, libView, makeView, designView);

    // ------------------------------------------------------------------
    // Build results (panel views next to the terminal)
    // ------------------------------------------------------------------
    const reportHost: ReportHost = {
        project: () => project,
        open: (file, line) => openLine(file, line),
        generateHierUtil: () => generateHierUtil(ctx),
    };
    const reportViews = [new LogReportView(ctx, reportHost), new TimingView(ctx, reportHost), new ResourceView(ctx, reportHost)];
    ['ruckus.logReport', 'ruckus.timing', 'ruckus.resources'].forEach((id, i) =>
        ctx.subscriptions.push(vscode.window.registerWebviewViewProvider(id, reportViews[i])));
    const updateReports = () => reportViews.forEach(v => v.update());
    ctx.subscriptions.push(vscode.tasks.onDidEndTaskProcess(e => { if (e.execution.task.source === 'ruckus') { updateReports(); } }));

    const updateAll = () => {
        projectTree.project = libTree.project = makeTree.project = project;
        makeTree.firmwareMakefile = project ? firmwareMakefile(project.topDir) : undefined;
        designTree.design = design;
        projectTree.refresh(); libTree.refresh(); makeTree.refresh(); designTree.refresh();
        const desc = project ? `${project.target.name}${project.part ? ' · ' + project.part : ''}` : undefined;
        projectView.description = desc;
        makeView.description = project?.target.name;
        designView.description = desc;
        designView.message = design && designTree.customTop ? `Custom top: ${designTree.customTop.name}` : undefined;
        vscode.commands.executeCommand('setContext', 'ruckus.customTop', !!designTree.customTop);
        if (project) {
            status.text = `$(circuit-board) ${project.target.name}`;
            status.tooltip = `Ruckus top level: ${project.target.dir}\nClick to change`;
            status.show();
        } else if (target) {
            status.text = `$(loading~spin) ${target.name}`;
            status.show();
        } else {
            status.text = '$(circuit-board) Select ruckus top level';
            status.show();
        }
        projectView.message = projectTree.filter ? `Filter: ${projectTree.filter}` : undefined;
        vscode.commands.executeCommand('setContext', 'ruckus.filterActive', !!projectTree.filter);
        vscode.commands.executeCommand('setContext', 'ruckus.hasProject', !!project);
        updateVivadoStatus();
        updateReports();
    };

    const updateVivadoStatus = () => {
        const setup = setupScript(project);
        if (!project || (!setup && project.backend !== 'vivado')) { vivadoStatus.hide(); return; }
        const v = cfg().get<string>('vivadoVersion', '');
        const def = setup ? parseSetupScript(setup).defaultVersion : undefined;
        const ignored = setup && v && !parseSetupScript(setup).takesVersionArg;
        vivadoStatus.text = `$(versions) Vivado ${ignored ? def ?? v : v || def || '(PATH)'}${ignored ? ' $(warning)' : ''}`;
        vivadoStatus.tooltip = (setup ? `make runs after: source ${setup}${v ? ' ' + v : ''}` : 'No setup script: make uses the Vivado found on PATH') +
            (ignored ? `\n${path.basename(setup!)} ignores its argument: the selected ${v} has no effect (make and the scan use ${def ?? 'the script\'s Vivado'})` : '') +
            '\nClick to select the Vivado version';
        vivadoStatus.show();
    };

    const scan = async (t: RuckusTarget, reveal = false) => {
        const seq = ++scanSeq;
        target = t;
        projectTree.loading = true;
        if (project && project.target.dir !== t.dir) { project = undefined; design = undefined; designTree.customTop = undefined; }
        updateAll();
        await vscode.window.withProgress({ location: { viewId: 'ruckus.project' }, title: 'Scanning ruckus.tcl' }, async () => {
            try {
                const c = cfg();
                const p = await loadProject(t, {
                    tclsh: c.get('tclsh', 'tclsh'),
                    scannerScript: ctx.asAbsolutePath(path.join('resources', 'ruckus_scan.tcl')),
                    extraEnv: c.get<Record<string, string>>('env', {}),
                    vivadoVersion: scanVivadoVersion(t),
                    timeoutMs: c.get('scanTimeout', 60000),
                });
                if (seq !== scanSeq) { return; }
                project = p;
                design = new Design(p);
                for (const e of design.errors) { output.appendLine(`  hdl: ${e}`); }
                output.appendLine(`[${new Date().toLocaleTimeString()}] ${t.name}: ${p.nodes.size} ruckus.tcl, ${p.files.length} files, ` +
                    `${p.problems.length} problems (${p.scanMs} ms, HDL parse ${design.parseMs} ms)`);
                for (const e of p.make.errors) { output.appendLine(`  makefile: ${e}`); }
                publishDiagnostics(p);
                if (p.problems.some(x => x.msg.includes('Tcl shell not found'))) {
                    vscode.window.showErrorMessage(p.problems[0].msg, 'Open Settings').then(a => {
                        if (a) { vscode.commands.executeCommand('workbench.action.openSettings', 'ruckus.tclsh'); }
                    });
                }
            } catch (e) {
                output.appendLine(`Scan failed: ${e instanceof Error ? e.stack : e}`);
                vscode.window.showErrorMessage(`Ruckus scan failed: ${e}`);
            } finally {
                if (seq === scanSeq) { projectTree.loading = false; updateAll(); }
            }
        });
        if (reveal) { vscode.commands.executeCommand('ruckus.design.focus'); }
    };

    const select = async (t: RuckusTarget) => {
        await ctx.workspaceState.update(STATE_KEY, t.dir);
        await scan(t, true);
    };

    const pickTarget = async () => {
        const roots = (vscode.workspace.workspaceFolders ?? []).map(f => f.uri.fsPath);
        const targets = await vscode.window.withProgress(
            { location: vscode.ProgressLocation.Window, title: 'Searching ruckus top levels' },
            () => findTargets(roots, cfg().get('targetSearchDepth', 6), cfg().get('excludeDirs', [])));
        type Item = vscode.QuickPickItem & { target?: RuckusTarget; browse?: boolean };
        const items: Item[] = targets.map(t => ({
            label: `$(circuit-board) ${t.name}`,
            description: t.dir === target?.dir ? '(current)' : '',
            detail: vscode.workspace.asRelativePath(t.dir),
            target: t,
        }));
        items.push({ label: '$(folder-opened) Browse...', browse: true, alwaysShow: true });
        const pick = await vscode.window.showQuickPick(items, {
            title: 'Select ruckus top level', placeHolder: targets.length ? 'Target directory' : 'No ruckus targets found in the workspace',
            matchOnDetail: true,
        });
        if (!pick) { return; }
        if (pick.browse) {
            const uri = await vscode.window.showOpenDialog({ canSelectFolders: true, canSelectFiles: false, openLabel: 'Use as top level' });
            if (!uri?.[0]) { return; }
            return useDir(uri[0].fsPath);
        }
        await select(pick.target!);
    };

    const useDir = async (dir: string) => {
        if (isRuckusTarget(dir)) { return select(makeTarget(dir)); }
        const enc = enclosingTarget(dir);
        if (enc) { return select(enc); }
        const inside = await findTargets([dir], 3, cfg().get('excludeDirs', []));
        if (inside.length === 1) { return select(inside[0]); }
        if (inside.length > 1) {
            const pick = await vscode.window.showQuickPick(inside.map(t => ({ label: t.name, detail: t.dir, t })), { title: 'Select ruckus top level' });
            if (pick) { return select(pick.t); }
            return;
        }
        if (fs.existsSync(path.join(dir, 'ruckus.tcl'))) {
            const a = await vscode.window.showWarningMessage(
                `${path.basename(dir)} has a ruckus.tcl but no Makefile including ruckus system_*.mk. Use it anyway?`, 'Use anyway');
            if (a) { return select(makeTarget(dir)); }
            return;
        }
        vscode.window.showWarningMessage(`No ruckus top level (Makefile + ruckus.tcl) found in ${dir}`);
    };

    // ------------------------------------------------------------------
    // Make execution
    // ------------------------------------------------------------------
    const runMake = async (name: string, cwd: string, args: string[] = []) => {
        const task = buildTask(name, cwd, args, project);
        await vscode.tasks.executeTask(task);
    };

    const makeArgs = (el: MakeElement | undefined): { name: string; cwd: string } | undefined => {
        if (el?.t === 'target') { return { name: el.target.name, cwd: el.cwd }; }
        return undefined;
    };

    const pickMakeTarget = async (): Promise<{ name: string; cwd: string } | undefined> => {
        if (!project) { await pickTarget(); }
        if (!project) { return; }
        const p = project;
        const pick = await vscode.window.showQuickPick(p.makeTargets.map((t: MakeTargetInfo) => ({
            label: t.name, description: t.description, detail: t.group,
        })), { title: `make ... (${p.target.name})` });
        return pick ? { name: pick.label, cwd: p.target.dir } : undefined;
    };

    // ------------------------------------------------------------------
    // Commands
    // ------------------------------------------------------------------
    const reg = (id: string, fn: (...a: any[]) => unknown) => ctx.subscriptions.push(vscode.commands.registerCommand(id, fn));

    reg('ruckus.selectTarget', pickTarget);
    reg('ruckus.selectTargetFromExplorer', (uri?: vscode.Uri) => uri ? useDir(uri.fsPath) : pickTarget());
    reg('ruckus.refresh', () => target ? scan(target) : pickTarget());
    reg('ruckus.toggleGrouping', () => {
        projectTree.grouping = projectTree.grouping === 'hierarchy' ? 'origin' : 'hierarchy';
        projectView.title = projectTree.grouping === 'hierarchy' ? 'Project' : 'Project (by origin)';
        projectTree.refresh();
    });
    reg('ruckus.toggleMakeGrouping', () => {
        makeTree.grouping = makeTree.grouping === 'common' ? 'makefile' : 'common';
        makeTree.refresh();
    });
    reg('ruckus.filter', async () => {
        const v = await vscode.window.showInputBox({
            title: 'Filter project files',
            prompt: 'Words match file or package names. Also: lib:<name>  ext:<vhd>  pkg:<name>  sim  !sim',
            value: projectTree.filter,
        });
        if (v === undefined) { return; }
        projectTree.filter = libTree.filter = v.trim();
        updateAll();
    });
    reg('ruckus.clearFilter', () => { projectTree.filter = libTree.filter = ''; updateAll(); });

    reg('ruckus.revealLoad', async (el?: ProjectElement | vscode.TreeItem) => {
        const loc = loadLocation(el);
        if (!loc) { return; }
        const doc = await vscode.workspace.openTextDocument(loc.file);
        const l = Math.max(0, loc.line - 1);
        await vscode.window.showTextDocument(doc, { selection: new vscode.Range(l, 0, l, doc.lineAt(Math.min(l, doc.lineCount - 1)).text.length) });
    });
    reg('ruckus.revealInExplorer', (el?: ProjectElement | vscode.TreeItem) => {
        const p = elementPath(el);
        if (p) { vscode.commands.executeCommand('revealInExplorer', vscode.Uri.file(p)); }
    });
    reg('ruckus.copyPath', (el?: ProjectElement | vscode.TreeItem) => {
        const p = elementPath(el);
        if (p) { vscode.env.clipboard.writeText(p); }
    });
    reg('ruckus.openPackage', (file: string, name: string) => openSymbol(file, new RegExp(`^\\s*package\\s+${name}\\b`, 'im')));
    reg('ruckus.openEntity', async (name: string) => {
        if (!project) { return; }
        const re = new RegExp(`^\\s*(entity|module)\\s+${name}\\b`, 'im');
        for (const f of project.files) {
            if (!['vhdl', 'verilog', 'systemverilog'].includes(f.category)) { continue; }
            if (path.basename(f.path, path.extname(f.path)).toLowerCase() !== name.toLowerCase()) { continue; }
            if (await openSymbol(f.path, re)) { return; }
        }
        for (const f of project.files) {
            if (['vhdl', 'verilog', 'systemverilog'].includes(f.category)) {
                try {
                    if (re.test(await fs.promises.readFile(f.path, 'latin1'))) { await openSymbol(f.path, re); return; }
                } catch { /* ignore */ }
            }
        }
        vscode.window.showInformationMessage(`Top module ${name} not found among loaded files`);
    });
    reg('ruckus.showInfo', () => showInfo());

    // ------------------------------------------------------------------
    // Design hierarchy
    // ------------------------------------------------------------------
    const pickUnit = async (title: string): Promise<DesignUnit | undefined> => {
        if (!design) { return; }
        const units = design.allUnits().sort((a, b) => a.name.localeCompare(b.name));
        const roots = new Set([...design.roots(false), ...design.roots(true)]);
        const items = units.map(u => ({
            label: `${roots.has(u) ? '$(star-full) ' : ''}${u.name}`,
            description: `${u.kind}${u.file.lib ? ' · ' + u.file.lib : ''}${u.file.sim ? ' · sim' : ''}`,
            detail: relTo(design!.project, u.file.path), u,
        }));
        // Uninstantiated units (likely tops / testbenches) first
        items.sort((a, b) => Number(roots.has(b.u)) - Number(roots.has(a.u)));
        const pick = await vscode.window.showQuickPick(items, { title, placeHolder: '★ = not instantiated anywhere (candidate top)', matchOnDetail: true });
        return pick?.u;
    };
    const setTop = (u: DesignUnit) => {
        designTree.customTop = { fileset: u.file.sim ? 'sim_1' : 'sources_1', name: u.name };
        updateAll();
    };
    reg('ruckus.design.setTop', async () => { const u = await pickUnit('Set design top'); if (u) { setTop(u); } });
    reg('ruckus.design.resetTop', () => { designTree.customTop = undefined; updateAll(); });
    reg('ruckus.design.setAsTop', (el?: DesignElement) => {
        if (el?.t === 'inst' && el.res.t === 'unit') { setTop(el.res.unit); }
        else if (el?.t === 'top' && el.unit) { setTop(el.unit); }
    });
    const toggle = (key: 'showProcesses' | 'showGenerates' | 'showPrimitives', setting: string) => {
        designTree[key] = !designTree[key];
        cfg().update(setting, designTree[key], vscode.ConfigurationTarget.Workspace);
        designTree.refresh();
    };
    reg('ruckus.design.toggleProcesses', () => toggle('showProcesses', 'design.showProcesses'));
    reg('ruckus.design.toggleGenerates', () => toggle('showGenerates', 'design.showGenerates'));
    reg('ruckus.design.togglePrimitives', () => toggle('showPrimitives', 'design.showPrimitives'));
    reg('ruckus.design.goToInstance', (el?: DesignElement) => {
        if (el?.t === 'inst') { openLine(el.ctx.path, el.inst.line); }
    });
    reg('ruckus.design.goToDefinition', (el?: DesignElement) => {
        if (el?.t === 'inst' && el.res.t === 'unit') { openLine(el.res.unit.file.path, el.res.unit.line); }
        else if (el?.t === 'inst' && (el.res.t === 'ip' || el.res.t === 'bd' || el.res.t === 'netlist')) { openLine(el.res.file.path, 1); }
        else if (el?.t === 'top' && el.unit) { openLine(el.unit.file.path, el.unit.line); }
    });
    reg('ruckus.design.copyPath', (el?: DesignElement) => { if (el) { vscode.env.clipboard.writeText(hierPath(el)); } });

    // Breadth-first search over the hierarchy (bounded), used by Find and Reveal
    const searchDesign = (pred: (el: DesignElement) => boolean, limit = 500): DesignElement[] => {
        const found: DesignElement[] = [];
        const queue: DesignElement[] = designTree.getChildren();
        let visited = 0;
        while (queue.length && found.length < limit && visited < 200000) {
            const el = queue.shift()!;
            visited++;
            if (pred(el)) { found.push(el); }
            queue.push(...designTree.getChildren(el));
        }
        return found;
    };
    reg('ruckus.design.find', async () => {
        if (!design) { return; }
        const q = await vscode.window.showInputBox({ title: 'Find in design hierarchy', prompt: 'Instance label or entity/module name (substring)' });
        if (!q) { return; }
        const lq = q.toLowerCase();
        const hits = searchDesign(el => (el.t === 'inst' && (el.inst.label.toLowerCase().includes(lq) || el.inst.ref.toLowerCase().includes(lq))) ||
            (el.t === 'proc' && el.label.toLowerCase().includes(lq)));
        if (!hits.length) { vscode.window.showInformationMessage(`No instance matching "${q}"`); return; }
        const pick = await vscode.window.showQuickPick(hits.map(h => ({
            label: h.t === 'inst' ? h.inst.label : (h as { label: string }).label,
            description: h.t === 'inst' ? h.inst.ref : 'process', detail: hierPath(h), h,
        })), { title: `${hits.length}${hits.length >= 500 ? '+' : ''} matches for "${q}"`, matchOnDetail: true });
        if (pick) { await designView.reveal(pick.h, { select: true, focus: true, expand: true }); }
    });
    reg('ruckus.design.revealActive', async () => {
        const f = vscode.window.activeTextEditor?.document.uri.fsPath;
        if (!f || !design) { return; }
        const hits = searchDesign(el => el.t === 'inst' && el.res.t === 'unit' && el.res.unit.file.path === f, 50);
        if (!hits.length) { vscode.window.showInformationMessage(`${path.basename(f)} is not instantiated in the current hierarchy`); return; }
        const target_ = hits.length === 1 ? hits[0] : (await vscode.window.showQuickPick(
            hits.map(h => ({ label: hierPath(h), h })), { title: `${path.basename(f)} is instantiated ${hits.length} times` }))?.h;
        if (target_) { await designView.reveal(target_, { select: true, focus: true, expand: false }); }
    });
    reg('ruckus.showScanLog', () => {
        if (!project) { return; }
        output.appendLine(`----- ruckus.tcl output for ${project.target.name} -----`);
        output.append(project.scanLog || '(empty)\n');
        output.show(true);
    });
    reg('ruckus.exportFileList', exportFileList);

    reg('ruckus.runMake', async (el?: MakeElement) => {
        const a = makeArgs(el) ?? await pickMakeTarget();
        if (a) { await runMake(a.name, a.cwd); }
    });
    reg('ruckus.runMakeWithArgs', async (el?: MakeElement) => {
        const a = makeArgs(el) ?? await pickMakeTarget();
        if (!a) { return; }
        const v = await vscode.window.showInputBox({
            title: `make ${a.name}`, prompt: 'Extra arguments, e.g. VIVADO_PROJECT_SIM=MyTb GIT_BYPASS=0 -j4',
            value: ctx.workspaceState.get<string>(`ruckus.args.${a.name}`, ''),
        });
        if (v === undefined) { return; }
        await ctx.workspaceState.update(`ruckus.args.${a.name}`, v);
        await runMake(a.name, a.cwd, splitShell(v));
    });
    reg('ruckus.runMakeCustom', async () => {
        if (!project) { await pickTarget(); }
        if (!project) { return; }
        const v = await vscode.window.showInputBox({
            title: `make (in ${project.target.name})`, prompt: 'Targets and arguments passed to make',
            value: ctx.workspaceState.get<string>('ruckus.customMake', ''),
        });
        if (!v) { return; }
        await ctx.workspaceState.update('ruckus.customMake', v);
        await runMake(v, project.target.dir, []);
    });
    // Simulate the entity/module of the active editor with the target's sim flow
    const simulateActive = async (askArgs: boolean) => {
        if (!project) { await pickTarget(); }
        const p = project;
        const f = vscode.window.activeTextEditor?.document.uri.fsPath;
        if (!p || !design || !f) { return; }
        let real = f;
        try { real = fs.realpathSync(f); } catch { /* keep */ }
        const units = design.allUnits().filter(u => u.file.path === f || u.file.path === real);
        if (!units.length) {
            vscode.window.showWarningMessage(`${path.basename(f)} is not loaded by ${p.target.name}'s ruckus.tcl (or defines no entity/module)`);
            return;
        }
        // Prefer testbenches when a file defines several units
        const tbs = units.filter(u => u.file.sim || /tb|test/i.test(u.name));
        const cands = tbs.length ? tbs : units;
        const unit = cands.length === 1 ? cands[0] : (await vscode.window.showQuickPick(
            cands.map(u => ({ label: u.name, description: u.kind, u })), { title: 'Unit to simulate' }))?.u;
        if (!unit) { return; }
        const sim = simGoal(p, unit.name, cfg().get('simulateTarget', 'xsim'));
        if (!sim) {
            vscode.window.showWarningMessage(`Simulating a single unit is not supported for the ${p.backend} backend`);
            return;
        }
        let extra: string[] = [];
        if (askArgs) {
            const key = `ruckus.simArgs.${sim.goal}`;
            const v = await vscode.window.showInputBox({
                title: `make ${sim.goal} ${sim.args.join(' ')}`, prompt: 'Extra arguments, e.g. VIVADO_PROJECT_SIM_TIME=10us GHDL_STOP_TIME=1us',
                value: ctx.workspaceState.get<string>(key, ''),
            });
            if (v === undefined) { return; }
            await ctx.workspaceState.update(key, v);
            extra = splitShell(v);
        }
        await runMake(sim.goal, p.target.dir, [...sim.args, ...extra]);
    };
    reg('ruckus.simulateActiveFile', () => simulateActive(false));
    reg('ruckus.simulateActiveFileWithArgs', () => simulateActive(true));
    reg('ruckus.setupWorkspace', () => project && setupWorkspace(project));
    reg('ruckus.showLogReport', () => vscode.commands.executeCommand('ruckus.logReport.focus'));
    reg('ruckus.showTiming', () => vscode.commands.executeCommand('ruckus.timing.focus'));
    reg('ruckus.showResources', () => vscode.commands.executeCommand('ruckus.resources.focus'));
    reg('ruckus.generateHierUtilization', () => generateHierUtil(ctx));

    reg('ruckus.selectVivadoVersion', async () => {
        const setup = setupScript(project);
        const info = setup ? parseSetupScript(setup) : { defaultVersion: undefined, installRoots: [], takesVersionArg: false };
        const current = cfg().get<string>('vivadoVersion', '');
        type Item = vscode.QuickPickItem & { value?: string };
        const items: Item[] = [{
            label: `$(discard) ${setup ? 'Setup script default' : 'Vivado on PATH'}`, value: '',
            description: info.defaultVersion ?? '', detail: setup ? `source ${setup}` : 'No setup script (setting ruckus.setupScript)',
        }];
        for (const v of listVivadoVersions(info.installRoots)) {
            items.push({ label: `${v === current ? '$(check) ' : ''}${v}`, value: v, description: v === info.defaultVersion ? 'script default' : '' });
        }
        items.push({ label: '$(edit) Other version...' });
        const pick = await vscode.window.showQuickPick(items, {
            title: 'Vivado version for make', placeHolder: setup ? `Passed as argument to ${path.basename(setup)}` : undefined,
        });
        if (!pick) { return; }
        let v = pick.value;
        if (v === undefined) {
            v = await vscode.window.showInputBox({ title: 'Vivado version', value: current, prompt: 'e.g. 2025.1', validateInput: x => !x || /^\d{4}\.\d+$/.test(x) ? undefined : 'Expected YYYY.N' });
            if (v === undefined) { return; }
        }
        await cfg().update('vivadoVersion', v || undefined, vscode.ConfigurationTarget.Workspace);
        if (!setup) {
            vscode.window.showWarningMessage('No setup script is sourced before make, so the version only affects the scan.', 'Open Settings').then(a => {
                if (a) { vscode.commands.executeCommand('workbench.action.openSettings', 'ruckus.setupScript'); }
            });
        }
    });
    reg('ruckus.followLog', async () => {
        if (!project) { return; }
        const p = project;
        const outDir = p.vars.OUT_DIR || path.join(p.topDir, 'build', p.target.name);
        // Make output saved by the task, then Vivado's own logs (vivado.log, runs/*/runme.log, ...)
        const makeLogs = findLogs(path.join(p.topDir, 'build', 'logs'), 0).filter(l => path.basename(l.file).startsWith(`${p.target.name}_`));
        const logs = [...makeLogs, ...findLogs(outDir)].sort((a, b) => b.mtime - a.mtime);
        if (!logs.length) { vscode.window.showInformationMessage(`No log files yet in ${outDir}`); return; }
        const openBtn = { iconPath: new vscode.ThemeIcon('go-to-file'), tooltip: 'Open in editor' };
        const qp = vscode.window.createQuickPick<vscode.QuickPickItem & { file: string }>();
        qp.title = `Follow log (${p.target.name})`;
        qp.matchOnDetail = true;
        qp.items = logs.map(l => ({
            label: path.basename(l.file), file: l.file, buttons: [openBtn],
            description: `${new Date(l.mtime).toLocaleString()} · ${(l.size / 1024).toFixed(0)} KiB`,
            detail: path.relative(p.topDir, l.file),
        }));
        qp.onDidTriggerItemButton(e => { qp.hide(); vscode.window.showTextDocument(vscode.Uri.file(e.item.file), { preview: false }); });
        qp.onDidAccept(() => {
            const it = qp.selectedItems[0];
            qp.hide();
            if (!it) { return; }
            const term = vscode.window.createTerminal({ name: `log: ${it.label}`, shellPath: '/bin/bash', shellArgs: ['-c', `tail -n 1000 -F ${quote(it.file)}`] });
            term.show();
        });
        qp.onDidHide(() => qp.dispose());
        qp.show();
    });
    reg('ruckus.openMakeTarget', (el?: MakeElement) => {
        if (el?.t === 'target') {
            const l = Math.max(0, el.target.line - 1);
            vscode.window.showTextDocument(vscode.Uri.file(el.target.file), { selection: new vscode.Range(l, 0, l, 0) });
        }
    });

    // Tasks: makes `ruckus` tasks in tasks.json runnable and lists common targets
    ctx.subscriptions.push(vscode.tasks.registerTaskProvider(TASK_TYPE, {
        provideTasks: () => {
            if (!project) { return []; }
            const common: string[] = cfg().get('commonMakeTargets', []);
            return project.makeTargets.filter(t => common.includes(t.name)).map(t => buildTask(t.name, project!.target.dir, [], project));
        },
        resolveTask: (task) => {
            const d = task.definition as { target?: string; dir?: string; args?: string[] };
            if (!d.target) { return undefined; }
            const dir = d.dir ? resolveVars(d.dir, project) : project?.target.dir;
            if (!dir) { return undefined; }
            return buildTask(d.target, dir, (d.args ?? []).map(a => resolveVars(a, project)), project, task.definition);
        },
    }));

    // Rescan when a ruckus.tcl / Makefile / .mk in the project changes
    let timer: NodeJS.Timeout | undefined;
    const onFsChange = (uri: vscode.Uri) => {
        if (!target || !project) { return; }
        const p = uri.fsPath;
        // An edited HDL file only needs a re-parse (Design caches unchanged files)
        let real = p;
        try { real = fs.realpathSync(p); } catch { /* deleted */ }
        if (/\.(vhdl?|s?v|svh?)$/i.test(p) && project.files.some(f => f.path === p || f.path === real)) {
            if (timer) { clearTimeout(timer); }
            timer = setTimeout(() => { if (project) { design = new Design(project); updateAll(); } }, 800);
            return;
        }
        const relevant = [...project.nodes.values()].some(n => path.join(n.dir, 'ruckus.tcl') === p) ||
            project.make.files.includes(p) ||
            (path.basename(p) === 'ruckus.tcl' && p.startsWith(project.topDir));
        const dirLoaded = [...project.nodes.values()].some(n => p.startsWith(n.dir + path.sep)) && /\.(vhdl?|s?v|svh?|xdc|xci|xcix|bd|dcp|c|cc|h)$/i.test(p);
        if (!relevant && !dirLoaded) { return; }
        if (timer) { clearTimeout(timer); }
        timer = setTimeout(() => target && scan(target), 1500);
    };
    const watcher = vscode.workspace.createFileSystemWatcher('**/{ruckus.tcl,Makefile,*.mk,*.vhd,*.vhdl,*.v,*.sv,*.svh,*.vh,*.xdc,*.xci,*.xcix,*.bd}');
    watcher.onDidChange(onFsChange); watcher.onDidCreate(onFsChange); watcher.onDidDelete(onFsChange);
    ctx.subscriptions.push(watcher);

    ctx.subscriptions.push(vscode.workspace.onDidChangeConfiguration(e => {
        if (e.affectsConfiguration('ruckus.showSimFiles')) {
            projectTree.showSim = libTree.showSim = designTree.showSim = cfg().get('showSimFiles', true);
            updateAll();
        }
        if (e.affectsConfiguration('ruckus.grouping')) {
            projectTree.grouping = cfg().get('grouping', 'hierarchy');
            projectTree.refresh();
        }
        if (e.affectsConfiguration('ruckus.commonMakeTargets')) { makeTree.refresh(); }
        if (e.affectsConfiguration('ruckus.showProblems') && project) { publishDiagnostics(project); }
        if (e.affectsConfiguration('ruckus.vivadoVersion') || e.affectsConfiguration('ruckus.setupScript') ||
            e.affectsConfiguration('ruckus.autoSourceSetupScript')) { updateVivadoStatus(); }
        if ((e.affectsConfiguration('ruckus.env') || e.affectsConfiguration('ruckus.tclsh') ||
             e.affectsConfiguration('ruckus.vivadoVersion')) && target) { scan(target); }
    }));

    // Restore the last selection, or auto-select if there is exactly one target
    const saved = ctx.workspaceState.get<string>(STATE_KEY);
    if (saved && fs.existsSync(saved)) {
        scan(makeTarget(saved));
    } else {
        updateAll();
        const roots = (vscode.workspace.workspaceFolders ?? []).map(f => f.uri.fsPath);
        findTargets(roots, cfg().get('targetSearchDepth', 6), cfg().get('excludeDirs', [])).then(ts => {
            if (ts.length === 1 && !target) { select(ts[0]); }
            else if (roots.length === 1 && isRuckusTarget(roots[0]) && !target) { select(makeTarget(roots[0])); }
        });
    }

    // API used by the integration test
    return { getProject: () => project, getDesign: () => design, projectTree, libTree, makeTree, designTree, buildTask, selectDir: useDir, vhdlLsToml };
}

export function deactivate() { /* nothing */ }

// ----------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------

// Targets that need a terminal for stdout (Vivado GUI / Tcl shell): not piped through tee
const INTERACTIVE_TARGETS = ['gui', 'interactive'];

function buildTask(name: string, cwd: string, args: string[], proj: RuckusProject | undefined,
    definition?: vscode.TaskDefinition): vscode.Task {
    const cfg = vscode.workspace.getConfiguration('ruckus');
    const make = cfg.get('makeCommand', 'make');
    const words = splitShell(name);
    // ${input:...} (tasks.json prompts) is substituted by VS Code and split by the shell
    const makeLine = [make, ...words, ...args].map(a => /^\$\{input:[\w.-]+\}$/.test(a) ? a : quote(a)).join(' ');
    const steps = envSteps(proj, !proj || proj.backend === 'vivado');
    const log = cfg.get('saveMakeLog', true) && proj && !INTERACTIVE_TARGETS.includes(words[0]) ? makeLogFile(proj, words[0] ?? 'make') : undefined;
    if (log) {
        steps.push(`mkdir -p ${quote(path.dirname(log))}`, `echo ${quote('==> log: ' + log)}`, `echo ${quote('==> ' + makeLine)}`,
            `${makeLine} 2>&1 | tee ${quote(log)}`);
    } else {
        steps.push(`echo ${quote('==> ' + makeLine)}`, makeLine);
    }
    const line = steps.join('; ');
    const def = definition ?? { type: TASK_TYPE, target: name, dir: cwd, args };
    const label = `${name}${args.length ? ' ' + args.join(' ') : ''}`;
    // setup_env_slac.sh scripts are written for bash
    const shellExec = new vscode.ShellExecution(line, { cwd, executable: '/bin/bash', shellArgs: ['-c'] });
    const task = new vscode.Task(def, vscode.TaskScope.Workspace, `${label} (${path.basename(cwd)})`, 'ruckus', shellExec, problemMatchers(proj));
    task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Dedicated, clear: true };
    if (['bit', 'prom', 'mcs', 'pdi', 'syn', 'dcp', 'target', 'all', 'build'].includes(name)) {
        task.group = vscode.TaskGroup.Build;
    }
    if (['xsim', 'vcs', 'msim'].includes(name)) { task.group = vscode.TaskGroup.Test; }
    return task;
}

/** Shell steps that source the setup script (and check for vivado) before a command */
function envSteps(proj: RuckusProject | undefined, needVivado: boolean): string[] {
    const setup = setupScript(proj);
    const version = vscode.workspace.getConfiguration('ruckus').get<string>('vivadoVersion', '');
    const steps: string[] = ['set -o pipefail'];
    if (setup) {
        // Opt-in convention: a setup script that reads $1 gets the selected Vivado version
        const src = `source ${quote(setup)}${version ? ' ' + quote(version) : ''}`;
        steps.push(`echo ${quote('==> ' + src)}`, `${src} || echo ${quote(`warning: ${path.basename(setup)} returned an error`)}`);
        if (version && !parseSetupScript(setup).takesVersionArg) {
            steps.push(`echo ${quote(`warning: ${path.basename(setup)} ignores its argument, so ruckus.vivadoVersion=${version} has no effect on make`)}`);
        }
    }
    if (needVivado) {
        steps.push(`if command -v vivado >/dev/null; then echo "==> vivado: $(command -v vivado)"; ` +
            `else echo ${quote('warning: vivado not found on PATH (configure ruckus.setupScript / ruckus.vivadoVersion)')}; fi`);
    }
    return steps;
}

/** Runs Vivado in batch mode on the routed checkpoint to write the hierarchical utilization report */
async function generateHierUtil(ctx: vscode.ExtensionContext) {
    const p = project;
    if (!p) { return; }
    const dcp = routedCheckpoint(p);
    if (!dcp) { vscode.window.showWarningMessage(`No implemented design for ${p.target.name} yet: run make bit first.`); return; }
    const rpt = hierUtilFile(p);
    const depth = vscode.workspace.getConfiguration('ruckus').get<number>('hierUtilizationDepth', 8);
    const script = ctx.asAbsolutePath(path.join('resources', 'ruckus_hier_util.tcl'));
    const tmp = path.join(path.dirname(rpt), '.ruckus_hier_util');
    // Separate directory: Vivado's .Xil / journal files must not disturb the project
    const cmd = `mkdir -p ${quote(tmp)} && cd ${quote(tmp)} && vivado -mode batch -nojournal -nolog -notrace -source ${quote(script)} -tclargs ${quote(dcp)} ${quote(rpt)} ${depth}`;
    const steps = [...envSteps(p, true), `echo ${quote('==> ' + cmd)}`, cmd];
    const task = new vscode.Task({ type: TASK_TYPE, target: 'hierarchical-utilization', dir: p.target.dir }, vscode.TaskScope.Workspace,
        `hierarchical utilization (${p.target.name})`, 'ruckus',
        new vscode.ShellExecution(steps.join('; '), { cwd: p.target.dir, executable: '/bin/bash', shellArgs: ['-c'] }));
    task.presentationOptions = { reveal: vscode.TaskRevealKind.Silent, panel: vscode.TaskPanelKind.Dedicated, clear: true };
    await vscode.tasks.executeTask(task);
    vscode.window.setStatusBarMessage(`$(sync~spin) Ruckus: generating hierarchical utilization of ${path.basename(dcp)}...`,
        new Promise<void>(res => { const d = vscode.tasks.onDidEndTask(e => { if (e.execution.task === task || e.execution.task.name === task.name) { d.dispose(); res(); } }); }));
}

/** make goal + variables that simulate `unit` instead of the target's default sim top */
function simGoal(p: RuckusProject, unit: string, vivadoSim: string): { goal: string; args: string[] } | undefined {
    const has = (g: string) => p.makeTargets.some(t => t.name === g);
    switch (p.backend) {
        case 'vivado': return has(vivadoSim) ? { goal: vivadoSim, args: [`VIVADO_PROJECT_SIM=${unit}`] } : undefined;
        // GHDL elaborates $(PROJECT); this also moves OUT_DIR to build/<unit>
        case 'ghdl': return has('tb') ? { goal: 'tb', args: [`PROJECT=${unit}`] } : undefined;
        case 'iverilog':
        case 'verilator': return has('tb') ? { goal: 'tb', args: [`SIM_TOP=${unit}`] } : undefined;
        default: return undefined;
    }
}

/** Problem matchers (package.json) for the tools a backend runs */
function problemMatchers(proj: RuckusProject | undefined): string[] {
    switch (proj?.backend) {
        case 'ghdl': return ['$ruckus-ghdl', '$ruckus-ghdl-run-error', '$ruckus-ghdl-run-warning'];
        case 'iverilog': return ['$ruckus-iverilog'];
        case 'verilator': return ['$ruckus-verilator'];
        default: return ['$ruckus-vivado'];
    }
}

/** Copy of the make output, kept outside OUT_DIR so `make clean` does not delete it */
function makeLogFile(proj: RuckusProject, goal: string): string {
    return path.join(proj.topDir, 'build', 'logs', `${proj.target.name}_${goal.replace(/[^\w.-]/g, '_')}.log`);
}

function setupScript(proj: RuckusProject | undefined): string | undefined {
    const cfg = vscode.workspace.getConfiguration('ruckus');
    const s = cfg.get<string>('setupScript', '');
    if (s) { return resolveVars(s, proj); }
    if (cfg.get('autoSourceSetupScript', true) && proj) { return findSetupScript(proj.topDir, 1); }
    return undefined;
}

/** VIVADO_VERSION assumed by the scan: the version make will use */
function scanVivadoVersion(t: RuckusTarget): string {
    const cfg = vscode.workspace.getConfiguration('ruckus');
    const v = cfg.get<string>('vivadoVersion', '');
    const s = cfg.get<string>('setupScript', '');
    // The project of t may not be loaded yet: derive ${topDir} from the target directory
    const topDir = project?.target.dir === t.dir ? project.topDir : path.resolve(t.dir, '..', '..');
    const script = s ? resolveVars(s, { topDir, target: t }) : cfg.get('autoSourceSetupScript', true) ? findSetupScript(topDir, 1) : undefined;
    const info = script ? parseSetupScript(script) : undefined;
    // A script that ignores $1 fixes the version make uses: scan with that one
    if (v && (!info || info.takesVersionArg)) { return v; }
    return info?.defaultVersion || v || '2024.2';
}

function resolveVars(s: string, proj: { topDir: string; target: { dir: string } } | undefined): string {
    const ws = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? '';
    const version = vscode.workspace.getConfiguration('ruckus').get<string>('vivadoVersion', '');
    const file = vscode.window.activeTextEditor?.document.uri.fsPath ?? '';
    return s.replace(/\$\{fileBasenameNoExtension\}/g, file ? path.basename(file, path.extname(file)) : '')
        .replace(/\$\{file\}/g, file)
        .replace(/\$\{topDir\}/g, proj?.topDir ?? '')
        .replace(/\$\{vivadoVersion\}/g, version)
        .replace(/\$\{targetDir\}/g, proj?.target.dir ?? '')
        .replace(/\$\{workspaceFolder\}/g, ws);
}

function quote(s: string): string {
    return /^[\w@%+=:,./-]+$/.test(s) ? s : `'${s.replace(/'/g, `'\\''`)}'`;
}

function splitShell(s: string): string[] {
    const out: string[] = [];
    const re = /"([^"]*)"|'([^']*)'|(\S+)/g;
    let m: RegExpExecArray | null;
    while ((m = re.exec(s)) !== null) { out.push(m[1] ?? m[2] ?? m[3]); }
    return out;
}

function publishDiagnostics(p: RuckusProject) {
    diagnostics.clear();
    if (!vscode.workspace.getConfiguration('ruckus').get('showProblems', true)) { return; }
    const byFile = new Map<string, vscode.Diagnostic[]>();
    for (const pr of p.problems) {
        if (!pr.file) { continue; }
        const l = Math.max(0, pr.line - 1);
        const d = new vscode.Diagnostic(new vscode.Range(l, 0, l, 1000), pr.msg,
            pr.severity === 'error' ? vscode.DiagnosticSeverity.Error : vscode.DiagnosticSeverity.Warning);
        d.source = 'ruckus';
        if (!byFile.has(pr.file)) { byFile.set(pr.file, []); }
        byFile.get(pr.file)!.push(d);
    }
    for (const [f, ds] of byFile) { diagnostics.set(vscode.Uri.file(f), ds); }
}

function loadLocation(el?: ProjectElement | vscode.TreeItem): { file: string; line: number } | undefined {
    if (!el) { return undefined; }
    if ('t' in el) {
        if (el.t === 'file' && el.file.file) { return { file: el.file.file, line: el.file.line }; }
        if (el.t === 'node' && el.node.callFile) { return { file: el.node.callFile, line: el.node.callLine }; }
        if (el.t === 'node') { return { file: path.join(el.node.dir, 'ruckus.tcl'), line: 1 }; }
    }
    // Elements of the libraries view: look the file up in the model
    const p = elementPath(el);
    const f = p ? project?.files.find(x => x.path === p) ?? project?.software.find(x => x.path === p) : undefined;
    return f?.file ? { file: f.file, line: f.line } : undefined;
}

function elementPath(el?: ProjectElement | vscode.TreeItem | { t: string; file?: unknown }): string | undefined {
    if (!el) { return undefined; }
    const e = el as Record<string, any>;
    if (e.t === 'file') { return e.file.path; }
    if (e.t === 'node') { return e.node.dir; }
    if (e.t === 'package') { return e.file.path; }
    if (e.t === 'group' && e.section === 'submodules' && project) {
        return e.key === 'target' ? project.target.dir : path.join(project.modulesDir, e.key);
    }
    if (e.resourceUri) { return (e.resourceUri as vscode.Uri).fsPath; }
    return undefined;
}

async function openLine(file: string, line: number) {
    const l = Math.max(0, line - 1);
    await vscode.window.showTextDocument(vscode.Uri.file(file), { selection: new vscode.Range(l, 0, l, 0) });
}

async function openSymbol(file: string, re: RegExp): Promise<boolean> {
    try {
        const text = await fs.promises.readFile(file, 'latin1');
        const m = re.exec(text);
        const line = m ? text.slice(0, m.index + (m[0].length - m[0].trimStart().length)).split('\n').length - 1 : 0;
        await vscode.window.showTextDocument(vscode.Uri.file(file), { selection: new vscode.Range(line, 0, line, 0) });
        return !!m;
    } catch {
        return false;
    }
}

async function showInfo() {
    const p = project;
    if (!p) { return; }
    const lines: string[] = [];
    lines.push(`# ${p.target.name}`, '');
    lines.push('| | |', '|---|---|');
    lines.push(`| Target dir | \`${p.target.dir}\` |`);
    lines.push(`| Firmware dir (TOP_DIR) | \`${p.topDir}\` |`);
    lines.push(`| Part | ${p.part} |`, `| Architecture | ${p.arch} |`, `| Version | ${p.version} |`, `| Backend | ${p.backend} |`);
    for (const t of p.tops) { lines.push(`| Top (${t.fileset}) | ${t.value} |`); }
    lines.push(`| ruckus.tcl files | ${p.nodes.size} |`, `| Loaded files | ${p.files.length} |`, `| Scan | ${p.scanMs} ms |`, '');
    lines.push('## Files per origin', '', '| Origin | HDL | Constraints | IP | Sim | Other |', '|---|---|---|---|---|---|');
    for (const o of p.origins) {
        const fs_ = p.files.filter(f => f.origin === o);
        const hdl = fs_.filter(f => ['vhdl', 'verilog', 'systemverilog', 'header'].includes(f.category) && !f.sim).length;
        lines.push(`| ${o} | ${hdl} | ${fs_.filter(f => f.category === 'constraint').length} | ${fs_.filter(f => f.category === 'ip').length} | ` +
            `${fs_.filter(f => f.sim).length} | ${fs_.length - hdl - fs_.filter(f => f.category === 'constraint' || f.category === 'ip' || f.sim).length} |`);
    }
    lines.push('', '## Makefile variables', '', '```make');
    for (const [k, v] of Object.entries(p.vars).sort()) { if (v && !k.startsWith('.') && !k.includes('TOKEN')) { lines.push(`${k} = ${v}`); } }
    lines.push('```');
    if (p.problems.length) {
        lines.push('', '## Problems', '');
        for (const pr of p.problems) { lines.push(`- **${pr.severity}** ${pr.msg} — \`${relTo(p, pr.file)}:${pr.line}\``); }
    }
    const doc = await vscode.workspace.openTextDocument({ language: 'markdown', content: lines.join('\n') });
    await vscode.window.showTextDocument(doc, { preview: true });
}

async function exportFileList() {
    const p = project;
    if (!p) { return; }
    type Fmt = { label: string; ext: string; gen: () => string };
    const hdl = p.files.filter(f => ['vhdl', 'verilog', 'systemverilog', 'header'].includes(f.category));
    const formats: Fmt[] = [
        { label: 'Plain list (all files)', ext: 'txt', gen: () => p.files.map(f => f.path).join('\n') + '\n' },
        {
            label: 'CSV (path, kind, library, sim, origin, loaded by)', ext: 'csv', gen: () =>
                'path,category,library,sim,origin,loaded_by\n' +
                [...p.files, ...p.software].map(f => [f.path, f.category, f.lib, f.sim ? 1 : 0, f.origin, `${f.file}:${f.line}`].join(',')).join('\n') + '\n',
        },
        {
            label: 'VHDL_LS (vhdl_ls.toml)', ext: 'toml', gen: () => vhdlLsToml(p),
        },
        {
            label: 'Verilog .f file list (Verilator / Icarus / Verible)', ext: 'f', gen: () => {
                const v = hdl.filter(f => f.category !== 'vhdl');
                const incs = [...new Set(v.filter(f => f.category === 'header').map(f => path.dirname(f.path)))];
                return [...incs.map(d => `+incdir+${d}`), ...v.filter(f => f.category !== 'header').map(f => f.path)].join('\n') + '\n';
            },
        },
    ];
    const pick = await vscode.window.showQuickPick(formats, { title: 'Export file list' });
    if (!pick) { return; }
    const defName = pick.ext === 'toml' ? 'vhdl_ls.toml' : `${p.target.name}_files.${pick.ext}`;
    const uri = await vscode.window.showSaveDialog({ defaultUri: vscode.Uri.file(path.join(pick.ext === 'toml' ? p.topDir : p.target.dir, defName)) });
    if (!uri) { return; }
    await fs.promises.writeFile(uri.fsPath, pick.gen());
    vscode.window.showInformationMessage(`Wrote ${uri.fsPath}`);
}

// VHDL_LS reserves "work" (it means "the library of the current file"): files
// loaded without -lib go to Vivado's default library instead
const VHDL_DEFAULT_LIB = 'xil_defaultlib';

function vhdlLsToml(p: RuckusProject): string {
    const libs = new Map<string, string[]>();
    for (const f of p.files.filter(x => x.category === 'vhdl')) {
        const l = !f.lib || f.lib.toLowerCase() === 'work' ? VHDL_DEFAULT_LIB : f.lib;
        if (!libs.has(l)) { libs.set(l, []); }
        libs.get(l)!.push(f.path);
    }
    const toml = (s: string) => JSON.stringify(s);
    const out = ['[libraries]', ''];
    for (const [l, fs_] of libs) { out.push(`${l}.files = [`, ...fs_.map(x => `  ${toml(x)},`), ']', ''); }
    const cfg = vscode.workspace.getConfiguration('ruckus');
    const vivado = findVivadoInstall(cfg.get<string>('vivadoPath', ''), setupScript(p), cfg.get<string>('vivadoVersion', ''));
    if (vivado) {
        out.push(`# Xilinx simulation libraries of ${vivado}`);
        for (const [l, fs_] of Object.entries(vivadoVhdlLibraries(vivado))) {
            if (libs.has(l)) { continue; }
            out.push(`${l}.files = [`, ...fs_.map(x => `  ${toml(x)},`), ']', `${l}.is_third_party = true`, '');
        }
    } else {
        out.push('# unisim / unimacro / xpm: Vivado installation not found (setting ruckus.vivadoPath)', '');
    }
    return out.join('\n');
}

// ----------------------------------------------------------------------
// Workspace setup (.vscode/settings.json, .vscode/tasks.json, vhdl_ls.toml)
// ----------------------------------------------------------------------

/** Python package directories of the firmware: submodules/<x>/python and <repo>/{python,software/python} */
function pythonPaths(p: RuckusProject): string[] {
    const out: string[] = [];
    const add = (d: string) => { if (fs.existsSync(d) && !out.includes(d)) { out.push(d); } };
    let mods: string[] = [];
    try { mods = fs.readdirSync(p.modulesDir).sort(); } catch { /* none */ }
    for (const m of mods) { add(path.join(p.modulesDir, m, 'python')); }
    const repo = path.dirname(p.topDir);
    for (const d of [path.join(p.topDir, 'python'), path.join(repo, 'python'), path.join(repo, 'software', 'python')]) { add(d); }
    return out;
}

/** Path relative to the workspace folder, as ${workspaceFolder}/... when inside it */
function wsPath(ws: string, p: string): string {
    const r = path.relative(ws, p);
    return r.startsWith('..') || path.isAbsolute(r) ? p : r ? `\${workspaceFolder}/${r}` : '\${workspaceFolder}';
}

function workspaceSettings(p: RuckusProject, ws: string): Record<string, unknown> {
    const py = pythonPaths(p).map(d => wsPath(ws, d));
    const build = path.relative(ws, path.join(p.topDir, 'build'));
    const glob = build.startsWith('..') ? '**/build' : build;
    const s: Record<string, unknown> = {
        // Vivado build trees hold 100k+ files: keep them out of the file watcher and search
        'files.watcherExclude': { [`${glob}/**`]: true, '**/.Xil/**': true },
        'search.exclude': { [`${glob}/**`]: true, '**/.Xil/**': true },
        'files.associations': { 'ruckus.tcl': 'tcl', '*.xdc': 'tcl' },
    };
    if (py.length) {
        s['python.analysis.extraPaths'] = py;
        s['terminal.integrated.env.linux'] = { PYTHONPATH: [...py, '${env:PYTHONPATH}'].join(':') };
        s['terminal.integrated.env.osx'] = { PYTHONPATH: [...py, '${env:PYTHONPATH}'].join(':') };
    }
    return s;
}

function workspaceTasks(p: RuckusProject, ws: string): { inputs: Record<string, unknown>[]; tasks: Record<string, unknown>[] } {
    const dir = wsPath(ws, p.target.dir);
    const name = p.target.name;
    const has = (g: string) => p.makeTargets.some(t => t.name === g);
    const tasks: Record<string, unknown>[] = [];
    const task = (label: string, target: string, args: string[], group?: Record<string, unknown>) =>
        tasks.push({ label: `ruckus: ${label} (${name})`, type: 'ruckus', target, dir, ...(args.length ? { args } : {}), ...(group ? { group } : {}) });
    const sim = simGoal(p, '${fileBasenameNoExtension}', vscode.workspace.getConfiguration('ruckus').get('simulateTarget', 'xsim'));
    if (p.backend === 'vivado') {
        if (has('bit')) { task('bitstream', 'bit', [], { kind: 'build', isDefault: true }); }
        if (has('syn')) { task('synthesis only', 'syn', []); }
        if (has('xsim')) { task('xsim (sim_1 top)', 'xsim', []); }
        if (has('gui')) { task('Vivado GUI', 'gui', []); }
    } else if (has('tb')) {
        task('testbench', 'tb', [], { kind: 'test', isDefault: true });
        if (has('gtkwave')) { task('testbench + GTKWave', 'gtkwave', []); }
    }
    if (sim) {
        task('simulate current file', sim.goal, sim.args, p.backend === 'vivado' ? { kind: 'test', isDefault: true } : undefined);
        task('simulate current file with variables', sim.goal, [...sim.args, '${input:ruckusMakeVars}']);
    }
    if (has('clean')) { task('clean', 'clean', []); }
    return {
        inputs: [{
            id: 'ruckusMakeVars', type: 'promptString', default: '',
            description: 'Extra make variables (e.g. VIVADO_PROJECT_SIM_TIME=10us GHDL_STOP_TIME=1us)',
        }],
        tasks,
    };
}

/** Adds the keys/entries of `add` that `cur` does not have; never changes existing values */
function mergeMissing(cur: Record<string, any>, add: Record<string, any>): string[] {
    const added: string[] = [];
    for (const [k, v] of Object.entries(add)) {
        if (!(k in cur)) { cur[k] = v; added.push(k); continue; }
        if (v && typeof v === 'object' && !Array.isArray(v) && cur[k] && typeof cur[k] === 'object' && !Array.isArray(cur[k])) {
            for (const [k2, v2] of Object.entries(v)) {
                if (!(k2 in cur[k])) { cur[k][k2] = v2; added.push(`${k}.${k2}`); }
            }
        }
    }
    return added;
}

async function readJson(file: string): Promise<Record<string, any> | undefined | 'invalid'> {
    let text: string;
    try { text = await fs.promises.readFile(file, 'utf8'); } catch { return undefined; }
    if (!text.trim()) { return undefined; }
    try { return JSON.parse(text); } catch { return 'invalid'; }
}

async function setupWorkspace(p: RuckusProject) {
    const folder = vscode.workspace.getWorkspaceFolder(vscode.Uri.file(p.target.dir)) ?? vscode.workspace.workspaceFolders?.[0];
    if (!folder) { vscode.window.showWarningMessage('Open a folder first'); return; }
    const ws = folder.uri.fsPath;
    type Item = vscode.QuickPickItem & { id: 'settings' | 'tasks' | 'vhdlls' };
    const items: Item[] = [
        { id: 'settings', label: 'settings.json', picked: true, detail: 'Python paths of submodules (surf, ...), exclude build/ from watcher and search, ruckus.tcl/.xdc as Tcl' },
        { id: 'tasks', label: 'tasks.json', picked: true, detail: `ruckus tasks for ${p.target.name}: build, simulate current file, clean (Ctrl+Shift+B / Run Test Task)` },
        { id: 'vhdlls', label: 'vhdl_ls.toml', picked: false, detail: 'VHDL library mapping for the VHDL-LS / rust_hdl language server (overwrites the file)' },
    ];
    const picks = await vscode.window.showQuickPick(items, { canPickMany: true, title: `Set up ${folder.name} for ${p.target.name}` });
    if (!picks?.length) { return; }
    const vsDir = path.join(ws, '.vscode');
    const report: string[] = [];
    const manual: string[] = [];
    for (const pick of picks) {
        if (pick.id === 'vhdlls') {
            const f = path.join(ws, 'vhdl_ls.toml');
            await fs.promises.writeFile(f, vhdlLsToml(p));
            report.push('vhdl_ls.toml');
            continue;
        }
        const file = path.join(vsDir, `${pick.id}.json`);
        const cur = await readJson(file);
        if (cur === 'invalid') { manual.push(file); continue; }
        let obj: Record<string, any> = cur ?? {};
        let added: string[];
        if (pick.id === 'settings') {
            added = mergeMissing(obj, workspaceSettings(p, ws));
        } else {
            const gen = workspaceTasks(p, ws);
            obj = { version: '2.0.0', ...obj };
            obj.inputs ??= [];
            obj.tasks ??= [];
            const ids = new Set(obj.inputs.map((i: { id: string }) => i.id));
            const labels = new Set(obj.tasks.map((t: { label: string }) => t.label));
            obj.inputs.push(...gen.inputs.filter(i => !ids.has(i.id)));
            const newTasks = gen.tasks.filter(t => !labels.has(t.label as string));
            obj.tasks.push(...newTasks);
            added = newTasks.map(t => t.label as string);
        }
        if (!added.length) { report.push(`${pick.label} (up to date)`); continue; }
        await fs.promises.mkdir(vsDir, { recursive: true });
        await fs.promises.writeFile(file, JSON.stringify(obj, null, 4) + '\n');
        report.push(`${pick.label} (+${added.length})`);
    }
    if (manual.length) {
        // JSON with comments: show what would be added instead of rewriting the user's file
        const text = picks.filter(x => x.id !== 'vhdlls' && manual.includes(path.join(vsDir, `${x.id}.json`)))
            .map(x => `// ${x.label}: merge by hand\n${JSON.stringify(x.id === 'settings' ? workspaceSettings(p, ws) : workspaceTasks(p, ws), null, 4)}`).join('\n\n');
        const doc = await vscode.workspace.openTextDocument({ language: 'jsonc', content: text });
        await vscode.window.showTextDocument(doc, { preview: true });
        vscode.window.showWarningMessage(`${manual.map(f => path.basename(f)).join(', ')} contain comments; the proposed entries are shown in an editor.`);
    }
    if (report.length) { vscode.window.showInformationMessage(`Ruckus workspace setup: ${report.join(', ')}`); }
}
