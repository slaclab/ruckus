The Vivado Build Pipeline
==========================

Running ``make bit`` triggers two separate Vivado invocations. The first, driven by
``sources.tcl``, assembles the Vivado project from the project's ``ruckus.tcl`` declarations.
The second, driven by ``build.tcl``, runs synthesis, implementation, and bitstream generation.
Both invocations run Vivado in batch mode (no GUI).

Build Flow Diagram
-------------------

.. code-block:: none

   make bit
      │
      ├──[Phase 1: Project Assembly]──────────────────────────────────────────────────────
      │   vivado -mode batch -source sources.tcl
      │      │
      │      ├──► Load env_var.tcl + proc.tcl
      │      ├──► CheckWritePermission
      │      ├──► CheckGitVersion (git >= 2.9.0, git-lfs >= 2.1.1)
      │      ├──► Create images/ directory if absent
      │      ├──► Open or create Vivado project (.xpr)
      │      ├──► VivadoRefresh (update IP catalog)
      │      ├──► GenBuildString → BuildInfoPkg.vhd
      │      ├──► Check git hash / firmware version; reset synth if changed
      │      ├──► loadRuckusTcl $PROJ_DIR ────────────────► ruckus.tcl recursion
      │      │       │                                           │
      │      │       │                            loadSource / loadConstraints / loadIpCore
      │      │       │                            loadRuckusTcl (sub-modules)
      │      │       └───────────────────────────────────────────────────────
      │      ├──► Set PATH_MODE AbsoluteFirst on all filesets
      │      ├──► UpgradeIpCores (if ::IP_LIST non-empty)
      │      ├──► [hook: ${VIVADO_DIR}/sources.tcl]
      │      ├──► Write dirList.txt, ipList.txt, bdList.txt
      │      └──► close_project
      │
      └──[Phase 2: Build]─────────────────────────────────────────────────────────────────
          vivado -mode batch -source build.tcl
             │
             ├──► open_project + load properties.tcl + messages.tcl
             ├──► update_compile_order
             ├──► CheckPrjConfig (verify sources_1 and sim_1)
             ├──► CheckImpl / CheckSynth (reset runs if needed)
             ├──► BuildIpCores (re-synthesize out-of-date IP cores)
             ├──► [hook: ${VIVADO_DIR}/pre_synthesis.tcl]
             ├──► launch_runs synth_1 -jobs $PARALLEL_SYNTH
             │       ├──► [hook: ${VIVADO_DIR}/pre_synth_run.tcl]   (in-run)
             │       └──► [hook: ${VIVADO_DIR}/post_synth_run.tcl]  (in-run)
             ├──► [hook: ${VIVADO_DIR}/post_synthesis.tcl]
             ├──► [exit if SYNTH_ONLY=1 or SYNTH_DCP=1]
             ├──► launch_runs -to_step write_bitstream impl_1
             │       ├──► [hook: ${VIVADO_DIR}/pre_route_run.tcl]   (in-run)
             │       └──► [hook: ${VIVADO_DIR}/post_route_run.tcl]  (in-run)
             ├──► CheckTiming (exits if violations; see TIG_* overrides)
             ├──► [hook: ${VIVADO_DIR}/post_route.tcl]
             ├──► CreateFpgaBit / CreateVersalOutputs
             ├──► [hook: ${VIVADO_DIR}/post_build.tcl]
             └──► images/$(IMAGENAME).bit  [and .mcs, .ltx, .pdi, .xsa as configured]


Phase 1: sources.tcl in Detail
---------------------------------

``sources.tcl`` assembles the Vivado project file (``.xpr``) from the project's source
declarations. Key steps:

1. Load ``env_var.tcl`` and ``proc.tcl`` to set up all build variables and custom procedures.
2. ``CheckWritePermission`` — verify the ruckus installation is writable (required for
   internal bookkeeping files).
3. ``CheckGitVersion`` — require git >= 2.9.0 and git-lfs >= 2.1.1; abort if too old.
4. Create the ``images/`` output directory if it does not yet exist.
5. Open or create the Vivado project (``.xpr``) via ``project.tcl``, then run
   ``VivadoRefresh`` to update the IP catalog.
6. ``GenBuildString`` — generates ``BuildInfoPkg.vhd`` in the project's source directory,
   embedding the firmware version and git hash as VHDL constants.
7. Check whether the git hash or firmware version has changed since the last run; if so,
   reset the synthesis run to force a full rebuild.
8. Initialize global lists (``::DIR_PATH``, ``::DIR_LIST``, ``::IP_LIST``, ``::IP_FILES``,
   ``::BD_FILES``) to empty, then call ``loadRuckusTcl ${PROJ_DIR}`` to recursively traverse
   all ``ruckus.tcl`` files. This is the entry point for all source, constraint, IP core, and
   block design declarations. See :doc:`ruckus_tcl_model` for how this recursion works.
9. Set ``PATH_MODE AbsoluteFirst`` on all file sets (sources, simulation, constraints) so
   Vivado uses absolute paths regardless of where the project is opened.
10. Upgrade any IP cores discovered during the ``ruckus.tcl`` traversal (``::IP_LIST``).
11. ``SourceTclFile ${VIVADO_DIR}/sources.tcl`` — fire the project-specific sources hook,
    allowing additional source additions after the recursive load is complete.
12. Write ``dirList.txt``, ``ipList.txt``, and ``bdList.txt`` to ``OUT_DIR`` for reference,
    then close the project.


Phase 2: build.tcl in Detail
-------------------------------

``build.tcl`` opens the assembled project and runs the full synthesis-to-bitstream flow.
Key steps:

1. Load ``env_var.tcl`` and ``proc.tcl``, then open the project and apply ``properties.tcl``
   and ``messages.tcl`` settings.
2. ``update_compile_order`` — refresh the compile order for the ``sources_1`` fileset.
3. ``CheckPrjConfig`` — verify that ``sources_1`` and ``sim_1`` are valid; abort if not.
4. ``CheckImpl`` / ``CheckSynth`` — inspect run state; reset any incomplete or stale runs.
5. ``BuildIpCores`` — re-synthesize any IP cores that are out-of-date (skipped if no IPs).
6. ``source ${RUCKUS_DIR}/vivado/pre_synthesis.tcl`` — generates block design wrappers and
   dispatches the ``${VIVADO_DIR}/pre_synthesis.tcl`` hook.
7. ``launch_runs synth_1 -jobs $PARALLEL_SYNTH`` — run synthesis; wait and check result.
8. ``source ${RUCKUS_DIR}/vivado/post_synthesis.tcl`` — dispatches the
   ``${VIVADO_DIR}/post_synthesis.tcl`` hook.
9. If ``SYNTH_ONLY=1``: write BuildInfo and exit 0 (partial flow). If ``SYNTH_DCP=1``:
   export a design checkpoint (DCP) and exit 0.
10. ``launch_runs -to_step write_bitstream impl_1`` — run place-and-route through bitstream
    generation; wait and check result.
11. ``CheckTiming`` — inspect timing report; exit with an error if setup or hold violations
    exist. Timing ignore groups (``TIG_*`` overrides) can suppress specific violations.
12. ``source ${RUCKUS_DIR}/vivado/post_route.tcl`` — runs BuildInfo, optional pyrogue/YAML
    packaging, optional MicroBlaze ELF integration, and dispatches the
    ``${VIVADO_DIR}/post_route.tcl`` hook.
13. ``CreateFpgaBit`` (non-Versal) or ``CreateVersalOutputs`` (Versal) — copies the bitstream
    and any additional output files to ``images/$(IMAGENAME).*``.
14. ``SourceTclFile ${VIVADO_DIR}/post_build.tcl`` — fire the post-build hook.
15. ``close_project`` and exit 0.


Interactive Builds with ``make gui``
--------------------------------------

Running ``make gui`` opens Vivado in interactive GUI mode instead of batch mode.
Before presenting the GUI, ruckus still runs Phase 1 in full — ``sources.tcl`` assembles
the Vivado project exactly as it would for ``make bit``. By the time Vivado's window
appears, the project is fully assembled: all sources, constraints, IP cores, and block
designs are registered and the IP catalog is up to date.

Common use cases for ``make gui``:

- **Early project exploration** — inspect the assembled source tree, fileset membership,
  and IP configurations before committing to a full batch build.
- **Reviewing synthesis and implementation results** — open a project where ``synth_1``
  or ``impl_1`` has already run and examine timing reports, resource utilization, or
  schematic views interactively.
- **Running XSIM simulation** — launch the simulator from the Vivado GUI against the
  assembled simulation fileset.
- **Investigating timing closure failures** — explore the timing report, highlight
  critical paths in the device view, and experiment with placement constraints.
- **Reading error and warning messages** — the Vivado Messages window aggregates
  synthesis and implementation diagnostics in a filterable view that is easier to
  navigate than the raw log files.

``make bit`` remains the preferred target for production and CI builds because it runs
entirely in batch mode and exits with a non-zero status on any error. Use ``make gui``
when interactive exploration or debugging is needed; ``make gui`` is the natural starting
point for any session where direct access to the Vivado GUI is required.


Dynamic Function eXchange (DFX) and Partial Build Flows
---------------------------------------------------------

AMD's current terminology for partial FPGA reconfiguration is **Dynamic Function eXchange
(DFX)**; the legacy name is *partial reconfiguration*. See AMD UG909 for the full DFX
design flow. The partial build flows below (``SYNTH_ONLY``, ``SYNTH_DCP``) are the
ruckus mechanisms most commonly used when working with DFX projects — the synthesized
checkpoint (DCP) produced by ``make dcp`` serves as the static-region input for a
subsequent DFX implementation run.

Two environment variables enable partial builds:

- ``SYNTH_ONLY=1`` — the build exits after synthesis completes and writes a BuildInfo file.
  Use ``make syn`` to invoke this flow.
- ``SYNTH_DCP=1`` — the build exports a synthesis design checkpoint (DCP) after synthesis
  completes. Use ``make dcp`` to invoke this flow. The DCP can be used as a starting point
  for implementation in another project.

These are the standard mechanisms for running only part of the Vivado pipeline. For the
complete hook script reference — including all Tier 1 and Tier 2 hook filenames and when
they fire — see :doc:`output_artifacts`.
