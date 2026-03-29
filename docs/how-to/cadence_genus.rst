How to Run Cadence Genus ASIC Synthesis
========================================

**Goal:** Run ASIC synthesis using Cadence Genus for an existing ruckus-based project.

Prerequisites
-------------

Before running synthesis, ensure the following are in place:

- Licensed Cadence Genus installation with the ``genus`` binary on PATH
- A PDK with liberty (``.lib``) and LEF (``.lef``) files
- ``PDK_PATH``, ``STD_CELL_LIB``, ``STD_LEF_LIB``, and ``OPERATING_CONDITION``
  set in the project ``Makefile``
- Project ``Makefile`` includes ``system_cadence_genus.mk``

Makefile Setup
--------------

Add the following to your project ``Makefile`` **before** the ruckus include line.
Replace the example paths with your actual PDK installation paths.

.. code-block:: makefile

   export PDK_PATH           = /path/to/pdk
   export OPERATING_CONDITION = tt_0p8v_25c
   export STD_CELL_LIB       = $(PDK_PATH)/lib/cells.lib
   export STD_LEF_LIB        = $(PDK_PATH)/lef/cells.lef

   include $(TOP_DIR)/submodules/ruckus/system_cadence_genus.mk

Top-Level ruckus.tcl Structure
------------------------------

Unlike the Vivado build flow (which automatically calls ``GenBuildString`` and
``AnalyzeSrcFileLists`` internally), the Cadence Genus flow requires you to call
these procedures explicitly in your project's top-level ``ruckus.tcl``. The
``GenBuildString`` call generates the build-metadata VHDL package; ``AnalyzeSrcFileLists``
passes all source files collected by prior ``loadRuckusTcl`` calls to Genus for analysis.

.. code-block:: tcl

   # Load RUCKUS environment and library
   source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_PROC_TCL)

   # Load ruckus library (ruckus.BuildInfoPkg.vhd only)
   GenBuildString $::env(SYN_DIR)

   # Load the surf library
   loadRuckusTcl "$::env(TOP_DIR)/submodules/surf"

   # Load the work library
   loadRuckusTcl "$::env(TOP_DIR)/shared"

   # Analyze source code loaded into ruckus for Cadence Genus
   AnalyzeSrcFileLists

Steps
-----

1. **Run synthesis:**

   .. code-block:: bash

      make syn

   This invokes ``genus -f syn.tcl`` using the variables you configured above.
   Synthesis runs with up to ``MAX_CORES`` parallel threads (default: 8).

2. **Export a behavioral Verilog netlist (optional):**

   .. code-block:: bash

      make behavioral_verilog

   Runs ``genus -f behavioral_verilog.tcl`` to export the post-synthesis netlist.
   Useful for downstream gate-level simulation or handoff to a P&R tool.

3. **Run VCS simulation (if VCS is available):**

   .. code-block:: bash

      make sim

   Sources ``sim.sh`` to run the VCS simulation flow against the synthesized netlist.

Output Artifacts
----------------

After a successful ``make syn`` run, outputs are placed in the following locations:

- ``$(OUT_DIR)/syn/`` — synthesis working directory
- ``$(OUT_DIR)/syn/out/`` — output netlists and reports
- ``$(OUT_DIR)/syn/out/reports/`` — timing and area reports
- ``$(OUT_DIR)/syn/out/svf/`` — SVF (Scan and Test Verification File)
- ``$(IMAGES_DIR)/`` — final promoted artifacts

Key Variables
-------------

.. list-table::
   :header-rows: 1
   :widths: 22 15 63

   * - Variable
     - Default
     - Description
   * - ``PDK_PATH``
     - (none)
     - Path to the PDK root. Must be set by user.
   * - ``OPERATING_CONDITION``
     - (none)
     - Timing corner name (e.g., ``tt_0p8v_25c``). Must be set by user.
   * - ``STD_CELL_LIB``
     - (none)
     - Standard cell liberty file path (``.lib``). Must be set by user.
   * - ``STD_LEF_LIB``
     - (none)
     - Standard cell LEF file path (``.lef``). Must be set by user.
   * - ``MAX_CORES``
     - ``8``
     - Number of parallel synthesis cores passed to Genus.
   * - ``GIT_BYPASS``
     - ``1``
     - Git dirty-state check bypassed by default in ASIC flows.

.. note::

   ``GIT_BYPASS = 1`` means the git dirty-state check is **disabled** by default.
   ASIC flows typically manage provenance through other mechanisms (e.g., SVF).
   Set ``GIT_BYPASS = 0`` to re-enable the check if your flow requires it.

See the :doc:`../reference/makefile_reference` for the complete variable reference.

Troubleshooting
---------------

**"Cannot find liberty file"**
   Verify that ``STD_CELL_LIB`` points to the ``.lib`` file itself, not to the
   PDK root directory. The value should be a full path to a single file, for
   example ``$(PDK_PATH)/lib/cells.lib``.

**"genus: command not found"**
   Source the Cadence tool setup script for your installation before running
   make. This is typically a script such as ``cadence_init.sh`` or a module load
   command provided by your site's EDA environment.
