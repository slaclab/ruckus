How to Simulate VHDL with GHDL
===============================

**Goal:** Analyze, elaborate, and simulate a VHDL design using the open-source
GHDL simulator.

.. note::

   GHDL requires no Vivado or Xilinx license. It is an independent open-source
   VHDL simulator and works on any Linux system where ``ghdl`` is installed.

Prerequisites
-------------

Before running the simulation flow, ensure the following are in place:

- ``ghdl`` binary installed and on PATH (version 2.0+ recommended)
- ``gtkwave`` installed for waveform viewing
- A ruckus project with ``system_ghdl.mk`` and a ``ghdl/load_source_code.tcl``
  source enumeration file
- ``yosys`` with GHDL plugin installed — only required if using
  ``make export_verilog`` (optional step)
- Project ``Makefile`` includes ``system_ghdl.mk``

Makefile Setup
--------------

Add the following to your project ``Makefile``:

.. code-block:: makefile

   include $(TOP_DIR)/submodules/ruckus/system_ghdl.mk

No PDK variables are required. GHDL uses only the VHDL sources enumerated by
``ghdl/load_source_code.tcl``.

Steps
-----

GHDL uses a staged pipeline. Each step corresponds to a distinct GHDL command.
Run targets in the order shown below.

1. **Create output directories:**

   .. code-block:: bash

      make dir

   Creates ``$(OUT_DIR)`` and ``$(IMAGES_DIR)`` if they do not exist.

2. **Load source file list:**

   .. code-block:: bash

      make load_source_code

   Runs ``ghdl/load_source_code.tcl`` to enumerate the VHDL source files for
   the project.

3. **Analyze VHDL sources** (``ghdl -a``):

   .. code-block:: bash

      make analysis

   Parses and type-checks all VHDL source files. Errors here indicate syntax or
   type-checking problems in your HDL.

4. **Import design units** (``ghdl -i``):

   .. code-block:: bash

      make import

   Imports design units into the working library.

5. **Determine elaboration order** (``ghdl --elab-order``):

   .. code-block:: bash

      make elab_order

   Writes the elaboration order to
   ``$(IMAGES_DIR)/$(PROJECT).elab_order`` for reference.

6. **Build (elaborate) the design** (``ghdl -m``):

   .. code-block:: bash

      make build

   Elaborates the top-level design unit into a simulation executable.

7. **Run simulation** (``ghdl -r``):

   .. code-block:: bash

      make tb

   Runs the simulation and produces a waveform file at
   ``$(OUT_DIR)/$(PROJECT).ghw``. Simulation stops at ``GHDL_STOP_TIME``
   (default: ``10ns``).

8. **View waveform in GTKWave:**

   .. code-block:: bash

      make gtkwave

   Opens GTKWave with the ``.ghw`` waveform file produced by ``make tb``.

.. note::

   Steps 1 through 7 can be run individually in sequence, or you can run
   ``make tb`` directly. Because ``make tb`` declares all prior targets as
   dependencies, it will execute the full chain automatically from a clean state.

Optional: Export Synthesizable Verilog
--------------------------------------

If you have ``yosys`` with the GHDL plugin installed, you can export a
synthesizable Verilog netlist from the VHDL design:

.. code-block:: bash

   make export_verilog

This runs ``yosys -m ghdl`` to synthesize the VHDL design into Verilog.
This step is independent of the simulation flow and does not require GTKWave.

Key Variables
-------------

.. list-table::
   :header-rows: 1
   :widths: 22 15 63

   * - Variable
     - Default
     - Description
   * - ``GHDL_CMD``
     - ``ghdl``
     - GHDL executable path or name. Override if ``ghdl`` is not on PATH or
       you need a specific version.
   * - ``GHDL_TOP_LIB``
     - ``work``
     - Top-level VHDL library name. Must match the ``library`` clause in your
       VHDL top-level entity.
   * - ``GHDL_STOP_TIME``
     - ``10ns``
     - Simulation stop time. Increase this for testbenches that require longer
       run times.
   * - ``GHDLFLAGS``
     - ``--std=08 --ieee=synopsys -frelaxed-rules ...``
     - Full set of flags passed to all GHDL commands. The complete default is:
       ``--workdir=$(OUT_DIR) --std=08 --ieee=synopsys -frelaxed-rules
       -fexplicit -Wno-elaboration -Wno-hide -Wno-specs -Wno-shared``.
       Override in your project Makefile (before the include) to change the
       VHDL standard or suppress different warnings.
   * - ``GIT_BYPASS``
     - ``1``
     - Git dirty-state check bypassed by default.

.. note::

   To override ``GHDLFLAGS``, set it in your project ``Makefile`` **before** the
   ``include`` line:

   .. code-block:: makefile

      export GHDLFLAGS = --workdir=$(OUT_DIR) --std=93 --ieee=standard

      include $(TOP_DIR)/submodules/ruckus/system_ghdl.mk

Troubleshooting
---------------

**"ghdl: command not found"**
   Install GHDL on your system:

   .. code-block:: bash

      # Debian / Ubuntu
      sudo apt install ghdl

   For other distributions or to build from source, see the GHDL repository at
   https://github.com/ghdl/ghdl.

**"bound check failure" or simulation stops immediately**
   Increase ``GHDL_STOP_TIME``. The default (``10ns``) is intentionally short
   and will be too brief for most testbenches. Set a longer stop time in your
   project ``Makefile``:

   .. code-block:: makefile

      export GHDL_STOP_TIME = 1us

**Analysis errors: "no library" or unresolved references**
   Verify that ``GHDL_TOP_LIB`` matches the library name used in your VHDL
   ``library`` and ``use`` clauses. If your design uses ``library work;``, the
   default value of ``work`` is correct. Mismatches cause GHDL to fail to find
   design units during elaboration.

**GTKWave shows an empty or unreadable waveform**
   Ensure ``make tb`` completed successfully and the ``.ghw`` file exists in
   ``$(OUT_DIR)/`` before running ``make gtkwave``. An incomplete simulation
   (stopped by a runtime assertion) may produce a truncated waveform file.
