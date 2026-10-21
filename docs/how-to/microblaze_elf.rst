How to Integrate a MicroBlaze ELF Binary
========================================

**Goal:** Build a MicroBlaze C/C++ application, compile it to an ELF binary, and embed
it into the Vivado bitstream.

.. note::

   The ruckus MicroBlaze flow auto-detects whether Vitis (Vivado 2019.2+) or the
   legacy Xilinx SDK (Vivado 2019.1 and older) is available. The same ``make elf``
   command works with both tools. This guide focuses on the Vitis path; the SDK path
   is functionally equivalent.

Prerequisites
-------------

- A Vivado installation with MicroBlaze support
- Vitis (Vivado 2019.2+) or Xilinx SDK (Vivado 2019.1) available on ``PATH``
- A completed Vivado block design with a MicroBlaze processor instance named by
  ``EMBED_PROC`` (default: ``microblaze_0``)
- C/C++ source directory set via ``VITIS_SRC_PATH`` in the project Makefile

Makefile Setup
--------------

Add these lines to your project ``Makefile`` **before** the ``include`` line:

.. code-block:: makefile

   export EMBED_PROC     = microblaze_0
   export VITIS_SRC_PATH = $(PROJ_DIR)/firmware/src

   include $(TOP_DIR)/submodules/ruckus/system_vivado.mk

Steps
-----

1. **Open the Vitis/SDK IDE** to develop your C/C++ application:

   .. code-block:: bash

      make vitis    # or: make sdk

   The two targets are aliases: both open the Vitis IDE when the ``vitis`` binary is
   on ``PATH`` and fall back to Xilinx SDK (``xsdk``) otherwise. The Vitis workspace
   is ``$(OUT_DIR)/$(PROJECT)_project.vitis`` (``.sdk`` for the SDK flow). Use the
   IDE to write and debug your C/C++ application before building the ELF.

2. **Build the ELF and embed it into the bitstream:**

   .. code-block:: bash

      make elf

   The ``make elf`` target automatically:

   - Opens the existing Vivado project
   - Exports the hardware platform (``$(OUT_DIR)/$(PROJECT).xsa``)
   - Creates a Vitis application project (``app_0``) scoped to ``$(EMBED_PROC)``
     (through XSCT for Vitis 2025.x and older, or the Vitis Python API for
     Vitis 2026.1 and newer)
   - Builds the ELF and copies it to ``$(VITIS_ELF)``
   - Adds the ELF to Vivado sources, scoped to the MicroBlaze instance
   - Resets ``impl_1`` and reruns ``write_bitstream`` to embed the ELF
   - Calls ``CreateFpgaBit`` (``CreateVersalOutputs`` on Versal) to produce the
     final artifact

Custom Hook
-----------

If ``vitis.tcl`` exists in your project's ``vivado/`` directory
(``$(VIVADO_DIR)/vitis.tcl``), it replaces the entire Vitis project creation, ELF
build, and bitstream rebuild. Use this for
non-standard BSP configurations or multi-processor designs.

Key Variables
-------------

.. list-table::
   :widths: 22 15 63
   :header-rows: 1

   * - Variable
     - Default
     - Description
   * - ``EMBED_PROC``
     - ``microblaze_0``
     - MicroBlaze processor instance name as it appears in the block design. Must match
       exactly.
   * - ``VITIS_SRC_PATH``
     - (user-set)
     - Path to the C/C++ source directory for the application. Required before running
       ``make elf``.
   * - ``VITIS_LIB``
     - ``$(MODULES)/surf/xilinx/general/sdk/common``
     - BSP library include paths. Override to add custom BSP libraries to the build.

Troubleshooting
---------------

**"vitis: command not found"**
   Source the Vitis settings script before running the build:

   .. code-block:: bash

      source /path/to/Vitis/settings64.sh

**"processor not found in block design"**
   Verify that ``EMBED_PROC`` matches the processor instance name exactly as it appears
   in the Vivado block design. Open the block design in Vivado and check the cell name.

**"xsct: command not found"**
   ``xsct`` ships with Vitis 2025.x and older (Vitis 2026.1 and newer use the Vitis
   Python API instead and do not need it). If it is missing, verify that the full Vitis installation
   (not just Vivado) is installed and that its ``settings64.sh`` is sourced. The
   ``xsct`` binary is in the Vitis ``bin/`` directory, not the Vivado ``bin/``
   directory.
