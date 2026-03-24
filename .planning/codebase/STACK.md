# Technology Stack

**Analysis Date:** 2026-03-24

## Languages

**Primary:**
- Tcl (Tool Command Language) - Build system orchestration, EDA tool scripting, source loading, project management. ~70 `.tcl` files across `vivado/`, `vitis/hls/`, `ghdl/`, `cadence/genus/`, `synopsys/design_compiler/`, and `shared/`
- GNU Make - Top-level build entry points. 8 `.mk` files at root level: `system_vivado.mk`, `system_vitis_hls.mk`, `system_vitis_unified_hls.mk`, `system_ghdl.mk`, `system_cadence_genus.mk`, `system_synopsys_dc.mk`, `system_vcs.mk`, `system_shared.mk`

**Secondary:**
- Python 3 - Release management, utility scripts, Vitis Unified HLS Python CLI. 9 `.py` files in `scripts/` and `vitis/hls/`
- Bash - Simulation launcher scripts. 2 `.sh` files in `cadence/genus/sim.sh` and `synopsys/design_compiler/sim.sh`

**HDL (managed by ruckus, not part of ruckus itself):**
- VHDL (`.vhd`, `.vhdl`) - Primary firmware language for SLAC projects
- Verilog (`.v`, `.vh`) - Secondary firmware language
- SystemVerilog (`.sv`, `.svh`) - Secondary firmware language

## Runtime

**Environment:**
- Linux (primary target, Ubuntu-based). CI runs on `ubuntu-24.04`
- Windows (limited support for Conda builds only via `conda_build_win.yml`)

**Interpreters:**
- Tcl/tclsh - Standalone TCL scripts (GHDL flow uses `#!/usr/bin/tclsh`)
- Python 3.12 - Used in CI workflows and scripts
- Vivado Tcl interpreter - Embedded Tcl in Xilinx Vivado
- Vitis HLS Tcl interpreter - Embedded Tcl in Xilinx Vitis HLS (legacy flow)
- Vitis Python CLI - Python API for Vitis Unified IDE (new flow via `vitis -s`)

**Package Manager:**
- pip - Python dependencies specified in `scripts/pip_requirements.txt`
- Conda/Miniforge3 - Used for release packaging and distribution

## Frameworks

**Core:**
- GNU Make - Build orchestration layer. Each EDA tool has a dedicated `.mk` entry point
- Ruckus TCL framework - Custom procedural library providing `loadSource`, `loadIpCore`, `loadBlockDesign`, `loadConstraints`, `loadRuckusTcl`, `loadZipIpCore` across all backends

**EDA Tool Backends:**
- AMD/Xilinx Vivado - FPGA synthesis, implementation, bitstream generation (`system_vivado.mk`, `vivado/`)
- AMD/Xilinx Vitis HLS (legacy) - High-Level Synthesis using `vitis_hls` CLI (`system_vitis_hls.mk`, `vitis/hls/`)
- AMD/Xilinx Vitis Unified HLS - High-Level Synthesis using `vitis -s` Python CLI (`system_vitis_unified_hls.mk`, `vitis/hls/`)
- GHDL - Open-source VHDL simulator (`system_ghdl.mk`, `ghdl/`)
- Cadence Genus - ASIC synthesis (`system_cadence_genus.mk`, `cadence/genus/`)
- Synopsys Design Compiler - ASIC synthesis (`system_synopsys_dc.mk`, `synopsys/design_compiler/`)
- Synopsys VCS - HDL simulation (`system_vcs.mk`, `cadence/genus/sim.sh`, `synopsys/design_compiler/sim.sh`)

**Simulation:**
- Xilinx XSIM - Vivado built-in simulator (`vivado/xsim.tcl`)
- Synopsys VCS - Commercial simulator (`vivado/vcs.tcl`, `system_vcs.mk`)
- Mentor ModelSim/Questa - Commercial simulator (`vivado/msim.tcl`)
- GHDL - Open-source VHDL simulator (`system_ghdl.mk`)
- GTKWave - Waveform viewer (used with GHDL, `system_ghdl.mk` `gtkwave` target)
- Yosys - Open-source synthesis framework (used with GHDL for Verilog export, `system_ghdl.mk` `export_verilog` target)

**Documentation:**
- Doxygen - API documentation generation (`Doxyfile`)

**Linting:**
- flake8 - Python linting (`.flake8`)

## Key Dependencies

**Python (from `scripts/pip_requirements.txt`):**
- `gitpython` - Git repository interaction for release management
- `PyYAML` - YAML parsing for `releases.yaml` configuration
- `pygithub` - GitHub API integration for releases, repo creation, PR management
- `vhdeps` - VHDL dependency analysis and compile order resolution

**Python (used in scripts but not in pip_requirements.txt):**
- `requests` - HTTP downloads in `scripts/download_github_asset.py`
- `vitis` - AMD/Xilinx Vitis Python SDK (installed with Vitis toolchain), used in `vitis/hls/build.py` and `vitis/hls/create_proj.py`

**System Tools:**
- `git` >= 2.9.0 - Version control (version enforced in `shared/proc.tcl` `CheckGitVersion`)
- `git-lfs` >= 2.1.1 - Large file support for binary artifacts like `.dcp` files (version enforced in `shared/proc.tcl`)

## Configuration

**Build Configuration (Make Variables):**
- `PROJECT` - Project name, defaults to `$(notdir $(PWD))`
- `PROJ_DIR` - Project directory path
- `TOP_DIR` - Repository root, defaults to `$(abspath $(PROJ_DIR)/../..)`
- `MODULES` - Submodules directory, defaults to `$(TOP_DIR)/submodules`
- `RUCKUS_DIR` - Ruckus framework location, defaults to `$(MODULES)/ruckus`
- `PRJ_PART` - FPGA part number (Vivado flow, user-defined)
- `PRJ_VERSION` - Firmware version, defaults to `0xFFFFFFFF`
- `PARALLEL_SYNTH` - Number of parallel synthesis jobs, defaults to CPU count
- `GIT_BYPASS` - Skip git dirty check, defaults to `1`

**Vivado-Specific Variables (from `system_vivado.mk`):**
- `GEN_BIT_IMAGE` - Generate `.bit` files (default: 1)
- `GEN_BIN_IMAGE` - Generate `.bin` files (default: 0)
- `GEN_MCS_IMAGE` - Generate `.mcs` files (default: 1)
- `GEN_PDI_IMAGE` - Generate Versal `.pdi` files (default: 1)
- `GEN_XSA_IMAGE` - Generate `.xsa` files (default: 0)
- `RECONFIG_CHECKPOINT` - Dynamic partial reconfiguration checkpoint
- `REMOVE_UNUSED_CODE` - Remove unused HDL code (default: 0)
- `REPORT_QOR` - Generate Quality-of-Results reports (default: 0)

**Vitis HLS Variables (from `system_vitis_hls.mk`):**
- `HLS_SIM_TOOL` - Simulation tool selection: `xsim`, `vcs`, `modelsim`, `ncsim`, `riviera`
- `SKIP_CSIM` - Skip C simulation (default: 0)
- `SKIP_COSIM` - Skip co-simulation (default: 0)
- `HDL_TYPE` - Output HDL type: `verilog` or `vhdl` (default: verilog)
- `ALL_XIL_FAMILY` - Modify IP to support all Xilinx FPGA families

**Vitis Unified HLS Variables (from `system_vitis_unified_hls.mk`):**
- `ALL_XIL_FAMILY` - Modify IP to support all Xilinx FPGA families (default: 1)

**GHDL Variables (from `system_ghdl.mk`):**
- `GHDL_CMD` - GHDL executable path (default: `ghdl`)
- `GHDLFLAGS` - Build flags including `--std=08`, `--ieee=synopsys`
- `GHDL_TOP_LIB` - Top-level VHDL library (default: `work`)
- `GHDL_STOP_TIME` - Simulation stop time (default: `10ns`)

**ASIC Variables (from `system_cadence_genus.mk`, `system_synopsys_dc.mk`):**
- `PDK_PATH` - Process Design Kit path
- `STD_CELL_LIB` - Standard cell library path
- `STD_LEF_LIB` - LEF library path (Genus only)
- `OPERATING_CONDITION` - Operating condition for synthesis
- `MAX_CORES` - Maximum parallel cores (Genus default: 8, DC default: 4)
- `DIG_TECH` - Digital technology library (DC only)

**Release Configuration:**
- `releases.yaml` - User project file defining release targets, types (Rogue/CPSW), packages, and conda dependencies
- `hls_config.cfg` - Vitis Unified HLS project configuration file

**Build Directories:**
- `$(TOP_DIR)/build/$(PROJECT)` - Primary build output directory
- `/u1/$(USER)/build` - Optional fast-storage build directory (auto-detected in `system_shared.mk`)
- `$(PROJ_DIR)/images` - Output firmware image directory

## Platform Requirements

**Development:**
- Linux (Ubuntu recommended, based on CI usage of `ubuntu-24.04`)
- One or more EDA tools installed and in `$PATH`:
  - Vivado (for FPGA flow)
  - Vitis / Vitis HLS (for HLS flow)
  - GHDL (for open-source VHDL simulation)
  - Cadence Genus (for ASIC synthesis)
  - Synopsys Design Compiler (for ASIC synthesis)
  - Synopsys VCS (for simulation)
- Git >= 2.9.0 with git-lfs >= 2.1.1
- Python 3 with packages from `scripts/pip_requirements.txt`
- GNU Make

**CI/CD:**
- GitHub Actions on `ubuntu-24.04` runners
- Python 3.12
- Miniforge3/Conda for package builds

**Supported FPGA Families (from `vitis/hls/proc.tcl` family list):**
- Xilinx 7-Series: Artix-7, Kintex-7, Virtex-7, Zynq
- Xilinx UltraScale: Kintex UltraScale, Virtex UltraScale
- Xilinx UltraScale+: Kintex UltraScale+, Virtex UltraScale+, Virtex UltraScale+ HBM, Zynq UltraScale+, Zynq UltraScale+ RFSoC
- Xilinx/AMD Versal

---

*Stack analysis: 2026-03-24*
