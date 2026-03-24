# Codebase Concerns

**Analysis Date:** 2026-03-24

## Tech Debt

**Massive Code Duplication Across Tool Backends:**
- Issue: The `loadRuckusTcl`, `loadSource`, `loadConstraints`, `getFpgaFamily`, `getFpgaArch`, `isVersal` procedures are duplicated nearly identically across four separate proc files for different EDA tool backends (Cadence Genus, Synopsys Design Compiler, GHDL, Vivado).
- Files: `cadence/genus/proc.tcl`, `synopsys/design_compiler/proc.tcl`, `ghdl/proc.tcl`, `vivado/proc/code_loading.tcl`
- Impact: Bug fixes and feature additions must be applied in four places independently. Divergence between backends is likely. The `cadence/genus/proc.tcl` and `synopsys/design_compiler/proc.tcl` files are nearly character-for-character identical (both 214+ lines of duplicated code).
- Fix approach: Extract shared source-loading procedures into `shared/proc.tcl` (which already exists as a shared base). Each backend proc file already sources `shared/proc.tcl`; the shared source-loading logic (loadRuckusTcl, loadSource, loadConstraints) should be moved there with backend-specific hooks for the parts that differ (e.g., how files are actually added to the project).

**Duplicate Shell Scripts:**
- Issue: `cadence/genus/sim.sh` and `synopsys/design_compiler/sim.sh` are byte-for-byte identical (33 lines each).
- Files: `cadence/genus/sim.sh`, `synopsys/design_compiler/sim.sh`
- Impact: Any fix to one must be manually applied to the other.
- Fix approach: Create a single shared `shared/sim.sh` and symlink or source it from both tool directories.

**Duplicate `SourceTclFile` and `GetCpuNumber` Procedures:**
- Issue: `SourceTclFile` is defined identically in `shared/proc.tcl` (line 12) and `vitis/hls/proc.tcl` (line 19). `GetCpuNumber` is duplicated in `shared/proc.tcl` (line 22) and `vitis/hls/proc.tcl` (line 29).
- Files: `shared/proc.tcl`, `vitis/hls/proc.tcl`
- Impact: Minor maintenance burden but risks divergence.
- Fix approach: Have `vitis/hls/proc.tcl` source `shared/proc.tcl` instead of redefining these procedures.

**Duplicate `vivado_proc.tcl` Top-Level Wrapper:**
- Issue: `vivado_proc.tcl` (at the repo root) is an exact copy of `vivado/proc.tcl`. Both files source the same eight sub-procedure files.
- Files: `vivado_proc.tcl`, `vivado/proc.tcl`
- Impact: Two files to maintain; unclear which one users should reference.
- Fix approach: Remove one file and replace it with a symlink or a one-line `source` redirect.

**Travis CI Variable Names in GitHub Actions:**
- Issue: `scripts/releaseGen.py` still uses `TRAVIS_REPO_SLUG` and `TRAVIS_TAG` environment variable names. The GitHub Actions workflow (`gen_release.yml`) maps the correct values to these legacy variable names, but the naming is confusing and reflects a CI migration that was never fully completed.
- Files: `scripts/releaseGen.py` (lines 18-20), `.github/workflows/gen_release.yml` (lines 52-53)
- Impact: Confusing for maintainers. If someone runs `releaseGen.py` outside the GitHub Actions context, the error messages reference Travis CI.
- Fix approach: Rename variables in `releaseGen.py` to generic names (e.g., `GH_REPO`, `RELEASE_TAG`) and update the GitHub Actions workflow accordingly.

**Legacy SDK Support Alongside Vitis:**
- Issue: `system_vivado.mk` maintains parallel support for both the legacy Xilinx SDK (Vivado 2019.1 and older) and Vitis (2019.2 and newer), including `SDK_SRC_PATH` to `VITIS_SRC_PATH` variable mapping and duplicate tool detection logic.
- Files: `system_vivado.mk` (lines 163-218), `vivado/proc/checking.tcl` (lines 78-113)
- Impact: Adds complexity to the Makefile and Tcl procedures. Vivado 2019.1 reached end-of-life years ago.
- Fix approach: Evaluate whether SDK (pre-2019.2) support can be dropped. If so, remove the SDK code paths and simplify to Vitis-only.

**Commented-Out Code Blocks:**
- Issue: Several files contain commented-out code blocks that appear to be abandoned experiments or deferred features.
- Files: `vivado/proc/ip_management.tcl` (lines 52-62, commented-out XDC disable logic), `scripts/firmwareRelease.py` (line 28, commented-out `getpass` import), `scripts/write_vhd_synth_stub_parser.py` (line 129, commented-out `os.system` call), `vivado/sources.tcl` (line 87, commented-out `set_property top "glbl"`)
- Impact: Clutters the codebase and makes it unclear whether these code paths are intentionally disabled or simply forgotten.
- Fix approach: Review each commented block; either delete it or add a comment explaining why it is preserved.

## Known Bugs

**Typo in Procedure Name `RemoveUnsuedCode`:**
- Symptoms: The function is named `RemoveUnsuedCode` instead of `RemoveUnusedCode`. Functionally harmless since the misspelled name is used consistently, but it is a code quality issue.
- Files: `vivado/proc/project_management.tcl` (line 324), `vivado/sources.tcl` (line 136)
- Trigger: Always present; visible in IDE autocompletion and documentation.
- Workaround: The misspelling is consistent, so the function works. But any future reference using the correct spelling will fail silently.

**Typo in Commit Message in `createNewRepo.py`:**
- Symptoms: The auto-generated commit message reads "adding submdoules" instead of "adding submodules".
- Files: `scripts/createNewRepo.py` (line 339)
- Trigger: Every time a new repository is created using this script.
- Workaround: None; the typo is committed to every new repository's git history.

**`ImportStaticReconfigDcp` Does Not Exit on Missing File:**
- Symptoms: When `RECONFIG_CHECKPOINT` points to a non-existent file, the procedure prints an error message but does NOT exit or return an error code. Execution continues, leading to unpredictable failures downstream.
- Files: `vivado/proc/Dynamic_Function_eXchange.tcl` (lines 23-27)
- Trigger: Providing an invalid `RECONFIG_CHECKPOINT` path.
- Workaround: Ensure the checkpoint file exists before invoking the build.

## Security Considerations

**GitHub Token Handling:**
- Risk: Multiple scripts accept GitHub tokens via command-line arguments (`--token`), which are visible in process listings (`ps aux`). The `input()` fallback for interactive token entry does not mask input (unlike `getpass`). The commented-out `from getpass import getpass` in `firmwareRelease.py` suggests this was recognized but never addressed.
- Files: `scripts/firmwareRelease.py` (lines 75-79, 607-617), `scripts/createNewRepo.py` (lines 38-42, 143-176), `scripts/releaseNotes.py` (lines 183-189)
- Current mitigation: Tokens can also be set via `GITHUB_TOKEN` environment variable, which is the safer approach.
- Recommendations: Use `getpass.getpass()` for interactive token input. Add a deprecation warning when `--token` command-line argument is used, suggesting the environment variable approach instead.

**`os.system()` with String Interpolation in `createNewRepo.py`:**
- Risk: `os.system()` calls with f-string interpolation of user-provided arguments (`args.name`, `repo.full_name`) could be exploited if the repo name contains shell metacharacters.
- Files: `scripts/createNewRepo.py` (lines 335-340)
- Current mitigation: The repo name comes from a command-line argument and is also validated by GitHub's API.
- Recommendations: Replace `os.system()` with `subprocess.run()` using list arguments to avoid shell injection. Also consider using GitPython for these operations instead of shelling out.

**Bare `except:` Clauses Swallowing Exceptions:**
- Risk: Two Python files use bare `except:` that catch and silently handle all exceptions, including `KeyboardInterrupt` and `SystemExit`.
- Files: `scripts/createNewRepo.py` (line 292), `scripts/releaseGen.py` (line 60)
- Current mitigation: None.
- Recommendations: Use specific exception types (e.g., `except AttributeError:` in `createNewRepo.py` line 292, `except github.UnknownObjectException:` in `releaseGen.py` line 60).

**`eval` Usage in Tcl Simulation Scripts:**
- Risk: `vivado/xsim.tcl` (line 66) and `vivado/msim.tcl` (lines 197, 211) use `eval` on variables that originate from environment variables (`VIVADO_PROJECT_SIM_TIME`, `CompSimLibComm`). If these environment variables contain unexpected Tcl commands, they execute in the current interpreter context.
- Files: `vivado/xsim.tcl` (line 66), `vivado/msim.tcl` (lines 197, 211)
- Current mitigation: These variables are set by the Makefile system and are not user-facing inputs.
- Recommendations: Document that these variables must be trusted. Consider validation before `eval`.

**`CheckWritePermission` Uses Touch on LICENSE.txt:**
- Risk: The write-permission check in `shared/proc.tcl` (line 87) modifies the timestamp of `LICENSE.txt` in the ruckus submodule, which can cause the git submodule to appear dirty.
- Files: `shared/proc.tcl` (lines 86-98)
- Current mitigation: The `touch` only updates the timestamp if permissions allow.
- Recommendations: Use a temporary file in the build output directory for the write-permission check instead of modifying a tracked file.

## Performance Bottlenecks

**CPU Detection via `/proc/cpuinfo` Parsing:**
- Problem: CPU count is determined by parsing `/proc/cpuinfo` using `cat | grep | wc -l`, which is done both in Makefiles (evaluated at make parse time) and in Tcl scripts.
- Files: `system_vivado.mk` (line 36), `system_synopsys_dc.mk` (line 71), `shared/proc.tcl` (line 23), `vitis/hls/proc.tcl` (line 30)
- Cause: Legacy approach predating modern tools like `nproc`.
- Improvement path: Replace with `$(shell nproc)` in Makefiles and `exec nproc` in Tcl for reliability and clarity. The current approach also fails on non-Linux systems.

**PyGithub Tag Iteration for Validation:**
- Problem: `scripts/firmwareRelease.py` iterates through ALL tags in both local and remote repositories (lines 632-653) to check if old/new tags exist, using linear search.
- Files: `scripts/firmwareRelease.py` (lines 630-653)
- Cause: Simple iteration instead of targeted API calls.
- Improvement path: Use `remRepo.get_git_ref(f'tags/{tagName}')` with exception handling instead of iterating all tags. For local tags, use `git.Git.tag('-l', tagName)`.

## Fragile Areas

**Hardcoded SLAC-Specific Paths and Assumptions:**
- Files: `system_shared.mk` (lines 26-41), `scripts/firmwareRelease.py` (line 587), `scripts/releaseNotes.py` (line 180)
- Why fragile: `system_shared.mk` checks for `/u1/` directory and auto-creates build symlinks there -- a SLAC-specific local disk convention. `firmwareRelease.py` hardcodes the regex `slaclab/` for extracting repo names from URLs. `releaseNotes.py` similarly hardcodes `slaclab/` in its regex.
- Safe modification: The `/u1/` logic is guarded by existence checks and is harmless elsewhere. However, the `slaclab/` regex in release scripts will break for any non-SLAC organization.
- Test coverage: No automated tests exist for these scripts.

**Vivado Version Detection and Comparison:**
- Files: `vivado/proc/project_management.tcl` (lines 122-234), `shared/proc.tcl` (lines 101-149)
- Why fragile: Version comparison uses string-to-number casting of version strings. The `VersionCheck` proc (line 134) compares versions as floating-point numbers (`${VersionNumber} < ${lockVersion}`), which fails for versions like `2024.1.1` vs `2024.2` (string comparison semantics differ from numeric). `VersionCompare` (line 195) does proper three-part parsing but `VersionCheck` does not.
- Safe modification: Use `VersionCompare` consistently everywhere instead of direct numeric comparison.
- Test coverage: No unit tests for version comparison logic.

**Makefile Dependency on `vivado -version` at Parse Time:**
- Files: `system_vivado.mk` (line 112), `system_vitis_hls.mk` (line 27), `system_vitis_unified_hls.mk` (line 27)
- Why fragile: `VIVADO_VERSION` is set via `$(shell vivado -version ...)` which executes during Makefile parsing. If `vivado` is not in `PATH`, the Makefile fails immediately with a cryptic error, even for targets that do not need Vivado (like `clean` or `test`).
- Safe modification: Use `$(if ...)` or lazy evaluation to defer version detection until needed.
- Test coverage: None.

**Build String with Unescaped Special Characters:**
- Files: `system_shared.mk` (line 49)
- Why fragile: `BUILD_STRING` incorporates the output of `grep PRETTY_NAME /etc/os-release` which may contain parentheses, quotes, or other shell-special characters. This string propagates into Vivado TCL scripts and VHDL constants without sanitization.
- Safe modification: Sanitize the OS name string to remove problematic characters before embedding.
- Test coverage: None.

## Scaling Limits

**Global Tcl Variables for State Tracking:**
- Current capacity: Works for projects with moderate numbers of sources, IP cores, and block designs.
- Limit: `::DIR_LIST`, `::IP_LIST`, `::IP_FILES`, and `::BD_FILES` are simple space-delimited strings (set in `vivado/sources.tcl` lines 95-99 and appended in `vivado/proc/code_loading.tcl`). For very large projects with thousands of source files, string concatenation becomes inefficient.
- Scaling path: Convert to proper Tcl lists using `lappend` instead of string concatenation with spaces.

## Dependencies at Risk

**PyGithub API Compatibility:**
- Risk: `scripts/firmwareRelease.py` (lines 621-626) contains a try/except block to handle both PyGithub >= 2.0 (new `Auth.Token` syntax) and older versions (direct token string). `scripts/createNewRepo.py` (line 176) only uses the old syntax. Future PyGithub versions may drop the legacy API entirely.
- Impact: `createNewRepo.py` will break when the old `Github(token)` constructor is removed.
- Migration plan: Update `createNewRepo.py` to use the same try/except pattern as `firmwareRelease.py`, or pin a minimum PyGithub version and use only the new API.

**`vhdeps` Dependency:**
- Risk: `scripts/pip_requirements.txt` lists `vhdeps` as a dependency, but it is not imported by any Python script in the repository. It may be an unused dependency or used by downstream projects that install ruckus requirements.
- Impact: Adds an unnecessary dependency to the install if truly unused.
- Migration plan: Verify whether `vhdeps` is actually needed and remove if not.

**Unpinned Python Dependencies:**
- Risk: `scripts/pip_requirements.txt` lists `gitpython`, `PyYAML`, `pygithub`, and `vhdeps` without version pins.
- Files: `scripts/pip_requirements.txt`
- Impact: Builds may break when upstream packages release breaking changes (as already happened with PyGithub 2.0).
- Migration plan: Add minimum version pins (e.g., `pygithub>=2.0`, `gitpython>=3.1`).

## Missing Critical Features

**No Automated Tests:**
- Problem: The repository contains zero unit tests or integration tests for any of the Python scripts or Tcl procedures. The CI pipeline (`ruckus_ci.yml`) only checks for trailing whitespace, tab characters, Python syntax (`compileall`), and flake8 linting.
- Blocks: Safe refactoring of shared procedures, version comparison logic, and release scripts. Any refactoring to address the code duplication concerns is risky without tests.

**No Error Recovery in Build Scripts:**
- Problem: Build scripts (`vivado/build.tcl`, `vivado/sources.tcl`) use `exit -1` on most error conditions with no cleanup (e.g., releasing Vivado licenses, closing open files). The `catch` blocks in `build.tcl` handle the main synthesis/implementation steps but not pre/post-synthesis script failures.
- Files: `vivado/build.tcl`, `vivado/sources.tcl`
- Blocks: Automated build recovery, license pool management in shared environments.

## Test Coverage Gaps

**All Python Scripts Untested:**
- What's not tested: `scripts/firmwareRelease.py` (release generation, GitHub API interaction, zip/tar file creation), `scripts/createNewRepo.py` (repo creation, permission setting), `scripts/releaseGen.py` (tag-based release), `scripts/releaseNotes.py` (release note generation from PR history), `scripts/download_github_asset.py` (asset download)
- Files: `scripts/firmwareRelease.py`, `scripts/createNewRepo.py`, `scripts/releaseGen.py`, `scripts/releaseNotes.py`, `scripts/download_github_asset.py`
- Risk: Release generation is a critical workflow; bugs here can result in incorrect release artifacts, missing files in ZIP/tar packages, or failed GitHub releases.
- Priority: High

**All Tcl Procedures Untested:**
- What's not tested: Version comparison (`CompareTags`, `VersionCompare`, `VersionCheck`), source loading (`loadSource`, `loadIpCore`, `loadBlockDesign`, `loadConstraints`), build string generation (`GenBuildString`), timing check (`CheckTiming`), synthesis/implementation status checks (`CheckSynth`, `CheckImpl`)
- Files: `shared/proc.tcl`, `vivado/proc/checking.tcl`, `vivado/proc/code_loading.tcl`, `vivado/proc/project_management.tcl`
- Risk: Version comparison edge cases (e.g., versions with different numbers of dot-separated components) could cause incorrect behavior. The `VersionCheck` float comparison vs. `VersionCompare` integer parsing inconsistency is a concrete example.
- Priority: High for version comparison logic; Medium for source loading (exercised heavily in practice but untested programmatically).

**Makefile Logic Untested:**
- What's not tested: The conditional `/u1/` build directory logic in `system_shared.mk`, the `RECONFIG_CHECKPOINT` parsing in `system_vivado.mk`, the SDK-to-Vitis variable mapping.
- Files: `system_shared.mk`, `system_vivado.mk`
- Risk: Makefile conditional logic is notoriously hard to debug; errors manifest as incorrect variable values that silently propagate.
- Priority: Medium

---

*Concerns audit: 2026-03-24*
