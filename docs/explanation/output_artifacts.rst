Output Artifacts and Hook Scripts
===================================

Output Artifacts
-----------------

When ``make bit`` completes successfully, ruckus copies the output files to the ``images/``
directory in the firmware repository. The filename stem is called ``IMAGENAME`` and encodes
five pieces of information that together identify exactly what was built, when, and by whom.

The IMAGENAME Formula
~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: none

   IMAGENAME = PROJECT-PRJ_VERSION-BUILD_TIME-USER-GIT_HASH_SHORT

.. list-table:: IMAGENAME components
   :header-rows: 1
   :widths: 22 38 20

   * - Component
     - Source
     - Example
   * - ``PROJECT``
     - Directory name of the target (``notdir $(PWD)``), or set explicitly in the project
       Makefile
     - ``Simple10GbeRudpKcu105Example``
   * - ``PRJ_VERSION``
     - Set in the project Makefile or an included ``shared_version.mk``; default
       ``0xFFFFFFFF`` if not overridden
     - ``0x02180000``
   * - ``BUILD_TIME``
     - ``$(shell date +%Y%m%d%H%M%S)`` — 14 digits, no separators: YYYYMMDDHHmmSS
     - ``20240315143022``
   * - ``USER``
     - Unix ``$USER`` environment variable at build time
     - ``smith``
   * - ``GIT_HASH_SHORT``
     - ``git rev-parse --short HEAD`` (7 characters); replaced with ``dirty`` if there are
       uncommitted changes in the working tree
     - ``a1b2c3d``

A Real Example, Decoded
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: none

   Simple10GbeRudpKcu105Example-0x02180000-20240315143022-smith-a1b2c3d.bit

Decoded: project ``Simple10GbeRudpKcu105Example``, firmware version ``0x02180000``
(v2.18.0.0), built 2024-03-15 at 14:30:22, by user ``smith``, from git commit
``a1b2c3d``.

If there are uncommitted local changes, ``GIT_HASH_SHORT`` is replaced with ``dirty``:

.. code-block:: none

   Simple10GbeRudpKcu105Example-0x02180000-20240315143022-smith-dirty.bit

The ``dirty`` suffix acts as a deliberate traceability gate — ruckus by default refuses to
build with uncommitted changes unless ``GIT_BYPASS=1`` is set in the project Makefile. This
prevents inadvertently releasing a bitstream that cannot be traced back to a specific commit.

Output File Extensions
~~~~~~~~~~~~~~~~~~~~~~~~

The ``IMAGENAME`` stem is used for all output files copied to ``images/``. Extensions depend
on the target device type and the active build flags:

- ``.bit`` — bitstream file (always produced for non-Versal targets when ``GEN_BIT_IMAGE=1``,
  which is the default)
- ``.mcs`` — PROM programming file (produced when ``GEN_MCS_IMAGE=1``; default on)
- ``.ltx`` — ILA/VIO debug probe file (produced automatically when debug cores are present)
- ``.pdi`` — Versal device image (produced for Versal targets instead of ``.bit``).
  When the target opts into Segmented Configuration (``USE_SEGMENTED_CONFIG=1`` —
  see :doc:`/how-to/segmented_configuration`), the single ``.pdi`` is replaced by
  a pair: ``<IMAGENAME>_static.pdi`` (becomes ``base-design.pdi`` inside ``BOOT.BIN``)
  and ``<IMAGENAME>_dynamic.pdi`` (the runtime-loadable artifact, typically shipped
  to the Linux rootfs as ``/boot/pl.pdi``).
- ``.xsa`` — Xilinx Support Archive for Vitis/PetaLinux (produced when ``GEN_XSA_IMAGE=1``;
  default off)

Hook Scripts
-------------

Hook scripts let a project inject custom TCL code at specific points in the build pipeline
without modifying ruckus itself. ruckus checks for hook files using ``SourceTclFile`` — if
the file exists it is sourced; if it does not exist the step is silently skipped. Users only
create the hook files they actually need.

All hook files live in the project's ``vivado/`` directory: ``$(PROJ_DIR)/vivado/``.

Tier 1: Pipeline-Level Hooks
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

These run in the main build pipeline, between or around the synthesis and implementation
launches. Each is dispatched by a corresponding ruckus-internal script that calls
``SourceTclFile ${VIVADO_DIR}/<hookname>.tcl``.

.. list-table:: Tier 1 pipeline-level hooks
   :header-rows: 1
   :widths: 35 42 23

   * - File to create in ``$(PROJ_DIR)/vivado/``
     - When it fires
     - Typical use
   * - ``sources.tcl``
     - After ``loadRuckusTcl`` completes, before IP upgrade check
     - Add sources that cannot be declared in a ``ruckus.tcl`` (e.g., dynamically generated
       files)
   * - ``pre_synthesis.tcl``
     - After block design wrapper generation, before synthesis launch
     - Last chance to modify project settings or add constraints before synthesis
   * - ``post_synthesis.tcl``
     - After synthesis completes, before implementation
     - Inspect or report on synthesis results
   * - ``post_route.tcl``
     - After timing check passes; after BuildInfo, pyrogue packaging, and ELF integration
     - Inspect implementation results, run custom reports
   * - ``post_build.tcl``
     - After ``CreateFpgaBit`` / ``CreateVersalOutputs``, before ``close_project``
     - Copy or post-process output files; trigger downstream automation

Tier 2: In-Run Hooks
~~~~~~~~~~~~~~~~~~~~~~

These run inside the Vivado synthesis (``synth_1``) or implementation (``impl_1``) run
context. They have access to the full Vivado in-memory design (the ``open_run`` context),
allowing calls to Vivado TCL API procedures such as ``get_cells``, ``get_nets``, and
``report_timing``. Like Tier 1 hooks, they use ``SourceTclFile`` and are silent no-ops if
the file does not exist.

Tier 2 hook files also live in ``$(PROJ_DIR)/vivado/``.

.. list-table:: Tier 2 in-run hooks
   :header-rows: 1
   :widths: 45 32 13

   * - File to create in ``$(PROJ_DIR)/vivado/``
     - Step
     - Pre / Post
   * - ``pre_synth_run.tcl``
     - synthesis
     - pre
   * - ``post_synth_run.tcl``
     - synthesis
     - post
   * - ``pre_opt_run.tcl``
     - opt
     - pre
   * - ``post_opt_run.tcl``
     - opt
     - post
   * - ``pre_place_run.tcl``
     - place
     - pre
   * - ``post_place_run.tcl``
     - place
     - post
   * - ``pre_phys_opt_run.tcl``
     - phys_opt
     - pre
   * - ``post_phys_opt_run.tcl``
     - phys_opt
     - post
   * - ``pre_power_opt_run.tcl``
     - power_opt
     - pre
   * - ``post_power_opt_run.tcl``
     - power_opt
     - post
   * - ``pre_post_place_power_opt_run.tcl``
     - post_place_power_opt
     - pre
   * - ``post_post_place_power_opt_run.tcl``
     - post_place_power_opt
     - post
   * - ``pre_post_route_phys_opt_run.tcl``
     - post_route_phys_opt
     - pre
   * - ``post_post_route_phys_opt_run.tcl``
     - post_route_phys_opt
     - post
   * - ``pre_route_run.tcl``
     - route
     - pre
   * - ``post_route_run.tcl``
     - route
     - post

Variables Available in Hooks
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

All Tier 1 hooks reload ``env_var.tcl`` and ``proc.tcl`` at the top of their ruckus-internal
dispatch script, so all TCL build variables are available: ``$PROJECT``, ``$PROJ_DIR``,
``$OUT_DIR``, ``$IMAGES_DIR``, ``$VIVADO_PROJECT``, ``$VIVADO_DIR``, ``$RUCKUS_DIR``, etc.
Tier 2 in-run hooks run inside the active Vivado run context and therefore also have access
to the full in-memory design.

For a description of how these hook points fit into the build timeline, see
:doc:`build_pipeline`.
