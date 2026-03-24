# Architecture

**Analysis Date:** 2026-03-24

## Pattern Overview

**Overall:** Multi-backend FPGA/ASIC build orchestration framework using a Make-driven entry point with TCL-based tool automation and a portable source-loading abstraction.

**Key Characteristics:**
- Make targets invoke EDA tool CLIs (Vivado, Vitis HLS, GHDL, Genus, Design Compiler) in batch mode, passing ruckus-provided TCL scripts
- A unified `loadRuckusTcl`/`loadSource`/`loadConstraints` API is re-implemented per backend so that the same user `ruckus.tcl` file works across Vivado, Cadence Genus, Synopsys DC, and GHDL
- Environment variables flow from Make to TCL via `$::env()`, forming the primary configuration interface
- Hook-based extensibility: ruckus sources user-defined TCL scripts at well-defined lifecycle points (pre_synthesis, post_route, etc.)
- Git integration for build tagging, image naming, and release management

## Layers

**Layer 1 -- Makefile Entry Points:**
- Purpose: Define environment variables, resolve paths, compute git hashes, provide user-facing `make` targets
- Location: `system_vivado.mk`, `system_vitis_hls.mk`, `system_vitis_unified_hls.mk`, `system_cadence_genus.mk`, `system_synopsys_dc.mk`, `system_ghdl.mk`, `system_vcs.mk`
- Contains: GNU Make variable definitions, phony targets (build, gui, syn, sim, clean, release, etc.)
- Depends on: `system_shared.mk` (included by all backend makefiles)
- Used by: User project `Makefile` (which includes exactly one `system_*.mk`)

**Layer 2 -- Shared Make Infrastructure:**
- Purpose: Common build-string generation, git hash computation, /u1 build-directory symlinking, ACTION_HEADER display
- Location: `system_shared.mk`
- Contains: `PRJ_VERSION`, `BUILD_STRING`, `GIT_HASH_LONG/SHORT`, `IMAGENAME` computation, build-dir auto-creation
- Depends on: System tools (git, uname, date)
- Used by: All `system_*.mk` files

**Layer 3 -- TCL Orchestration Scripts:**
- Purpose: Drive the EDA tool through its full build lifecycle (project creation, source loading, synthesis, implementation, bitstream generation)
- Location: `vivado/build.tcl`, `vivado/sources.tcl`, `vivado/project.tcl`, `vivado/gui.tcl`, `vivado/batch.tcl`, `vivado/dcp.tcl`, `vitis/hls/build.tcl`, `vitis/hls/sources.tcl`, `cadence/genus/syn.tcl`, `synopsys/design_compiler/syn.tcl`, `ghdl/load_source_code.tcl`
- Contains: Sequential build flow logic, error checking, output file generation
- Depends on: Layer 4 (TCL Procedure Libraries), Layer 5 (Environment Variables)
- Used by: EDA tools invoked in batch mode by Layer 1

**Layer 4 -- TCL Procedure Libraries:**
- Purpose: Reusable TCL procedures providing a portable source-loading API and build-system utilities
- Location: `shared/proc.tcl` (cross-backend), `vivado/proc.tcl` (loader), `vivado/proc/*.tcl` (8 files), `vitis/hls/proc.tcl`, `ghdl/proc.tcl`, `cadence/genus/proc.tcl`, `synopsys/design_compiler/proc.tcl`
- Contains: `loadRuckusTcl`, `loadSource`, `loadIpCore`, `loadBlockDesign`, `loadConstraints`, `loadZipIpCore`, `CheckSynth`, `CheckImpl`, `CheckTiming`, `BuildIpCores`, `CreateDebugCore`, `VersionCompare`, `GenBuildString`, etc.
- Depends on: `shared/proc.tcl` (base utilities), EDA tool TCL APIs
- Used by: All Layer 3 scripts

**Layer 5 -- Environment Variable Bridge:**
- Purpose: Import Make environment variables into TCL namespace for use by procedures and scripts
- Location: `vivado/env_var.tcl`, `vitis/hls/env_var.tcl`, `cadence/genus/env_var.tcl`, `synopsys/design_compiler/env_var.tcl`
- Contains: `set VAR $::env(VAR)` mappings
- Depends on: Environment set by Layer 1/2
- Used by: Layer 3 and Layer 4

**Layer 6 -- Build Lifecycle Hooks:**
- Purpose: Allow user projects and ruckus itself to inject logic at specific points in the Vivado build pipeline
- Location: `vivado/pre_synthesis.tcl`, `vivado/post_synthesis.tcl`, `vivado/post_route.tcl`, `vivado/properties.tcl`, `vivado/messages.tcl`, `vivado/run/pre/*.tcl` (8 files), `vivado/run/post/*.tcl` (9 files)
- Contains: Pre/post scripts for each Vivado implementation step, user hook sourcing via `SourceTclFile ${VIVADO_DIR}/<hook>.tcl`
- Depends on: Layer 4 procedures, user-provided TCL scripts in `${VIVADO_DIR}/`
- Used by: Vivado's `STEPS.*.TCL.PRE/POST` properties (set in `vivado/properties.tcl`)

**Layer 7 -- Python Utilities:**
- Purpose: Release management, firmware packaging, repository scaffolding, and Vitis Unified HLS build automation
- Location: `scripts/firmwareRelease.py`, `scripts/releaseGen.py`, `scripts/releaseNotes.py`, `scripts/createNewRepo.py`, `scripts/download_github_asset.py`, `scripts/bin2txt.py`, `scripts/write_vhd_synth_stub_parser.py`, `vitis/hls/build.py`, `vitis/hls/create_proj.py`
- Contains: GitHub release automation (GitPython + PyGithub), Vitis Python API usage
- Depends on: Python 3, GitPython, PyGithub (listed in `scripts/pip_requirements.txt`), Vitis Python SDK
- Used by: `make release` targets, `system_vitis_unified_hls.mk`

**Layer 8 -- Embedded Processor Support:**
- Purpose: Microblaze soft-processor SDK/Vitis project creation, ELF generation, and bit-file embedding
- Location: `MicroblazeBasicCore/sdk/prj.tcl`, `MicroblazeBasicCore/sdk/bit.tcl`, `MicroblazeBasicCore/sdk/elf.tcl`, `MicroblazeBasicCore/vitis/prj.tcl`, `MicroblazeBasicCore/vitis/bit.tcl`, `MicroblazeBasicCore/vitis/elf.tcl`
- Contains: SDK/Vitis workspace creation, BSP configuration, ELF compilation, bitstream embedding
- Depends on: Vivado, Vitis/SDK tools, completed synthesis/implementation
- Used by: `vivado/post_route.tcl` (auto-detects MicroblazeBasicCore.bd), `make elf` target

## Data Flow

**Vivado Full Build (make bit):**

1. `system_vivado.mk` computes env vars (PROJECT, PROJ_DIR, TOP_DIR, OUT_DIR, GIT_HASH, IMAGENAME, etc.) via `system_shared.mk`
2. `make bit` depends on `$(SOURCE_DEPEND)`, which runs `vivado -mode batch -source vivado/sources.tcl`
3. `vivado/sources.tcl` sources `vivado/env_var.tcl` + `vivado/proc.tcl`, creates/opens the Vivado project via `vivado/project.tcl`, generates `BuildInfoPkg.vhd`, then calls `loadRuckusTcl ${PROJ_DIR}` to recursively load the user's `ruckus.tcl` hierarchy
4. User `ruckus.tcl` files call `loadSource`, `loadIpCore`, `loadBlockDesign`, `loadConstraints` to register HDL files, IP cores, block designs, and constraints
5. After source loading completes, `make bit` invokes `vivado -mode batch -source vivado/build.tcl`
6. `vivado/build.tcl` opens the project, sets properties, runs pre_synthesis hooks, builds IP cores, launches synthesis, runs post_synthesis hooks, launches implementation with write_bitstream, checks timing, runs post_route hooks, copies output images to `${IMAGES_DIR}`
7. Output files: `${IMAGES_DIR}/${IMAGENAME}.bit`, `.mcs`, `.pdi`, `.ltx`, `.xsa` (depending on configuration)

**Vitis HLS Build (make build via system_vitis_hls.mk):**

1. `system_vitis_hls.mk` sets env vars, depends on `$(SOURCE_DEPEND)` which runs `vitis_hls -f vitis/hls/sources.tcl`
2. `vitis/hls/sources.tcl` creates the HLS project, sets the top module, sources user's `sources.tcl` and `solution.tcl`
3. `make build` runs `vitis_hls -f vitis/hls/build.tcl` which executes csim, csynth, cosim, and export_design
4. Output: `${PROJ_DIR}/ip/${PROJECT}.zip` (IP catalog ZIP for integration into Vivado)

**Vitis Unified HLS Build (make build via system_vitis_unified_hls.mk):**

1. `system_vitis_unified_hls.mk` sets env vars, `make proj` runs `vitis -s vitis/hls/create_proj.py` to create the project from `hls_config.cfg`
2. `make build` runs `vitis -s vitis/hls/build.py` which uses the Vitis Python API to run C_SIMULATION, SYNTHESIS, CO_SIMULATION, PACKAGE, and optionally IMPLEMENTATION
3. Output: `${PROJ_DIR}/ip/${PROJECT}.zip`

**GHDL Simulation (make tb):**

1. `system_ghdl.mk` sets env vars, `make load_source_code` runs `ghdl/load_source_code.tcl` via tclsh
2. `ghdl/load_source_code.tcl` calls `loadRuckusTcl` to load user sources (symlinked into OUT_DIR by type/library)
3. `make analysis` runs `ghdl/analysis.tcl` (ghdl -a), `make import` runs `ghdl/import.tcl` (ghdl -i)
4. `make build` runs ghdl -m (make/elaborate), `make tb` runs ghdl -r (simulate with waveform output)

**ASIC Synthesis (Cadence Genus / Synopsys DC):**

1. `system_cadence_genus.mk` or `system_synopsys_dc.mk` sets env vars
2. `make syn` invokes the tool with `cadence/genus/syn.tcl` or `synopsys/design_compiler/syn.tcl`
3. These scripts source `proc.tcl` (which provides backend-specific `loadSource`), then source the user's `ruckus.tcl`
4. After source loading, the user's `syn/compile.tcl` runs synthesis constraints
5. Output: gate-level netlist, SDF, SDC, reports in `${IMAGES_DIR}/`

**State Management:**
- Build state persists in `${OUT_DIR}` (typically `${TOP_DIR}/build/${PROJECT}`)
- Vivado project state: `.xpr` file + `.runs/` directory
- Source dependency tracking: `${SOURCE_DEPEND}` file (e.g., `${PROJECT}_sources.txt`)
- Git hash tracking: `${SYN_DIR}/git.hash` for incremental build detection
- Image outputs: `${PROJ_DIR}/images/` directory

## Key Abstractions

**loadRuckusTcl -- Recursive Source Tree Walker:**
- Purpose: Traverse a hierarchical firmware project by sourcing `ruckus.tcl` files found at each directory level
- Examples: `vivado/proc/code_loading.tcl` (Vivado impl), `ghdl/proc.tcl` (GHDL impl), `cadence/genus/proc.tcl` (Genus impl), `synopsys/design_compiler/proc.tcl` (DC impl)
- Pattern: Each backend re-implements this proc with the same signature. The proc sets `::DIR_PATH` to the current directory, sources `${filePath}/ruckus.tcl`, then restores `::DIR_PATH`. User `ruckus.tcl` files use `$::DIR_PATH` to reference files relative to their own location.

**loadSource -- Universal HDL File Loader:**
- Purpose: Add RTL source files (VHDL, Verilog, SystemVerilog) to the build, with backend-specific implementation
- Examples: `vivado/proc/code_loading.tcl` (calls Vivado's `add_files`), `ghdl/proc.tcl` (creates symlinks by type/library), `cadence/genus/proc.tcl` (creates symlinks), `synopsys/design_compiler/proc.tcl` (appends to global lists)
- Pattern: `-path <file>` for single file, `-dir <directory>` for all files, `-lib <name>` for VHDL library, `-sim_only` flag for simulation-only files, `-fileType` for explicit file type override

**loadIpCore / loadBlockDesign / loadConstraints -- Vivado-Specific Loaders:**
- Purpose: Add Xilinx IP cores (.xci), block designs (.bd/.tcl), and constraints (.xdc) to the Vivado project
- Examples: `vivado/proc/code_loading.tcl`
- Pattern: Same `-path`/`-dir` interface as `loadSource`. Non-Vivado backends silently ignore these or provide stubs.

**SourceTclFile -- Optional Hook Sourcing:**
- Purpose: Source a TCL file if it exists, silently skip if it does not
- Examples: `shared/proc.tcl`
- Pattern: Used extensively to source optional user-defined hook scripts (e.g., `${VIVADO_DIR}/post_synthesis.tcl`)

**VersionCompare -- Vivado Version Gating:**
- Purpose: Conditionally execute code based on the Vivado version number
- Examples: `vivado/proc/checking.tcl`
- Pattern: Returns -1/0/1 for less/equal/greater comparison. Used throughout to handle Vivado API differences across versions (2014.1 through 2025.2).

**GenBuildString -- Build Metadata Injection:**
- Purpose: Encode build metadata (git hash, firmware version, build string) into the FPGA design as a generic parameter and auto-generated VHDL package
- Examples: `shared/proc.tcl`
- Pattern: Creates `BuildInfoPkg.vhd` containing `BUILD_INFO_C` constant. Also sets top-level generic `BUILD_INFO_G` for Vivado projects.

## Entry Points

**make bit / make mcs / make prom / make pdi (Vivado Full Build):**
- Location: `system_vivado.mk` (line 310-312)
- Triggers: User runs `make` in a target project directory that includes `system_vivado.mk`
- Responsibilities: Full FPGA build pipeline -- source loading, synthesis, implementation, bitstream generation

**make build (Vitis HLS):**
- Location: `system_vitis_hls.mk` (line 167-170)
- Triggers: User runs `make build` in a Vitis HLS project
- Responsibilities: C/C++ simulation, HLS synthesis, co-simulation, IP export

**make build (Vitis Unified HLS):**
- Location: `system_vitis_unified_hls.mk` (line 68-75)
- Triggers: User runs `make build` in a Vitis Unified HLS project
- Responsibilities: Python-driven HLS flow using `vitis -s build.py`

**make syn (Cadence Genus):**
- Location: `system_cadence_genus.mk` (line 131-136)
- Triggers: User runs `make syn` in a Cadence Genus ASIC project
- Responsibilities: ASIC synthesis with Cadence Genus

**make syn (Synopsys Design Compiler):**
- Location: `system_synopsys_dc.mk` (line 149-154)
- Triggers: User runs `make syn` in a Synopsys DC ASIC project
- Responsibilities: ASIC synthesis with Synopsys Design Compiler

**make tb (GHDL Simulation):**
- Location: `system_ghdl.mk` (line 175-179)
- Triggers: User runs `make tb` in a GHDL simulation project
- Responsibilities: VHDL analysis, elaboration, simulation with waveform output

**make gui (Vivado GUI):**
- Location: `system_vivado.mk` (line 301-304)
- Triggers: User runs `make gui` to open Vivado in interactive mode
- Responsibilities: Opens project with all ruckus procedures loaded

**make release:**
- Location: `system_vivado.mk` (line 359-362)
- Triggers: User runs `make release RELEASE=<tag>` after a successful build
- Responsibilities: Runs `scripts/firmwareRelease.py` to create GitHub releases with firmware images

**make xsim / make vcs / make msim (Simulation):**
- Location: `system_vivado.mk` (lines 399-418)
- Triggers: User runs simulation make targets
- Responsibilities: Generate and run simulation scripts for Xilinx XSIM, Synopsys VCS, or Mentor ModelSim/Questa

## Error Handling

**Strategy:** Fail-fast with detailed error messages at every stage. TCL `catch` blocks wrap critical operations; Make targets rely on non-zero exit codes to halt the build.

**Patterns:**
- TCL procedures return `true`/`false` and callers check before proceeding (e.g., `CheckSynth`, `CheckImpl`, `CheckTiming`, `CheckPrjConfig`)
- Error messages are printed within prominently formatted blocks (`*****` delimiters) to stand out in build logs
- `CheckProcRetVal` in `vitis/hls/proc.tcl` wraps HLS operations with catch-and-exit-on-failure
- `PrintOpenGui` directs users to open the GUI to inspect errors
- Git status validation: builds refuse to proceed with uncommitted code unless `GIT_BYPASS=1`
- Version validation: `CheckVivadoVersion` blocks unsupported Vivado versions, warns on untested versions

## Cross-Cutting Concerns

**Logging:** Stdout-based logging through TCL `puts` statements. Vivado message filtering configured in `vivado/messages.tcl` (219 lines of `set_msg_config` rules to suppress/upgrade/downgrade specific Vivado message IDs).

**Validation:** Multi-level validation including git version checks (`CheckGitVersion`), Vivado version checks (`CheckVivadoVersion`, `VersionCompare`), syntax checking (`check_syntax`), timing checks (`CheckTiming` with WNS/TNS/WHS/THS/TPWS/FAILED_NETS), and submodule version locks (`SubmoduleCheck`).

**Authentication:** Not applicable (local build system). GitHub releases use PyGithub with token-based auth in `scripts/firmwareRelease.py`.

**Build Metadata:** Every build embeds git hash, firmware version, build string, and timestamp into the FPGA bitstream via `BUILD_INFO_G` generic and auto-generated `BuildInfoPkg.vhd`. Image files are named with the pattern `${PROJECT}-${PRJ_VERSION}-${BUILD_TIME}-${USER}-${GIT_HASH_SHORT}`.

**Incremental Build Support:** Vivado projects use `AUTO_INCREMENTAL_CHECKPOINT` (2018.3+). Source dependency tracked via `$(SOURCE_DEPEND)` file. Git hash compared against `${SYN_DIR}/git.hash` to detect when re-synthesis is needed.

**Dynamic Partial Reconfiguration (DFX):** Full support via `RECONFIG_CHECKPOINT`, `RECONFIG_ENDPOINT`, `RECONFIG_PBLOCK` variables and dedicated procedures in `vivado/proc/Dynamic_Function_eXchange.tcl`.

---

*Architecture analysis: 2026-03-24*
