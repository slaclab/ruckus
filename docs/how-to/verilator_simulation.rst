How to Simulate Verilog with Verilator
========================================

**Goal:** Load, compile, and simulate a Verilog/SystemVerilog design using the
open-source Verilator simulator.

.. note::

   This flow needs no Vivado or Xilinx license. It handles Verilog and
   SystemVerilog sources only; VHDL is a hard error (see Troubleshooting
   below). For a VHDL design, use :doc:`ghdl_simulation` instead.

Prerequisites
-------------

Before running the simulation flow, ensure the following are in place:

- Verilator 5.020 or newer, on PATH. The ``--binary``/``--timing`` flags this
  flow relies on require timing support, which is not present in older
  releases. The version check runs in ``make load_source_code``, before any
  source is loaded.
- ``gtkwave`` installed for waveform viewing.
- For Rogue co-simulation designs only: ``gcc``, ``pkg-config``, ``libzmq``
  4.1.0 or newer, and a surf version that provides ``simlink/verilator/``.
- Project ``Makefile`` includes ``system_verilator.mk``.

Makefile Setup
--------------

Add the following to your project ``Makefile``:

.. code-block:: makefile

   include $(TOP_DIR)/submodules/ruckus/system_verilator.mk

Set any knobs **before** the include line, the same way ``GHDLFLAGS`` is set
for the GHDL flow:

.. code-block:: makefile

   export VERILOG_INCDIRS = $(PROJ_DIR)/rtl/include
   export VERILOG_DEFINES = SIM_SPEED_UP
   export SIM_TOP = MyTb

   include $(TOP_DIR)/submodules/ruckus/system_verilator.mk

Switching simulators means changing only this include line to
``system_iverilog.mk`` (see :doc:`iverilog_simulation`); every other knob is
shared between the two flows.

Loading Sources
----------------

A project's ``ruckus.tcl`` tree is loaded the same way as every other ruckus
backend, through ``loadSource`` and ``loadRuckusTcl``, using the same shared
loader as the Icarus Verilog flow:

.. code-block:: tcl

   source $::env(RUCKUS_PROC_TCL)

   # A package that other files in this directory depend on
   loadSource -path "$::DIR_PATH/rtl/MyPkg.sv"

   # The rest of the RTL sources in this directory
   loadSource -dir "$::DIR_PATH/rtl"

   # Testbench-only sources
   loadSource -sim_only -dir "$::DIR_PATH/tb"

The loader (``shared/verilog_proc.tcl``) applies the following rules:

- ``.v`` and ``.sv`` files are compiled in **load order**: the order
  ``loadSource``/``loadRuckusTcl`` calls occur across the whole recursive
  load, not alphabetical or directory order. Verilator tolerates either
  package/user order (unlike Icarus, see :doc:`iverilog_simulation`).
- ``loadSource -dir`` loads the directory's ``.v``/``.sv``/``.vh``/``.svh``
  files sorted by name, non-recursively.
- Duplicate files (loaded twice through different paths) are dropped by real
  path.
- ``.vh`` and ``.svh`` files are never compiled; each loaded header's
  directory is instead added as an include directory automatically.
- ``-lib`` is accepted and ignored, since Verilog has no libraries.
- ``-sim_only`` is accepted and stripped; both flows compile everything in
  one filelist.
- Any ``.vhd``/``.vhdl`` file anywhere in the loaded tree is a **hard error**:
  ``load_source_code`` lists every offending path and exits before writing a
  filelist. If the VHDL came from surf, ``loadRuckusTcl
  $::env(MODULES)/surf/simlink`` instead of loading all of surf.
- No ``BuildInfoPkg.vhd``/``BUILD_INFO_C`` generic is generated: that
  mechanism is VHDL-only and would trip the rule above.

Steps
-----

1. **Load the source file list:**

   .. code-block:: bash

      make load_source_code

   Checks the Verilator version floor, loads the project's ``ruckus.tcl``
   tree, and writes the ordered, deduplicated filelist to
   ``$(OUT_DIR)/$(PROJECT).f``.

2. **Build:**

   .. code-block:: bash

      make build

   Runs ``verilator $(VERILATOR_FLAGS) [--trace-fst] +incdir+<dir>... +define+<def>... --top-module $(SIM_TOP) --Mdir $(OUT_DIR) -o V$(SIM_TOP) -f $(PROJECT).f [<OUT_DIR>/libRogueSimLinkDpi.so -LDFLAGS "-Wl,-rpath,$(OUT_DIR) <pkg-config libzmq libs>"]`` in ``$(OUT_DIR)``. When a Rogue SimLink leaf is in the filelist, this step also builds and links the SimLink DPI library first (see Rogue Co-Simulation below).

3. **Run:**

   .. code-block:: bash

      make tb

   Runs ``./V$(SIM_TOP) $(SIM_PLUSARGS)`` in ``$(OUT_DIR)``. ``make tb`` depends on ``build``, which depends on ``load_source_code``, which depends on ``dir`` (which itself depends on ``clean``), so a bare ``make tb`` always runs the whole chain from a clean ``$(OUT_DIR)``, exactly like the GHDL flow.

4. **View a waveform:**

   .. code-block:: bash

      make gtkwave

   Sets ``WAVES=1``, runs ``make tb``, and opens
   ``$(OUT_DIR)/$(PROJECT).fst`` in GTKWave.

5. **Print environment variables:**

   .. code-block:: bash

      make test

6. **Clean the build directory:**

   .. code-block:: bash

      make clean

Waveforms
---------

The testbench owns waveform dumping; Verilator does not dump anything on its
own:

.. code-block:: verilog

   initial begin
      $dumpfile("MyTb.fst");
      $dumpvars;
   end

``WAVES=1`` adds ``--trace-fst`` to the ``verilator`` build, so the dump above
is written in FST format. ``make gtkwave`` sets ``WAVES=1`` for you and opens
the ``.fst`` file.

.. note::

   Verilator's FST writer needs the ``lz4`` (and ``zlib``) development
   headers installed. Without them, ``make build WAVES=1`` stops with
   ``fatal error: lz4.h: No such file or directory`` (see Troubleshooting).

Rogue Co-Simulation
--------------------

A design that instantiates surf's flat SimLink wrappers, ``RogueTcpStreamWrap``,
``RogueTcpMemoryWrap``, ``RogueSideBandWrap`` (loaded via ``loadRuckusTcl
$::env(MODULES)/surf/simlink``; port and parameter contract documented as
plain text in surf's ``simlink/sv/README.md``, since it lives in another
repository), gets Rogue co-simulation automatically:

- ``make build`` detects ``RogueTcpStream.sv``, ``RogueTcpMemory.sv``, or
  ``RogueSideBand.sv`` in the filelist. If none is present, the rest of this
  section is skipped entirely and no libzmq check runs.
- When a leaf is detected, ``make build`` checks ``gcc``, ``pkg-config``, and
  ``libzmq`` >= 4.1.0, then runs ``make`` in-tree in surf's
  ``simlink/verilator/``, copies the resulting ``libRogueSimLinkDpi.so`` into
  ``$(OUT_DIR)``, and runs ``make clean`` in the surf tree.
- Unlike the Icarus flow, which loads its VPI module at ``vvp`` run time, the
  ``verilator`` build links ``libRogueSimLinkDpi.so`` directly, staged from
  ``$(OUT_DIR)``, with ``-LDFLAGS "-Wl,-rpath,$(OUT_DIR) <pkg-config libzmq
  libs>"`` so the resulting ``V$(SIM_TOP)`` binary finds the library and
  libzmq at run time with no additional setup.
- No environment setup (no ``setup_env.sh``, no ``LD_LIBRARY_PATH``) is
  needed; the rpath resolves the library.
- A Rogue peer (a PyRogue client) connects to ports ``N`` and ``N + 1`` of
  each wrapper's ``PORT_NUM_G`` once the simulation is running.

Key Variables
-------------

.. list-table::
   :header-rows: 1
   :widths: 22 15 63

   * - Variable
     - Default
     - Description
   * - :envvar:`SIM_TOP`
     - ``$(PROJECT)``
     - Top module name simulated by ``V$(SIM_TOP)``.
   * - :envvar:`VERILATOR_FLAGS`
     - ``--binary --timing -j 0``
     - Flags passed to ``verilator``. Override before the include line to
       change build behavior.
   * - :envvar:`VERILOG_INCDIRS`
     - (empty)
     - Whitespace-separated list of extra include directories, each added as
       ``+incdir+<dir>``.
   * - :envvar:`VERILOG_DEFINES`
     - (empty)
     - Whitespace-separated list of ``NAME`` or ``NAME=VAL`` words, each
       added as ``+define+<def>``. Values containing spaces are not
       supported.
   * - :envvar:`SIM_PLUSARGS`
     - (empty)
     - Plusargs appended verbatim after ``V$(SIM_TOP)`` on the run command
       line.
   * - :envvar:`WAVES`
     - (empty)
     - Set to ``1`` to add ``--trace-fst`` to the ``verilator`` build.
   * - :envvar:`RUCKUS_SIM_BACKEND`
     - ``verilator``
     - Backend selector read by ``surf/simlink/ruckus.tcl``.
   * - :envvar:`GIT_BYPASS`
     - ``1``
     - Git dirty-state check bypassed by default.

.. note::

   Parameter overrides go through the ``-G<name>=<value>`` escape hatch in
   :envvar:`VERILATOR_FLAGS` rather than a dedicated variable:

   .. code-block:: makefile

      export VERILATOR_FLAGS = --binary --timing -j 0 -GWIDTH_G=16

Troubleshooting
---------------

**"VerilogCheckVersion: ruckus requires verilator 5.020 or newer"**
   The Verilator on PATH is older than the enforced floor (the ``--binary``
   and ``--timing`` flags this flow relies on require 5.020 or newer). There
   is no bypass variable; install Verilator 5.020 or newer.

**"libzmq package was not found"**

   .. code-block:: text

      libzmq package was not found
      Please make sure that you have libzmq installed
      or have sourced the necessary rogue setup scripts

   Only appears for a design containing a Rogue SimLink leaf. Install the
   ``libzmq`` development package so ``pkg-config`` can find it.

**"VerilogWriteFilelist: VHDL sources are not supported ..."**
   A ``.vhd``/``.vhdl`` file is somewhere in the loaded tree. Remove it, or
   if it came from surf, ``loadRuckusTcl $::env(MODULES)/surf/simlink``
   instead of loading all of surf.

**Fatal lint warnings stop the build**
   Verilator's default lint warnings are fatal. Add ``-Wno-fatal`` to
   ``VERILATOR_FLAGS`` to continue past them (fix the warnings when
   practical instead of suppressing them permanently).

**"%Warning-TIMESCALEMOD"**
   Mixing timescaled and non-timescaled modules in the same design raises
   this warning (fatal by default, see above). surf SimLink sources carry no
   timescale. Add ``--timescale 1ns/1ps`` to ``VERILATOR_FLAGS``.

**"fatal error: lz4.h: No such file or directory"**
   Verilator's FST waveform writer needs the ``lz4`` (and ``zlib``)
   development headers. Install them, or avoid ``WAVES=1``/``make gtkwave``
   if tracing is not needed.
