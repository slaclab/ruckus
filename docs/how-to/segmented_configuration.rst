How to Use Versal Segmented Configuration
=========================================

**Goal:** Build a Versal design that emits both a base (static) PDI for ``BOOT.BIN``
and a runtime-loadable (dynamic) PDI from a single RTL source, using Vivado's
Segmented Configuration feature without requiring a Reconfigurable Partition wrapper
or a DFX license.

.. note::

   Unlike Dynamic Function eXchange (DFX), Segmented Configuration does **not**
   require a Vivado DFX license. It does require Vivado 2025.1 or later. See
   :doc:`dfx_partial_reconfig` if you need an explicit Reconfigurable Partition
   wrapper instead.

Prerequisites
-------------

- A Versal target part (the option is ignored on non-Versal architectures)
- Vivado 2025.1 or later (Segmented Configuration is unsupported on earlier versions)
- No DFX license required, and no Reconfigurable Partition / pblock floorplanning
  needed
- No RTL changes required: Vivado splits the design into boot and PL
  partitions automatically based on hard-block boundaries (PMC, PS, NoC, DDR
  controller into the boot PDI; everything else into the PL PDI)

When to Use
-----------

Use Segmented Configuration when you want runtime PL reload on a Versal target
through the Linux ``fpga_manager`` driver (``fpgautil -b /boot/pl.pdi``), but
without restructuring your RTL into Reconfigurable Partitions.

The Versal Platform Management Controller (PMC) requires the runtime-loaded PDI
to be **distinct** from the base PDI baked into ``BOOT.BIN``. Segmented
Configuration provides that distinct runtime PDI as a build-time output of the
same RTL. See the AMD `Solution Versal PL Programming
<https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/1188397412/Solution+Versal+PL+Programming>`__
wiki for the underlying base-vs-runtime PDI model.

Opt-in
------

Set a single environment variable in your target ``Makefile`` before including
``system_vivado.mk``:

.. code-block:: makefile

   export USE_SEGMENTED_CONFIG = 1

   include $(TOP_DIR)/submodules/ruckus/system_vivado.mk

When ``USE_SEGMENTED_CONFIG = 1``, ruckus calls ``EnableSegmentedConfig``
during ``properties.tcl`` (which sets ``SEGMENTED_CONFIGURATION 1`` on the
project) and ``ExportSegmentedPdi`` during ``build.tcl`` (which renames the
two Vivado-emitted PDIs to the SLAC suffix convention below). The default value
is ``0`` (standard single-PDI Versal build, no behavior change).

Outputs
-------

After a successful Segmented build, two PDI files appear in ``images/``:

.. code-block:: text

   <Target>-<PRJ_VERSION>-<timestamp>-<user>-<sha>_static.pdi
   <Target>-<PRJ_VERSION>-<timestamp>-<user>-<sha>_dynamic.pdi

The ``_static.pdi`` becomes ``base-design.pdi`` inside ``BOOT.BIN``; the
``_dynamic.pdi`` is the artifact loaded at runtime by ``fpgautil`` (typically
shipped to the Linux rootfs as ``/boot/pl.pdi``).

Both names inherit the full SLAC ``<Target>-<PRJ_VERSION>-<timestamp>-<user>-<sha>``
convention from ``$IMAGENAME``; only the suffix differs.

Key Variables
-------------

.. list-table::
   :widths: 30 10 60
   :header-rows: 1

   * - Variable
     - Default
     - Description
   * - ``USE_SEGMENTED_CONFIG``
     - ``0``
     - Enables Vivado 2025.1+ Segmented Configuration mode on Versal targets.
       When set to ``1``, the build emits two PDIs (``${IMAGENAME}_static.pdi``
       and ``${IMAGENAME}_dynamic.pdi``) instead of the single
       ``${IMAGENAME}.pdi``. Ignored on non-Versal targets.

See the :doc:`../reference/makefile_reference` for the complete variable reference.

Limitations and Non-Goals
-------------------------

- **No no-reboot runtime reload helper.** Segmented Configuration produces the
  artifact; how Linux loads it (boot-time via ``startup-app-init`` vs. runtime via
  a userspace helper) is the consumer's concern.
- **No multi-variant PL support.** This hook handles the single-design two-PDI
  flow only. Designs that need multiple distinct PL PDIs sharing one boot PDI
  require ``read_noc_solution`` / ``write_noc_solution`` and ``pr_verify``
  invocations not currently exposed by the hook.
- **No DFX migration.** If you need explicit Reconfigurable Partitions, decouplers,
  or floorplanning, see :doc:`dfx_partial_reconfig`. Segmented Configuration is
  the **alternative** to that flow, not a stepping stone toward it.

Troubleshooting
---------------

**"Versal Segmented Configuration requires Vivado 2025.1 or later"**
   Source a Vivado 2025.1+ ``settings64.sh`` before running ``make``. Older Vivado
   releases do not implement the ``SEGMENTED_CONFIGURATION`` project property and
   the build will abort. SLAC S3DF users:
   ``source /sdf/group/faders/tools/xilinx/2025.2/Vivado/2025.2/settings64.sh``.

**No _static/_dynamic PDIs on a non-Versal target**
   The opt-in variable was set but the target's ``PRJ_PART`` is a non-Versal
   architecture. ``properties.tcl`` only calls ``EnableSegmentedConfig`` for Versal
   parts, so the option is silently ignored: the build completes, but the two-PDI
   output does not appear. Either remove ``USE_SEGMENTED_CONFIG`` from the target
   Makefile or change the target part.

**"Expected exactly one *_boot.pdi in IMPL_DIR"** (or ``*_pld.pdi``)
   Vivado did not emit the segmented PDIs even though the property was set. Check
   ``runme.log`` in the ``impl_1`` run directory for ``SEGMENTED_CONFIGURATION``
   confirmation; if absent, Vivado may have rejected the property silently for
   the part. If there are two or more matches, clean the build directory
   (``make clean``) and rebuild.
