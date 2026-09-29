How to Simulate Verilog with Icarus Verilog
============================================

**Goal:** Load, compile, and simulate a Verilog/SystemVerilog design using the
open-source Icarus Verilog simulator.

.. note::

   This flow needs no Vivado or Xilinx license. It handles Verilog and
   SystemVerilog sources only; VHDL is a hard error (see Troubleshooting
   below). For a VHDL design, use :doc:`ghdl_simulation` instead.

Prerequisites
-------------

Before running the simulation flow, ensure the following are in place:

- Icarus Verilog 12.0 or newer, with ``iverilog``, ``iverilog-vpi``, and
  ``vvp`` all on PATH. The version and tool checks run in
  ``make load_source_code``, before any source is loaded.
- ``gtkwave`` installed for waveform viewing.
- For Rogue co-simulation designs only: ``gcc``, ``pkg-config``, ``libzmq``
  4.1.0 or newer, and a surf version that provides ``simlink/iverilog/``.
- Project ``Makefile`` includes ``system_iverilog.mk``.

Makefile Setup
--------------

Add the following to your project ``Makefile``:

.. code-block:: makefile

   include $(TOP_DIR)/submodules/ruckus/system_iverilog.mk

Set any knobs **before** the include line, the same way ``GHDLFLAGS`` is set
for the GHDL flow:

.. code-block:: makefile

   export VERILOG_INCDIRS = $(PROJ_DIR)/rtl/include
   export VERILOG_DEFINES = SIM_SPEED_UP
   export SIM_TOP = MyTb

   include $(TOP_DIR)/submodules/ruckus/system_iverilog.mk

Switching simulators means changing only this include line to
``system_verilator.mk``; every other knob is shared between the two flows.

Loading Sources
----------------

A project's ``ruckus.tcl`` tree is loaded the same way as every other ruckus
backend, through ``loadSource`` and ``loadRuckusTcl``:

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
  load, not alphabetical or directory order.
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

Icarus needs a package compiled before the files that use it: load the
package with ``-path`` **before** the ``-dir`` that references it. Loading
them in the wrong order surfaces as a ``syntax error`` at the ``import`` line
(see Troubleshooting). Verilator tolerates either order.

Steps
-----

1. **Load the source file list:**

   .. code-block:: bash

      make load_source_code

   Checks the Icarus version floor and the ``iverilog-vpi``/``vvp`` tools,
   loads the project's ``ruckus.tcl`` tree, and writes the ordered,
   deduplicated filelist to ``$(OUT_DIR)/$(PROJECT).f``.

2. **Build:**

   .. code-block:: bash

      make build

   Runs ``iverilog $(IVERILOG_FLAGS) -I<dir>... -D<def>... -s $(SIM_TOP) -o $(SIM_TOP).vvp -c $(PROJECT).f`` in ``$(OUT_DIR)``. When a Rogue SimLink leaf is in the filelist, this step also builds the SimLink VPI module first (see Rogue Co-Simulation below).

3. **Run:**

   .. code-block:: bash

      make tb

   Runs ``vvp $(VVP_FLAGS) [-M$(OUT_DIR) -mRogueSimLink] $(SIM_TOP).vvp [-fst] $(SIM_PLUSARGS)`` in ``$(OUT_DIR)``. ``make tb`` depends on ``build``, which depends on ``load_source_code``, which depends on ``dir`` (which itself depends on ``clean``), so a bare ``make tb`` always runs the whole chain from a clean ``$(OUT_DIR)``, exactly like the GHDL flow.

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

The testbench owns waveform dumping; neither tool dumps anything on its
own:

.. code-block:: verilog

   initial begin
      $dumpfile("MyTb.fst");
      $dumpvars;
   end

``WAVES=1`` adds ``-fst`` to the ``vvp`` run, so the dump above is written in
FST format. ``make gtkwave`` sets ``WAVES=1`` for you and opens the ``.fst``
file. Without ``-fst``, ``vvp`` still honors ``$dumpfile``/``$dumpvars`` but
writes plain VCD text under the ``.fst`` filename.

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
  ``simlink/iverilog/``, copies the resulting ``RogueSimLink.vpi`` into
  ``$(OUT_DIR)``, and runs ``make clean`` in the surf tree.
- ``make tb`` adds ``-M$(OUT_DIR) -mRogueSimLink`` to the ``vvp`` command
  line so the VPI module loads at run time.
- No environment setup (no ``setup_env.sh``, no ``LD_LIBRARY_PATH``) is
  needed; the module is found through ``-M$(OUT_DIR)``.
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
     - Top module name simulated by ``vvp``.
   * - :envvar:`IVERILOG_FLAGS`
     - ``-g2012``
     - Flags passed to ``iverilog``. Override before the include line to
       change the Verilog/SystemVerilog standard.
   * - :envvar:`VVP_FLAGS`
     - ``-n``
     - Flags passed to ``vvp``.
   * - :envvar:`VERILOG_INCDIRS`
     - (empty)
     - Whitespace-separated list of extra include directories, each added as
       ``-I<dir>``.
   * - :envvar:`VERILOG_DEFINES`
     - (empty)
     - Whitespace-separated list of ``NAME`` or ``NAME=VAL`` words, each
       added as ``-D<def>``. Values containing spaces are not supported.
   * - :envvar:`SIM_PLUSARGS`
     - (empty)
     - Plusargs appended verbatim after the ``.vvp`` file on the ``vvp``
       command line.
   * - :envvar:`WAVES`
     - (empty)
     - Set to ``1`` to add ``-fst`` to the ``vvp`` run.
   * - :envvar:`RUCKUS_SIM_BACKEND`
     - ``iverilog``
     - Backend selector read by ``surf/simlink/ruckus.tcl``.
   * - :envvar:`GIT_BYPASS`
     - ``1``
     - Git dirty-state check bypassed by default.

.. note::

   Parameter overrides go through the ``-P<top>.<name>=<value>`` escape
   hatch in :envvar:`IVERILOG_FLAGS` rather than a dedicated variable:

   .. code-block:: makefile

      export IVERILOG_FLAGS = -g2012 -PMyTb.WIDTH_G=16

Troubleshooting
---------------

**"VerilogCheckVersion: ruckus requires iverilog 12.0 or newer"**
   The Icarus Verilog on PATH is older than the enforced floor. There is no
   bypass variable; install Icarus Verilog 12.0 or newer.

**"VerilogCheckTool: ... not found in PATH"**
   One of ``iverilog``, ``iverilog-vpi``, or ``vvp`` is missing. Install
   Icarus Verilog and confirm all three binaries are on PATH.

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

**"VerilogWriteFilelist: no .v or .sv sources were loaded"**
   The loaded tree has no compilable sources; check that ``loadSource`` /
   ``loadRuckusTcl`` calls actually resolve to a directory containing
   ``.v``/``.sv`` files.

**"syntax error" at an ``import`` line**
   A SystemVerilog package was loaded after the file that imports it. Move
   the package's ``loadSource -path`` call before the ``loadSource -dir``
   call that references it (see Loading Sources above).

**Waveform file is empty or missing**
   Confirm the testbench calls ``$dumpfile``/``$dumpvars`` and that
   ``WAVES=1`` was set (``make gtkwave`` sets it for you). ``make tb``
   without ``WAVES=1`` still writes a file under the ``.fst`` name, but as
   plain VCD text rather than FST.
