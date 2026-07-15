# Agent Guidance For ruckus

ruckus is a Makefile/TCL hybrid firmware build system for SLAC FPGA and ASIC projects. It is shared infrastructure that other repositories consume as a git submodule, not a single board project. It provides a standard library of TCL procedures, Makefile targets, and Python helper scripts that abstract Vivado, Vitis HLS, Vitis Unified (HLS/AIE), GHDL, VCS, Cadence Genus, and Synopsys DC into a consistent `make bit` / `make syn` / `make sim` interface, plus source loading, IP management, hook-script injection, and firmware release packaging.

Treat ruckus as a public API. Downstream firmware repos depend on the exact names and behavior of its TCL procedures, Makefile targets, exported variables, and hook-script filenames. Keep changes narrow, preserve existing public interfaces, and avoid broad style cleanups unless the user asks for them.

Do not stage files or make git commits unless the user explicitly asks for staging or committing.

## Repository Map

Start with [README.md](README.md) for user-facing links. Full documentation is published from `docs/` to https://slaclab.github.io/ruckus/. The most useful local orientation points are:

- `system_shared.mk` — common Makefile logic (build dir, git hash, build string) included by every backend.
- `system_vivado.mk`, `system_vcs.mk`, `system_ghdl.mk`, `system_synopsys_dc.mk`, `system_cadence_genus.mk`, `system_vitis_hls.mk`, `system_vitis_unified_hls.mk`, `system_vitis_unified_aie.mk` — per-backend Makefile entry points that projects `include`.
- `shared/proc.tcl` — backend-agnostic TCL procedures (`SourceTclFile`, `SubmoduleCheck`, `GenBuildString`, version/tag checks).
- `vivado/` — the Vivado flow. `vivado/proc.tcl` sources the per-topic procedure files under `vivado/proc/` (`code_loading.tcl`, `checking.tcl`, `ip_management.tcl`, `project_management.tcl`, `sim_management.tcl`, `debug_probes.tcl`, `output_files.tcl`, `Dynamic_Function_eXchange.tcl`, `SegmentedConfiguration.tcl`). Build-stage drivers (`sources.tcl`, `project.tcl`, `build.tcl`, `properties.tcl`, `env_var.tcl`, etc.) live directly under `vivado/`.
- `ghdl/`, `cadence/genus/`, `synopsys/design_compiler/`, `vitis/` — TCL for the non-Vivado backends.
- `scripts/` — Python helpers (`firmwareRelease.py`, `releaseGen.py`, `releaseNotes.py`, `createNewRepo.py`, `download_github_asset.py`, and small parsers). This is the only directory linted and syntax-checked by CI.
- `MicroblazeBasicCore/` — reference MicroBlaze SDK/Vitis sources.
- `docs/` — the Sphinx documentation site (see Documentation below).
- `.github/workflows/` — CI (`ruckus_ci.yml`), documentation (`docs.yml`), release (`gen_release.yml`), and conda/docker build workflows.

## The ruckus.tcl Recursive Loading Model

This is the single most important concept in the codebase. Every firmware project and every submodule library has a `ruckus.tcl` manifest that declares its source, IP, and constraint files. ruckus loads them recursively by following `loadRuckusTcl` calls.

- `loadRuckusTcl <dir>` saves the caller's `$::DIR_PATH`, sets `$::DIR_PATH` to `<dir>`, sources `<dir>/ruckus.tcl`, then restores the caller's `$::DIR_PATH`. This save/set/restore discipline is what makes recursion correct in a language with no per-call scope for globals.
- **Invariant:** at any instant during a load, `$::DIR_PATH` is the absolute path of the directory containing the `ruckus.tcl` that is currently executing.
- Every path passed to `loadSource`, `loadConstraints`, `loadIpCore`, `loadBlockDesign`, and `loadZipIpCore` MUST be anchored with `$::DIR_PATH`, e.g. `loadSource -dir "$::DIR_PATH/rtl"`. A bare relative path (`loadSource -dir "rtl"`) resolves against Vivado's working directory (`OUT_DIR`), not the source tree, and the directory-existence check will `exit -1` and abort the build.
- See [docs/explanation/ruckus_tcl_model.rst](docs/explanation/ruckus_tcl_model.rst) for the full walkthrough before touching loading logic.

## TCL Conventions

- Use three-space indentation. Do not use tab characters. Do not leave trailing whitespace on any line. CI (`ruckus_ci.yml`) fails the build if a `.tcl` file contains a tab or trailing whitespace.
- Keep the standard SLAC license banner at the top of maintained TCL files, using the `##` comment delimiter and the exact separator width of nearby files. Match the local file's existing banner text when adding to an existing subtree.
- Procedure names are the public API. Existing loaders and helpers use PascalCase for structural procedures (`GetCpuNumber`, `BuildInfo`, `SubmoduleCheck`, `CheckTiming`) and camelCase for the user-facing source loaders (`loadSource`, `loadRuckusTcl`, `loadConstraints`, `loadIpCore`, `loadBlockDesign`, `loadZipIpCore`, `getFpgaArch`). Preserve existing names and argument signatures; downstream `ruckus.tcl` files call them directly.
- Option-style procedures parse arguments with `::cmdline::getoptions`. Follow that pattern (and its `-path`/`-dir` mutual-exclusion checks) when extending a loader rather than inventing a new argument convention.
- Follow the established error style: print a fenced banner of `*` characters with a `procName: <reason>` message, then `exit -1`. Do not silently swallow errors in build-critical paths.
- Use `getFpgaArch` / `getFpgaFamily` / `isVersal` for family-specific selection. Follow existing family strings (`kintexu`, `virtexu`, `kintexuplus`, `zynquplus`, `zynquplusRFSOC`, `virtexuplus`, `virtexuplusHBM`, `versal`).
- Start a per-topic Vivado procedure file only when it belongs to a coherent group, source it from `vivado/proc.tcl`, and gate optional project overrides through `SourceTclFile`.
- Prefer the existing exported globals (`$::env(RUCKUS_DIR)`, `$::env(PROJ_DIR)`, `$::env(TOP_DIR)`, `$::env(OUT_DIR)`, `$::env(RUCKUS_PROC_TCL)`, `$::env(RUCKUS_QUIET_FLAG)`) over hard-coded paths.

## Hook Scripts

ruckus injects optional, project-supplied TCL at fixed points in the Vivado pipeline. Hooks are silently skipped when absent. Two tiers exist:

- **Tier-1 (pipeline-level):** files in a project's `$PROJ_DIR/vivado/` such as `sources.tcl`, `project_setup.tcl`, `properties.tcl`, `pre_synthesis.tcl`, `post_synthesis.tcl`, `post_route.tcl` (conditional on `CheckTiming`), and `post_build.tcl`.
- **Tier-2 (in-run):** `pre_*_run.tcl` / `post_*_run.tcl` registered via `STEPS.<STEP>.TCL.PRE/POST`, running inside the synth/impl subprocess where ruckus procedures are NOT auto-sourced.

The hook filenames, firing order, and the set of TCL variables in scope are a contract. Do not rename hooks, change when they fire, or drop variables from scope without updating [docs/reference/hook_scripts.rst](docs/reference/hook_scripts.rst) in the same change. `post_route.tcl` must remain conditional on `CheckTiming`.

## Makefile Conventions

- The `make` target names are a public interface: `make bit`/`make target`, `make syn`, `make sim`, `make test`, `make dir`, `make clean`, `make gui`, plus backend-specific targets. Preserve them and their behavior.
- Every backend `system_*.mk` includes `system_shared.mk`. Keep shared logic (build directory selection, `/u1` symlink handling, git hash/version/build-string generation, `IMAGENAME`) in `system_shared.mk` rather than duplicating it per backend.
- Preserve exported environment variables consumed by TCL and hook scripts (`PROJECT`, `PRJ_VERSION`, `PRJ_PART`, `TOP_DIR`, `PROJ_DIR`, `OUT_DIR`, `BUILD_STRING`, `GIT_HASH_LONG`, `RECONFIG_*`, etc.). Renaming or dropping one silently breaks downstream builds and hooks.
- Guard optional behavior with `ifndef`/`ifeq` and provide sane defaults, matching the existing style. Recipe lines must use real tabs (Makefile syntax); the CI whitespace/tab check only scans `.tcl`, `.py`, and `.sh`, so Makefiles are exempt — but do not introduce trailing whitespace.

## Python Conventions

- Python lives under `scripts/` and targets Python 3 (CI uses 3.12). Runtime dependencies are pinned in `scripts/pip_requirements.txt` (`gitpython`, `PyYAML`, `pygithub`, `vhdeps`).
- Keep the standard SLAC license banner at the top using the `#---` hash-comment style. For executable scripts, keep the shebang (`#!/usr/bin/env python3`) first and place the license block immediately after it. `Title`/`Description` sections are optional and follow the local file's pattern.
- Do not use tab characters and do not leave trailing whitespace. CI fails on either in `.py` (and `.sh`) files.
- Lint with the repo's config: `flake8 --count scripts/`. `.flake8` intentionally relaxes many whitespace and line-length rules (E1xx/E2xx, E501, W605, etc.) and excludes `__init__.py`. Do not run a general autoformatter that fights those relaxations; fix only real findings.
- CI also runs `python -m compileall -f scripts/`; make sure new/edited scripts import and byte-compile cleanly.

## Documentation

- `docs/` is a Sphinx site organized by the Diátaxis model: `explanation/`, `tutorial/`, `reference/`, `how-to/`, each with an `index.rst` wired into `docs/index.rst`.
- CI (`docs.yml`) builds with `sphinx-build -b html -W --keep-going docs/ docs/_build/html`. `-W` promotes every warning to an error, so a new `.rst`/`.md` page that is not referenced from a `toctree`, a broken cross-reference, or a bad heading underline will fail the build. Add new pages to the nearest `index.rst` toctree.
- `myst-parser` is enabled, so Markdown files placed under `docs/` are parsed by Sphinx. Keep task-planning or scratch Markdown OUT of the `docs/` tree, or the `-W` build will fail on an unreferenced document.
- Doc dependencies are pinned in `docs/requirements.txt`; keep the `sphinx` and `sphinx-rtd-theme` pins in sync when bumping either.
- When you change a TCL procedure signature, Makefile target/variable, or hook lifecycle, update the matching page under `docs/reference/` (`tcl_api.rst`, `makefile_reference.rst`, `hook_scripts.rst`) in the same change. Keep README links and the published docs accurate.

## Code Header Formats

Use the existing header style for the file type and local subtree. Do not rewrite imported, generated, or third-party headers.

TCL, Makefile, and other files using the SLAC firmware banner use the `##`/`#` hash style with the standard separator:

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

Python and other hash-comment files use the `#---` banner (shebang first if present):

```python
#-----------------------------------------------------------------------------
# Title      : Optional short title
#-----------------------------------------------------------------------------
# Description:
# Optional one- or two-line description
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
```

Some CI/workflow files use the `'Ruckus Package'` variant of this banner. Match whichever banner the file you are editing already uses rather than normalizing them.

## Tests And Verification

ruckus has no RTL or unit-test suite of its own; verification is CI-driven and lightweight:

- For edited `.tcl`, `.py`, or `.sh` files, check for tabs and trailing whitespace before staging (this is what `ruckus_ci.yml` enforces):

  ```sh
  grep -rnI $'\t' --include=\*.{tcl,py,sh} .
  grep -rnI '[[:blank:]]$' --include=\*.{tcl,py,sh} .
  ```

- For Python changes, run `flake8 --count scripts/` and `python -m compileall -f scripts/`.
- For documentation changes, run `sphinx-build -b html -W --keep-going docs/ docs/_build/html` (install `docs/requirements.txt` first) and confirm a clean, warning-free build.
- For TCL, Makefile, or backend changes, the most meaningful verification is a downstream build (`make bit`/`make sim` in a consuming firmware project) since ruckus is not exercised in isolation. When a full build is not practical, state what was and was not run and the remaining risk.
- Do not hand-edit or commit generated output such as `docs/_build/`, `build/`, or release artifacts.

## Task Tracking

For substantial feature work, refactors, or multi-step investigations, keep planning, progress, and handoff Markdown outside the published `docs/` tree so the `-W` Sphinx build is not affected. Capture the goal, current status, decisions, files involved, verification run, open risks, and next steps so another contributor can resume without reconstructing the work from chat history. Keep large logs and generated artifacts out of the notes; summarize and link instead.

## Pull Requests

Create pull requests against the `pre-release` branch unless the user or a maintainer directs otherwise. This repository has no `.github/pull_request_template.md`, so write a clean, release-note-ready `Description` of what changed and why; add build/verification context when it helps a reviewer. Do not stage files or make commits unless explicitly asked.
