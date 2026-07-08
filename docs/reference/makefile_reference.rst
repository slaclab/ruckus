Makefile Reference
==================

This page documents the targets and environment variables provided by the
ruckus backend Makefile fragments — ``system_vivado.mk`` (Vivado) and
``system_vitis_unified_aie.mk`` (Vitis AIE). Include one of these from your
project's ``Makefile`` to access the corresponding build pipeline.

For Vivado build pipeline context see :doc:`/explanation/build_pipeline`. For
the AIE workflow walkthrough see :doc:`/how-to/vitis_aie`.

.. contents::
   :local:
   :depth: 2

Targets
-------

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - Target
     - Description
   * - ``bit`` / ``mcs`` / ``prom`` / ``pdi``
     - Full Vivado batch build: synthesis + implementation + bitstream. ``mcs``, ``prom``, and ``pdi`` are aliases for ``bit``; output format is controlled by output format variables.
   * - ``syn``
     - Synthesis only (sets ``SYNTH_ONLY=1``). Stops after ``synth_1`` completes.
   * - ``dcp``
     - Synthesis + DCP export (sets ``SYNTH_DCP=1``). Exports the post-synthesis checkpoint.
   * - ``gui``
     - Open the Vivado project in GUI mode. Automatically detects and builds the Rogue TCP/SideBand co-simulation DPI library when present; see :doc:`../how-to/xsim_rogue_cosim`.
   * - ``interactive``
     - Open Vivado in TCL interactive mode.
   * - ``sources``
     - Run source setup (ruckus.tcl loading) only — no synthesis. Useful for verifying project structure.
   * - ``sdk`` / ``vitis``
     - Open the Vitis/SDK workspace GUI. ``sdk`` and ``vitis`` are aliases.
   * - ``elf``
     - Build MicroBlaze ELF and embed in bitstream. Requires ``VITIS_SRC_PATH``.
   * - ``release``
     - Run ``firmwareRelease.py`` and push a release tag. Requires a clean git tree.
   * - ``release_files``
     - Run ``firmwareRelease.py`` without pushing the tag. Useful for generating release archives locally.
   * - ``pyrogue``
     - Generate PyRogue tarball.
   * - ``yaml``
     - Generate CPSW YAML tarball.
   * - ``wis``
     - Generate ``init_wis.tcl`` for Windows Vivado initialisation.
   * - ``xsim``
     - Run Vivado XSIM simulation. Automatically detects and builds the Rogue TCP/SideBand co-simulation DPI library when present; see :doc:`../how-to/xsim_rogue_cosim`.
   * - ``vcs``
     - Generate VCS simulation scripts.
   * - ``msim``
     - Run ModelSim/Questa simulation.
   * - ``batch``
     - Open Vivado project in batch mode.
   * - ``test``
     - Print all environment variable values. Useful for debugging Makefile variable resolution.
   * - ``dir``
     - Create the build directory structure (``OUT_DIR``, ``SYN_DIR``, ``IMPL_DIR``, ``IMAGES_DIR``).
   * - ``clean``
     - Delete the entire ``OUT_DIR`` build tree.

Project Identity Variables
--------------------------

These variables define the project's identity and directory structure. They are set
by ``system_vivado.mk`` and ``system_shared.mk`` using ``ifndef VAR / export VAR``
— if a variable is already set in the shell environment, the shell value takes precedence.

.. envvar:: PROJECT

   Project name. Used for the Vivado project name and output filenames.

   :default: ``$(notdir $(PWD))`` — the name of the project directory

.. envvar:: PROJ_DIR

   Absolute path to the top-level firmware project directory (where ``Makefile`` lives).

   :default: ``$(abspath $(PWD))``

.. envvar:: TOP_DIR

   Two levels up from ``PROJ_DIR``. Typically the root of a multi-project tree.

   :default: ``$(abspath $(PROJ_DIR)/../..)``

.. envvar:: MODULES

   Root of the submodule tree (where ``ruckus``, ``surf``, and similar modules live).

   :default: ``$(TOP_DIR)/submodules``

.. envvar:: RUCKUS_DIR

   Path to the ruckus installation.

   :default: ``$(MODULES)/ruckus``

.. envvar:: RELEASE_DIR

   Directory where release tarballs are placed by the ``release`` and ``release_files`` targets.

   :default: ``$(TOP_DIR)/release``

.. envvar:: PRJ_VERSION

   Firmware version embedded in output filenames and the build info string.

   :default: ``0xFFFFFFFF``
   :valid values: Any hex string in the form ``0xNNNNNNNN``

Build Behaviour Variables
-------------------------

.. envvar:: GIT_BYPASS

   Controls whether the build requires a clean git working tree.

   :default: ``1`` (bypass **enabled** — git checking is skipped)
   :valid values: ``0`` (strict: fail if uncommitted files exist), ``1`` (permissive: allow dirty trees)

   .. warning::

      The default is ``1``, which means git checking is **disabled** by default.
      Set ``GIT_BYPASS=0`` to enforce a clean tree before building.

   .. code-block:: make

      GIT_BYPASS=0 make bit

.. envvar:: PARALLEL_SYNTH

   Number of parallel jobs used for IP core synthesis by :func:`BuildIpCores`.

   :default: CPU count (read from ``/proc/cpuinfo`` via :func:`GetCpuNumber`)
   :valid values: Any positive integer

.. envvar:: REMOVE_UNUSED_CODE

   When ``1``, removes auto-disabled source files from the project before synthesis.

   :default: ``0`` (disabled)
   :valid values: ``0``, ``1``

.. envvar:: REPORT_QOR

   When ``1`` (and Vivado >= 2020.1), writes QoR assessment reports during route.

   :default: ``0`` (disabled)
   :valid values: ``0``, ``1``

Output Format Variables
-----------------------

These variables control which output files are copied to the ``images/`` directory
after a successful build.

.. envvar:: GEN_BIT_IMAGE

   Copy ``.bit`` bitstream to ``images/``.

   :default: ``1`` (enabled)
   :valid values: ``0``, ``1``

.. envvar:: GEN_BIT_IMAGE_GZIP

   Copy gzip-compressed ``.bit.gz`` to ``images/``.

   :default: ``0`` (disabled)
   :valid values: ``0``, ``1``

.. envvar:: GEN_BIN_IMAGE

   Copy raw binary ``.bin`` to ``images/``.

   :default: ``0`` (disabled)
   :valid values: ``0``, ``1``

.. envvar:: GEN_BIN_IMAGE_GZIP

   Copy gzip-compressed ``.bin.gz`` to ``images/``.

   :default: ``0`` (disabled)
   :valid values: ``0``, ``1``

.. envvar:: GEN_PDI_IMAGE

   Copy ``.pdi`` (Versal) to ``images/``.

   :default: ``1`` (enabled)
   :valid values: ``0``, ``1``

.. envvar:: GEN_PDI_IMAGE_GZIP

   Copy gzip-compressed ``.pdi.gz`` to ``images/``.

   :default: ``0`` (disabled)
   :valid values: ``0``, ``1``

.. envvar:: GEN_MCS_IMAGE

   Generate MCS PROM file. Requires a ``vivado/promgen.tcl`` script in your project.
   See :func:`CreatePromMcs`.

   :default: ``1`` (enabled)
   :valid values: ``0``, ``1``

.. envvar:: GEN_MCS_IMAGE_GZIP

   Gzip-compress the MCS output.

   :default: ``0`` (disabled)
   :valid values: ``0``, ``1``

.. envvar:: GEN_XSA_IMAGE

   Generate ``.xsa`` hardware platform file for Vitis/Yocto. Only useful for projects
   with embedded processors. See :func:`CreateXsaFile`.

   :default: ``0`` (disabled)
   :valid values: ``0``, ``1``

**Example — build Versal PDI only:**

.. code-block:: make

   GEN_BIT_IMAGE=0 GEN_MCS_IMAGE=0 GEN_PDI_IMAGE=1 make bit

Timing Violation Override Variables
------------------------------------

These variables override timing failure checks in :func:`CheckTiming`. They are
boolean environment variables: ruckus uses ``[string is true -strict ...]``
which recognises ``true``, ``yes``, ``on``, and ``1`` as truthy.

**All timing override variables are unset by default.** Leaving a variable unset
is the correct way to keep it disabled. Setting ``TIG=false`` does *not* disable
the override — pass ``false`` as a string and TCL may evaluate it as truthy depending
on context; the safe approach is to leave the variable unset.

.. envvar:: TIG

   Override **all** timing failures (setup + hold + pulse-width).
   Use with extreme caution — this allows a non-timing-clean bitstream to be produced.

   :default: unset (override disabled)
   :valid values: ``true``, ``1`` (to enable); leave unset to disable

   .. code-block:: make

      TIG=true make bit

.. envvar:: TIG_SETUP

   Override setup timing failures only (WNS < 0, TNS < 0).

   :default: unset (override disabled)
   :valid values: ``true``, ``1``

.. envvar:: TIG_HOLD

   Override hold timing failures only (WHS < 0, THS < 0).

   :default: unset (override disabled)
   :valid values: ``true``, ``1``

.. envvar:: TIG_PULSE

   Override pulse-width timing failures only (TPWS < 0).

   :default: unset (override disabled)
   :valid values: ``true``, ``1``

.. envvar:: ALLOW_MULTI_DRIVEN

   Controls how multi-driven net violations are handled during synthesis.

   :default: unset (multi-driven nets abort the build with ERROR)
   :valid values: ``1`` or ``true`` (demote to INFO, allowing the build to continue)

   .. note::

      This variable has no ``ifndef`` default in any Makefile. It must be passed
      explicitly as an environment variable. When ``0`` or unset, ``MDRV-1`` DRC
      and ``Synth 8-6859`` / ``Synth 8-3352`` messages are elevated to ERROR.
      When truthy, they are demoted to INFO.

   .. code-block:: make

      ALLOW_MULTI_DRIVEN=1 make bit

Simulation Variables
--------------------

.. envvar:: VIVADO_PROJECT_SIM

   Top module name for Vivado simulation. For a batch Rogue co-sim, set this to
   the demo testbench (e.g. ``RogueTcpStreamXsimDemoTb``); see
   :doc:`../how-to/xsim_rogue_cosim`.

   :default: ``$(PROJECT)``

.. envvar:: VIVADO_PROJECT_SIM_TIME

   Simulation run length. The default ``all`` free-runs until the testbench
   calls ``$finish``/``$stop`` or is interrupted; a testbench with neither
   (and a free-running clock) never self-terminates, so a batch ``make xsim``
   must be stopped manually. Pass a time value (e.g. ``1000 ns``) to bound the
   run. ``all`` is required for the Rogue co-sim so the external peer can drive
   the testbench — see :doc:`../how-to/xsim_rogue_cosim`.

   :default: ``all``

.. envvar:: SIM_CARGS_VERILOG

   VCS Verilog compile flags.

   :default: ``-nc -l +v2k -xlrm -kdb -v2005 +define+SIM_SPEED_UP``

.. envvar:: SIM_CARGS_VHDL

   VCS VHDL compile flags.

   :default: ``-nc -l +v2k -xlrm -kdb``

.. envvar:: SIM_VCS_FLAGS

   VCS simulation run flags.

   :default: ``-debug_acc+pp+dmptf +warn=none -kdb -lca``

Partial Reconfiguration Variables
----------------------------------

.. envvar:: RECONFIG_CHECKPOINT

   Path to static DCP for DFX (Dynamic Function eXchange) partial reconfiguration
   build. Set to a valid DCP path to enable partial reconfiguration mode.

   :default: ``0`` (standard build — partial reconfiguration disabled)

.. envvar:: RECONFIG_ENDPOINT

   Partial reconfiguration endpoint name.

   :default: ``0`` (disabled)

.. envvar:: RECONFIG_PBLOCK

   Partial reconfiguration pblock name.

   :default: ``0`` (disabled)

Versal Segmented Configuration Variables
-----------------------------------------

.. envvar:: USE_SEGMENTED_CONFIG

   Enables Vivado 2025.1+ Segmented Configuration mode on Versal targets. When set
   to ``1``, the build emits two PDIs (``${IMAGENAME}_static.pdi`` for ``BOOT.BIN``
   and ``${IMAGENAME}_dynamic.pdi`` for runtime PL reload) instead of the single
   ``${IMAGENAME}.pdi``. Ignored on non-Versal targets (soft-warn at build time).
   See :doc:`../how-to/segmented_configuration` for the full opt-in workflow.

   :default: ``0`` (standard single-PDI Versal build)

Vitis / SDK Variables
----------------------

.. envvar:: EMBED_PROC

   MicroBlaze processor instance name for ELF embedding.

   :default: ``microblaze_0``

.. envvar:: VITIS_SRC_PATH

   Path to the Vitis/SDK application source tree for ELF embedding.

   :default: unset (ELF embedding disabled)

.. envvar:: SDK_SRC_PATH

   Legacy alias for :envvar:`VITIS_SRC_PATH`. Used with Vivado 2019.1 and older.

   :default: unset

Vitis AIE Targets
-----------------

These targets are provided by ``system_vitis_unified_aie.mk`` (Vitis 2025.1+
unified toolchain). For the end-to-end workflow see :doc:`/how-to/vitis_aie`.

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - Target
     - Description
   * - ``proj``
     - Idempotently create the Vitis workspace and AIE component
       (``vitis -s create_proj.py``). No-op if the component already exists.
   * - ``build``
     - Build the AIE graph for the ``hw`` target (``vitis -s build.py``).
       Emits ``libadf.a`` under ``$(OUT_DIR)/$(PROJECT)/build/hw/``.
   * - ``x86sim``
     - Build for the x86 simulator (``vitis -s build.py --x86sim``).
   * - ``package``
     - Wrap ``libadf.a`` + the newest ``.xsa`` in ``$(VIVADO_XSA_DIR)`` into
       the dynamic PDI (``bash package.sh``). Uses ``v++ --package``
       (primary) or ``bootgen`` (fallback when ``USE_BOOTGEN_FALLBACK=1``).
   * - ``partition_conf``
     - Invoke ``$(AIE_PARTITION_CONF_SCRIPT)`` to extract the AIE partition
       geometry (``PARTITION_ID`` + ``UID``) from the Vitis-emitted
       ``aie_partition.json`` and write ``ip/$(PROJECT).partition.conf``.
       The default ``target`` chain is ``package partition_conf``.
   * - ``program``
     - Invoke ``$(AIE_PROGRAM_SCRIPT)`` to deploy ``$(AIE_PDI)`` (plus the
       ``partition.conf`` sidecar) to ``/boot/aie/`` on the target board.
   * - ``gui``
     - Open the same workspace in the Vitis Unified IDE
       (``vitis -w $(OUT_DIR)``).
   * - ``interactive``
     - Drop into a Python REPL with the ``vitis`` module loaded
       (``vitis -i``).
   * - ``test``
     - Print all AIE environment variable values.
   * - ``clean``
     - Delete the build directory (``rm -rf $(OUT_DIR)``).

Vitis AIE Variables
-------------------

These variables drive ``system_vitis_unified_aie.mk``. The platform/part,
sources, top-level graph, and XSA-directory variables must be set in the
consuming Makefile **before** the ``include`` line; ``VIVADO_XSA_DIR`` is
asserted at recipe time so only ``package`` requires it.

.. envvar:: AIE_PLATFORM

   Absolute path to the platform ``.xpfm``. Use this for dev boards with an
   AMD-shipped xpfm (e.g. ``xilinx_vek280_base_*``). Mutually exclusive with
   :envvar:`AIE_PART` — set exactly one.

   :default: unset (the Makefile errors at parse time if neither
             ``AIE_PLATFORM`` nor ``AIE_PART`` is defined)

   .. code-block:: makefile

      export AIE_PLATFORM := $(firstword $(wildcard \
          $(XILINX_VITIS)/base_platforms/xilinx_vek280_base_*/xilinx_vek280_base_*.xpfm))

   The wildcard pattern keeps the same Makefile working across Vitis
   releases — AMD bumps the numeric suffix per release (``202510_1`` in
   2025.1, ``202520_1`` in 2025.2, …) so a literal path would pin the
   project to one Vitis version.

.. envvar:: AIE_PART

   Versal device ID (e.g. ``xcve2802-vsvh1760-2MP-e-S``). Use this for
   custom AIE boards without a shipped xpfm. The PL clock hint comes from
   the cfg's ``pl-freq=`` line. Mutually exclusive with :envvar:`AIE_PLATFORM`.

   :default: unset

.. envvar:: AIE_SOURCES

   Whitespace-separated list of ``path[:dest_subdir]`` entries. The
   ``path`` half is either:

   - a **file** path → imports just that file, **or**
   - a **directory** path → imports every ``.cpp`` / ``.cc`` / ``.h`` /
     ``.hpp`` file in that directory (**non-recursive** — subdirectories
     are not walked).

   Without ``:dest_subdir``, imports land flat at the component root; with
   ``:dest_subdir``, they import into ``<component>/<dest_subdir>/``
   (matches the AMD-canonical ``kernels/`` layout where ``graph.h`` does
   ``adf::source(loop) = "kernels/loopback.cc";``). ``include=`` paths for
   the component root and every ``dest_subdir`` are auto-merged into the
   generated cfg. Mix local and shared sources freely (including
   submodule paths).

   :default: unset (parse-time error)

   .. code-block:: makefile

      SHARED_AIE := $(TOP_DIR)/submodules/aie-common-kernels
      export AIE_SOURCES = \
          $(CURDIR)/aie \
          $(CURDIR)/aie/kernels:kernels \
          $(SHARED_AIE)/util.cc

.. envvar:: AIE_TOP_LEVEL_FILE

   Top-level graph file **basename** only (e.g. ``graph.cpp``). The
   top-level graph imports at the component root, so this is just the
   filename — never a path.

   :default: unset (parse-time error)

.. envvar:: VIVADO_XSA_DIR

   Directory containing the Vivado-built ``.xsa`` images, required by the
   ``package`` target. Set it in the consuming AIE Makefile before the
   ``include`` line:

   .. code-block:: makefile

      export VIVADO_XSA_DIR = $(abspath $(CURDIR)/../../targets/<target>/images)

   The ``package`` step auto-selects the newest ``.xsa`` by the
   ``BUILD_TIME`` timestamp encoded in the image filename
   (``<project>-<version>-<YYYYMMDDhhmmss>-<user>-<githash>.xsa``) and
   hard-errors if the directory contains no ``.xsa``.

   :default: unset (recipe-time error from the ``package`` target)

   .. note::

      A directory is used instead of an explicit file path because the
      Vivado-side ``IMAGENAME`` embeds ``BUILD_TIME`` and is not
      predictable from inside the AIE archetype.

.. envvar:: AIE_CONF

   Optional ``partition.conf`` sidecar path, forwarded to
   ``$(AIE_PROGRAM_SCRIPT)`` as the ``-c`` flag when set. When unset the
   default helper auto-derives it from the PDI directory as
   ``<pdi-dir>/<name>.partition.conf`` — which matches the ``ip/`` pair
   written by the default ``target`` chain, so most consumers never set
   it.

   :default: unset (helper auto-derives the path)

.. envvar:: AIE_BOARD_IP

   ``user@host`` for the ``program`` target. Forwarded to
   ``$(AIE_PROGRAM_SCRIPT)`` as the ``-i`` flag when set.

   :default: unset (the default ``program.sh`` errors if no ``-i`` is
             passed — most consumers set a project default with
             ``AIE_BOARD_IP ?= root@<dev-ip>``)

.. envvar:: OUT_DIR

   Vitis workspace root. The AIE component is created at
   ``$(OUT_DIR)/$(PROJECT)/``.

   :default: ``$(PROJ_DIR)/build``

.. envvar:: AIE_IP_DIR

   Final deliverable directory for the dynamic PDI. Mirrors the unified
   HLS convention of writing artifacts to ``$(PROJ_DIR)/ip/``.

   :default: ``$(PROJ_DIR)/ip``

.. envvar:: AIE_PDI

   Output dynamic PDI path written by ``make package``. Named
   ``$(PROJECT).pdi`` so ``ip/`` matches the normalized
   ``/boot/aie/<name>`` pair basename — the deploy helper uploads it
   verbatim, and still strips a legacy ``_aie_dynamic`` / ``_dynamic``
   suffix if a consumer overrides ``AIE_PDI`` to keep one.

   :default: ``$(AIE_IP_DIR)/$(PROJECT).pdi``

.. envvar:: AIE_PKG_DIR

   Scratch directory used by the package step (``v++ --package`` working
   tree).

   :default: ``$(OUT_DIR)/aie_package``

.. envvar:: VPP_LOG

   Log file path for the ``v++ --package`` invocation.

   :default: ``$(OUT_DIR)/vpp_package.log``

.. envvar:: USE_BOOTGEN_FALLBACK

   Set to ``1`` to package via ``bootgen`` instead of ``v++ --package``.
   Both paths produce a functionally equivalent dynamic PDI for the
   AIE-overlay case.

   :default: ``0``

.. envvar:: AIE_PROGRAM_SCRIPT

   Deploy helper invoked by ``make program``. The default helper is a
   generic Versal/PetaLinux deploy: scp the PDI + ``partition.conf``
   sidecar to ``/boot/aie/<name>.{pdi,partition.conf}``, ssh-reboot, then
   verify the startup-app-init boot loop loaded the AIE (journal
   ``AIE load:`` line + ``fpga_manager`` dmesg write),
   ``aie-partition-init@<name>.service`` is active, and ``/sys/class/aie``
   exists. Override to point at a project-specific helper when richer
   verification (application-specific systemd checks, ``xsdb`` readout,
   etc.) is required.

   :default: ``$(RUCKUS_DIR)/vitis/aie/program.sh``

   The helper must accept the following flag contract:

   .. list-table::
      :header-rows: 1
      :widths: 18 82

      * - Flag
        - Meaning
      * - ``-p <path>``
        - Runtime PDI to upload (required)
      * - ``-i <user@host>``
        - Board target (required; forwarded from :envvar:`AIE_BOARD_IP`)
      * - ``-c <path>``
        - ``partition.conf`` sidecar (optional; forwarded from
          :envvar:`AIE_CONF` when set — auto-derived from the PDI
          directory otherwise)

.. envvar:: AIE_PARTITION_CONF_SCRIPT

   ``partition.conf`` extractor invoked by ``make partition_conf``. The
   default helper reads the AIE partition geometry from the Vitis-emitted
   ``aie_partition.json`` (``Work/arch/``) and writes
   ``$(AIE_IP_DIR)/$(PROJECT).partition.conf`` with two lines —
   ``PARTITION_ID=<hex>`` and ``UID=<hex>`` — consumed on-board by
   ``aie-partition-init``. Driven purely by the ``OUT_DIR`` / ``PROJECT``
   / ``AIE_IP_DIR`` env vars. Override only if a project needs bespoke
   partition.conf emission.

   :default: ``$(RUCKUS_DIR)/vitis/aie/emit_partition_conf.sh``
