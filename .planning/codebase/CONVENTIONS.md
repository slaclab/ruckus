# Coding Conventions

**Analysis Date:** 2026-03-24

## Languages Overview

Ruckus is a multi-language FPGA build framework. Code conventions vary by language:

| Language | File Count | Primary Use |
|----------|-----------|-------------|
| TCL | 71 | Build procedures, EDA tool automation, source loading |
| Python | 9 | Release management, HLS build scripts, utilities |
| Makefile | 8 | Top-level build orchestration per EDA tool |
| Shell | 2 | Simulation runner scripts |
| YAML | 6 | GitHub Actions CI workflows |

## File Header Convention

**Every file** must include the SLAC license header block. Two styles are used:

**TCL/Makefile style** (use `##` comment prefix):
```tcl
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
```

**Python style** (use `#` comment prefix with dashes):
```python
#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : [Script Title]
# ----------------------------------------------------------------------------
# Description:
# [Description text]
# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# ...
# ----------------------------------------------------------------------------
```

- Files: All `.tcl`, `.py`, `.mk`, `.sh`, `.yml` files
- Presence is CI-validated via `ruckus_ci.yml`

## Naming Patterns

### TCL Procedure Names

**Use PascalCase** for all TCL procedures:
- `LoadRuckusTcl`, `CheckTiming`, `BuildIpCores`, `CreateDebugCore`
- `GetCpuNumber`, `GetGitHash`, `GetFwVersion`, `GenBuildString`
- `SourceTclFile`, `CheckWritePermission`, `CompareTags`
- Exception: Some utility procs use camelCase: `getFpgaFamily`, `getFpgaArch`, `isVersal`
- Exception: `loadSource`, `loadIpCore`, `loadBlockDesign`, `loadConstraints` use camelCase (these are the public API procs called from user `ruckus.tcl` files)

**Convention rule:** Internal/infrastructure procs use PascalCase. User-facing API procs (called from `ruckus.tcl` files in target projects) use camelCase with a `load` prefix.

### TCL Variable Names

**Use camelCase** for local variables:
```tcl
set fileExt [file extension $params(path)]
set fbasename [file tail ${path}]
set gitHash $::env(GIT_HASH_LONG)
set ipSynthRun ${corePntr}_synth_1
set validTag [CompareTags ${tag} ${lockTag}]
```

**Use UPPER_CASE** for environment-derived variables:
```tcl
set PRJ_PART    $::env(PRJ_PART)
set PROJECT     $::env(PROJECT)
set OUT_DIR     $::env(OUT_DIR)
set VIVADO_DIR  $::env(VIVADO_DIR)
set RUCKUS_DIR  $::env(RUCKUS_DIR)
```

**Use UPPER_CASE with `::` prefix** for global TCL variables:
```tcl
set ::DIR_PATH ""
set ::DIR_LIST ""
set ::IP_LIST  ""
set ::IP_FILES ""
set ::BD_FILES ""
```

### Makefile Variable Names

**Use UPPER_CASE with underscores** for all Make variables:
```makefile
export PROJECT = $(notdir $(PWD))
export PROJ_DIR = $(abspath $(PWD))
export TOP_DIR  = $(abspath $(PROJ_DIR)/../..)
export MODULES = $(TOP_DIR)/submodules
export RUCKUS_DIR = $(MODULES)/ruckus
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))
```

### Python Naming

**Functions:** Use camelCase (matches TCL convention):
```python
def loadReleaseConfig():
def getVersion():
def releaseType(ver):
def selectRelease(cfg):
def selectBuildImages(cfg, relName, relData):
def buildRogueFile(zipName, cfg, ver, relName, relData, imgList):
def pushRelease(cfg, relName, relData, ver, tagAttach, prev):
```

**Local variables:** camelCase:
```python
relName = args.release
gitDir = os.path.join(args.project, cfg['GitBase'])
locRepo = git.Repo(gitDir)
remRepo = gh.get_repo(f'slaclab/{project}')
```

**Constants/config keys in YAML:** PascalCase:
```python
cfg['GitBase']
cfg['Releases']
cfg['Targets']
cfg['TopRoguePackage']
cfg['RoguePackages']
```

### File Naming

**TCL files:** Use lowercase with underscores:
- `env_var.tcl`, `proc.tcl`, `code_loading.tcl`, `debug_probes.tcl`
- `ip_management.tcl`, `output_files.tcl`, `project_management.tcl`
- `sim_management.tcl`, `pre_synthesis.tcl`, `post_synthesis.tcl`
- Exception: `Dynamic_Function_eXchange.tcl` (matches Xilinx terminology)

**Python files:** Use camelCase:
- `firmwareRelease.py`, `releaseGen.py`, `releaseNotes.py`
- `createNewRepo.py`, `bin2txt.py`, `download_github_asset.py`

**Makefile files:** Use `system_<toolname>.mk` pattern:
- `system_vivado.mk`, `system_vitis_hls.mk`, `system_ghdl.mk`
- `system_cadence_genus.mk`, `system_synopsys_dc.mk`, `system_shared.mk`

## Code Style

### Formatting

**Indentation:** 3 spaces for TCL, 4 spaces for Python. No tabs allowed anywhere.
- Files: `.tcl`, `.py`, `.sh`
- Enforced via CI: `.github/workflows/ruckus_ci.yml` runs `grep -rnI $'\t'` to reject tabs
- Trailing whitespace is also CI-rejected: `grep -rnI '[[:blank:]]$'`

**Python Linting:** flake8 with extensive rule relaxation in `.flake8`:
- Many whitespace rules are ignored (E201, E202, E221, E241, E251, etc.)
- Line length (E501) is not enforced
- Bare `except` (E722) is allowed
- `__init__.py` files are excluded from linting
- CI runs: `flake8 --count scripts/`

### TCL Variable Reference Style

**Always use `${varName}` braces** for variable references:
```tcl
# Correct
set fileExt [file extension ${filePath}]
puts "loadRuckusTcl: ${filePath} ${flags}"
if { [file exists ${filePath}/ruckus.tcl] == 1 } {

# Also correct for env vars
set PRJ_PART $::env(PRJ_PART)
source $::env(RUCKUS_DIR)/vivado/proc.tcl
```

### TCL Conditional Style

**Use braces around conditions, spaces around operators:**
```tcl
if { ${has_path} && ${has_dir} } {
   # error
} elseif {$has_path} {
   # load single file
} elseif {$has_dir} {
   # load directory
}
```

**Use `expr` for comparisons:**
```tcl
if { [expr { ${major} < ${majorLock} }] } {
   set validTag 0
}
```

## TCL Proc Argument Pattern

**Use the `cmdline` package** for complex argument parsing (Vivado-specific procs):
```tcl
package require cmdline

proc loadSource args {
   set options {
      {sim_only         "flag for tagging simulation file(s)"}
      {path.arg      "" "path to a single file"}
      {dir.arg       "" "path to a directory of file(s)"}
      {lib.arg       "" "library for file(s)"}
      {fileType.arg  "" "library for file(s)"}
   }
   set usage ": loadSource \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   # ...
}
```
- Location: `vivado/proc/code_loading.tcl`

**Use simple array parsing** for non-Vivado backends (GHDL, Synopsys, Cadence):
```tcl
proc loadSource args {
   array set params $args
   if {![info exists params(-path)]} {
      set has_path 0
   } else {
      set has_path 1
   }
   # ...
}
```
- Locations: `ghdl/proc.tcl`, `synopsys/design_compiler/proc.tcl`, `cadence/genus/proc.tcl`

## Error Handling

### TCL Error Handling

**Primary pattern: Visible banner + exit -1**
```tcl
puts "\n\n\n\n\n********************************************************"
puts "loadSource: $params(path) doesn't exist"
puts "********************************************************\n\n\n\n\n"
exit -1
```
- The distinctive `\n\n\n\n\n` (5 newlines) + `***` banner pattern is used universally
- All fatal errors call `exit -1`
- This pattern appears in every proc that validates inputs

**Secondary pattern: catch + return code**
```tcl
set src_rc [catch {add_files -fileset ${fileset} $params(path)} _RESULT]
if {$src_rc} {
   puts "\n\n\n\n\n********************************************************"
   puts ${_RESULT}
   puts "********************************************************\n\n\n\n\n"
   exit -1
}
```
- Used when calling Vivado/EDA tool commands that may fail
- The `_RESULT` variable captures the error message

**Tertiary pattern: Boolean return values**
```tcl
proc CheckSynth { {flags ""} } {
   # ... validation logic ...
   return true    # or return false
}

# Caller checks:
if { [CheckSynth] != true } {
   reset_run synth_1
}
```
- Check* procs return `true`/`false` strings
- Callers compare against `true` explicitly

### Python Error Handling

**Use `raise Exception()` for configuration errors:**
```python
if not 'GitBase' in cfg or cfg['GitBase'] is None:
    raise Exception("Invalid release config. GitBase key is missing or empty!")
```

**Use argparse for CLI validation:**
```python
parser = argparse.ArgumentParser('Release Generation')
parser.add_argument("--project", type=str, required=True, help="Project directory path")
```

**Bare except is permitted** (per `.flake8` E722 ignore):
```python
try:
    remRepo.get_release(newTag)
except:
    remRel = remRepo.create_git_release(...)
```

## Environment Variable Convention

Ruckus relies heavily on environment variables passed from Makefiles to TCL scripts:

**Core variables (always available):**
- `RUCKUS_DIR`: Path to ruckus submodule
- `PROJECT`: Project name (defaults to directory name)
- `PROJ_DIR`: Project directory path
- `TOP_DIR`: Top-level repository path
- `OUT_DIR`: Build output directory
- `MODULES`: Submodules directory path
- `PRJ_VERSION`: Firmware version hex string (e.g., `0x01000400`)

**Build metadata:**
- `GIT_HASH_LONG`: Full 40-char git SHA
- `GIT_HASH_SHORT`: Short git SHA
- `BUILD_STRING`: Human-readable build info string
- `IMAGENAME`: Output image filename (format: `PROJECT-VERSION-TIMESTAMP-USER-HASH`)

**Tool-specific:**
- `VIVADO_VERSION`: Detected Vivado version number
- `VIVADO_DIR`: Target's Vivado directory
- `RUCKUS_QUIET_FLAG`: Set to `-quiet` for suppressing source output

## Import Organization

### TCL Source Loading Order

TCL files are loaded via `source` commands in a specific order:

1. Environment variables: `source env_var.tcl`
2. Shared procedures: `source shared/proc.tcl`
3. Tool-specific procedures: `source vivado/proc.tcl` (which sources sub-procs)
4. Tool-specific messaging: `source messages.tcl`
5. Tool-specific properties: `source properties.tcl`
6. User project code: `loadRuckusTcl ${PROJ_DIR}` (loads user's `ruckus.tcl`)

### Python Imports

Standard library imports first, then third-party, then local:
```python
import os
import argparse
import zipfile

import git    # GitPython
import github # PyGithub

import releaseNotes  # local module
```

## Comments

### TCL Comment Style

**Use `##` for procedure documentation (Doxygen-compatible):**
```tcl
## \file vivado/proc.tcl
# \brief This script contains all the custom TLC procedures for Vivado

## Check if the Synthesize is completed
proc CheckSynth { {flags ""} } {
```

**Use `#` for inline and section comments:**
```tcl
# Check for error state
if {${has_path} && ${has_dir}} {

########################################################
## Section Header
########################################################
```

**Use `###` block separators for major sections:**
```tcl
###############################################################
#### Hardware Debugging Functions #############################
###############################################################
```

### Python Comment Style

**Use `#` for inline comments with section separators:**
```python
#############################################################################################

def githubLogin():
    # Inform the user that you are logging in
    print('\nLogging into github....\n')
```

## Module Design

### Proc File Organization

Each EDA tool backend provides a consistent set of procs by re-implementing the same API:

**Required API procs** (implemented per-backend):
- `loadRuckusTcl { filePath {flags ""} }` - Load a project's `ruckus.tcl`
- `loadSource args` - Load RTL source files (`-path`, `-dir`, `-lib`, `-sim_only`)
- `getFpgaFamily` - Return FPGA family string
- `getFpgaArch` - Return FPGA architecture string
- `isVersal` - Return whether target is Versal

**Backend-specific procs** in `vivado/proc/code_loading.tcl`:
- `loadIpCore args` - Load Xilinx IP core files (`.xci`, `.xcix`)
- `loadBlockDesign args` - Load block design files (`.bd`, `.tcl`)
- `loadConstraints args` - Load constraint files (`.xdc`, `.tcl`)
- `loadZipIpCore args` - Load ZIP-packaged IP cores

### Makefile Structure

Each `system_*.mk` file follows the same pattern:
1. Default variable definitions with `ifndef` guards
2. `include $(TOP_DIR)/submodules/ruckus/system_shared.mk`
3. `.PHONY : all` target
4. `test` target printing environment variables
5. `dir` target creating build directories
6. Tool-specific build targets
7. `clean` target removing `$(OUT_DIR)`

## Doxygen Documentation

**Configuration:** `Doxyfile` at repository root
- Documentation generated from `##`/`#` comment blocks in TCL
- CI generates docs on push, deploys on tag via `peaceiris/actions-gh-pages@v3`
- Files: `.github/workflows/ruckus_ci.yml`

---

*Convention analysis: 2026-03-24*
