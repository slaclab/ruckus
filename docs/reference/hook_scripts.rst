Hook Script Reference
=====================

ruckus supports two tiers of hook scripts that allow you to inject custom TCL at
specific points in the build pipeline. Hook scripts are optional — ruckus silently
skips them if they do not exist.

For an overview of where hooks fit in the pipeline, see
:doc:`/explanation/build_pipeline`.

.. contents::
   :local:
   :depth: 2

Build Lifecycle Overview
------------------------

Hook scripts fire in the following order relative to the Vivado build stages:

.. code-block:: text

   make bit
     |
     ├── sources.tcl loaded (ruckus.tcl recursive loading)
     │     └── [hook] vivado/sources.tcl         (after all sources loaded)
     │     └── [hook] vivado/project_setup.tcl   (after project properties set)
     │     └── [hook] vivado/properties.tcl      (after run-step hook registration)
     |
     ├── BuildIpCores (IP synthesis)
     |
     ├── [hook] vivado/pre_synthesis.tcl          (before synth_1 launch)
     │
     ├── SYNTHESIS (synth_1 run)
     │     ├── [in-run hook] pre_synth_run.tcl    (SYNTH_DESIGN PRE)
     │     └── [in-run hook] post_synth_run.tcl   (SYNTH_DESIGN POST)
     │
     ├── [hook] vivado/post_synthesis.tcl         (after synth_1 completes)
     │
     ├── IMPLEMENTATION (impl_1 run)
     │     ├── [in-run hook] pre_opt_run.tcl            (OPT_DESIGN PRE)
     │     ├── [in-run hook] post_opt_run.tcl           (OPT_DESIGN POST)
     │     ├── [in-run hook] pre_power_opt_run.tcl      (POWER_OPT_DESIGN PRE)
     │     ├── [in-run hook] post_power_opt_run.tcl     (POWER_OPT_DESIGN POST)
     │     ├── [in-run hook] pre_place_run.tcl          (PLACE_DESIGN PRE)
     │     ├── [in-run hook] post_place_run.tcl         (PLACE_DESIGN POST)
     │     ├── [in-run hook] pre_post_place_power_opt_run.tcl  (POST_PLACE_POWER_OPT PRE)
     │     ├── [in-run hook] post_post_place_power_opt_run.tcl (POST_PLACE_POWER_OPT POST)
     │     ├── [in-run hook] pre_phys_opt_run.tcl       (PHYS_OPT_DESIGN PRE)
     │     ├── [in-run hook] post_phys_opt_run.tcl      (PHYS_OPT_DESIGN POST)
     │     ├── [in-run hook] pre_route_run.tcl          (ROUTE_DESIGN PRE)
     │     ├── [in-run hook] post_route_run.tcl         (ROUTE_DESIGN POST)
     │     ├── [in-run hook] pre_post_route_phys_opt_run.tcl   (POST_ROUTE_PHYS_OPT PRE)
     │     └── [in-run hook] post_post_route_phys_opt_run.tcl  (POST_ROUTE_PHYS_OPT POST)
     │
     ├── CheckTiming  ← if timing fails and no TIG override is set, stops here
     │
     ├── [hook] vivado/post_route.tcl             (only when CheckTiming passes)
     │
     ├── CreateFpgaBit / CreateVersalOutputs
     │
     └── [hook] vivado/post_build.tcl             (final hook)

Tier-1 Hooks (Pipeline-Level)
------------------------------

Tier-1 hooks are sourced directly by the outer ruckus TCL scripts (``build.tcl``,
``sources.tcl``, ``project.tcl``). They run in the outer Vivado session context,
outside any synthesis or implementation run subprocess.

Place these files in your project's ``vivado/`` directory (i.e., ``$PROJ_DIR/vivado/``).

.. list-table::
   :header-rows: 1
   :widths: 35 45 20

   * - Hook File (in ``$PROJ_DIR/vivado/``)
     - When It Fires
     - Sourced By
   * - ``sources.tcl``
     - After all source files loaded (end of ``vivado/sources.tcl``)
     - ``vivado/sources.tcl``
   * - ``project_setup.tcl``
     - After Vivado project properties are configured
     - ``vivado/project.tcl``
   * - ``properties.tcl``
     - After run-step hook registrations complete
     - ``vivado/properties.tcl``
   * - ``pre_synthesis.tcl``
     - After IP cores built, before ``launch_runs synth_1``
     - ``build.tcl``
   * - ``post_synthesis.tcl``
     - After ``synth_1`` completes, before implementation
     - ``build.tcl``
   * - ``post_route.tcl``
     - After implementation and *only if* :func:`CheckTiming` returns ``true``
     - ``build.tcl``
   * - ``post_build.tcl``
     - After ``CreateFpgaBit``/``CreateVersalOutputs`` — the final hook
     - ``build.tcl``

.. warning::

   ``post_route.tcl`` is **conditional**. It fires only when :func:`CheckTiming`
   returns ``true`` (timing met or overridden by a TIG variable). If timing fails
   and no override is active, this hook is silently skipped.

**TCL variables in scope for all Tier-1 hooks:**

``$::PRJ_PART``, ``$::PROJECT``, ``$::PRJ_VERSION``, ``$::PROJ_DIR``,
``$::TOP_DIR``, ``$::IMAGES_DIR``, ``$::OUT_DIR``, ``$::SYN_DIR``,
``$::IMPL_DIR``, ``$::VIVADO_DIR``, ``$::VIVADO_PROJECT``,
``$::VIVADO_VERSION``, ``$::RUCKUS_DIR``

All ruckus procedures (:func:`loadSource`, :func:`loadRuckusTcl`, etc.) are also
in scope.

Tier-2 Hooks (In-Run)
----------------------

Tier-2 hooks are registered via ``STEPS.<STEP>.TCL.PRE`` / ``STEPS.<STEP>.TCL.POST``
properties in ``vivado/properties.tcl``. They run inside the Vivado synthesis or
implementation run subprocess. The Vivado project is open but the run is in progress.

Place these files in your project's ``vivado/`` directory (i.e., ``$PROJ_DIR/vivado/``).

.. note::

   In-run hooks do **not** have access to Vivado project-level commands that require
   a closed run (e.g., ``open_run``). Environment variables from ``env_var.tcl`` are
   available; ruckus procedure definitions are NOT automatically sourced in the
   run subprocess.

.. list-table::
   :header-rows: 1
   :widths: 45 30 10

   * - Hook File (in ``$PROJ_DIR/vivado/``)
     - Vivado Step
     - Pre/Post
   * - ``pre_synth_run.tcl``
     - ``SYNTH_DESIGN``
     - PRE
   * - ``post_synth_run.tcl``
     - ``SYNTH_DESIGN``
     - POST
   * - ``pre_opt_run.tcl``
     - ``OPT_DESIGN``
     - PRE
   * - ``post_opt_run.tcl``
     - ``OPT_DESIGN``
     - POST
   * - ``pre_power_opt_run.tcl``
     - ``POWER_OPT_DESIGN``
     - PRE
   * - ``post_power_opt_run.tcl``
     - ``POWER_OPT_DESIGN``
     - POST
   * - ``pre_place_run.tcl``
     - ``PLACE_DESIGN``
     - PRE
   * - ``post_place_run.tcl``
     - ``PLACE_DESIGN``
     - POST
   * - ``pre_post_place_power_opt_run.tcl``
     - ``POST_PLACE_POWER_OPT``
     - PRE
   * - ``post_post_place_power_opt_run.tcl``
     - ``POST_PLACE_POWER_OPT``
     - POST
   * - ``pre_phys_opt_run.tcl``
     - ``PHYS_OPT_DESIGN``
     - PRE
   * - ``post_phys_opt_run.tcl``
     - ``PHYS_OPT_DESIGN``
     - POST
   * - ``pre_route_run.tcl``
     - ``ROUTE_DESIGN``
     - PRE
   * - ``post_route_run.tcl``
     - ``ROUTE_DESIGN``
     - POST
   * - ``pre_post_route_phys_opt_run.tcl``
     - ``POST_ROUTE_PHYS_OPT``
     - PRE
   * - ``post_post_route_phys_opt_run.tcl``
     - ``POST_ROUTE_PHYS_OPT``
     - POST

**TCL variables in scope for all Tier-2 hooks** (sourced from ``env_var.tcl``):

``PRJ_PART``, ``PROJECT``, ``PRJ_VERSION``, ``PROJ_DIR``, ``TOP_DIR``,
``IMAGES_DIR``, ``OUT_DIR``, ``SYN_DIR``, ``IMPL_DIR``, ``VIVADO_DIR``,
``VIVADO_PROJECT``, ``VIVADO_VERSION``, ``RUCKUS_DIR``,
``VIVADO_PROJECT_SIM``, ``VIVADO_PROJECT_SIM_TIME``,
``VITIS_PRJ``, ``VITIS_LIB``, ``VITIS_ELF``,
``SDK_PRJ``, ``SDK_LIB``, ``SDK_ELF``,
``RECONFIG_CHECKPOINT``, ``RECONFIG_ENDPOINT``, ``RECONFIG_PBLOCK``,
``PRJ_TOP``, ``SIM_TOP``

.. seealso::

   :func:`CheckTiming` — the procedure that reads TIG variables and determines
   whether ``post_route.tcl`` fires.
