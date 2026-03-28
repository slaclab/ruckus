How to Run Synopsys Design Compiler ASIC Synthesis
===================================================

**Goal:** Run ASIC synthesis using Synopsys Design Compiler (DC) for an existing
ruckus-based project.

Prerequisites
-------------

Before running synthesis, ensure the following are in place:

- Licensed Synopsys DC installation with the ``dc_shell-xg-t`` binary on PATH
- A technology library with compiled liberty (``.db``) files
- ``DIG_TECH`` and ``STD_CELL_LIB`` set in the project ``Makefile``
- Project ``Makefile`` includes ``system_synopsys_dc.mk``

Makefile Setup
--------------

Add the following to your project ``Makefile`` **before** the ruckus include line.
Replace the example paths with your actual library installation paths.

.. code-block:: makefile

   export DIG_TECH     = /path/to/tech/library
   export STD_CELL_LIB = /path/to/cells.db

   include $(TOP_DIR)/submodules/ruckus/system_synopsys_dc.mk

Steps
-----

1. **Run synthesis:**

   .. code-block:: bash

      make syn

   This invokes the Design Compiler command (``dc_shell-xg-t -64bit
   -topographical_mode -f syn.tcl`` by default) with colored status output
   through ``$(DC_MSG)``. Parallelism is auto-detected from ``/proc/cpuinfo``
   unless overridden with ``PARALLEL_SYNTH``.

2. **Run VCS simulation (if VCS is available):**

   .. code-block:: bash

      make sim

   Sources ``sim.sh`` to run a VCS simulation against the synthesized netlist.

Output Artifacts
----------------

After a successful ``make syn`` run, outputs follow the same directory structure
as the Cadence Genus flow:

- ``$(OUT_DIR)/syn/out/`` — output netlists and reports
- ``$(IMAGES_DIR)/`` — final promoted artifacts

Key Variables
-------------

.. list-table::
   :header-rows: 1
   :widths: 22 15 63

   * - Variable
     - Default
     - Description
   * - ``DIG_TECH``
     - (none)
     - Digital technology library path. Must be set by user.
   * - ``STD_CELL_LIB``
     - (none)
     - Standard cell library (``.db``) path. Must be set by user.
   * - ``MAX_CORES``
     - ``4``
     - Number of parallel synthesis cores.
   * - ``DC_CMD``
     - ``dc_shell-xg-t -64bit -topographical_mode``
     - Full Design Compiler invocation command. Override to use a different
       DC variant or mode.
   * - ``PARALLEL_SYNTH``
     - auto (from ``/proc/cpuinfo``)
     - CPU count used for parallelism. Auto-detected if not set.
   * - ``SIM_TIMESCALE``
     - ``1ns/1ps``
     - VCS simulation timescale used by ``make sim``.
   * - ``GIT_BYPASS``
     - ``1``
     - Git dirty-state check bypassed by default in ASIC flows.

.. note::

   ``GIT_BYPASS = 1`` means the git dirty-state check is **disabled** by default.
   Set ``GIT_BYPASS = 0`` to re-enable it if your flow requires provenance tracking
   via git status.

See the :doc:`../reference/makefile_reference` for the complete variable reference.

Troubleshooting
---------------

**"dc_shell-xg-t: command not found"**
   Source the Synopsys tool setup script before running make. This is typically:

   .. code-block:: bash

      source /path/to/synopsys/settings.sh

   The exact path depends on your site's Synopsys installation. Check with your
   EDA administrator if the standard location is not known.

**"Cannot read library file"**
   Verify that ``STD_CELL_LIB`` points to the compiled ``.db`` file, not the
   ``.lib`` source. Design Compiler requires pre-compiled ``.db`` format. If you
   only have ``.lib`` files, compile them first using ``lc_shell``.
