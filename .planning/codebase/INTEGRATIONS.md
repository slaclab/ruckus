# External Integrations

**Analysis Date:** 2026-03-24

## EDA Tool Integrations

Ruckus is a multi-backend firmware build framework. Each backend integrates with a specific EDA (Electronic Design Automation) tool suite via dedicated Makefile entry points, TCL scripts, and proc libraries.

### AMD/Xilinx Vivado (FPGA Synthesis & Implementation)

**Entry Point:** `system_vivado.mk`
**Tool Binary:** `vivado` (must be in `$PATH`)
**Version Detection:** `vivado -version | grep -Po "v(\d+\.)+\d+" | cut -c2-"` in `system_vivado.mk` line 112
**TCL Scripts:**
- `vivado/sources.tcl` - Project creation and source loading
- `vivado/build.tcl` - Synthesis and implementation batch flow
- `vivado/gui.tcl` - GUI mode launch
- `vivado/project.tcl` - Project file management
- `vivado/properties.tcl` - Synthesis/implementation property configuration
- `vivado/messages.tcl` - Message severity configuration
- `vivado/env_var.tcl` - Environment variable mapping to TCL variables
- `vivado/proc.tcl` - Master procedure library (loads all proc/*.tcl files)
- `vivado/proc/code_loading.tcl` - `loadSource`, `loadIpCore`, `loadBlockDesign`, `loadConstraints`, `loadZipIpCore` procedures
- `vivado/proc/checking.tcl` - Build validation procedures
- `vivado/proc/debug_probes.tcl` - ILA debug probe management
- `vivado/proc/Dynamic_Function_eXchange.tcl` - Partial reconfiguration support
- `vivado/proc/ip_management.tcl` - IP core build and upgrade
- `vivado/proc/output_files.tcl` - Bitstream and image file generation
- `vivado/proc/project_management.tcl` - Project file operations
- `vivado/proc/sim_management.tcl` - Simulation setup
- `vivado/run/pre/*.tcl` - Pre-step hook scripts (synth, opt, place, route, etc.)
- `vivado/run/post/*.tcl` - Post-step hook scripts

**Make Targets:**
- `bit` / `mcs` / `prom` / `pdi` - Full synthesis + implementation + bitstream
- `syn` - Synthesis only
- `dcp` - Synthesis DCP output
- `gui` - Open Vivado GUI with project
- `interactive` - Vivado TCL interactive mode
- `xsim` - Xilinx XSIM simulation
- `vcs` - Generate VCS simulation scripts
- `msim` - ModelSim/Questa simulation
- `batch` - Batch mode within project environment
- `sources` - Source loading only
- `pyrogue` - Generate pyrogue.tar.gz
- `yaml` - Generate CPSW YAML config
- `sdk` / `vitis` - Launch embedded SDK/Vitis GUI
- `elf` - Generate embedded ELF file

**Output Formats:**
- `.bit` - FPGA bitstream
- `.bin` - Binary image
- `.mcs` - Intel MCS flash image
- `.pdi` - Versal programmable device image
- `.xsa` - Xilinx Support Archive (for embedded)
- `.ltx` - Debug probes file
- `.dcp` - Design checkpoint

### AMD/Xilinx Vitis HLS (Legacy TCL Flow)

**Entry Point:** `system_vitis_hls.mk`
**Tool Binary:** `vitis_hls` (must be in `$PATH`)
**Minimum Version:** 2021.1 (enforced in `vitis/hls/proc.tcl` `HlsVersionCheck`)
**TCL Scripts:**
- `vitis/hls/sources.tcl` - Project creation and source loading
- `vitis/hls/build.tcl` - C simulation, synthesis, co-simulation, export
- `vitis/hls/interactive.tcl` - Interactive TCL mode
- `vitis/hls/proc.tcl` - HLS-specific procedures
- `vitis/hls/env_var.tcl` - Environment variable setup

**Make Targets:**
- `build` - Full HLS build (csim + synthesis + cosim + export)
- `interactive` - Interactive TCL shell
- `gui` - Open Vitis HLS GUI
- `sources` - Source setup only

**User Project Files:**
- `sources.tcl` - HLS source file definitions
- `solution.tcl` - Solution configuration (clock, part, directives)
- `directives.tcl` - HLS optimization directives

### AMD/Xilinx Vitis Unified HLS (New Python CLI Flow)

**Entry Point:** `system_vitis_unified_hls.mk`
**Tool Binary:** `vitis` with `-s` flag for Python scripting (must be in `$PATH`)
**Python Scripts:**
- `vitis/hls/create_proj.py` - Project creation using `vitis.create_client()` API
- `vitis/hls/build.py` - Build flow: C_SIMULATION, SYNTHESIS, CO_SIMULATION, PACKAGE, IMPLEMENTATION
- `vitis/hls/dcp_rename_ref.tcl` - Post-build DCP reference renaming (uses Vivado)

**Python API Usage:**
```python
import vitis
client = vitis.create_client()
client.set_workspace(workspace)
hls_test_comp = client.create_hls_component(name=comp_name, cfg_file=[cfg_file])
hls_test_comp.run('C_SIMULATION')
hls_test_comp.run('SYNTHESIS')
hls_test_comp.run('CO_SIMULATION')
hls_test_comp.run('PACKAGE')
hls_test_comp.run('IMPLEMENTATION')
vitis.dispose()
```

**Make Targets:**
- `proj` - Create HLS project
- `build` - Full HLS build
- `csim` - C simulation only
- `interactive` - Vitis interactive Python shell
- `gui` - Vitis Unified IDE

**User Project Files:**
- `hls_config.cfg` - HLS configuration file (replaces legacy `solution.tcl`)

### GHDL (Open-Source VHDL Simulation)

**Entry Point:** `system_ghdl.mk`
**Tool Binary:** `ghdl` (configurable via `GHDL_CMD`)
**VHDL Standard:** VHDL-2008 (`--std=08`)
**IEEE Library:** Synopsys (`--ieee=synopsys`)
**TCL Scripts:**
- `ghdl/proc.tcl` - GHDL-specific `loadSource`, `loadRuckusTcl` procedures
- `ghdl/load_source_code.tcl` - Source code loading (uses `tclsh`)
- `ghdl/analysis.tcl` - GHDL analyze step (uses `vhdeps` for compile order)
- `ghdl/import.tcl` - GHDL import step

**Make Targets:**
- `load_source_code` - Load source files
- `analysis` - Analyze VHDL (`ghdl -a`)
- `import` - Import VHDL (`ghdl -i`)
- `elab_order` - Elaboration order (`ghdl --elab-order`)
- `build` - Build design (`ghdl -m`)
- `tb` - Run testbench (`ghdl -r`)
- `gtkwave` - View waveforms in GTKWave
- `elaboration` - Full elaboration (`ghdl -e`)
- `export_verilog` - Export VHDL to Verilog via Yosys+GHDL plugin

**External Tool Dependencies:**
- `vhdeps` - VHDL dependency resolution (Python package)
- `yosys` with GHDL plugin - For Verilog export

### Cadence Genus (ASIC Synthesis)

**Entry Point:** `system_cadence_genus.mk`
**Tool Binary:** `genus`
**TCL Scripts:**
- `cadence/genus/proc.tcl` - Genus-specific `loadSource`, `loadRuckusTcl`, `AnalyzeSrcFileLists` procedures
- `cadence/genus/syn.tcl` - Synthesis flow
- `cadence/genus/behavioral_verilog.tcl` - Behavioral Verilog export
- `cadence/genus/env_var.tcl` - Environment variables
- `cadence/genus/messages.tcl` - Message configuration

**Make Targets:**
- `syn` - Run synthesis
- `behavioral_verilog` - Export behavioral Verilog
- `sim` - VCS simulation of synthesized design

**External Tool Dependencies:**
- `vhdeps` - VHDL dependency resolution
- VCS (`vlogan`, `vcs`) - For post-synthesis simulation

### Synopsys Design Compiler (ASIC Synthesis)

**Entry Point:** `system_synopsys_dc.mk`
**Tool Binary:** `dc_shell-xg-t -64bit -topographical_mode` (configurable via `DC_CMD`)
**TCL Scripts:**
- `synopsys/design_compiler/proc.tcl` - DC-specific `loadSource`, `loadRuckusTcl`, `AnalyzeSrcFileLists` procedures
- `synopsys/design_compiler/syn.tcl` - Synthesis flow
- `synopsys/design_compiler/env_var.tcl` - Environment variables

**Make Targets:**
- `syn` - Run synthesis
- `sim` - VCS simulation of synthesized design

### Synopsys VCS (Standalone Simulation)

**Entry Point:** `system_vcs.mk`
**Tool Binaries:** `vlogan` (analyzer), `vcs` (simulator)
**Make Targets:**
- `analyzes` - Analyze source files
- `elaborate` - Elaborate design
- `gui` - Run simulation with DVE GUI
- `gen_vcs_ip` - Generate VCS IP package
- `pre_compiled_ip` - Build pre-compiled IP

### Xilinx SDK / Vitis Embedded (MicroBlaze)

**TCL Scripts (legacy SDK):**
- `MicroblazeBasicCore/sdk/bit.tcl` - Generate bitstream with ELF
- `MicroblazeBasicCore/sdk/elf.tcl` - ELF generation
- `MicroblazeBasicCore/sdk/prj.tcl` - SDK project creation

**TCL Scripts (Vitis):**
- `MicroblazeBasicCore/vitis/bit.tcl` - Generate bitstream with ELF
- `MicroblazeBasicCore/vitis/elf.tcl` - ELF generation
- `MicroblazeBasicCore/vitis/prj.tcl` - Vitis project creation

**Auto-Detection:** `system_vivado.mk` detects whether `vitis` or `xsdk` is available and sets `EMBED_TYPE` accordingly (line 200-218)

## APIs & External Services

### GitHub API

**SDK/Client:** PyGithub (`pygithub` package)
**Auth:** `GITHUB_TOKEN` environment variable or `--token` CLI arg or `GH_REPO_TOKEN` env var (legacy Travis CI)
**Used In:**
- `scripts/firmwareRelease.py` - Create tagged releases, upload assets, manage tags
- `scripts/releaseGen.py` - Auto-generate releases from CI (Travis CI legacy)
- `scripts/releaseNotes.py` - Generate markdown release notes from PR history
- `scripts/createNewRepo.py` - Create new GitHub repos with team permissions, submodules, branch protection
- `scripts/download_github_asset.py` - Download release assets from private repos

**Operations:**
- Create git tags and push to remote
- Create GitHub releases with assets
- Generate release notes from merged PRs (categorized by labels: Bug, Enhancement, Documentation, Interface-change)
- Upload firmware images as release assets
- Create repositories with team/user permissions
- Set branch protection rules
- Download release assets with token authentication

**GitHub Organization:** `slaclab` (hardcoded in `scripts/firmwareRelease.py` line 587, `scripts/releaseGen.py` line 39)

### GitHub Actions (CI/CD)

**Workflows:**
- `.github/workflows/ruckus_ci.yml` - Main CI: trailing whitespace/tab checks, Python syntax (flake8), Doxygen docs, release generation
- `.github/workflows/gen_release.yml` - Reusable workflow for generating GitHub releases from tags
- `.github/workflows/docker_build.yml` - Reusable workflow for Docker image builds, pushes to GHCR
- `.github/workflows/conda_build_lib.yml` - Reusable workflow for Conda library builds
- `.github/workflows/conda_build_proj.yml` - Reusable workflow for Conda project builds
- `.github/workflows/conda_build_win.yml` - Reusable workflow for Windows Conda builds

**Secrets Required:**
- `GH_TOKEN` - GitHub token for releases, Docker pushes, documentation deployment
- `CONDA_UPLOAD_TOKEN_TAG` - Anaconda.org upload token

**GitHub Actions Used:**
- `actions/checkout@v2`, `@v3`, `@v4`
- `actions/setup-python@v2`, `@v4`
- `peaceiris/actions-gh-pages@v3` - Deploy docs to GitHub Pages
- `docker/setup-buildx-action@v3`
- `docker/login-action@v3`
- `docker/build-push-action@v6`

### GitHub Container Registry (GHCR)

**Registry:** `ghcr.io`
**Used In:** `.github/workflows/docker_build.yml`
**Image Tags:** `ghcr.io/slaclab/{docker_name}:{tag}` and `ghcr.io/slaclab/{docker_name}:latest`
**Auth:** GitHub token via `docker/login-action`

### GitHub Pages

**Used In:** `.github/workflows/ruckus_ci.yml` line 65-69
**Content:** Doxygen-generated documentation published to `html/` directory
**Trigger:** Tag releases only

## Data Storage

**Databases:**
- None (filesystem-based build system)

**File Storage:**
- Local filesystem only
- Build artifacts stored in `$(TOP_DIR)/build/$(PROJECT)/`
- Firmware images stored in `$(PROJ_DIR)/images/`
- Release files stored in `$(TOP_DIR)/release/`
- Optional fast storage at `/u1/$(USER)/build` (auto-detected in `system_shared.mk` lines 26-41)

**Caching:**
- Build directory caching via Make dependency tracking (`$(SOURCE_DEPEND)`)
- IP core synthesis run caching (Vivado incremental builds)
- Git hash change detection triggers synthesis reset (`vivado/sources.tcl` lines 49-79)

## Package Distribution

### Conda / Anaconda

**Build System:** Miniforge3 with conda-build
**Channels:** `tidair-tag`, `tidair-packages`, `conda-forge`
**Upload Target:** Anaconda.org via `anaconda` CLI

**Package Types:**
1. **Library builds** (`.github/workflows/conda_build_lib.yml`) - Compiled libraries with C/C++ components
2. **Project builds** (`.github/workflows/conda_build_proj.yml`) - Python packages from release ZIP files
3. **Windows builds** (`.github/workflows/conda_build_win.yml`) - Windows-specific Conda packages

**Auto-Generated Files (in `scripts/firmwareRelease.py`):**
- `conda-recipe/build.sh` - Build script
- `conda-recipe/meta.yaml` - Package metadata with dependencies
- `conda.sh` - Convenience build script
- `conda-recipe/conda_build_config.yaml` - Pin configuration (for library builds)

**Default Dependencies:**
- `rogue` (DAQ framework)
- `python>=3.7`
- User-configurable via `CondaDependencies` in `releases.yaml`

### Python setuptools

**Generated In:** `scripts/firmwareRelease.py` `buildSetupPy()` function
**Distribution:** ZIP files uploaded as GitHub release assets (e.g., `rogue_v1.2.3.zip`)
**Contents:** Python packages, configuration files, firmware images, scripts

### Release ZIP/Tarball

**Rogue ZIP** (`rogue_{version}.zip`):
- Python packages from `RoguePackages` config
- Configuration files from `RogueConfig` config
- Firmware images (`.bit`, `.mcs`, etc.)
- Scripts from `RogueScripts` config
- Auto-generated `setup.py` and conda recipe
- `LICENSE.txt`

**CPSW Tarball** (`cpsw_{version}.tar.gz`):
- CPSW source files from `CpswSource` config
- CPSW configuration files from `CpswConfig` config

## Authentication & Identity

**Auth Provider:** GitHub (token-based)
- `GITHUB_TOKEN` environment variable (primary)
- `--token` CLI argument (alternative)
- `GH_REPO_TOKEN` environment variable (legacy Travis CI compatibility)

**No Other Auth:** No database auth, no SSH key management, no OAuth flows

## Monitoring & Observability

**Error Tracking:** None (build system - errors are in console/log output)

**Logs:**
- Build logs stored in EDA tool output directories
- `$(OUT_DIR)/$(PROJECT).elab_order` (GHDL elaboration order)
- `$(SIM_OUT_DIR)/elaborate.log` (VCS elaboration log)
- `build.info` file generated by `shared/proc.tcl` `BuildInfo` procedure

**Build Metadata:**
- `BUILD_STRING` environment variable: `$(PROJECT): Vivado v${VIVADO_VERSION}, ${BUILD_SYS_NAME} (${BUILD_SVR_TYPE}), Built ${BUILD_DATE} by ${BUILD_USER}`
- `BuildInfoPkg.vhd` auto-generated VHDL package with build info constant (generated by `shared/proc.tcl` `GenBuildString`)
- `BUILD_INFO_G` top-level VHDL generic with git hash, firmware version, and build string

## JIRA Integration

**Used In:** `scripts/releaseNotes.py` line 69-72
**Pattern:** Branch names starting with `slaclab/es` are parsed as JIRA ticket references
**URL Format:** `https://jira.slac.stanford.edu/issues/{ticket_id}`
**Scope:** Release notes generation only (informational link in PR details)

## Git Submodule Management

**Core Pattern:** Ruckus expects to live at `$(TOP_DIR)/submodules/ruckus`
**Default Submodules (new repos):** `ruckus` and `surf` (SLAC firmware standard library)
**Version Checking:** `shared/proc.tcl` `SubmoduleCheck` procedure validates submodule tags against minimum version requirements
**LFS Support:** Error messages in `vivado/proc/code_loading.tcl` detect git-lfs issues with `.dcp` files and provide recovery instructions

## Webhooks & Callbacks

**Incoming:**
- GitHub Actions webhook triggers on `push` events (`.github/workflows/ruckus_ci.yml`)
- Tag-based triggers for release and Conda build workflows

**Outgoing:**
- None

## Environment Configuration

**Required Environment Variables (tool-specific):**
- EDA tool must be in `$PATH` (Vivado, Vitis, GHDL, Genus, or DC)
- `GITHUB_TOKEN` - Required for release scripts and CI

**Optional Environment Variables:**
- `XILINX_LOCAL_USER_DATA` - Set to `no` to work around Vivado app install errors (default in `system_vivado.mk`)
- `LD_PRELOAD` - Legacy SDK compatibility
- `SWT_GTK3` - Legacy SDK GTK3 compatibility

**CI Environment Variables (GitHub Actions):**
- `TRAVIS_REPO_SLUG` - Repository slug (legacy naming, maps from `github.repository`)
- `TRAVIS_TAG` - Release tag (legacy naming, maps from git describe)
- `GH_REPO_TOKEN` - GitHub token (legacy naming)

---

*Integration audit: 2026-03-24*
