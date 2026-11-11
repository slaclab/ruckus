// Launches VS Code with the extension and the example firmware workspace:
//   npm run test:vscode -- <firmware dir>
import * as path from 'path';
import { runTests } from '@vscode/test-electron';

async function main() {
    if (!process.argv[2]) {
        console.error('usage: npm run test:vscode -- <firmware dir> (RUCKUS_TEST_TARGET=<target dir> to pick the target)');
        process.exit(2);
    }
    const ws = path.resolve(process.argv[2]);
    await runTests({
        vscodeExecutablePath: process.env.VSCODE_EXE,
        extensionDevelopmentPath: path.resolve(__dirname, '../../..'),
        extensionTestsPath: path.resolve(__dirname, 'suite.js'),
        launchArgs: [ws, '--disable-extensions', '--user-data-dir', '/tmp/ruckus-vscode-test-ud'],
    });
}
main().catch(e => { console.error(e); process.exit(1); });
