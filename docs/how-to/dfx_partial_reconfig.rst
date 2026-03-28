How to Use Dynamic Function eXchange (Partial Reconfiguration)
==============================================================

**Goal:** Build a partial reconfiguration design using Xilinx DFX, producing both a
static bitstream and a partial reconfiguration bitstream.

.. warning::

   DFX (Dynamic Function eXchange) requires a Vivado DFX license. The two-step build
   workflow described here is mandatory — the static design must be built and a routed
   DCP produced before the partial module build can begin.

Prerequisites
-------------

- A licensed Vivado installation with the DFX license enabled
- A static design with a reconfigurable module cell and a pblock defined in constraints
- A fully routed static DCP from a previous ``make bit`` run (produced in Step 1)

Two-Step Build Workflow
-----------------------

The DFX flow requires two separate build invocations. The partial module build cannot
proceed without the routed static DCP from Step 1.

Step 1: Build the Static Design
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Build the static design without setting any DFX variables:

.. code-block:: bash

   make bit

When the build completes, the output DCP is placed in the ``images/`` directory with
the standard ruckus naming pattern:

.. code-block::

   PROJECT-VERSION-TIME-USER-GITHASH_static.dcp

Record the full path to this file — it is required as the value of
``RECONFIG_CHECKPOINT`` in Step 2.

Step 2: Build the Partial Module
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Set the three DFX variables in your project ``Makefile`` **before** the ``include``
line, then rebuild:

.. code-block:: makefile

   export RECONFIG_CHECKPOINT = ../../images/StaticDesign-v1.0.0-20240101-user-abcd1234_static.dcp
   export RECONFIG_ENDPOINT   = u_PartialModule
   export RECONFIG_PBLOCK     = pblock_partial

   include $(TOP_DIR)/submodules/ruckus/system_vivado.mk

Then run:

.. code-block:: bash

   make bit

When ``RECONFIG_CHECKPOINT`` is set to a valid DCP path (not ``0``), the ruckus build
system automatically calls ``ImportStaticReconfigDcp`` before implementation. This
procedure:

- Opens the static DCP
- Makes the reconfigurable endpoint a black box
- Locks the static routing
- Reads the partial module synthesis DCP into the black box cell
- Runs DRC and saves the merged checkpoint

Partial bitstream artifacts are placed in ``$(IMAGES_DIR)/`` alongside the full
bitstream.

Key Variables
-------------

.. list-table::
   :widths: 25 10 65
   :header-rows: 1

   * - Variable
     - Default
     - Description
   * - ``RECONFIG_CHECKPOINT``
     - ``0``
     - Path to the static design's routed DCP. Setting this to a valid path enables DFX
       mode. The ``_static.dcp`` suffix is appended automatically by
       ``ExportStaticReconfigDcp`` during Step 1.
   * - ``RECONFIG_ENDPOINT``
     - ``0``
     - Cell name of the reconfigurable module (the black-box endpoint in the static
       design).
   * - ``RECONFIG_PBLOCK``
     - ``0``
     - Pblock name for partial bitstream export. Must match the pblock name defined in
       your constraints exactly.

See the :doc:`../reference/makefile_reference` for the complete variable reference.

Troubleshooting
---------------

**"DFX license not found"**
   DFX requires a separate Vivado DFX license. Contact your Xilinx/AMD account manager
   to enable the DFX feature in your license file.

**"DRC errors in ImportStaticReconfigDcp"**
   Ensure the static DCP is fully routed (not just synthesized) and that the pblock
   name in your constraints matches ``RECONFIG_PBLOCK`` exactly. Common causes: using
   a post-synthesis DCP instead of a post-route DCP, or a typo in the pblock name.

**"Cannot find RECONFIG_CHECKPOINT file"**
   Use an absolute path or a path relative to the project directory. Verify that Step 1
   completed successfully and that the ``_static.dcp`` file exists in ``images/``
   before starting Step 2.
