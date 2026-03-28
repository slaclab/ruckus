How to Generate a Vitis HLS IP Core
====================================

**Goal:** Build an HLS IP core from C/C++ sources and export it for use in a
Vivado project.

.. note::

   Two HLS backends are available. Use the **Legacy Vitis HLS** backend
   (``system_vitis_hls.mk``) if your project calls the ``vitis_hls`` binary (Vivado
   2020.x and earlier workflows). Use the **Vitis Unified HLS** backend
   (``system_vitis_unified_hls.mk``) if your project uses the ``vitis`` binary
   (Vivado 2022.x and later unified toolchain).

Legacy Vitis HLS
----------------

Prerequisites
~~~~~~~~~~~~~

- ``vitis_hls`` binary on PATH
- A ``sources.tcl`` file at ``$(PROJ_DIR)/sources.tcl`` defining HLS source files
- Makefile includes ``system_vitis_hls.mk``

Makefile include line:

.. code-block:: makefile

   include $(TOP_DIR)/submodules/ruckus/system_vitis_hls.mk

Steps
~~~~~

1. Create the project and set up sources:

   .. code-block:: bash

      make sources

2. Run the full HLS build (includes C-simulation by default):

   .. code-block:: bash

      make build

   To skip C-simulation for faster iteration:

   .. code-block:: bash

      SKIP_CSIM=1 make build

   To skip co-simulation as well:

   .. code-block:: bash

      SKIP_CSIM=1 SKIP_COSIM=1 make build

3. Open the Vitis HLS GUI to inspect results:

   .. code-block:: bash

      make gui

**Output:** IP core placed in ``$(PROJ_DIR)/ip/``

Available Targets
~~~~~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - Target
     - Action
   * - ``make sources``
     - Create project and run source setup (skips C-sim: ``SKIP_CSIM=1``)
   * - ``make build``
     - Full HLS build including C-simulation (unless ``SKIP_CSIM=1``)
   * - ``make interactive``
     - Open ``vitis_hls`` in interactive TCL mode
   * - ``make gui``
     - Open Vitis HLS GUI (``vitis_hls -p $(PROJECT)_project``)
   * - ``make clean``
     - Delete the build directory

Key Variables
~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 22 15 63

   * - Variable
     - Default
     - Description
   * - ``SKIP_CSIM``
     - ``0``
     - Set to ``1`` to skip C-simulation.
   * - ``SKIP_COSIM``
     - ``0``
     - Set to ``1`` to skip co-simulation.
   * - ``SKIP_DCP``
     - ``1``
     - DCP generation skipped by default; set to ``0`` to enable.
   * - ``HDL_TYPE``
     - ``verilog``
     - Output HDL: ``verilog`` or ``vhdl``.
   * - ``HLS_SIM_TOOL``
     - ``xsim``
     - Co-simulation tool: ``vcs``, ``xsim``, ``modelsim``, ``ncsim``, ``riviera``.
   * - ``ALL_XIL_FAMILY``
     - ``0``
     - Set to ``1`` to target all Xilinx FPGA families in ``component.xml``.
   * - ``EXPORT_VENDOR``
     - ``SLAC``
     - IP vendor name in ``component.xml``.
   * - ``EXPORT_VERSION``
     - ``1.0``
     - IP version string.

See the :doc:`../reference/makefile_reference` for additional variable details.

Vitis Unified HLS
-----------------

Prerequisites
~~~~~~~~~~~~~

- ``vitis`` binary on PATH (Vivado 2022.x or later unified toolchain)
- An ``hls_config.cfg`` file at ``$(PROJ_DIR)/hls_config.cfg``
- Makefile includes ``system_vitis_unified_hls.mk``

Makefile include line:

.. code-block:: makefile

   include $(TOP_DIR)/submodules/ruckus/system_vitis_unified_hls.mk

Steps
~~~~~

1. Create the project:

   .. code-block:: bash

      make proj

2. Run the full build:

   .. code-block:: bash

      make build

   If ``vivado.syn_dcp=1`` is set in ``hls_config.cfg``, the build also generates
   and renames a DCP file automatically.

3. Run C-simulation only (faster iteration):

   .. code-block:: bash

      make csim

4. Open the Vitis IDE to inspect results:

   .. code-block:: bash

      make gui

Available Targets
~~~~~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - Target
     - Action
   * - ``make proj``
     - Create the project (``vitis -s create_proj.py``)
   * - ``make build``
     - Full build; if ``vivado.syn_dcp=1`` in ``hls_config.cfg``, also renames DCP
   * - ``make csim``
     - C-simulation only (``vitis -s build.py --csim``)
   * - ``make interactive``
     - Open ``vitis -i`` interactive mode
   * - ``make gui``
     - Open Vitis IDE (``vitis -w $(OUT_DIR)``)
   * - ``make clean``
     - Delete the build directory

Key Variables
~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 22 15 63

   * - Variable
     - Default
     - Description
   * - ``SKIP_CSIM``
     - ``0``
     - Set to ``1`` to skip C-simulation.
   * - ``SKIP_COSIM``
     - ``0``
     - Set to ``1`` to skip co-simulation.
   * - ``ALL_XIL_FAMILY``
     - ``1``
     - All Xilinx FPGA families targeted by default (differs from legacy default of ``0``).
   * - ``OUT_DIR``
     - ``$(PROJ_DIR)/build``
     - Build output directory (project-scoped; differs from legacy).

.. note::

   ``OUT_DIR`` in the Unified backend defaults to ``$(PROJ_DIR)/build`` — the output
   is scoped to each project directory. In the legacy backend, the output directory is
   within ``$(TOP_DIR)/build`` at the repository root. Keep this in mind when looking
   for generated artifacts.

Troubleshooting
---------------

**"vitis_hls: command not found"**
   Source your Vivado or Vitis settings script:

   .. code-block:: bash

      source /path/to/Vivado/settings64.sh
      # or for the unified toolchain:
      source /path/to/Vitis/settings64.sh

**"vitis: command not found"**
   The Unified backend requires the Vitis unified toolchain (2022.x or later). Source
   the Vitis settings script and verify with:

   .. code-block:: bash

      vitis --version

**C-simulation fails with compilation errors**
   Set ``CFLAGS`` for additional compiler flags:

   .. code-block:: bash

      CFLAGS="-I/path/to/include" make build

**DCP not generated by legacy backend**
   ``SKIP_DCP`` defaults to ``1``. Enable DCP output with:

   .. code-block:: bash

      SKIP_DCP=0 make build
