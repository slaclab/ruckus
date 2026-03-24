# Testing Patterns

**Analysis Date:** 2026-03-24

## Test Framework

**Runner:**
- No unit test framework (no pytest, unittest, or TCL test harness)
- Testing is performed through CI linting and EDA tool simulation flows
- No automated test suite exists for the ruckus framework itself

**CI System:**
- GitHub Actions (`.github/workflows/ruckus_ci.yml`)
- Runs on: `ubuntu-24.04`
- Python: 3.12

**Run Commands:**
```bash
# CI validates code quality (not functional tests):
python -m compileall -f scripts/   # Python syntax validation
flake8 --count scripts/            # Python lint check
grep -rnI '[[:blank:]]$' ...       # Trailing whitespace check
grep -rnI $'\t' ...                # Tab character check
doxygen Doxyfile                   # Documentation generation
```

## Test Types

### CI Validation (ruckus_ci.yml)

The CI pipeline at `.github/workflows/ruckus_ci.yml` performs four validation steps:

**1. Trailing Whitespace Check:**
```bash
if grep -rnI '[[:blank:]]$' --include=\*.{tcl,py,sh} .; then
    echo "Error: Trailing whitespace found in the repository!"
    exit 1
fi
```
- Applies to: `.tcl`, `.py`, `.sh` files
- Zero tolerance - any trailing whitespace fails CI

**2. Tab Character Check:**
```bash
if grep -rnI $'\t' --include=\*.{tcl,py,sh} .; then
    echo "Error: Tab characters found in the repository! Please use spaces for indentation."
    exit 1
fi
```
- Applies to: `.tcl`, `.py`, `.sh` files
- Spaces only - tabs are forbidden

**3. Python Syntax and Lint Check:**
```bash
python -m compileall -f scripts/
flake8 --count scripts/
```
- Validates Python files compile without syntax errors
- Runs flake8 with relaxed rules from `.flake8` config
- Only checks `scripts/` directory (not `vitis/hls/*.py`)

**4. Doxygen Documentation Generation:**
```bash
doxygen Doxyfile
```
- Ensures documentation can be built from source comments
- Deployed to GitHub Pages on tagged releases

### Firmware Simulation (User-Project Level)

Ruckus provides simulation infrastructure but does not contain its own test benches. Simulation is driven by user projects that include ruckus as a submodule.

**Vivado XSIM Simulation:**
- Entry: `make xsim` (in user project)
- Script: `vivado/xsim.tcl`
- Configuration variables:
  - `VIVADO_PROJECT_SIM`: Simulation top module name
  - `VIVADO_PROJECT_SIM_TIME`: Simulation duration (default: `1000 ns`)
- Flow: Opens project -> Sets XSim simulator -> Launches simulation -> Runs for specified time

**VCS Simulation:**
- Entry: `make vcs` (in user project)
- Script: `vivado/vcs.tcl`
- Generates VCS scripts, user runs `./sim_vcs_mx.sh` manually
- Supports Rogue co-simulation via `setup_env.sh`/`setup_env.csh`

**ModelSim/Questa Simulation:**
- Entry: `make msim` (in user project)
- Script: `vivado/msim.tcl`
- Generates ModelSim scripts, user runs `./sim_msim.sh` manually

**GHDL Simulation:**
- Entry: `make tb` (via `system_ghdl.mk`)
- Flow: `load_source_code` -> `analysis` -> `import` -> `elab_order` -> `build` -> `tb`
- Uses `ghdl -r` with `--wave` output for waveform viewing
- GTKWave integration: `make gtkwave`
- Default stop time: `10ns` (configurable via `GHDL_STOP_TIME`)
- GHDL flags: `--std=08 --ieee=synopsys -frelaxed-rules -fexplicit`

**Cadence/Synopsys Simulation:**
- Script: `cadence/genus/sim.sh`, `synopsys/design_compiler/sim.sh`
- Uses VCS (`vlogan`, `vcs`) for gate-level simulation
- Compiles standard cells, post-synthesis netlist, and testbench
- Variables: `SIM_CARGS_VERILOG`, `SIM_CARGS_VHDL`, `SIM_VCS_FLAGS`

### Vitis HLS Simulation

**C-Simulation (csim):**
- Entry: `make csim` (Vitis Unified) or configured via `SKIP_CSIM` flag
- TCL: `vitis/hls/build.tcl` runs `csim_design -clean -O`
- Python: `vitis/hls/build.py` runs `hls_test_comp.run('C_SIMULATION')`
- Tests C/C++ source against C testbench

**Co-Simulation (cosim):**
- TCL: `cosim_design` in `vitis/hls/build.tcl`
- Python: `hls_test_comp.run('CO_SIMULATION')` in `vitis/hls/build.py`
- Compares C/C++ behavioral model against synthesized RTL
- Configurable: `SKIP_COSIM`, `HLS_SIM_TOOL` (xsim/vcs/modelsim/ncsim/riviera)
- Trace level: `HLS_SIM_TRACE_LEVEL` (default: `none`)

## Build Verification (Not Tests, But Validation)

Ruckus performs extensive build-time validation that functions as a testing layer:

### Syntax Checking
```tcl
# In vivado/proc/project_management.tcl - CheckPrjConfig
set syntaxReport [check_syntax -fileset ${fileset} -return_string -quiet -verbose]
```
- Runs Vivado's `check_syntax` on all source files before synthesis
- Available in Vivado 2016.1+
- Errors halt the build with detailed error messages

### Version Validation
```tcl
# In shared/proc.tcl
proc CheckGitVersion { }      # Validates git >= 2.9.0, git-lfs >= 2.1.1
proc SubmoduleCheck { }       # Validates submodule tag versions
proc CompareTags { }          # Semantic version comparison

# In vivado/proc/project_management.tcl
proc CheckVivadoVersion { }   # Validates Vivado version compatibility
proc VersionCheck { }         # User-callable version lock
proc VersionRangeCheck { }    # User-callable version range lock
```

### Timing Verification
```tcl
# In vivado/proc/checking.tcl
proc CheckTiming { } {
   set WNS [get_property STATS.WNS [get_runs impl_1]]
   set TNS [get_property STATS.TNS [get_runs impl_1]]
   set WHS [get_property STATS.WHS [get_runs impl_1]]
   set THS [get_property STATS.THS [get_runs impl_1]]
   # Checks setup, hold, pulse width, and routing
   # Returns false if any timing constraint is violated
}
```
- Timing failure halts the build by default
- Override flags: `TIG`, `TIG_SETUP`, `TIG_HOLD`, `TIG_PULSE`

### Synthesis/Implementation Completion Checks
```tcl
proc CheckSynth { }    # Verifies synthesis completed successfully
proc CheckImpl { }     # Verifies implementation completed successfully
proc CheckIpSynth { }  # Verifies IP core synthesis completed
```
- Check run progress, status, and log files for ERROR patterns
- GIT hash tracking: compares build hash to prevent stale builds

## Test File Organization

**Location:** No dedicated test files in ruckus itself
- Simulation testbench files live in user projects, not in ruckus
- User projects reference ruckus simulation infrastructure via `make xsim`, `make vcs`, etc.

**Naming:**
- Simulation top modules are set via `VIVADO_PROJECT_SIM` environment variable
- Default simulation top = project name
- VCS testbenches conventionally use `tb_${PROJECT}` prefix

## Mocking

**Framework:** Not applicable
- No unit test mocking framework exists
- Simulation uses the EDA tool's built-in simulation engine
- Hardware models come from Xilinx/vendor IP simulation libraries

## Fixtures and Factories

**Test Data:**
- HLS C-simulation test data is provided by user projects via `ARGV` variable
- GHDL testbenches use VHDL stimulus files from user projects
- No shared test fixtures in ruckus itself

## Coverage

**Requirements:** None enforced at the ruckus framework level
- No code coverage tools are configured
- No coverage thresholds exist
- Simulation coverage is a user-project concern

**HLS Coverage:**
- Vitis HLS co-simulation provides functional coverage of C-to-RTL equivalence
- No explicit coverage metrics collected

## CI/CD Workflows

### Primary CI Pipeline
- File: `.github/workflows/ruckus_ci.yml`
- Trigger: On every push
- Jobs:
  1. `test_and_document`: Lint checks + Doxygen
  2. `gen_release`: Creates GitHub release (on tags only)

### Release Generation
- File: `.github/workflows/gen_release.yml`
- Reusable workflow called from `ruckus_ci.yml`
- Runs `scripts/releaseGen.py` to auto-create GitHub releases from tags
- Depends on: `scripts/releaseNotes.py` for changelog generation

### Supporting Workflows
- `conda_build_lib.yml`: Conda package build for library projects
- `conda_build_proj.yml`: Conda package build for project releases
- `conda_build_win.yml`: Windows Conda package build
- `docker_build.yml`: Docker image builds

## Test Gaps

**No unit tests for TCL procedures:**
- All 71 TCL files have zero automated test coverage
- Procedures like `CompareTags`, `SubmoduleCheck`, `VersionCompare` contain logic that could be unit tested
- Files: `shared/proc.tcl`, `vivado/proc/checking.tcl`, `vivado/proc/project_management.tcl`

**No unit tests for Python scripts:**
- 9 Python scripts have zero pytest/unittest coverage
- CI only checks syntax compilation and flake8 linting for `scripts/` directory
- `vitis/hls/build.py` and `vitis/hls/create_proj.py` are not linted by CI
- Files: `scripts/firmwareRelease.py`, `scripts/releaseNotes.py`, `scripts/releaseGen.py`

**No integration tests:**
- Framework correctness depends entirely on real FPGA builds succeeding
- No mock EDA tool environment for testing build flows
- No regression test for verifying ruckus works across Vivado versions

**No TCL linting:**
- No equivalent of flake8 for TCL code
- TCL style is enforced only by the whitespace/tab CI checks
- No `nagelfar` or similar TCL lint tool configured

---

*Testing analysis: 2026-03-24*
