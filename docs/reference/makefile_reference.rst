Makefile Reference
==================

This page documents the targets and environment variables provided by
``system_vivado.mk``. Include this file from your project's ``Makefile`` to access
the Vivado build pipeline.

For build pipeline context see :doc:`/explanation/build_pipeline`.

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
     - Open the Vivado project in GUI mode.
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
     - Run Vivado XSIM simulation.
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

   Top module name for Vivado simulation.

   :default: ``$(PROJECT)``

.. envvar:: VIVADO_PROJECT_SIM_TIME

   Default simulation run time.

   :default: ``1000 ns``

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
