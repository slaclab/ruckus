TCL API Reference
=================

This page documents all TCL procedures provided by ruckus. Procedures are called from
your project's ``ruckus.tcl`` file or from hook scripts.

For an explanation of ``$::DIR_PATH`` and the recursive loading model, see
:doc:`/explanation/ruckus_tcl_model`.

.. contents::
   :local:
   :depth: 2

Source-Loading Procedures
-------------------------

These procedures are defined in ``vivado/proc/code_loading.tcl``.
Call them from your ``ruckus.tcl`` to populate the Vivado project with RTL, IP cores,
block designs, and constraints.

.. function:: loadSource

   ``loadSource [-path PATH] [-dir DIR] [-sim_only] [-lib LIBRARY] [-fileType TYPE]``

   Add RTL source files to the Vivado project's ``sources_1`` fileset (or ``sim_1``
   when ``-sim_only`` is given).

   .. option:: -path <path>

      Absolute path to a single source file. Mutually exclusive with ``-dir``.
      Use ``$::DIR_PATH`` to construct the path relative to the current ``ruckus.tcl``.

   .. option:: -dir <dir>

      Directory path. All supported files found in this directory are added.
      Mutually exclusive with ``-path``.

   .. option:: -sim_only

      Boolean flag. When present, files are added to the ``sim_1`` fileset instead
      of ``sources_1``. Use for testbench files that should not be synthesised.

   .. option:: -lib <library>

      VHDL library name to assign to any ``.vhd`` or ``.vhdl`` files loaded.
      Has no effect on Verilog or SystemVerilog files.

   .. option:: -fileType <type>

      Override the ``FILE_TYPE`` property that Vivado assigns to loaded files.

   **Supported file extensions:** ``.vhd`` ``.vhdl`` ``.v`` ``.vh`` ``.sv`` ``.svh``
   ``.dat`` ``.coe`` ``.mem`` ``.edif`` ``.dcp``

   **Error behaviour:** Calls ``exit -1`` if the file is missing, the extension is
   unsupported, or both ``-path`` and ``-dir`` are supplied.

   .. note::

      If adding a ``.dcp`` file fails with a "Runs 36-335" error, ruckus prints
      a reminder to run ``git lfs pull`` — large DCP files must be stored in Git LFS.

   **Examples:**

   .. code-block:: tcl

      # Add a single HDL source file
      loadSource -path $::DIR_PATH/rtl/MyModule.vhd

      # Add all HDL sources in a directory
      loadSource -dir $::DIR_PATH/rtl/

      # Add a simulation-only testbench
      loadSource -path $::DIR_PATH/tb/MyTb_tb.vhd -sim_only

      # Add a VHDL file and assign it to a named library
      loadSource -path $::DIR_PATH/rtl/surf/SurfPkg.vhd -lib surf

.. function:: loadIpCore

   ``loadIpCore [-path PATH] [-dir DIR]``

   Import a Vivado IP core (``.xci`` or ``.xcix``) into the project's ``sources_1``
   fileset via ``import_ip``.

   .. option:: -path <path>

      Absolute path to a single ``.xci`` or ``.xcix`` file.

   .. option:: -dir <dir>

      Directory path. All ``.xci`` / ``.xcix`` files found there are imported.

   The proc appends the resolved path(s) to the global ``$::IP_LIST`` and ``$::IP_FILES``
   variables, which are used by :func:`BuildIpCores` later in the pipeline.

   **Example:**

   .. code-block:: tcl

      loadIpCore -path $::DIR_PATH/ip/MyFifo.xci
      loadIpCore -dir  $::DIR_PATH/ip/

.. function:: loadBlockDesign

   ``loadBlockDesign [-path PATH] [-dir DIR]``

   Import or regenerate a Vivado block design (``.bd`` or ``.tcl``).

   .. option:: -path <path>

      Absolute path to a ``.bd`` or ``.tcl`` file.

   .. option:: -dir <dir>

      Directory path. All ``.bd`` and ``.tcl`` files found there are processed.

   **``.bd`` files** are imported via ``import_files -norecurse``.

   **``.tcl`` files** are sourced directly, regenerating the block design from script.
   Use the ``.tcl`` form when the block design is version-controlled as a script.

   The resolved ``.bd`` path is appended to ``$::BD_FILES``.

   **Example:**

   .. code-block:: tcl

      # Import a pre-built block design
      loadBlockDesign -path $::DIR_PATH/bd/system.bd

      # Regenerate a block design from its TCL script
      loadBlockDesign -path $::DIR_PATH/bd/system.tcl

.. function:: loadConstraints

   ``loadConstraints [-path PATH] [-dir DIR]``

   Add timing or physical constraints to the project's ``constrs_1`` fileset.

   .. option:: -path <path>

      Absolute path to a single ``.xdc`` or ``.tcl`` constraint file.

   .. option:: -dir <dir>

      Directory path. All ``.xdc`` and ``.tcl`` files found there are added.

   **Example:**

   .. code-block:: tcl

      loadConstraints -path $::DIR_PATH/constraints/timing.xdc
      loadConstraints -dir  $::DIR_PATH/constraints/

.. function:: loadNoCSolution

   ``loadNoCSolution -path PATH``

   Lock the ``impl_1`` run to a pre-computed Versal NoC solution (``.ncr``) file
   by setting its ``NOC_SOLUTION_FILE`` property.

   .. option:: -path <path>

      Absolute path to a single ``.ncr`` file.

   Used with Versal Segmented Configuration so that the NoC compiler reuses a
   locked solution and the static portion of the NoC (routing, QoS) stays
   identical between the static and dynamic partitions. No-op with a warning
   when the target is not Versal, so a shared device ``ruckus.tcl`` can call it
   unconditionally. Hard error if ``-path`` is missing, the file does not exist,
   or the file lacks a ``.ncr`` extension.

   Defined in ``vivado/proc/code_loading.tcl``.

   **Example:**

   .. code-block:: tcl

      if { $::env(USE_SEGMENTED_CONFIG) != 0 } {
         loadNoCSolution -path $::DIR_PATH/bd/XilinxVek280NoC.ncr
      }

.. function:: loadRuckusTcl {filePath {flags ""}}

   Recursively load a submodule's ``ruckus.tcl``. This is the primary mechanism for
   composing firmware projects from multiple ruckus-aware modules.

   :param filePath: **Directory** path containing the target ``ruckus.tcl``.
                    Do not pass the file itself — ruckus appends ``/ruckus.tcl``
                    internally. Passing a file path (e.g.
                    ``$::DIR_PATH/submodule/ruckus.tcl``) will cause ``exit -1``.
   :param flags: (Optional) Pass ``"debug"`` to enable TCL tracing during the load.
                 Omit or pass ``""`` for normal operation.

   **What it does:**

   1. Saves the current ``$::DIR_PATH``
   2. Sets ``$::DIR_PATH`` to ``filePath``
   3. Sources ``${filePath}/ruckus.tcl``
   4. Restores the original ``$::DIR_PATH``
   5. Appends ``filePath`` to ``$::DIR_LIST``

   See :doc:`/explanation/ruckus_tcl_model` for the full explanation of
   ``$::DIR_PATH`` semantics.

   .. warning::

      Pass the **directory**, not the file.
      ``loadRuckusTcl $::env(MODULES)/surf`` is correct.
      ``loadRuckusTcl $::env(MODULES)/surf/ruckus.tcl`` will fail with ``exit -1``.

   **Examples:**

   .. code-block:: tcl

      # Load a submodule (surf firmware library)
      loadRuckusTcl $::env(MODULES)/surf

      # Load with debug tracing enabled
      loadRuckusTcl $::env(MODULES)/surf "debug"

      # Load a subdirectory within the same project
      loadRuckusTcl $::DIR_PATH/shared

Vivado Pipeline Procedures
--------------------------

These procedures are called internally by ruckus during the Vivado build pipeline.
Users may call some of them from hook scripts or ``ruckus.tcl`` for project-level
control.

These procedures are defined in ``vivado/proc/``.

.. function:: CheckVivadoVersion

   Check the active Vivado version against known-good and known-bad version lists.

   :returns: Nothing on success. Raises ``-code error`` for unsupported versions.

   Checks ``$::env(VIVADO_VERSION)`` against:

   - Known-bad versions (2017.1, pre-2014.1) — raises an error.
   - Versions newer than 2025.2.0 — prints a warning (untested).

   Defined in ``vivado/proc/project_management.tcl``. Called automatically at project
   open time from ``vivado/project.tcl``. Users may also call it from ``ruckus.tcl``
   to gate a project on a required Vivado version.

   **Example:**

   .. code-block:: tcl

      # Call from ruckus.tcl for project-level version gating
      CheckVivadoVersion

.. function:: CheckTiming {{printTiming true}}

   Evaluate implementation timing results and return pass/fail status.

   :param printTiming: (Optional, default ``true``) When ``true``, prints
                       WNS/TNS/WHS/THS/TPWS/FAILED_NETS to stdout if timing failed.
   :returns: ``true`` if timing passed or was overridden; ``false`` if timing failed
             and no override is active.

   Reads ``STATS.*`` properties from the ``impl_1`` run after route. Checks
   the ``TIG``, ``TIG_SETUP``, ``TIG_HOLD``, and ``TIG_PULSE`` environment variables;
   if any override is set, a timing failure does not prevent bitstream generation.

   Defined in ``vivado/proc/checking.tcl``. Called internally from ``build.tcl`` and
   ``post_route.tcl``. The ``post_route.tcl`` Tier-1 hook fires only when
   ``CheckTiming`` returns ``true``.

   **Example:**

   .. code-block:: tcl

      # Called with default printTiming=true (prints stats on failure)
      CheckTiming

.. function:: BuildIpCores

   Upgrade and synthesise all project IP cores.

   :returns: Nothing.

   Upgrades all IP cores in the project, then synthesises any whose synthesis run is
   stale. Uses ``$::env(PARALLEL_SYNTH)`` parallel jobs.

   Defined in ``vivado/proc/ip_management.tcl``. Called automatically from ``build.tcl``
   before synthesis.

   **Example:**

   .. code-block:: tcl

      BuildIpCores

.. function:: CreateFpgaBit

   Copy implementation output files to the ``images/`` directory after a successful build.

   :returns: Nothing.

   Copies output files according to output format variables:

   - ``.bit`` file if :envvar:`GEN_BIT_IMAGE` ``!= 0``
   - Gzip of ``.bit`` if :envvar:`GEN_BIT_IMAGE_GZIP` ``!= 0``
   - ``.bin`` file if :envvar:`GEN_BIN_IMAGE` ``!= 0``
   - Gzip of ``.bin`` if :envvar:`GEN_BIN_IMAGE_GZIP` ``!= 0``

   Calls :func:`CreateXsaFile` and :func:`CreatePromMcs` internally.

   Defined in ``vivado/proc/output_files.tcl``. Not used for Versal devices
   (use ``CreateVersalOutputs`` instead).

   **Example:**

   .. code-block:: tcl

      CreateFpgaBit

.. function:: CreatePromMcs

   Generate an MCS PROM file if a ``promgen.tcl`` hook is present.

   :returns: Nothing.

   Sources ``$::env(PROJ_DIR)/vivado/promgen.tcl`` if it exists; no-op otherwise.
   To customise MCS generation, create ``vivado/promgen.tcl`` in your project directory.

   Defined in ``vivado/proc/output_files.tcl``. Called internally by
   :func:`CreateFpgaBit`.

   **Example:**

   .. code-block:: tcl

      CreatePromMcs

.. function:: CreateXsaFile

   Generate an XSA (or HDF) hardware platform file for embedded processor projects.

   :returns: Nothing.

   Generates a ``.xsa`` hardware platform file (Vivado 2019.2 and later) or ``.hdf``
   (Vivado 2019.1 and older) when :envvar:`GEN_XSA_IMAGE` ``!= 0``. Only relevant for
   projects containing embedded processors such as MicroBlaze.

   Defined in ``vivado/proc/output_files.tcl``. Called internally by
   :func:`CreateFpgaBit`.

   **Example:**

   .. code-block:: tcl

      CreateXsaFile

.. function:: EnableSegmentedConfig

   Enable Versal Segmented Configuration on the current project.

   :returns: Nothing on success. Calls ``exit -1`` for Vivado < 2025.1.

   Sets ``SEGMENTED_CONFIGURATION 1`` on the current project so that
   ``write_device_image`` emits two PDIs (``<design>_boot.pdi`` and
   ``<design>_pld.pdi``) instead of the standard single PDI. No-op with a
   warning when the target is not Versal. Hard error when the active Vivado
   version is older than 2025.1.

   Defined in ``vivado/proc/SegmentedConfiguration.tcl``. Called automatically
   from ``vivado/properties.tcl`` when ``USE_SEGMENTED_CONFIG = 1`` is exported
   by the target Makefile (the recommended opt-in path — see
   :doc:`/how-to/segmented_configuration`). Users do not normally call this
   directly.

   **Example:**

   .. code-block:: tcl

      # Enabled implicitly by setting USE_SEGMENTED_CONFIG = 1 in the
      # target Makefile. Direct invocation is for advanced users only.
      EnableSegmentedConfig

.. function:: ExportSegmentedPdi

   Copy the Segmented Configuration PDIs to the ``images/`` directory with the
   SLAC ``IMAGENAME`` suffix convention.

   :returns: Nothing. Calls ``exit -1`` if the expected boot/PLD PDIs are not
             found in the implementation directory.

   Discovers the Vivado-emitted ``*_boot.pdi`` (becomes ``<IMAGENAME>_static.pdi``,
   feeds ``BOOT.BIN``) and ``*_pld.pdi`` (becomes ``<IMAGENAME>_dynamic.pdi``,
   the runtime-loadable artifact) under :envvar:`IMPL_DIR`, copies both to
   :envvar:`IMAGES_DIR` when :envvar:`GEN_PDI_IMAGE` ``!= 0``, and gzips them
   when :envvar:`GEN_PDI_IMAGE_GZIP` ``!= 0``. Also emits ``.ltx`` and ``.xsa``
   to maintain parity with the single-PDI Versal path it replaces.

   Defined in ``vivado/proc/SegmentedConfiguration.tcl``. Called automatically
   from ``vivado/build.tcl`` when ``USE_SEGMENTED_CONFIG = 1``. Users do not
   normally call this directly.

   **Example:**

   .. code-block:: tcl

      # Called implicitly during build.tcl when USE_SEGMENTED_CONFIG = 1.
      ExportSegmentedPdi

Shared Utility Procedures
-------------------------

These procedures are defined in ``shared/proc.tcl`` and are available in all
ruckus-supported tool backends (Vivado, Vitis HLS, Cadence Genus, Synopsys DC, GHDL,
Icarus Verilog, Verilator).

.. function:: GetCpuNumber

   Return the number of CPU threads available on the build host.

   :returns: Integer CPU thread count.

   Reads ``/proc/cpuinfo`` to count processor entries. Used internally to configure
   Vivado parallelism via ``set_param general.maxThreads``.

   **Example:**

   .. code-block:: tcl

      set nCpu [GetCpuNumber]

.. function:: GetRealPath {path}

   Resolve a filesystem path to its canonical absolute form.

   :param path: Any filesystem path, possibly containing symlinks.
   :returns: Fully resolved canonical absolute path (all symlinks followed).

   Follows symlinks recursively using ``file readlink`` until reaching the true
   filesystem location.

   **Example:**

   .. code-block:: tcl

      set realDir [GetRealPath $::DIR_PATH/../../shared]

.. function:: BuildInfo

   Write a ``build.info`` summary file at the end of a successful build.

   :returns: Nothing.

   Writes ``$::env(PROJ_DIR)/build.info`` containing the following fields:
   ``PROJECT``, ``FW_VERSION``, ``BUILD_STRING``, ``GIT_HASH``.

   Called at the end of a successful build from ``build.tcl`` (for synthesis-only and
   DCP-only paths) and from ``post_route.tcl`` after the timing check passes.

   **Example:**

   .. code-block:: tcl

      BuildInfo

.. function:: CheckGitVersion

   Enforce minimum required versions of git and git-lfs.

   :returns: Nothing on success. Calls ``exit -1`` if either tool is below the minimum.

   Enforces:

   - ``git`` >= 2.9.0
   - ``git-lfs`` >= 2.1.1

   Called automatically from ``sources.tcl`` at project setup time.

   **Example:**

   .. code-block:: tcl

      CheckGitVersion

.. function:: RogueCheckLibZmq

   Check that ``libzmq`` 4.1.0 or newer is discoverable through ``pkg-config``.

   :returns: Nothing on success. Calls ``exit -1`` with the ``libzmq package
             was not found`` banner when ``pkg-config --exists {libzmq >=
             4.1.0}`` fails.

   No arguments. Called by the VCS and xsim Rogue co-simulation hooks
   (``vivado/vcs.tcl``, the xsim pre-compile hook) and by the Icarus Verilog
   and Verilator SimLink library build (:func:`VerilogSimLinkBuild`) before
   any of them build the surf SimLink backend library.

   **Example:**

   .. code-block:: tcl

      RogueCheckLibZmq

.. function:: GenBuildString {pkgDir}

   Generate the ``BuildInfoPkg.vhd`` VHDL package containing the build metadata string.

   :param pkgDir: Output directory where ``BuildInfoPkg.vhd`` will be written.
   :returns: Nothing.

   Generates a ``BUILD_INFO_G`` VHDL generic and writes ``BuildInfoPkg.vhd`` to
   ``pkgDir``, encoding the build string as a hex-encoded constant. Sets the generic on
   ``[current_fileset]`` when Vivado is available.

   Called automatically from ``sources.tcl`` on every source setup run.

   **Example:**

   .. code-block:: tcl

      GenBuildString $::env(OUT_DIR)/GeneratedSource

Icarus Verilog and Verilator Procedures
----------------------------------------

These procedures are defined in ``shared/verilog_proc.tcl`` and provide the
Vivado-free :func:`loadSource` and :func:`loadRuckusTcl` used by
``system_iverilog.mk`` and ``system_verilator.mk``; see
:doc:`/how-to/iverilog_simulation` and :doc:`/how-to/verilator_simulation`.

The Vivado-free ``loadSource``/``loadRuckusTcl`` differ from the Vivado forms
documented above: only ``.v``, ``.sv``, ``.vh``, and ``.svh`` extensions are
accepted (plus ``.vhd``/``.vhdl``, which are collected separately and turned
into a hard error), ``-lib`` and ``-fileType`` are accepted but have no
effect, ``-sim_only`` is accepted and stripped, and there is no Vivado
fileset to add files to; sources accumulate in an ordered, deduplicated
in-memory filelist instead, written to disk by :func:`VerilogWriteFilelist`.

.. function:: VerilogInitSources

   Reset the ordered source, include-dir, and VHDL-offender lists.

   :returns: Nothing.

   Called once at the start of ``load_source_code.tcl``, never at file scope:
   every loaded ``ruckus.tcl`` (including ``surf/simlink/ruckus.tcl``)
   re-sources ``$::env(RUCKUS_PROC_TCL)`` mid-load, and a file-scope reset
   would silently discard everything loaded before that point.

   **Example:**

   .. code-block:: tcl

      VerilogInitSources

.. function:: VerilogAddFile {path}

   Classify one file into the ordered source list, the include-dir list, or
   the VHDL offender list, deduplicating each by real path.

   :param path: Path to classify.
   :returns: Nothing.

   ``.v``/``.sv`` files are appended to the ordered source list;
   ``.vh``/``.svh`` files contribute their directory to the include-dir list;
   ``.vhd``/``.vhdl`` files are appended to the VHDL offender list consumed by
   :func:`VerilogWriteFilelist`'s hard error. Called internally by
   :func:`loadSource`.

   **Example:**

   .. code-block:: tcl

      VerilogAddFile $::DIR_PATH/rtl/MyModule.sv

.. function:: VerilogWriteFilelist {filePath}

   Write the ordered, deduplicated filelist consumed by ``iverilog -c`` /
   ``verilator -f``.

   :param filePath: Output filelist path (``$(OUT_DIR)/$(PROJECT).f``).
   :returns: Nothing on success. Calls ``exit -1`` if any ``.vhd``/``.vhdl``
             file was loaded, or if no ``.v``/``.sv`` source was loaded.

   Writes one ``+incdir+<dir>`` line per collected include directory,
   followed by one line per ordered source path. Called at the end of
   ``load_source_code.tcl``, after the project's ``ruckus.tcl`` tree has
   been loaded.

   **Example:**

   .. code-block:: tcl

      VerilogWriteFilelist "$::env(OUT_DIR)/$::env(PROJECT).f"

.. function:: VerilogCheckTool {tool}

   Resolve a tool on PATH or hard-error.

   :param tool: Executable name to resolve (e.g. ``iverilog``).
   :returns: The resolved binary path on success. Calls ``exit -1`` with the
             ``VerilogCheckTool: ... not found in PATH`` banner if the tool
             is not found.

   Called by ``load_source_code.tcl`` for each required tool and internally
   by :func:`VerilogCheckVersion` and :func:`VerilogSimLinkBuild`.

   **Example:**

   .. code-block:: tcl

      VerilogCheckTool iverilog-vpi

.. function:: VerilogCheckVersion {tool versionArg pattern floor}

   Resolve a tool, run it to capture its version string, and hard-error below
   a floor.

   :param tool: Executable name to resolve and version-check.
   :param versionArg: Argument that makes the tool print its version (e.g.
                       ``-V`` for ``iverilog``, ``--version`` for
                       ``verilator``).
   :param pattern: Regular expression matching the version text, with one
                    capture group.
   :param floor: Minimum accepted ``major.minor`` version string.
   :returns: Nothing on success. Calls ``exit -1`` with the ``VerilogCheckVersion:
             ruckus requires <tool> <floor> or newer`` banner when the found
             version is below the floor.

   Compares the parsed ``major.minor`` via ``CompareTags`` rather than
   ``expr``, avoiding an octal-parse error on a minor version such as
   Verilator's ``020``. Called once at the start of each flow's
   ``load_source_code.tcl``, before any source is loaded.

   **Example:**

   .. code-block:: text

      VerilogCheckVersion iverilog -V {Icarus Verilog version (\d+\.\d+)} 12.0

.. function:: VerilogSimLinkBuild {artifact}

   Build the surf SimLink backend library in-tree, stage it in
   ``$::env(OUT_DIR)``, and clean the surf tree.

   :param artifact: Backend artifact filename to stage (``RogueSimLink.vpi``
                     for Icarus Verilog, ``libRogueSimLinkDpi.so`` for
                     Verilator).
   :returns: Nothing. Skips entirely (with a message) if no Rogue SimLink
             leaf is present in the written filelist. Calls ``exit -1`` if
             the located backend directory has no ``Makefile``, ``make``
             fails, or the expected artifact is not produced.

   Locates the backend directory by scanning the written filelist for a
   known Rogue leaf (``RogueTcpStream.sv``, ``RogueTcpMemory.sv``, or
   ``RogueSideBand.sv``) and taking its directory, mirroring the VCS/xsim
   in-tree build/copy/clean pattern. Calls :func:`RogueCheckLibZmq` before
   building. Called from each flow's ``simlink.tcl`` at the start of
   ``make build``.

   **Example:**

   .. code-block:: tcl

      VerilogSimLinkBuild RogueSimLink.vpi

.. seealso::

   :doc:`hook_scripts`
      Hook script reference — covers all named hook points, when they fire, and which
      TCL variables are in scope. Relevant for users calling pipeline procs such as
      :func:`CheckTiming` or :func:`CreateFpgaBit` from hook scripts.
