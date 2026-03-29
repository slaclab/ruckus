Your First Vivado Firmware Build
==================================

This tutorial walks through setting up a Vivado firmware project that uses ruckus as its
build system. You will clone a working example project, examine its structure, and run
``make bit`` to produce a bitstream.

The example project is `Simple-10GbE-RUDP-KCU105-Example
<https://github.com/slaclab/Simple-10GbE-RUDP-KCU105-Example>`_ — a real SLAC firmware
project for the KCU105 evaluation board. Its Makefile and ruckus.tcl are minimal and
representative of how ruckus projects are structured.

By the end of this tutorial you will understand:

- What the three mandatory files in a ruckus project are and what each does
- How ruckus.tcl declares sources using ``$::DIR_PATH/``
- How to run a build from scratch and what the output artifacts look like


Prerequisites
--------------

Before you begin, ensure you have:

- **Linux** — ruckus requires a Linux environment. macOS and Windows are not supported.
- **Vivado** — Xilinx/AMD Vivado installed and on your PATH. The example project requires
  Vivado 2023.1 or later. Test with:

  .. code-block:: bash

     vivado -version

- **git** — version 2.9.0 or later. Test with:

  .. code-block:: bash

     git --version

- **git-lfs** — version 2.1.1 or later. Test with:

  .. code-block:: bash

     git lfs version

- **Python 3** — required only for ``make release`` (not for ``make bit``).
  Install pip packages if you plan to use release targets:

  .. code-block:: bash

     pip install gitpython PyGithub pyyaml

.. note::

   Vivado must be activated in your shell before running any make target. Source the
   Vivado settings script before proceeding:

   .. code-block:: bash

      source /path/to/Vivado/2023.1/settings64.sh

   Replace ``/path/to/Vivado/2023.1`` with your actual Vivado installation path.
   After sourcing, confirm Vivado is accessible: ``vivado -version``.


Clone the Example Project
--------------------------

The example project uses git submodules to pull in its dependencies (including ruckus
itself). Clone it recursively so that all submodules are populated:

.. code-block:: bash

   git clone --recursive https://github.com/slaclab/Simple-10GbE-RUDP-KCU105-Example.git
   cd Simple-10GbE-RUDP-KCU105-Example

If you forget ``--recursive``, initialize submodules manually:

.. code-block:: bash

   git submodule update --init --recursive

ruckus itself lives at ``firmware/submodules/ruckus/`` inside the cloned repository — it
is a git submodule, not a system-wide tool. Every ruckus-based project carries its own
pinned copy this way.


Project Directory Structure
-----------------------------

After cloning, the relevant structure under ``firmware/`` is:

.. code-block:: none

   firmware/
   ├── shared/
   │   ├── ruckus.tcl          <- shared library manifest
   │   ├── rtl/                <- shared RTL source files
   │   ├── ip/                 <- shared IP core files (.xci)
   │   └── xdc/                <- shared constraint files (.xdc)
   ├── submodules/
   │   ├── ruckus/             <- this build system (as a git submodule)
   │   └── surf/               <- SLAC FPGA library (as a git submodule)
   ├── targets/
   │   ├── shared_version.mk   <- firmware version and target-common settings
   │   └── Simple10GbeRudpKcu105Example/
   │       ├── Makefile         <- build entry point
   │       ├── ruckus.tcl       <- target-specific source manifest
   │       ├── hdl/             <- target-specific RTL source files
   │       └── tb/              <- testbench files
   └── build/                  <- created at first build (or symlinked to scratch disk)

The three mandatory files for any ruckus project are:

1. **Makefile** — includes ``system_vivado.mk`` from the ruckus submodule
2. **ruckus.tcl** — declares the project's sources using ruckus procedures
3. **images/** directory — receives output artifacts (ruckus creates it automatically
   on the first successful build)

Everything else in the structure above (``shared/``, ``surf/``, etc.) belongs to this
particular example project. A minimal new project needs only the three items above.


Understanding the Makefile
----------------------------

Look at the Makefile for this target
(``firmware/targets/Simple10GbeRudpKcu105Example/Makefile``):

.. code-block:: make

   export TOP_DIR = $(abspath $(PWD)/../..)
   include ../shared_version.mk
   include $(TOP_DIR)/submodules/ruckus/system_vivado.mk

Three lines. ``TOP_DIR`` points two levels up to the ``firmware/`` root. ``shared_version.mk``
sets ``PRJ_VERSION``, ``PRJ_PART``, and the default build target. ``system_vivado.mk``
provides all build targets (``bit``, ``mcs``, ``gui``, ``sim``, etc.) and the complete
pipeline logic.

The ``shared_version.mk`` for this project:

.. code-block:: make

   export PRJ_VERSION = 0x02180000
   target: prom
   export PRJ_PART = XCKU040-FFVA1156-2-E
   export USE_XVC_DEBUG = 1
   ifndef RELEASE
   export RELEASE = simple_10gbe_rudp_kcu105_example
   endif

``PRJ_PART`` identifies the target FPGA device (the Kintex UltraScale KU040 on the KCU105
board). ``PRJ_VERSION`` is a 32-bit firmware version number embedded in the output filename
and in the bitstream. The ``target: prom`` line makes ``make prom`` the default target
instead of ``make bit`` — for this project, the default build produces both a bitstream
and a PROM programming file.

To understand the full list of variables that ``system_vivado.mk`` recognizes, see
:doc:`../explanation/build_pipeline`.


Understanding ruckus.tcl
--------------------------

The ruckus.tcl for this target
(``firmware/targets/Simple10GbeRudpKcu105Example/ruckus.tcl``):

.. code-block:: tcl

   # Load RUCKUS environment
   source $::env(RUCKUS_PROC_TCL)

   # Check for version 2023.1 of Vivado (or later)
   if { [VersionCheck 2023.1] < 0 } {exit -1}

   # Load shared and sub-module ruckus.tcl files
   loadRuckusTcl $::env(TOP_DIR)/submodules/surf
   loadRuckusTcl $::env(TOP_DIR)/shared

   # Load local source code and constraints
   loadSource      -dir "$::DIR_PATH/hdl"
   loadConstraints -dir "$::DIR_PATH/hdl"

   # Load local simulation source code
   loadSource -sim_only -dir  "$::DIR_PATH/tb"
   set_property top {Simple10GbeRudpKcu105ExampleTb} [get_filesets sim_1]

Walk through each line:

- ``source $::env(RUCKUS_PROC_TCL)`` — loads all ruckus procedures. This must appear first
  in every top-level ruckus.tcl. ``RUCKUS_PROC_TCL`` is set by ``system_vivado.mk`` and
  points to ``submodules/ruckus/vivado/proc.tcl``.

- ``VersionCheck 2023.1`` — enforces the minimum Vivado version for this project. The build
  exits immediately with a non-zero status if the installed Vivado is older than 2023.1.
  Each project sets its own minimum; ruckus itself imposes no global minimum.

- ``loadRuckusTcl $::env(TOP_DIR)/submodules/surf`` — loads the surf submodule's ruckus.tcl,
  which recursively adds all of surf's source files to the Vivado project.

- ``loadRuckusTcl $::env(TOP_DIR)/shared`` — loads the shared library's ruckus.tcl.

- ``loadSource -dir "$::DIR_PATH/hdl"`` — adds all HDL files (VHDL, Verilog, SystemVerilog)
  in the ``hdl/`` subdirectory of **this target** to the project. ``$::DIR_PATH`` is set by
  ruckus to the directory of the currently-executing ruckus.tcl, so this path always resolves
  correctly regardless of where the build was initiated. See
  :doc:`../explanation/ruckus_tcl_model` for details.

- ``loadConstraints -dir "$::DIR_PATH/hdl"`` — adds all XDC constraint files from the same
  directory. Constraint files sit alongside the RTL sources in this project.

- ``loadSource -sim_only -dir "$::DIR_PATH/tb"`` — adds files in the ``tb/`` directory as
  simulation-only sources. They are included in the simulation fileset but not the synthesis
  fileset.

- ``set_property top {Simple10GbeRudpKcu105ExampleTb} [get_filesets sim_1]`` — sets the
  simulation top-level entity, which Vivado needs to know to run simulation.


Writing Your Own ruckus.tcl
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For a minimal new project that has no submodule dependencies, the pattern is:

.. code-block:: tcl

   # Load RUCKUS environment
   source $::env(RUCKUS_PROC_TCL)

   # Load source files from this module's hdl/ directory
   loadSource      -dir "$::DIR_PATH/hdl"

   # Load constraint files
   loadConstraints -dir "$::DIR_PATH/xdc"

The ``$::DIR_PATH/`` prefix is mandatory on every path argument to ``loadSource``,
``loadConstraints``, ``loadIpCore``, and ``loadBlockDesign``. Without it, the path is
resolved against Vivado's current working directory — the build output directory, not
your module's source directory — and the build will fail immediately with a
directory-not-found error.

This is the most common mistake when writing a first ruckus.tcl. See
:doc:`../explanation/ruckus_tcl_model` for the full explanation of why ``$::DIR_PATH``
is necessary and how it works.


Running the Build
------------------

Navigate to the target directory:

.. code-block:: bash

   cd firmware/targets/Simple10GbeRudpKcu105Example

Create the build directory (required before the first build):

.. code-block:: bash

   make dir

This verifies that ``firmware/build/`` exists and creates the per-project output directory
inside it (``firmware/build/Simple10GbeRudpKcu105Example/``). If the build directory does
not exist yet, ``make dir`` prints instructions:

.. code-block:: none

   Build directory missing!
   You must create a build directory at the top level.

   This directory can either be a normal directory:
      mkdir firmware/build

   Or by creating a symbolic link to a directory on another disk:
      ln -s /scratch/disk/path firmware/build

Create the directory and re-run ``make dir``:

.. code-block:: bash

   mkdir firmware/build
   make dir

On SLAC HPC systems with a ``/u1/`` scratch disk, ruckus automatically creates
``/u1/$USER/build`` and symlinks ``firmware/build`` to it. On workstations, just
``mkdir firmware/build``.

Run the full build:

.. code-block:: bash

   make bit

This runs two Vivado invocations in sequence:

1. **Source setup** — Vivado assembles the project by executing all ruckus.tcl files
   recursively. This creates the ``.xpr`` project file in the build directory.
2. **Build** — Vivado runs synthesis, implementation, and bitstream generation.

A complete build takes 30-90 minutes depending on the design size and host machine.
You will see Vivado log output scrolling in the terminal. The build is complete when
the terminal prompt returns without error.


Interpreting the Output
~~~~~~~~~~~~~~~~~~~~~~~~~

When the build succeeds, output files appear in
``firmware/targets/Simple10GbeRudpKcu105Example/images/``:

.. code-block:: none

   images/
   └── Simple10GbeRudpKcu105Example-0x02180000-20240315143022-smith-a1b2c3d.bit

The filename encodes:

- **Project name** — ``Simple10GbeRudpKcu105Example``
- **Firmware version** — ``0x02180000`` (from ``PRJ_VERSION`` in ``shared_version.mk``)
- **Build timestamp** — ``20240315143022`` (UTC, format ``YYYYMMDDHHMMSS``)
- **Username** — ``smith`` (the ``$USER`` shell variable at build time)
- **Git commit hash** — ``a1b2c3d`` (short hash of the HEAD commit)

If git shows uncommitted changes at build time, the git hash is replaced with ``dirty``:

.. code-block:: none

   images/
   └── Simple10GbeRudpKcu105Example-0x02180000-20240315143022-smith-dirty.bit

The ``dirty`` suffix is a signal that the bitstream was built from a modified working
tree — it cannot be reproduced exactly from the git history. For reproducible builds,
commit all changes before running ``make bit``.

See :doc:`../explanation/output_artifacts` for the complete output artifact naming
convention and the full list of file types generated (MCS, PDI, LTX debug probes, etc.).


Other Useful Make Targets
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

   make gui       # Open Vivado GUI with the assembled project (without building)
   make syn       # Run synthesis only
   make sim       # Run simulation (XSIM)
   make clean     # Delete the build output directory (keeps images/)
   make test      # Print all resolved Makefile variables (useful for debugging)

``make gui`` is particularly useful during development: it assembles the Vivado project
from the ruckus.tcl declarations and then opens the Vivado GUI, so you can interactively
explore the project, run synthesis, or modify constraints without leaving the GUI.


Next Steps
-----------

Now that you have a working build, explore the rest of the documentation:

- :doc:`../explanation/ruckus_tcl_model` — Deep explanation of ``$::DIR_PATH`` and the
  recursive loading model. Required reading before writing your own ruckus.tcl files.
- :doc:`../explanation/build_pipeline` — Full pipeline walkthrough showing every step
  from ``make bit`` to the images directory, including hook injection points.
- :doc:`../explanation/output_artifacts` — Complete output artifact naming convention
  and the full list of file types generated per build.
- :doc:`../explanation/overview` — Conceptual overview of what ruckus is, the problem
  it solves, and how it fits into a firmware repository.
