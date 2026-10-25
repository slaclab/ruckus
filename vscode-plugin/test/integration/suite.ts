import * as assert from 'assert';
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

async function walk(p: vscode.TreeDataProvider<any>, el: any, depth: number, out: string[], indent = ''): Promise<number> {
    const kids = (await p.getChildren(el)) ?? [];
    let n = kids.length;
    for (const k of kids) {
        const it = await p.getTreeItem(k);
        const label = typeof it.label === 'string' ? it.label : it.label?.label ?? (it.resourceUri ? it.resourceUri.path.split('/').pop() : '?');
        if (out.length < 400 && depth > 0) { out.push(`${indent}${label}  [${it.description ?? ''}]`); }
        if (depth > 0) { n += await walk(p, k, depth - 1, out, indent + '  '); }
    }
    return n;
}

export async function run() {
    const ext = vscode.extensions.all.find(e => e.packageJSON.name === 'slac-ruckus-plugin')!;
    const api = await ext.activate();
    const ws = vscode.workspace.workspaceFolders![0].uri.fsPath;
    // RUCKUS_TEST_TARGET, else the first target under targets/ (a directory with
    // several targets would open the target picker, which a headless run cannot answer)
    const targets = fs.existsSync(path.join(ws, 'targets')) ? fs.readdirSync(path.join(ws, 'targets')).sort()
        .map(t => path.join(ws, 'targets', t)).filter(d => fs.existsSync(path.join(d, 'ruckus.tcl'))) : [];
    const target = process.env.RUCKUS_TEST_TARGET ?? targets[0];
    assert.ok(target, `no target in ${ws}/targets (set RUCKUS_TEST_TARGET)`);
    await api.selectDir(target);
    const p = api.getProject();
    assert.ok(p, 'project loaded');
    assert.ok(p.files.length > 500, 'files loaded');
    const out: string[] = [];
    out.push('---- design');
    const nd = await walk(api.designTree, undefined, 4, out);
    out.push(`design items (depth 4): ${nd}`);
    // reveal() needs getParent: exercise it deep in the tree
    let el: any = (await api.designTree.getChildren())[0];
    for (let i = 0; i < 4 && el; i++) {
        const kids = await api.designTree.getChildren(el);
        assert.ok(kids.every((k: any) => api.designTree.getParent(k) === el), 'getParent consistent');
        el = kids.find((k: any) => k.t === 'inst' && k.res.t === 'unit') ?? kids[0];
    }
    const n1 = await walk(api.projectTree, undefined, 2, out);
    out.push('---- libraries');
    const n2 = await walk(api.libTree, undefined, 2, out);
    out.push('---- make');
    const n3 = await walk(api.makeTree, undefined, 2, out);
    api.projectTree.grouping = 'origin';
    const n4 = await walk(api.projectTree, undefined, 9, []);
    const t = api.buildTask('bit', p.target.dir, ['GIT_BYPASS=0'], p);
    out.push(`task: ${(t.execution as vscode.ShellExecution).commandLine}`);
    console.log(out.join('\n'));
    console.log(`items: project=${n1} libs=${n2} make=${n3} origin-all=${n4}`);
    const cmds = await vscode.commands.getCommands(true);
    const mine = (ext.packageJSON.contributes.commands as { command: string }[]).map(c => c.command);
    const missing = mine.filter(c => !cmds.includes(c));
    assert.deepStrictEqual(missing, [], 'all contributed commands registered');
    await vscode.commands.executeCommand('ruckus.design.focus');
    await vscode.commands.executeCommand('ruckus.design.toggleProcesses');
    await vscode.commands.executeCommand('ruckus.design.toggleProcesses');
    // Panel report views resolve and render without errors
    for (const c of ['ruckus.showLogReport', 'ruckus.showTiming', 'ruckus.showResources']) {
        await vscode.commands.executeCommand(c);
        await new Promise(r => setTimeout(r, 1500));
    }
    console.log(`toml: ${api.vhdlLsToml(p).split('\n').filter((l: string) => /^\w+\.files/.test(l)).join(' ')}`);
}
