How to Build a Vitis AI Engine (AIE) Graph
============================================

**Goal:** Compile an AI Engine graph from C++ sources, package the resulting
``libadf.a`` against a Vivado-built ``.xsa`` into a dynamic PDI, and (optionally)
deploy the PDI + matching device-tree overlay to a Versal/PetaLinux board.

.. note::

   This backend (``system_vitis_unified_aie.mk``) requires the **Vitis 2025.1 or
   newer** unified toolchain. It is driven by the Vitis Python API
   (``vitis -s <script>.py``) — mirroring :doc:`vitis_hls`'s unified backend so
   the same workspace can be opened batch-style for CI and GUI-style for
   debugging.

Prerequisites
-------------

- ``vitis`` binary on PATH (Vitis 2025.1+ unified toolchain)
- ``XILINX_VITIS`` environment variable exported (the Makefile asserts on this
  at parse time)
- A Vivado-built ``.xsa`` from the companion target (required by ``make package``
  only — not by ``make proj`` / ``make build``)
- An ``aie_config.cfg`` at ``$(PROJ_DIR)/aie_config.cfg`` (same convention as
  the unified HLS flow's ``hls_config.cfg``)
- Makefile includes ``system_vitis_unified_aie.mk``

Project Layout
--------------

ruckus's standard convention is to keep the Vivado target and the AIE
component in **separate** project directories (mirroring how Vitis HLS targets
are split out from Vivado targets). A typical tree:

.. code-block:: none

   firmware/
     submodules/ruckus/
     shared/
       <AieProject>/
         Makefile               <- includes system_vitis_unified_aie.mk
         aie_config.cfg         <- [aie] pl-freq=…, Xpreproc=…
         aie/
           graph.cpp
           graph.h
           kernels/
             *.cc *.h
     targets/
       <VivadoTarget>/
         Makefile               <- includes system_vivado.mk; produces the .xsa

The AIE project is fully self-contained: ``make package`` writes the final
dynamic PDI to ``$(PROJ_DIR)/ip/`` (matching the HLS convention of writing
deliverables into ``ip/``) so the Vivado target does not need to know where
the AIE archetype lives on disk.

Makefile include line:

.. code-block:: makefile

   include $(TOP_DIR)/submodules/ruckus/system_vitis_unified_aie.mk

A minimal consumer ``Makefile`` looks like:

.. code-block:: makefile

   target: build

   export AIE_SOURCES = \
       $(abspath $(CURDIR)/aie) \
       $(abspath $(CURDIR)/aie/kernels)

   export AIE_TOP_LEVEL_FILE = graph.cpp

   # Wildcard picks up the xpfm the active Vitis release ships
   # (xilinx_vek280_base_202510_1 in 2025.1, _202520_1 in 2025.2, …)
   export AIE_PLATFORM := $(firstword $(wildcard \
       $(XILINX_VITIS)/base_platforms/xilinx_vek280_base_*/xilinx_vek280_base_*.xpfm))

   AIE_BOARD_IP ?= root@10.0.0.191

   include ../../submodules/ruckus/system_vitis_unified_aie.mk

Steps
-----

1. Create the workspace and AIE component:

   .. code-block:: bash

      make proj

   Idempotent — re-running is a cheap no-op if the component already exists,
   so ``make build`` and ``make gui`` declare ``proj`` as a prereq freely.

2. Build the graph for hardware:

   .. code-block:: bash

      make build

   Emits ``libadf.a`` under ``$(OUT_DIR)/$(PROJECT)/build/hw/``.

3. Or run the x86 simulator instead of the AIE compiler:

   .. code-block:: bash

      make x86sim

4. Wrap ``libadf.a`` + the Vivado ``.xsa`` into a dynamic PDI:

   .. code-block:: bash

      make AIE_XSA_INPUT=<absolute-path-to>.xsa package

   ``AIE_XSA_INPUT`` is supplied on the command line because the Vivado-side
   ``IMAGENAME`` embeds ``BUILD_TIME``, so the ``.xsa`` filename produced by
   an earlier Vivado run is not predictable from inside the AIE archetype.

   The package step's output is ``$(AIE_PDI)`` —
   ``$(PROJ_DIR)/ip/$(PROJECT)_aie_dynamic.pdi`` by default.

5. Deploy the PDI + matching DTBO to a Versal/PetaLinux board:

   .. code-block:: bash

      make AIE_DTBO=<absolute-path-to>.dtbo \
           AIE_BOARD_IP=root@<board-ip> \
           program

   The default deploy helper (``$(RUCKUS_DIR)/vitis/aie/program.sh``) scp's
   the PDI and DTBO to ``/boot/{pl.pdi,pl.dtbo}``, reboots the board, waits
   for ssh liveness, then verifies ``/sys/class/fpga_manager/fpga0/state``
   reports ``operating``.

6. Open the same workspace interactively in the Vitis IDE:

   .. code-block:: bash

      make gui

   Or drop into a Python REPL with the ``vitis`` module pre-loaded:

   .. code-block:: bash

      make interactive

**Output:** dynamic PDI at ``$(PROJ_DIR)/ip/$(PROJECT)_aie_dynamic.pdi``.

Available Targets
-----------------

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - Target
     - Action
   * - ``make proj``
     - Create the workspace + AIE component (``vitis -s create_proj.py``).
       No-op if the component already exists.
   * - ``make build``
     - Build for the ``hw`` target (``vitis -s build.py``). Emits
       ``libadf.a`` under ``$(OUT_DIR)/$(PROJECT)/build/hw/``.
   * - ``make x86sim``
     - Build for the x86 simulator (``vitis -s build.py --x86sim``).
   * - ``make package``
     - Wrap ``libadf.a`` + ``$(AIE_XSA_INPUT)`` into the dynamic PDI
       (``bash package.sh``). Uses ``v++ --package`` (primary) or
       ``bootgen`` (fallback when ``USE_BOOTGEN_FALLBACK=1``).
   * - ``make program``
     - Invoke ``$(AIE_PROGRAM_SCRIPT)`` to deploy ``$(AIE_PDI)`` and
       ``$(AIE_DTBO)`` to ``$(AIE_BOARD_IP)``.
   * - ``make gui``
     - Open the same workspace in the Vitis Unified IDE
       (``vitis -w $(OUT_DIR)``).
   * - ``make interactive``
     - Drop into a Python REPL with the ``vitis`` module loaded
       (``vitis -i``).
   * - ``make test``
     - Print all AIE-related environment variables — useful for
       diagnosing Makefile variable resolution.
   * - ``make clean``
     - Delete the build directory (``rm -rf $(OUT_DIR)``).

Caller Contract
---------------

The consuming target's AIE Makefile must define these **before** including
``system_vitis_unified_aie.mk``:

**Exactly one of:**

- :envvar:`AIE_PLATFORM` — absolute path to the platform ``.xpfm``. Use this
  for dev boards with an AMD-shipped xpfm
  (e.g. ``$(XILINX_VITIS)/base_platforms/xilinx_vek280_base_*/...xpfm``).
- :envvar:`AIE_PART` — Versal device ID. Use this for custom AIE boards
  without a shipped xpfm (e.g. ``xcve2802-vsvh1760-2MP-e-S``). The PL clock
  hint comes from the cfg's ``pl-freq=`` line instead of the xpfm.

Plus:

- :envvar:`AIE_SOURCES` — whitespace-separated list of source paths. Each
  entry is either:

  - a **file** path → imports just that file, **or**
  - a **directory** path → imports every ``.cpp`` / ``.cc`` / ``.h`` /
    ``.hpp`` file in that directory (**non-recursive** — subdirectories are
    not walked).

  All imports land **flat** at the component root. This mirrors the trust
  model of HLS's ``hls_config.cfg`` (``syn.file=`` / ``tb.file=``) — the
  application owns the source list; ruckus does no Python-side recursive
  globbing.

  Mix local and shared sources freely:

  .. code-block:: makefile

     SHARED_AIE := $(TOP_DIR)/submodules/aie-common-kernels
     export AIE_SOURCES = \
         $(CURDIR)/aie \
         $(CURDIR)/aie/kernels \
         $(SHARED_AIE)/util.cc

  The first entry pulls in everything directly under ``aie/``; the second
  pulls in everything under ``aie/kernels/``; the third names one file from
  a submodule.

- :envvar:`AIE_TOP_LEVEL_FILE` — top-level graph file **basename** only
  (e.g. ``graph.cpp``), because all imports land flat at the component root.

And on the command line (recipe-time, not parse-time):

- :envvar:`AIE_XSA_INPUT` — absolute path to the Vivado-built ``.xsa``,
  required by the ``package`` target.
- :envvar:`AIE_DTBO` — absolute path to the matching ``.dtbo``, required by
  the ``program`` target.
- :envvar:`AIE_BOARD_IP` — ``user@host`` for the ``program`` target.
  Forwarded to ``$(AIE_PROGRAM_SCRIPT)`` as the ``-i`` flag.

aie_config.cfg
--------------

The consuming Makefile must also provide an ``aie_config.cfg`` file at
``$(PROJ_DIR)/aie_config.cfg`` — **next to the Makefile itself**. This
location is hardcoded (not configurable), mirroring the unified HLS flow's
``hls_config.cfg`` convention. The cfg's ``[aie]`` section carries
``pl-freq=`` and any other ``aiecompiler`` options:

.. code-block:: ini

   [aie]
   pl-freq=250
   xlopt=1
   verbose=true
   # Xpreproc=-DMY_MACRO=value

When ``AIE_PART`` is in use (no xpfm), the ``pl-freq=`` line is the **only**
hint Vitis has for the PL clock frequency, so it must be set.

Customising the Deploy Step
---------------------------

``make program`` invokes ``$(AIE_PROGRAM_SCRIPT)``, which defaults to
``$(RUCKUS_DIR)/vitis/aie/program.sh`` — a generic Versal/PetaLinux deploy
helper that:

1. Pre-flights the PDI/DTBO paths and ssh reachability
2. Refuses to upload a ``*_static.pdi`` filename (which belongs in
   ``BOOT.BIN``, not as a runtime overlay)
3. ``scp``'s ``$(AIE_PDI)`` → ``$(AIE_BOARD_IP):/boot/pl.pdi`` and
   ``$(AIE_DTBO)`` → ``$(AIE_BOARD_IP):/boot/pl.dtbo``
4. Reboots the board (skippable with ``-r``)
5. Waits for ssh liveness, then verifies
   ``/sys/class/fpga_manager/fpga0/state == operating``

Projects that need richer verification (application-specific systemd
checks, ``xsdb`` readout, etc.) override the default by pointing
:envvar:`AIE_PROGRAM_SCRIPT` at their own helper. The override must accept
the same flag contract:

.. list-table::
   :header-rows: 1
   :widths: 18 82

   * - Flag
     - Meaning
   * - ``-p <path>``
     - Runtime PDI to upload (required)
   * - ``-d <path>``
     - Matching device-tree overlay (required)
   * - ``-i <user@host>``
     - Board target (forwarded from ``$(AIE_BOARD_IP)`` when set)

The default helper additionally accepts ``-r`` (dry-run: skip reboot) and
``-h`` (show help); custom helpers may ignore those if not relevant. The
helper's exit codes follow the convention 0 = success, 1 = local pre-flight
failed, 2 = scp/ssh failure, 3 = post-reboot verification failed.

Key Variables
-------------

.. list-table::
   :header-rows: 1
   :widths: 26 22 52

   * - Variable
     - Default
     - Description
   * - ``OUT_DIR``
     - ``$(PROJ_DIR)/build``
     - Vitis workspace root. The AIE component lives at
       ``$(OUT_DIR)/$(PROJECT)/``.
   * - ``AIE_IP_DIR``
     - ``$(PROJ_DIR)/ip``
     - Final deliverable directory (matches the HLS convention).
   * - ``AIE_PDI``
     - ``$(AIE_IP_DIR)/$(PROJECT)_aie_dynamic.pdi``
     - Output dynamic PDI path written by ``make package``.
   * - ``AIE_PKG_DIR``
     - ``$(OUT_DIR)/aie_package``
     - Scratch directory used by the package step.
   * - ``USE_BOOTGEN_FALLBACK``
     - ``0``
     - Set to ``1`` to package via ``bootgen`` instead of ``v++ --package``.
   * - ``VPP_LOG``
     - ``$(OUT_DIR)/vpp_package.log``
     - Log file path for the ``v++ --package`` invocation.
   * - ``AIE_PROGRAM_SCRIPT``
     - ``$(RUCKUS_DIR)/vitis/aie/program.sh``
     - Deploy helper invoked by ``make program``. Override for project-
       specific verification.

See :doc:`../reference/makefile_reference` for the full AIE variable
reference.

Troubleshooting
---------------

**"XILINX_VITIS not set"**
   The Makefile hard-fails at parse time if the Vitis environment was not
   sourced. Source the Vitis settings script (or a SLAC-local wrapper like
   ``setup_env_slac.sh``):

   .. code-block:: bash

      source /path/to/Vitis/settings64.sh
      vitis --version    # confirm 2025.1 or newer

**"Define either AIE_PLATFORM or AIE_PART"**
   Set exactly one. ``AIE_PLATFORM`` for dev boards with an AMD-shipped
   ``.xpfm``; ``AIE_PART`` for custom Versal AIE boards without one.

**"AIE_XSA_INPUT not set"**
   Only the ``package`` target requires the ``.xsa``. Pass it on the
   command line — do not bake an ``IMAGENAME``-derived path into the
   Makefile, because the upstream Vivado ``IMAGENAME`` embeds
   ``BUILD_TIME`` and is not predictable from this archetype.

**"AIE_DTBO not set"**
   ``make program`` requires the matching device-tree overlay path.
   Typically lives next to the Vivado ``.xsa`` under the upstream target's
   ``images/`` directory.

**"Refusing to upload static PDI as runtime overlay"**
   The default deploy helper refuses any ``-p`` argument containing
   ``_static`` in the filename. ``<name>_static.pdi`` is the ``BOOT.BIN``
   half of a segmented-configuration build (see
   :doc:`segmented_configuration`); the runtime overlay is
   ``<name>_aie_dynamic.pdi`` (or ``<name>_dynamic.pdi`` for a
   non-AIE segmented build). Point ``-p`` at the dynamic half.

**``v++ --package`` fails on packaging**
   As a fallback path, set ``USE_BOOTGEN_FALLBACK=1`` to package via
   ``bootgen`` instead. The two paths produce a functionally equivalent
   dynamic PDI for the AIE-overlay case.

**Subdirectory headers go missing from the component**
   ``AIE_SOURCES`` directory entries are **non-recursive** and all imports
   land flat at the component root. If your graph ``#include``\ s a header
   via a subdirectory path (e.g. ``#include "kernels/foo.h"``), either
   rewrite the include as a bare basename or add ``aie/kernels`` as a
   separate ``AIE_SOURCES`` entry so the header lands at the root.
