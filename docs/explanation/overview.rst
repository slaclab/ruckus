Overview
========

ruckus is a firmware build framework developed at SLAC National Accelerator Laboratory. It
wraps Vivado and other EDA tools (Vitis HLS, GHDL, Cadence Genus, Synopsys DC) behind a
consistent GNU Make interface. Every firmware project that uses ruckus runs the same way:
the engineer types ``make bit`` (or another target) and ruckus drives the EDA tool from
project source description through to output artifacts.

Without ruckus, each FPGA firmware project would need its own Vivado project file, its own
TCL scripts to load sources and run synthesis and implementation, and its own CI configuration.
Because SLAC firmware projects share dozens of submodule libraries, maintaining all of that
per-project tooling would multiply the maintenance burden across every project.


The Problem ruckus Solves
--------------------------

FPGA firmware projects at SLAC depend on shared submodule libraries — ``surf``,
``lcls-timing-core``, ``axi-pcie-core``, and others. A given firmware target might include
HDL sources from three or four submodule trees, plus local sources in the target directory.
Integrating all of those into a single Vivado project requires explicitly enumerating every
source file and constraint in a form Vivado can read.

The conventional solution — maintaining a Vivado project file (``.xpr``) in git — creates
problems at scale. Vivado project files contain absolute paths, generated file lists, and
tool-internal state. Every time source files are added or changed, the ``.xpr`` diff is large
and hard to review. Merging ``.xpr`` changes across branches regularly causes conflicts that
require manual resolution inside Vivado's GUI.

ruckus replaces the ``.xpr`` file with a small ``ruckus.tcl`` script that describes the
project's sources declaratively, using ruckus-provided procedures (``loadSource``,
``loadConstraints``, ``loadIpCore``, etc.). The Vivado project is reconstructed from scratch
on every build by running these scripts inside Vivado's TCL interpreter. The project file is
never committed to git; only the ``ruckus.tcl`` manifest is.

Because each submodule library also carries its own ``ruckus.tcl``, the entire source tree
can be described by loading ruckus.tcl files recursively — each library knows how to add its
own files to the project. A top-level firmware target's ``ruckus.tcl`` only needs to
reference its immediate dependencies; ruckus traverses the rest.


How ruckus Works: The Makefile/TCL Hybrid
-------------------------------------------

ruckus uses a two-layer model: Make orchestrates the build process at the outer level, and
TCL runs inside Vivado at the inner level.

**Layer 1 — Make:** The engineer runs ``make bit`` from the firmware target directory. The
project's Makefile includes ``system_vivado.mk`` from the ruckus submodule, which provides
all build targets. ``system_vivado.mk`` drives two Vivado invocations in sequence:

1. ``vivado -source $(RUCKUS_DIR)/vivado/sources.tcl`` — assembles the Vivado project by
   recursively loading all ``ruckus.tcl`` files and adding their declared sources.
2. ``vivado -source $(RUCKUS_DIR)/vivado/build.tcl`` — runs synthesis, implementation,
   bitstream generation, and copies output artifacts to ``images/``.

**Layer 2 — TCL:** The ``ruckus.tcl`` file in each firmware target directory is the project
manifest. It uses ruckus-provided procedures to declare what belongs in the project. These
procedures run inside Vivado's TCL interpreter during the first Vivado invocation
(``sources.tcl``). The most common procedures are:

- ``loadSource`` — add HDL source files to the Vivado ``sources_1`` fileset
- ``loadConstraints`` — add XDC/TCL constraint files to the Vivado ``constrs_1`` fileset
- ``loadIpCore`` — import Vivado IP core (``.xci``) files
- ``loadRuckusTcl`` — recursively load another directory's ``ruckus.tcl``

A real-world example shows how compact this model is. The
``Simple-10GbE-RUDP-KCU105-Example`` project's Makefile is three lines:

.. code-block:: make

   export TOP_DIR = $(abspath $(PWD)/../..)
   include ../shared_version.mk
   include $(TOP_DIR)/submodules/ruckus/system_vivado.mk

The first line sets ``TOP_DIR`` to the ``firmware/`` root. The second line pulls in
``PRJ_VERSION``, ``PRJ_PART``, and the default build target from a shared version file. The
third line provides the entire ruckus build system.

The corresponding ``ruckus.tcl`` for that project is equally concise:

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
   loadSource -sim_only -dir "$::DIR_PATH/tb"
   set_property top {Simple10GbeRudpKcu105ExampleTb} [get_filesets sim_1]

This ``ruckus.tcl`` loads the ``surf`` library and the project's local shared code by
delegating to their own ``ruckus.tcl`` files, then adds the target's own HDL sources and
constraints. The ``$::DIR_PATH/hdl`` syntax ensures that paths are always anchored to the
directory containing this specific ``ruckus.tcl`` — not to Vivado's working directory.

The rest of this section explains the ``$::DIR_PATH`` mechanism that makes
``$::DIR_PATH/hdl`` work correctly, the full build pipeline, and the output artifact naming
convention.
