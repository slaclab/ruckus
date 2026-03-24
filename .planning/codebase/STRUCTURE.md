# Codebase Structure

**Analysis Date:** 2026-03-24

## Directory Layout

```
ruckus/
├── cadence/                    # Cadence Genus ASIC synthesis backend
│   └── genus/                  # Genus-specific TCL scripts and shell scripts
├── ghdl/                       # GHDL open-source VHDL simulator backend
├── .github/                    # GitHub Actions CI/CD workflows
│   └── workflows/              # Reusable workflow definitions
├── MicroblazeBasicCore/        # Microblaze soft-processor embedded support
│   ├── sdk/                    # Legacy Xilinx SDK scripts (Vivado <= 2019.1)
│   └── vitis/                  # Vitis embedded platform scripts (Vivado >= 2019.2)
├── scripts/                    # Python utility scripts (releases, repo setup, file conversion)
├── shared/                     # Shared TCL procedures used across all backends
├── synopsys/                   # Synopsys Design Compiler ASIC synthesis backend
│   └── design_compiler/        # DC-specific TCL scripts and shell scripts
├── vitis/                      # Xilinx Vitis HLS backend
│   └── hls/                    # HLS project creation, build, and export scripts
├── vivado/                     # Xilinx Vivado FPGA backend (primary)
│   ├── proc/                   # Modular TCL procedure libraries
│   └── run/                    # Pre/post hook scripts for implementation stages
│       ├── pre/                # Pre-stage hook dispatchers
│       └── post/               # Post-stage hook dispatchers
├── system_cadence_genus.mk     # Makefile entry point for Cadence Genus flow
├── system_ghdl.mk              # Makefile entry point for GHDL simulation flow
├── system_shared.mk            # Shared Makefile logic (versioning, git, build strings)
├── system_synopsys_dc.mk       # Makefile entry point for Synopsys DC flow
├── system_vcs.mk               # Makefile entry point for VCS standalone simulation flow
├── system_vitis_hls.mk         # Makefile entry point for Vitis HLS (legacy TCL-based)
├── system_vitis_unified_hls.mk # Makefile entry point for Vitis Unified HLS (Python-based)
├── system_vivado.mk            # Makefile entry point for Vivado FPGA flow (primary)
├── vivado_proc.tcl             # Standalone Vivado proc loader (no user target sourcing)
├── Doxyfile                    # Doxygen configuration for API documentation
├── .flake8                     # Flake8 Python linting configuration
├── .gitattributes              # Git LFS and attribute configuration
├── .gitignore                  # Ignore patterns for build artifacts
├── LICENSE.txt                 # SLAC Open License
└── README.md                   # Project overview and user TCL script reference
```

## Directory Purposes

**`vivado/`:**
- Purpose: Primary Xilinx Vivado FPGA synthesis, implementation, and simulation flow
- Contains: TCL scripts for every build phase (source loading, synthesis, routing, output generation)
- Key files:
  - `vivado/sources.tcl`: Loads all source code into a Vivado project
  - `vivado/build.tcl`: Full batch build flow (synthesis through bitstream)
  - `vivado/env_var.tcl`: Sets all TCL variables from Makefile environment
  - `vivado/proc.tcl`: Master procedure loader (sources `shared/proc.tcl` + all `vivado/proc/*.tcl`)
  - `vivado/project.tcl`: Creates or opens the Vivado project
  - `vivado/properties.tcl`: Sets Vivado project properties
  - `vivado/messages.tcl`: Configures message severity filters
  - `vivado/gui.tcl`: Opens project in Vivado GUI mode
  - `vivado/batch.tcl`: Runs batch commands within an open project
  - `vivado/pre_synthesis.tcl`: Pre-synthesis hook dispatcher
  - `vivado/post_synthesis.tcl`: Post-synthesis hook dispatcher
  - `vivado/post_route.tcl`: Post-route hook dispatcher
  - `vivado/dcp.tcl`: DCP (design checkpoint) output generation
  - `vivado/xsim.tcl`: Xilinx XSIM simulation flow
  - `vivado/vcs.tcl`: VCS simulation script generation
  - `vivado/msim.tcl`: ModelSim/Questa simulation flow
  - `vivado/pyrogue.tcl`: PyRogue tarball generation
  - `vivado/cpsw.tcl`: CPSW YAML tarball generation
  - `vivado/promgen.tcl`: PROM generation hook dispatcher
  - `vivado/wis.tcl`: Windows init script generation

**`vivado/proc/`:**
- Purpose: Modular library of reusable TCL procedures for Vivado
- Contains: Categorized procedure files, each focused on a specific concern
- Key files:
  - `vivado/proc/code_loading.tcl`: `loadSource`, `loadIpCore`, `loadBlockDesign`, `loadConstraints`, `loadZipIpCore` procedures (603 lines, largest proc file)
  - `vivado/proc/project_management.tcl`: `CheckVivadoVersion`, `CheckPrjConfig`, `VivadoRefresh`, version comparison (328 lines)
  - `vivado/proc/checking.tcl`: Build state checks (`CheckSynth`, `CheckImpl`, `CheckTiming`) (287 lines)
  - `vivado/proc/ip_management.tcl`: `BuildIpCores`, IP synthesis run management (188 lines)
  - `vivado/proc/Dynamic_Function_eXchange.tcl`: Partial reconfiguration DCP import/export (135 lines)
  - `vivado/proc/output_files.tcl`: `CreateFpgaBit`, `CreateVersalOutputs`, output file generation (132 lines)
  - `vivado/proc/debug_probes.tcl`: ILA debug probe insertion procedures (97 lines)
  - `vivado/proc/sim_management.tcl`: Simulation setup procedures (97 lines)

**`vivado/run/`:**
- Purpose: Pre/post hook dispatchers for each Vivado implementation stage
- Contains: TCL scripts that source optional user-defined hook scripts from the target's vivado directory
- Key files:
  - `vivado/run/pre/synth.tcl`, `vivado/run/post/synth.tcl`: Synthesis stage hooks
  - `vivado/run/pre/opt.tcl`, `vivado/run/post/opt.tcl`: Optimization stage hooks
  - `vivado/run/pre/place.tcl`, `vivado/run/post/place.tcl`: Placement stage hooks
  - `vivado/run/pre/route.tcl`, `vivado/run/post/route.tcl`: Routing stage hooks
  - `vivado/run/pre/phys_opt.tcl`, `vivado/run/post/phys_opt.tcl`: Physical optimization hooks
  - `vivado/run/pre/power_opt.tcl`, `vivado/run/post/power_opt.tcl`: Power optimization hooks
  - `vivado/run/post/gui_write.tcl`: Post-GUI write hook

**`vitis/hls/`:**
- Purpose: Xilinx Vitis HLS (High-Level Synthesis) C/C++ to RTL compilation
- Contains: Both legacy TCL-based scripts and newer Python-based scripts for Vitis Unified
- Key files:
  - `vitis/hls/sources.tcl`: Creates HLS project and loads sources (legacy TCL flow)
  - `vitis/hls/build.tcl`: Full HLS build: csim, csynth, cosim, export (legacy TCL flow)
  - `vitis/hls/create_proj.py`: Creates HLS project from `hls_config.cfg` (Vitis Unified Python flow)
  - `vitis/hls/build.py`: Full HLS build using Python Vitis API (Vitis Unified Python flow)
  - `vitis/hls/proc.tcl`: HLS-specific TCL procedures (`HlsVersionCheck`, `ComponentXmlAllFamilySupport`)
  - `vitis/hls/env_var.tcl`: HLS environment variable setup
  - `vitis/hls/interactive.tcl`: Interactive TCL session launcher
  - `vitis/hls/dcp_rename_ref.tcl`: Renames DCP reference to match project name

**`shared/`:**
- Purpose: Cross-backend TCL utility procedures
- Contains: Single file with procedures used by Vivado, Cadence, GHDL, and Synopsys backends
- Key files:
  - `shared/proc.tcl`: `SourceTclFile`, `GetCpuNumber`, `sleep`, `ListComp`, `findFiles`, `GetRealPath`, `BuildInfo`, `CheckWritePermission`, `CompareTags`, `SubmoduleCheck`, `GetGitHash`, `GetFwVersion`, `GenBuildString`, `CheckGitVersion`

**`cadence/genus/`:**
- Purpose: Cadence Genus ASIC synthesis and behavioral Verilog export flow
- Contains: TCL scripts and shell scripts for ASIC synthesis
- Key files:
  - `cadence/genus/proc.tcl`: Genus-specific `loadRuckusTcl`, `loadSource`, `UpdateSrcFileLists`, `AnalyzeSrcFileLists`
  - `cadence/genus/syn.tcl`: Synthesis flow script
  - `cadence/genus/behavioral_verilog.tcl`: Behavioral Verilog export
  - `cadence/genus/env_var.tcl`: Environment variable setup
  - `cadence/genus/messages.tcl`: Message configuration
  - `cadence/genus/sim.sh`: VCS simulation shell script

**`synopsys/design_compiler/`:**
- Purpose: Synopsys Design Compiler ASIC synthesis and VCS simulation flow
- Contains: TCL scripts and shell scripts mirroring Cadence Genus structure
- Key files:
  - `synopsys/design_compiler/proc.tcl`: DC-specific `loadRuckusTcl`, `loadSource`, `UpdateSrcFileLists`
  - `synopsys/design_compiler/syn.tcl`: Synthesis flow script
  - `synopsys/design_compiler/env_var.tcl`: Environment variable setup
  - `synopsys/design_compiler/sim.sh`: VCS simulation shell script

**`ghdl/`:**
- Purpose: GHDL open-source VHDL simulator flow (analysis, import, elaborate, simulate)
- Contains: TCL scripts invoked as shell commands (not inside a TCL interpreter)
- Key files:
  - `ghdl/proc.tcl`: GHDL-specific `loadRuckusTcl`, `loadSource`, `UpdateSrcFileLists`
  - `ghdl/load_source_code.tcl`: Loads source files by invoking `loadRuckusTcl`
  - `ghdl/analysis.tcl`: GHDL analysis (compile) step
  - `ghdl/import.tcl`: GHDL import step

**`MicroblazeBasicCore/`:**
- Purpose: Embedded Microblaze soft-processor support for bitstream generation with ELF
- Contains: TCL scripts for both legacy Xilinx SDK and modern Vitis embedded platforms
- Key files:
  - `MicroblazeBasicCore/sdk/bit.tcl`, `MicroblazeBasicCore/sdk/elf.tcl`, `MicroblazeBasicCore/sdk/prj.tcl`: Legacy SDK flow
  - `MicroblazeBasicCore/vitis/bit.tcl`, `MicroblazeBasicCore/vitis/elf.tcl`, `MicroblazeBasicCore/vitis/prj.tcl`: Modern Vitis flow

**`scripts/`:**
- Purpose: Python utility scripts for release management, repo creation, and file conversion
- Contains: Standalone Python scripts invoked by Makefile targets or CI
- Key files:
  - `scripts/firmwareRelease.py`: Interactive firmware release generator (GitHub releases, Rogue ZIPs, CPSW tarballs, Conda packages)
  - `scripts/releaseGen.py`: Automated CI release generation (triggered by tags)
  - `scripts/releaseNotes.py`: Git-based release notes generator
  - `scripts/createNewRepo.py`: New firmware repository scaffolding
  - `scripts/download_github_asset.py`: GitHub release asset downloader
  - `scripts/bin2txt.py`: Binary to text file converter
  - `scripts/write_vhd_synth_stub_parser.py`: VHDL synthesis stub file parser
  - `scripts/pip_requirements.txt`: Python dependencies (gitpython, PyYAML, pygithub, vhdeps)

**`.github/workflows/`:**
- Purpose: Reusable GitHub Actions workflow templates for CI/CD
- Contains: YAML workflow definitions for testing, releases, Conda builds, and Docker builds
- Key files:
  - `.github/workflows/ruckus_ci.yml`: Main CI: trailing whitespace checks, Python syntax (flake8), Doxygen docs
  - `.github/workflows/gen_release.yml`: Reusable release generation workflow (called by other repos)
  - `.github/workflows/conda_build_lib.yml`: Reusable Conda package build workflow (library type)
  - `.github/workflows/conda_build_proj.yml`: Reusable Conda package build workflow (project type)
  - `.github/workflows/conda_build_win.yml`: Reusable Conda build for Windows
  - `.github/workflows/docker_build.yml`: Reusable Docker image build and push to GHCR

## Key File Locations

**Entry Points (Makefiles -- consumed by target projects):**
- `system_vivado.mk`: Primary entry point for Vivado FPGA builds. Include from a target project's Makefile.
- `system_vitis_hls.mk`: Entry point for legacy Vitis HLS builds (TCL-based, `vitis_hls` CLI).
- `system_vitis_unified_hls.mk`: Entry point for Vitis Unified HLS builds (Python-based, `vitis` CLI).
- `system_cadence_genus.mk`: Entry point for Cadence Genus ASIC synthesis.
- `system_synopsys_dc.mk`: Entry point for Synopsys Design Compiler ASIC synthesis.
- `system_ghdl.mk`: Entry point for GHDL open-source VHDL simulation.
- `system_vcs.mk`: Entry point for standalone VCS simulation.
- `system_shared.mk`: Shared logic included by all other system_*.mk files.

**Configuration:**
- `Doxyfile`: Doxygen documentation generation config
- `.flake8`: Python linting rules (used by CI)
- `.gitattributes`: Git LFS tracking patterns
- `.gitignore`: Build artifact exclusions

**Core Build Logic (Vivado):**
- `vivado/sources.tcl`: Source code loading orchestrator
- `vivado/build.tcl`: Full synthesis-through-bitstream build orchestrator
- `vivado/proc.tcl`: Master procedure loader

**Core Build Logic (Vitis HLS):**
- `vitis/hls/sources.tcl`: Legacy TCL project creation
- `vitis/hls/build.tcl`: Legacy TCL build flow
- `vitis/hls/create_proj.py`: Unified Python project creation
- `vitis/hls/build.py`: Unified Python build flow

**Shared Procedures:**
- `shared/proc.tcl`: Cross-backend utility procedures
- `vivado_proc.tcl`: Standalone Vivado procedure loader (identical to `vivado/proc.tcl` but without user target sourcing)

## Naming Conventions

**Files:**
- Makefile entry points: `system_{toolchain}.mk` (lowercase, underscores)
- TCL scripts: `lowercase_with_underscores.tcl` (exception: `Dynamic_Function_eXchange.tcl` uses mixed case)
- Python scripts: `camelCase.py` for release tools (e.g., `firmwareRelease.py`, `releaseGen.py`)
- Shell scripts: `sim.sh` (short descriptive names)

**Directories:**
- Tool backends: Match vendor/tool naming (lowercase): `vivado/`, `vitis/`, `cadence/`, `synopsys/`, `ghdl/`
- Sub-tool directories: `cadence/genus/`, `synopsys/design_compiler/`, `vitis/hls/`
- Functional directories: `proc/`, `run/`, `scripts/`, `shared/`
- Special project: `MicroblazeBasicCore/` (PascalCase, matches Xilinx naming)

**TCL Procedures:**
- Public procedures: PascalCase (`LoadRuckusTcl`, `GenBuildString`, `CheckSynth`, `BuildIpCores`)
- Getter functions: `get`-prefixed PascalCase (`getFpgaFamily`, `getFpgaArch`)
- Boolean checks: `is`-prefixed PascalCase (`isVersal`)
- Internal helpers: PascalCase (`UpdateSrcFileLists`, `AnalyzeSrcFileLists`)

**Environment Variables:**
- All uppercase with underscores: `PROJECT`, `PROJ_DIR`, `TOP_DIR`, `OUT_DIR`, `RUCKUS_DIR`, `VIVADO_VERSION`
- Image format flags: `GEN_BIT_IMAGE`, `GEN_MCS_IMAGE`, `GEN_PDI_IMAGE`
- HLS-specific: `SKIP_CSIM`, `SKIP_COSIM`, `HDL_TYPE`, `EXPORT_VENDOR`, `EXPORT_VERSION`

## Where to Add New Code

**New EDA Tool Backend:**
- Create directory: `{vendor}/` or `{vendor}/{tool}/` following existing pattern
- Required files: `proc.tcl` (implement `loadRuckusTcl`, `loadSource`), `env_var.tcl`, `syn.tcl`
- Create matching Makefile: `system_{tool}.mk` at repository root
- Include `system_shared.mk` from the new Makefile
- Override `RUCKUS_PROC_TCL` to point to the new `proc.tcl`
- Source `shared/proc.tcl` from the new `proc.tcl`

**New Vivado Build Phase Hook:**
- Add pre/post dispatcher scripts: `vivado/run/pre/{phase}.tcl` and `vivado/run/post/{phase}.tcl`
- Follow existing pattern: source `env_var.tcl`, then `SourceTclFile ${VIVADO_DIR}/{user_script}.tcl`
- Document user script name in `README.md` table

**New Vivado TCL Procedure:**
- Add to the appropriate file in `vivado/proc/`:
  - Source loading: `vivado/proc/code_loading.tcl`
  - Build checks: `vivado/proc/checking.tcl`
  - IP management: `vivado/proc/ip_management.tcl`
  - Output files: `vivado/proc/output_files.tcl`
  - Project config: `vivado/proc/project_management.tcl`
  - Debug probes: `vivado/proc/debug_probes.tcl`
  - Simulation: `vivado/proc/sim_management.tcl`
  - Partial reconfiguration: `vivado/proc/Dynamic_Function_eXchange.tcl`
- If adding a new category, create a new file and add a `source` line in `vivado/proc.tcl`

**New Shared TCL Procedure:**
- Add to `shared/proc.tcl` if the procedure is needed across multiple backends (Vivado, Cadence, GHDL, Synopsys)
- Procedures here must be backend-agnostic (no Vivado-specific commands)

**New Vitis HLS Script (Unified Python API):**
- Add Python scripts to `vitis/hls/`
- Reference from `system_vitis_unified_hls.mk` using `vitis -s $(RUCKUS_DIR)/vitis/hls/{script}.py`
- Follow `create_proj.py` / `build.py` patterns for workspace and client setup

**New Vitis HLS Script (Legacy TCL API):**
- Add TCL scripts to `vitis/hls/`
- Reference from `system_vitis_hls.mk` using `vitis_hls -f $(RUCKUS_DIR)/vitis/hls/{script}.tcl`
- Source `env_var.tcl` and `proc.tcl` at the top

**New Python Utility Script:**
- Add to `scripts/`
- Use `camelCase.py` naming for consistency with existing scripts
- Add any new pip dependencies to `scripts/pip_requirements.txt`
- Ensure script passes `flake8` checks (CI enforced via `.flake8` config)

**New GitHub Actions Reusable Workflow:**
- Add to `.github/workflows/`
- Use `on: workflow_call:` pattern for reusable workflows (see `gen_release.yml` as template)
- Target `ubuntu-24.04` runners

**New Makefile Target:**
- Add to the appropriate `system_*.mk` file
- Follow existing pattern: `.PHONY` declaration, `ACTION_HEADER` call, `@cd $(OUT_DIR);` execution
- Use `$(SOURCE_DEPEND)` as prerequisite if the target needs loaded sources

## Special Directories

**`build/` (generated at project level, not in ruckus):**
- Purpose: Contains all build outputs, project files, synthesis/implementation runs
- Generated: Yes, by Makefile `dir` target
- Committed: No (in `.gitignore`)
- Location: `$(TOP_DIR)/build/$(PROJECT)/` or symlinked to `/u1/$(USER)/build/` if available

**`images/` (generated at target project level):**
- Purpose: Final output images (.bit, .mcs, .pdi, .ltx files)
- Generated: Yes, by build process
- Committed: No (in `.gitignore`, except `.bit.gz` and `.mcs.gz`)
- Location: `$(PROJ_DIR)/images/`

**`ip/` (generated at HLS target project level):**
- Purpose: Exported HLS IP core ZIP files
- Generated: Yes, by HLS build
- Committed: Varies by project
- Location: `$(PROJ_DIR)/ip/`

**`.planning/`:**
- Purpose: AI agent analysis documents
- Generated: Yes, by analysis tools
- Committed: Varies

---

*Structure analysis: 2026-03-24*
