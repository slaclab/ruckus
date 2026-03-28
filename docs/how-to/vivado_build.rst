How to Run a Vivado FPGA Build
==============================

**Goal:** Run synthesis, implementation, and bitstream generation for an existing
ruckus-based Vivado project.

Prerequisites
-------------

Before running a build, ensure you have:

- Linux operating system
- Licensed Vivado installation (version ≥ 2018.3 recommended)
- A ruckus-based project with a ``Makefile``, ``ruckus.tcl``, and ``images/`` directory
- ``PRJ_PART`` set in the project ``Makefile`` (FPGA part number, e.g.,
  ``xcku15p-ffva1760-2-e``)
- Build directory at ``$(TOP_DIR)/build/`` (see Step 1)

Steps
-----

Step 1: Create the build directory (one-time setup)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Vivado build pipeline writes all intermediate files to ``$(TOP_DIR)/build/``.
Create this directory before running any build target. A symlink to a fast scratch
location works equally well:

.. code-block:: bash

   mkdir $(TOP_DIR)/build
   # or symlink a fast scratch location:
   ln -s /scratch/build $(TOP_DIR)/build

.. note::

   ``TOP_DIR`` defaults to ``$(abspath $(PROJ_DIR)/../..)``, which is two directories
   above your project directory. This is the root of your firmware repository.

Step 2: Set the FPGA part number
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If ``PRJ_PART`` is not already defined in your project ``Makefile``, add it before the
``include`` line:

.. code-block:: makefile

   ifndef PRJ_PART
   export PRJ_PART = xcku15p-ffva1760-2-e
   endif

   include $(TOP_DIR)/submodules/ruckus/system_vivado.mk

.. note::

   ``PROJECT`` is auto-detected from the directory name (``$(notdir $(PWD))``). You do
   not need to set it unless you want a different project name.

Step 3: Run the full build
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

   make bit

``make bit``, ``make mcs``, and ``make pdi`` all invoke the same build rule. Use
whichever matches your desired output format. The generated artifacts are placed in
``images/`` with the naming pattern:

.. code-block:: text

   PROJECT-VERSION-TIME-USER-GITHASH.bit
   PROJECT-VERSION-TIME-USER-GITHASH.mcs
   PROJECT-VERSION-TIME-USER-GITHASH.pdi   (Versal only)

Step 4: Open the project in the Vivado GUI (optional)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After a build completes, open the project to inspect timing, utilization, and log
reports:

.. code-block:: bash

   make gui

Available Targets
-----------------

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Target
     - Action
   * - ``make bit``
     - Full synthesis + implementation + ``.bit`` bitstream
   * - ``make mcs``
     - Full synthesis + implementation + ``.mcs`` flash image
   * - ``make pdi``
     - Full synthesis + implementation + ``.pdi`` (Versal devices)
   * - ``make syn``
     - Synthesis only (sets ``SYNTH_ONLY=1``)
   * - ``make dcp``
     - Synthesis to DCP checkpoint (sets ``SYNTH_DCP=1``)
   * - ``make gui``
     - Open existing project in Vivado GUI
   * - ``make sources``
     - Source setup only (creates ``.xpr``); no build
   * - ``make interactive``
     - Open Vivado in TCL interactive mode
   * - ``make xsim``
     - Vivado XSIM simulation
   * - ``make vcs``
     - Generate VCS simulation scripts
   * - ``make msim``
     - ModelSim/Questa simulation
   * - ``make batch``
     - Vivado batch mode within existing project
   * - ``make release``
     - Tag and push firmware release to GitHub
   * - ``make release_files``
     - Generate release files without GitHub push
   * - ``make clean``
     - Delete ``build/$(PROJECT)`` directory

Key Variables
-------------

.. list-table::
   :header-rows: 1
   :widths: 20 15 65

   * - Variable
     - Default
     - Description
   * - ``PRJ_PART``
     - (none)
     - FPGA part number. Must be set by user.
   * - ``PROJECT``
     - ``$(notdir $(PWD))``
     - Project name; auto-detected from directory.
   * - ``TOP_DIR``
     - ``$(abspath $(PROJ_DIR)/../..)``
     - Firmware repository root.
   * - ``GEN_BIT_IMAGE``
     - ``1``
     - Generate ``.bit`` file (set to ``0`` to skip).
   * - ``GEN_MCS_IMAGE``
     - ``1``
     - Generate ``.mcs`` flash image (set to ``0`` to skip).
   * - ``GEN_PDI_IMAGE``
     - ``1``
     - Generate ``.pdi`` file for Versal (set to ``0`` to skip).

See the :doc:`../reference/makefile_reference` for the complete variable reference
including timing override and git bypass variables.

Troubleshooting
---------------

**"Build directory missing!" error**
   Create ``$(TOP_DIR)/build/`` or symlink it to a scratch location:

   .. code-block:: bash

      mkdir $(TOP_DIR)/build

**"PRJ_PART is not set" error**
   Add ``export PRJ_PART = <your-part>`` to your project ``Makefile`` before the
   ``include`` line (see Step 2).

**Timing violations fail the build**
   See the timing override variables (``TIG``, ``TIG_SETUP``, ``TIG_HOLD``) in the
   :doc:`../reference/makefile_reference`.

**Vivado not found**
   Ensure Vivado is on your PATH. Source the settings script if needed:

   .. code-block:: bash

      source /path/to/Vivado/2023.1/settings64.sh
