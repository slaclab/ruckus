How to Build a Vitis AI Engine (AIE) Graph
============================================

**Goal:** Compile an AI Engine graph from C++ sources, package the resulting
``libadf.a`` against a Vivado-built ``.xsa`` into a dynamic PDI with a matching
``partition.conf`` sidecar, and (optionally) deploy the pair to ``/boot/aie/``
on a Versal/PetaLinux board.

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

The AIE project is fully self-contained: ``make`` writes the final
deliverable pair — ``$(PROJECT).pdi`` + ``$(PROJECT).partition.conf`` — to
``$(PROJ_DIR)/ip/`` (matching the HLS convention of writing deliverables
into ``ip/``) so the Vivado target does not need to know where the AIE
archetype lives on disk.

Makefile include line:

.. code-block:: makefile

   include $(TOP_DIR)/submodules/ruckus/system_vitis_unified_aie.mk

A minimal consumer ``Makefile`` looks like:

.. code-block:: makefile

   export AIE_SOURCES = \
       $(abspath $(CURDIR)/aie) \
       $(abspath $(CURDIR)/aie/kernels):kernels

   export AIE_TOP_LEVEL_FILE = graph.cpp

   # Wildcard picks up the xpfm the active Vitis release ships
   # (xilinx_vek280_base_202510_1 in 2025.1, _202520_1 in 2025.2, …)
   export AIE_PLATFORM := $(firstword $(wildcard \
       $(XILINX_VITIS)/base_platforms/xilinx_vek280_base_*/xilinx_vek280_base_*.xpfm))

   # Directory of Vivado-built .xsa images; `make package` auto-selects
   # the newest by the BUILD_TIME timestamp encoded in the filename.
   export VIVADO_XSA_DIR = $(abspath $(CURDIR)/../../targets/<VivadoTarget>/images)

   AIE_BOARD_IP ?= root@10.0.0.191

   include ../../submodules/ruckus/system_vitis_unified_aie.mk

No ``target:`` rule is needed — the include provides the default chain
``target: package partition_conf`` (build → package → emit the
``partition.conf`` sidecar), so a bare ``make`` produces the full
``ip/`` deliverable pair.

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

      make package

   The ``.xsa`` is auto-discovered from :envvar:`VIVADO_XSA_DIR` (set in
   the consuming Makefile): the newest ``.xsa`` wins, by the ``BUILD_TIME``
   timestamp encoded in the image filename. A directory is used because the
   Vivado-side ``IMAGENAME`` embeds ``BUILD_TIME``, so the ``.xsa`` filename
   produced by an earlier Vivado run is not predictable from inside the AIE
   archetype.

   The package step's output is ``$(AIE_PDI)`` —
   ``$(PROJ_DIR)/ip/$(PROJECT).pdi`` by default. The PDI is a CDO-only
   partial PDI loaded at runtime through
   ``/sys/class/fpga_manager/fpga0/firmware``; no device-tree overlay is
   part of the deliverable (the ``ai_engine`` DT node is already live from
   the design's ``pl.dtbo``).

5. Emit the ``partition.conf`` sidecar for the ``/boot/aie/`` runtime:

   .. code-block:: bash

      make partition_conf

   Extracts the AIE partition geometry (``PARTITION_ID`` + ``UID``) from
   the Vitis-emitted ``aie_partition.json`` and writes
   ``$(PROJ_DIR)/ip/$(PROJECT).partition.conf`` — consumed on-board by
   ``aie-partition-init``. A bare ``make`` runs steps 2, 4, and 5 in one go
   (default chain ``target: package partition_conf``).

6. Deploy the pdi+conf pair to a Versal/PetaLinux board:

   .. code-block:: bash

      make AIE_BOARD_IP=root@<board-ip> program

   The default deploy helper (``$(RUCKUS_DIR)/vitis/aie/program.sh``) scp's
   the PDI and ``partition.conf`` to
   ``/boot/aie/<name>.{pdi,partition.conf}``, reboots the board, waits for
   ssh liveness, then verifies the startup-app-init boot loop loaded the
   AIE (journal ``AIE load:`` line + ``fpga_manager`` dmesg write), that
   ``aie-partition-init@<name>.service`` is active, and that
   ``/sys/class/aie`` exists.

7. Open the same workspace interactively in the Vitis IDE:

   .. code-block:: bash

      make gui

   Or drop into a Python REPL with the ``vitis`` module pre-loaded:

   .. code-block:: bash

      make interactive

**Output:** deliverable pair at ``$(PROJ_DIR)/ip/$(PROJECT).pdi`` +
``$(PROJ_DIR)/ip/$(PROJECT).partition.conf``.

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
     - Wrap ``libadf.a`` + the newest ``.xsa`` in ``$(VIVADO_XSA_DIR)``
       into the dynamic PDI (``bash package.sh``). Uses ``v++ --package``
       (primary) or ``bootgen`` (fallback when ``USE_BOOTGEN_FALLBACK=1``).
   * - ``make partition_conf``
     - Invoke ``$(AIE_PARTITION_CONF_SCRIPT)`` to extract the AIE
       partition geometry from the Vitis-emitted ``aie_partition.json``
       and write ``ip/$(PROJECT).partition.conf``. Part of the default
       ``target`` chain.
   * - ``make program``
     - Invoke ``$(AIE_PROGRAM_SCRIPT)`` to deploy ``$(AIE_PDI)`` (and the
       ``partition.conf`` sidecar) to ``$(AIE_BOARD_IP)``.
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

- :envvar:`AIE_SOURCES` — whitespace-separated list of ``path[:dest_subdir]``
  entries. The ``path`` half is either:

  - a **file** path → imports just that file, **or**
  - a **directory** path → imports every ``.cpp`` / ``.cc`` / ``.h`` /
    ``.hpp`` file in that directory (**non-recursive** — subdirectories are
    not walked).

  Without ``:dest_subdir``, imports land **flat** at the component root.
  With ``:dest_subdir``, they import into ``<component>/<dest_subdir>/`` —
  needed for the AMD-canonical ``kernels/`` layout where ``graph.h`` does
  ``adf::source(loop) = "kernels/loopback.cc";``. ``include=`` paths for
  the component root and every ``dest_subdir`` are auto-merged into the
  generated cfg, so headers in those directories resolve without manual
  ``Xpreproc=-I`` lines. This mirrors the trust model of HLS's
  ``hls_config.cfg`` (``syn.file=`` / ``tb.file=``) — the application owns
  the source list; ruckus does no Python-side recursive globbing.

  Mix local and shared sources freely:

  .. code-block:: makefile

     SHARED_AIE := $(TOP_DIR)/submodules/aie-common-kernels
     export AIE_SOURCES = \
         $(CURDIR)/aie \
         $(CURDIR)/aie/kernels:kernels \
         $(SHARED_AIE)/util.cc

  The first entry pulls in everything directly under ``aie/`` (flat at the
  component root); the second pulls in everything under ``aie/kernels/``
  into the component's ``kernels/`` subdirectory; the third names one file
  from a submodule.

- :envvar:`AIE_TOP_LEVEL_FILE` — top-level graph file **basename** only
  (e.g. ``graph.cpp``), because the top-level graph imports at the
  component root.

- :envvar:`VIVADO_XSA_DIR` — directory containing the Vivado-built ``.xsa``
  images, required by the ``package`` target (asserted at recipe time, not
  parse time). The newest ``.xsa`` — by the ``BUILD_TIME`` timestamp encoded
  in the image filename — is selected automatically; the build hard-errors
  if the directory contains no ``.xsa``.

And on the command line (recipe-time, not parse-time):

- :envvar:`AIE_BOARD_IP` — ``user@host`` for the ``program`` target.
  Forwarded to ``$(AIE_PROGRAM_SCRIPT)`` as the ``-i`` flag.
- :envvar:`AIE_CONF` — optional override for the ``partition.conf`` sidecar
  path, forwarded to ``$(AIE_PROGRAM_SCRIPT)`` as the ``-c`` flag when set.
  When unset the helper auto-derives it from the PDI directory as
  ``<pdi-dir>/<name>.partition.conf`` — which matches the ``ip/`` pair
  written by the default ``target`` chain, so most consumers never set it.

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

The cfg actually attached to the component is a generated file
(``$(OUT_DIR)/aie_config.generated.cfg``) that merges auto-derived
``include=`` lines — the component root plus every ``AIE_SOURCES``
``dest_subdir`` — ahead of the user's ``aie_config.cfg`` body. Edits to
``aie_config.cfg`` are re-merged on every ``make proj``; never edit the
generated file directly.

Customising the Deploy Step
---------------------------

``make program`` invokes ``$(AIE_PROGRAM_SCRIPT)``, which defaults to
``$(RUCKUS_DIR)/vitis/aie/program.sh`` — a generic Versal/PetaLinux deploy
helper that:

1. Derives the normalized ``<name>`` from the ``-p`` PDI basename minus
   ``.pdi`` (a legacy ``_aie_dynamic`` / ``_dynamic`` suffix is stripped,
   so ``AieLoopback_aie_dynamic.pdi`` still deploys as ``AieLoopback``)
2. Pre-flights the PDI path and ssh reachability, and refuses to upload a
   ``*_static*`` filename (which belongs in ``BOOT.BIN``, not as a runtime
   overlay)
3. ``scp``'s ``$(AIE_PDI)`` → ``$(AIE_BOARD_IP):/boot/aie/<name>.pdi`` and
   the ``partition.conf`` sidecar →
   ``$(AIE_BOARD_IP):/boot/aie/<name>.partition.conf`` (warn-not-fail if
   the sidecar is absent — the PDI still uploads, but
   ``aie-partition-init`` will not start for that image)
4. Reboots the board (skippable with ``-r`` for stage-only uploads)
5. Waits for ssh liveness, then verifies the Phase-2 startup-app-init boot
   loop loaded the AIE: the journal ``AIE load: /boot/aie/<name>.pdi``
   line, the ``fpga_manager`` dmesg record of writing ``<name>.pdi``, an
   active ``aie-partition-init@<name>.service``, and the presence of
   ``/sys/class/aie``

No device-tree overlay is deployed: the AIE PDI is a CDO-only partial PDI
delivered via ``/sys/class/fpga_manager/fpga0/firmware`` — the
``ai_engine`` DT node is already live from the design's ``pl.dtbo``.

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
   * - ``-i <user@host>``
     - Board target (required; forwarded from ``$(AIE_BOARD_IP)`` when set)
   * - ``-c <path>``
     - ``partition.conf`` sidecar (optional; forwarded from ``$(AIE_CONF)``
       when set — auto-derived from the PDI directory otherwise)

The default helper additionally accepts ``-r`` (stage-only: upload without
rebooting or verifying) and ``-h`` (show help); custom helpers may ignore
those if not relevant. The helper's exit codes follow the convention
0 = success, 1 = local pre-flight failed, 2 = scp/ssh failure,
3 = post-reboot verification failed.

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
     - ``$(AIE_IP_DIR)/$(PROJECT).pdi``
     - Output dynamic PDI path written by ``make package``. Named
       ``$(PROJECT).pdi`` so ``ip/`` matches the normalized
       ``/boot/aie/<name>`` pair basename.
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
   * - ``AIE_PARTITION_CONF_SCRIPT``
     - ``$(RUCKUS_DIR)/vitis/aie/emit_partition_conf.sh``
     - ``partition.conf`` extractor invoked by ``make partition_conf``.
       Override only for bespoke partition.conf emission.

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

**"VIVADO_XSA_DIR not set" / "no .xsa found in ..."**
   Only the ``package`` target requires the ``.xsa``. Set
   ``VIVADO_XSA_DIR`` in the consuming Makefile to the upstream Vivado
   target's ``images/`` directory and build that target's ``.xsa`` first —
   the newest ``.xsa`` (by the filename-encoded ``BUILD_TIME`` timestamp)
   is selected automatically.

**"no <name>.partition.conf found" warning from ``make program``**
   The deploy helper could not find the ``partition.conf`` sidecar next to
   the PDI (and no ``AIE_CONF`` override was given). The PDI still uploads,
   but ``aie-partition-init@<name>.service`` will not start for that image.
   Run ``make partition_conf`` (or a bare ``make``) first so the sidecar
   lands in ``ip/`` next to the PDI.

**"Refusing to upload static PDI as runtime overlay"**
   The default deploy helper refuses any ``-p`` argument containing
   ``_static`` in the filename. ``<name>_static.pdi`` is the ``BOOT.BIN``
   half of a segmented-configuration build (see
   :doc:`segmented_configuration`); the runtime overlay is ``<name>.pdi``
   (legacy ``<name>_aie_dynamic.pdi`` / ``<name>_dynamic.pdi`` names also
   work — the suffix is stripped on upload). Point ``-p`` at the dynamic
   half.

**``v++ --package`` fails on packaging**
   As a fallback path, set ``USE_BOOTGEN_FALLBACK=1`` to package via
   ``bootgen`` instead. The two paths produce a functionally equivalent
   dynamic PDI for the AIE-overlay case.

**Subdirectory headers go missing from the component**
   ``AIE_SOURCES`` directory entries are **non-recursive**. If your graph
   references sources via a subdirectory path (e.g.
   ``#include "kernels/foo.h"`` or
   ``adf::source(k) = "kernels/foo.cc";``), add the directory as a
   separate entry with a matching ``:dest_subdir`` (e.g.
   ``aie/kernels:kernels``) so the files import into
   ``<component>/kernels/`` — the matching ``include=`` path is auto-added
   to the generated cfg.
