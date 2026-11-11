Hook Script Reference
=====================

ruckus supports two tiers of hook scripts that allow you to inject custom TCL at
specific points in the build pipeline. Hook scripts are optional; ruckus silently
skips any that do not exist.

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
     │
     ├── sources.tcl loaded (ruckus.tcl recursive loading)
     │     ├── [hook] vivado/properties.tcl      (after run-step hook registration)
     │     ├── [hook] vivado/project_setup.tcl   (after project properties set)
     │     └── [hook] vivado/sources.tcl         (after all sources loaded)
     │
     ├── [hook] vivado/properties.tcl            (re-sourced when build.tcl opens the project)
     │
     ├── BuildIpCores (IP synthesis)
     │
     ├── [hook] vivado/pre_synthesis.tcl          (before synth_1 launch)
     │
     ├── SYNTHESIS (synth_1 run)
     │     ├── [in-run hook] pre_synth_run.tcl    (SYNTH_DESIGN PRE)
     │     └── [in-run hook] post_synth_run.tcl   (SYNTH_DESIGN POST)
     │
     ├── [hook] vivado/post_synthesis.tcl         (after synth_1 completes)
     │
     ├── IMPLEMENTATION (impl_1 run)
     │     ├── [in-run hook] pre_opt_run.tcl                   (OPT_DESIGN PRE)
     │     ├── [in-run hook] post_opt_run.tcl                  (OPT_DESIGN POST)
     │     ├── [in-run hook] pre_power_opt_run.tcl             (POWER_OPT_DESIGN PRE)
     │     ├── [in-run hook] post_power_opt_run.tcl            (POWER_OPT_DESIGN POST)
     │     ├── [in-run hook] pre_place_run.tcl                 (PLACE_DESIGN PRE)
     │     ├── [in-run hook] post_place_run.tcl                (PLACE_DESIGN POST)
     │     ├── [in-run hook] pre_post_place_power_opt_run.tcl  (POST_PLACE_POWER_OPT_DESIGN PRE)
     │     ├── [in-run hook] post_post_place_power_opt_run.tcl (POST_PLACE_POWER_OPT_DESIGN POST)
     │     ├── [in-run hook] pre_phys_opt_run.tcl              (PHYS_OPT_DESIGN PRE)
     │     ├── [in-run hook] post_phys_opt_run.tcl             (PHYS_OPT_DESIGN POST)
     │     ├── [in-run hook] pre_route_run.tcl                 (ROUTE_DESIGN PRE)
     │     ├── [in-run hook] post_route_run.tcl                (ROUTE_DESIGN POST)
     │     ├── [in-run hook] pre_post_route_phys_opt_run.tcl   (POST_ROUTE_PHYS_OPT_DESIGN PRE)
     │     └── [in-run hook] post_post_route_phys_opt_run.tcl  (POST_ROUTE_PHYS_OPT_DESIGN POST)
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

Tier-1 hooks are sourced by the outer ruckus TCL scripts (``vivado/sources.tcl``,
``vivado/project.tcl``, ``vivado/build.tcl``, and the stage scripts it sources). They run in the outer Vivado session context,
outside any synthesis or implementation run subprocess.

Place these files in your project's ``vivado/`` directory (i.e., ``$PROJ_DIR/vivado/``).

.. list-table::
   :header-rows: 1
   :widths: 35 45 20

   * - Hook File (in ``$PROJ_DIR/vivado/``)
     - When It Fires
     - Sourced By
   * - ``sources.tcl``
     - After all source files are loaded (end of ``vivado/sources.tcl``)
     - ``vivado/sources.tcl``
   * - ``project_setup.tcl``
     - After Vivado project properties are configured
     - ``vivado/project.tcl``
   * - ``properties.tcl``
     - After run-step hook registrations complete (once from ``vivado/project.tcl``
       and again when ``vivado/build.tcl`` opens the project)
     - ``vivado/properties.tcl``
   * - ``pre_synthesis.tcl``
     - After IP cores are built, before ``launch_runs synth_1``
     - ``vivado/pre_synthesis.tcl``
   * - ``post_synthesis.tcl``
     - After ``synth_1`` completes, before implementation
     - ``vivado/post_synthesis.tcl``
   * - ``post_route.tcl``
     - After implementation and *only if* :func:`CheckTiming` returns ``true``
     - ``vivado/post_route.tcl``
   * - ``post_build.tcl``
     - After ``CreateFpgaBit``/``CreateVersalOutputs`` (the final hook)
     - ``vivado/build.tcl``

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
implementation run subprocess, while the run is in progress.

Place these files in your project's ``vivado/`` directory (i.e., ``$PROJ_DIR/vivado/``).

.. note::

   In-run hooks do **not** have access to Vivado project-level commands that require
   a closed run (e.g., ``open_run``). The ruckus wrapper registered for each step
   (``vivado/run/pre/*.tcl`` / ``vivado/run/post/*.tcl``) sources ``env_var.tcl``
   and ``proc.tcl`` before calling your hook, so the variables from ``env_var.tcl``
   and the ruckus procedures are available in the run subprocess.

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
     - ``POST_PLACE_POWER_OPT_DESIGN``
     - PRE
   * - ``post_post_place_power_opt_run.tcl``
     - ``POST_PLACE_POWER_OPT_DESIGN``
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
     - ``POST_ROUTE_PHYS_OPT_DESIGN``
     - PRE
   * - ``post_post_route_phys_opt_run.tcl``
     - ``POST_ROUTE_PHYS_OPT_DESIGN``
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

   :func:`CheckTiming`: the procedure that reads the TIG variables and determines
   whether ``post_route.tcl`` fires.
