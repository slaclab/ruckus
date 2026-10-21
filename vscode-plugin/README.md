# SLAC Ruckus for VS Code

Explorer for SLAC firmware projects built with [ruckus](https://github.com/slaclab/ruckus)
(`firmware/targets/<Target>/{Makefile,ruckus.tcl}` + `submodules/{ruckus,surf,...}`).

The extension is developed in the `vscode-plugin/` directory of the ruckus
repository, because it mirrors the ruckus loader procedures and `system_*.mk`
files. Full documentation:
[How to Use the ruckus VS Code Extension](https://slaclab.github.io/ruckus/how-to/vscode_plugin.html).

Pick a **top level** (a target directory) and the extension evaluates its
`ruckus.tcl` tree the same way ruckus does. It follows `loadRuckusTcl` recursively
and records every `loadSource`, `loadConstraints`, `loadIpCore`, `loadBlockDesign`,
`loadZipIpCore` and `loadNoCSolution`. Vivado is **not** needed, only `tclsh`.

## Views (activity bar → Ruckus)

**Design Hierarchy** is the main view. It starts from the synthesis top
(`set_property top`, otherwise `PROJECT`) and the simulation top (`sim_1`), then
shows recursively:
- **instances**: VHDL `entity lib.X(arch)` / `component` / `configuration`, and
  Verilog/SV `Mod #(...) u_x (...)`. Each is resolved to its entity/module,
  respecting `-lib` libraries (`work` = the library of the instantiating file).
  Other possible targets are IP cores (`.xci`), block designs, netlists (`.dcp`)
  and vendor primitives (IBUFDS, BUFG, ...). Anything not found is flagged.
- **generate blocks** (if / elsif / else / for / case, named blocks) with their condition
- **processes** (`process`, `always_ff`, `always_comb`, `always`, `initial`, ...)

Click opens the definition; the inline button goes to the instantiation line.
The tooltip shows the generic/parameter map. Context menu: *Set as Design Top*,
*Copy Hierarchical Path*. Toolbar: *Find Instance*, *Set Design Top* (★ marks units
not instantiated anywhere), *Reveal Current File in Hierarchy*, and toggles for
processes, generates and primitives. Only the loaded files are parsed (~0.3 s for
surf), and branches expand lazily. Editing an HDL file re-parses it automatically.

Generics are **not** elaborated: every branch of an `if generate` is shown,
and `for generate` loops are shown once.


**Sources (ruckus.tcl)**: the load hierarchy, one node per `ruckus.tcl`:
- target summary (part, FPGA architecture, backend, tops)
- every loaded file with its library (`-lib`), `sim` tag and the exact
  `ruckus.tcl:line` that loaded it (inline "Go to Load Statement" button)
- *Load Problems*: missing dirs/files, bad extensions, Tcl errors (also in the Problems panel)
- C/C++ files that ruckus does not load but that belong to the build:
  DPI-C/VHPI models next to loaded HDL (e.g. `surf/simlink/xsim`), and
  `VITIS_SRC_PATH`/`SDK_SRC_PATH` (MicroBlaze)
- Vivado hook scripts in `<target>/vivado/` (`post_synthesis.tcl`, `promgen.tcl`, ...)
- the toolbar toggles between *hierarchy* and *by origin* (target / shared / surf / ...)
  and has a filter (`AxiStream`, `lib:surf`, `ext:sv`, `pkg:StdRtl`, `sim`, `!sim`)

**Libraries & Categories** has cross-cutting views:
- Top modules (sources_1 / sim_1)
- Libraries / Submodules
- HDL libraries (`-lib`)
- VHDL/SV packages (click to jump to the declaration)
- Constraints, IP cores, block designs, zipped IP, netlists (.dcp/.edif), memory files, headers
- Simulation sources
- C/C++

**Make Targets**: targets of the selected top level, mostly inherited from
`ruckus/system_*.mk`, plus the firmware-level `Makefile` (`build`, `clean` for all targets):
- ▶ runs `make <target>` in a dedicated terminal (as a VS Code task, with a Vivado problem matcher).
  The firmware's `setup_env_slac.sh` is sourced first, so `vivado`/`vcs` are on the PATH. The Vivado version
  is read from it (e.g. `source .../2026.1/Vivado/2026.1/settings64.sh`) and used by the scan. A version
  selected in the status bar is passed as `$1` (`source setup_env_slac.sh 2025.1`); this is opt-in and only
  affects `make` if the script reads `$1`
- the Vivado version is picked from the status bar or the view toolbar (**Ruckus: Select Vivado Version**);
  installed versions are listed from the install path found in the setup script
- the make output is also saved to `build/logs/<target>_<goal>.log`; **Follow Build Log...** tails it,
  or any Vivado log in the build directory (`vivado.log`, `runs/*/runme.log`, ...), in a terminal
- "Run with Variables..." for things like `VIVADO_PROJECT_SIM=MyTb GIT_BYPASS=0`
- clicking a target opens its definition; *Environment* shows the evaluated Makefile variables
- toolbar: custom `make ...` command, grouping by *Common/Other* or by defining Makefile

**Build reports** (bottom panel, next to the terminal; refreshed while visible and after each `ruckus` task):
- **Ruckus: Log Report**: messages of `vivado.log` and the synth_1/impl_1 `runme.log` (plus OOC IP runs and saved
  `make xsim` output), Vivado *Messages*-style: toggle errors / critical warnings / warnings / infos, text filter
  (`-word` excludes), group by message ID, step or source file; click opens the source, Alt+click the log line.
  Other backends read the make output saved in `build/logs/`
- **Ruckus: Timing**: `<top>_timing_summary_routed.rpt`: WNS/TNS, WHS/THS, WPWS/TPWS, check_timing issues,
  intra-clock (clock tree), inter-clock and path-group tables, worst paths by slack. Negative slack is highlighted,
  *Only failing* hides the rest, clicking a path opens its detail in the report
- **Ruckus: Resources**: placed and synthesis utilization (headline resources as bars, plus every report table) and a
  *Hierarchy* tab: **Generate hierarchical utilization** runs Vivado in batch mode on the routed checkpoint
  (`report_utilization -hierarchical`) and shows the per-instance tree

**Simulate Current File** (beaker icon in the editor title, editor context menu):
finds the entity/module of the active file (testbenches first) and runs the target's
simulation with it as top: `make xsim VIVADO_PROJECT_SIM=<unit>` (Vivado; `ruckus.simulateTarget`
selects xsim/vcs/msim), `make tb PROJECT=<unit>` (GHDL), `make tb SIM_TOP=<unit>` (Icarus, Verilator).
The *with Variables...* variant asks for extra variables (`VIVADO_PROJECT_SIM_TIME=10us`, ...).
The make tasks use a problem matcher for the backend (Vivado, GHDL, Icarus, Verilator).

**Set Up Workspace** (Sources view `...` menu) adds to `.vscode/settings.json` the Python paths of
`submodules/*/python` and `software/python` (Pylance + terminal `PYTHONPATH`), excludes `build/` and
`.Xil` from the file watcher/search, and adds `ruckus` tasks to `.vscode/tasks.json` (build, simulate
current file, clean). It optionally writes `vhdl_ls.toml`: files without `-lib` go to `xil_defaultlib` (VHDL-LS
reserves `work`), and `unisim`/`unimacro`/`xpm` map to the Vivado installation's VHDL sources (`ruckus.vivadoPath`,
else detected from `$XILINX_VIVADO`, the setup script or `ruckus.vivadoVersion`). Existing keys and tasks are never changed.

Other: status-bar top-level picker, explorer context menu **Ruckus: Use as Top Level**,
**Ruckus: Export File List** (plain, CSV, `vhdl_ls.toml`, Verilog `.f`),
**Ruckus: Show Project Info**, and automatic rescan when `ruckus.tcl`/Makefiles change.
`ruckus` tasks can also be put in `tasks.json`:

```json
{ "type": "ruckus", "target": "bit", "args": ["GIT_BYPASS=0"] }
{ "type": "ruckus", "target": "xsim", "args": ["VIVADO_PROJECT_SIM=${fileBasenameNoExtension}", "${input:ruckusMakeVars}"] }
```

`dir` and `args` accept `${workspaceFolder}`, `${topDir}`, `${targetDir}`, `${file}` and
`${fileBasenameNoExtension}`; an `${input:...}` argument is not quoted, so it can hold several words.

## Settings

| Setting | Default | |
|---|---|---|
| `ruckus.tclsh` | `tclsh` | Tcl shell used for the scan |
| `ruckus.setupScript` | | sourced before `make`, e.g. `${topDir}/setup_env_slac.sh`; gets the selected Vivado version as `$1` |
| `ruckus.autoSourceSetupScript` | `true` | source `firmware/setup_env_slac.sh` (or `setup_env*.sh`) when `setupScript` is empty |
| `ruckus.env` | `{}` | extra variables for the scan, e.g. `{"RUCKUS_SIM_BACKEND":"vcs"}` |
| `ruckus.vivadoVersion` | | Vivado version passed to the setup script and assumed by the scan (empty: script default) |
| `ruckus.vivadoPath` | | Vivado install (`$XILINX_VIVADO`) for `unisim`/`unimacro`/`xpm` in `vhdl_ls.toml` (empty: detected) |
| `ruckus.saveMakeLog` | `true` | copy make output to `build/logs/<target>_<goal>.log` |
| `ruckus.hierUtilizationDepth` | `8` | `-hierarchical_depth` of the generated hierarchical utilization |
| `ruckus.simulateTarget` | `xsim` | Vivado simulator used by *Simulate Current File* (`xsim`, `vcs`, `msim`) |
| `ruckus.commonMakeTargets` | bit, prom, syn, ... | order of the *Common* make targets |
| `ruckus.grouping` | `hierarchy` | default Project view grouping |
| `ruckus.showSimFiles` | `true` | show `-sim_only` files |

## Build / install

```sh
./scripts/build.sh            # npm install + tsc + package slac-ruckus-plugin-<ver>.vsix
./scripts/build.sh --compile  # compile only
./scripts/install.sh          # build if needed, then `code --install-extension`
./scripts/install.sh --uninstall
```

Requires Node.js ≥ 18 to build and `tclsh` at runtime (pre-installed on macOS and most Linux).
If the system Node.js is older, install one with conda:

```sh
conda create -y -n node20 -c conda-forge nodejs=20
conda activate node20
node -v && npm -v
```

With VS Code Remote, build and install on the server: run `install.sh` in a VS Code integrated
terminal (its `code` command installs on the server), or use *Extensions → … → Install from VSIX...*
while connected.
To develop it, open this folder in VS Code and press F5 ("Run Extension").
CI (`.github/workflows/ruckus_ci.yml`, job `vscode_plugin`) builds the `.vsix` and uploads it as an artifact.

When a loader procedure or option is added to `ruckus/vivado/proc/code_loading.tcl`,
add the same stub to `resources/ruckus_scan.tcl` in the same change.

Tests:
`node out/test/smoke.js <target dir>` prints the model from the command line.
`npm test -- <firmware dir>` runs the views inside VS Code. If you run it from a
VS Code terminal, unset `ELECTRON_RUN_AS_NODE` first.

## How the scan works

`resources/ruckus_scan.tcl` is run with the environment that the target's
Makefile would export. `src/core/makefile.ts` evaluates `TOP_DIR`, `PRJ_PART`,
`PRJ_VERSION`, includes `shared_version.mk` and `system_vivado.mk`, and so on,
without running `make`. The scanner replaces the ruckus loader procs and the few
Vivado commands that matter (`set_property top`, `add_files`, `get_filesets`, ...)
with recorders. Every other Vivado command becomes a no-op. `getFpgaArch` is
derived from `PRJ_PART`, so family-dependent branches
(`if {$family eq "kintexu"} ...`) pick the same files as a real build.

Limitations:
- Logic that depends on real Vivado state (e.g. `get_files` results, IP
  properties) evaluates as "empty".
- `$(shell ...)` in Makefiles is not executed.
- To get a different branch, override variables with `ruckus.env`.
