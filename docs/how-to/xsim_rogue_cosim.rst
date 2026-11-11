How to Run the Rogue Co-Simulation in Vivado XSIM
===================================================

**Goal:** Run the surf Rogue TCP/SideBand co-simulation inside Vivado xsim,
either interactively in the GUI or in batch mode.

The co-simulation HDL and C sources live in the **surf** submodule under
``simlink/``; ruckus provides only the build and simulation orchestration
described here. Any ``simlink/...`` path below is relative to the surf
submodule root, not ruckus.

.. note::

   This flow is GUI-interactive/local only and requires a licensed Vivado
   install. It has no CI coverage; verification is manual against a local
   Vivado + Rogue environment.

Prerequisites
-------------

- ``libzmq >= 4.1.0`` and ``pkg-config`` on the build machine.
- A Rogue-environment Python shell for the peer script (it imports
  ``pyrogue`` / ``rogue``).
- Vivado 2023.1 or newer, the floor enforced by ``VersionCheck`` in the
  co-sim pre-compile hook (``vivado/run/pre/xsim.tcl``). The latest *tested* Vivado release is tracked centrally by
  ``CheckVivadoVersion`` (see :doc:`../reference/tcl_api`), which warns when the
  active Vivado is newer; this page intentionally does not restate a version.
- A surf version that provides the ``simlink/xsim/`` DPI backend. Older
  surf (legacy ``axi/simlink/sim`` + ``src`` VHPI layout) is VCS-only; use
  ``make vcs`` there.

Makefile Setup
--------------

Add the following to your project ``Makefile``:

.. code-block:: makefile

   include $(TOP_DIR)/submodules/ruckus/system_vivado.mk

No additional variables are required. The co-sim hook is registered
unconditionally by ``project.tcl`` and is a fast no-op for any project that
doesn't contain a Rogue co-sim source.

.. note::

   ``make xsim`` and ``make gui`` automatically select the surf xsim DPI-C
   backend (they export ``RUCKUS_SIM_BACKEND=xsim``), so having Synopsys VCS
   sourced in the same shell alongside Vivado (common in a combined setup
   script) no longer misroutes the flow to the VCS/VHPI backend. Switching
   between this xsim flow and ``make vcs`` in the same build directory swaps
   the backend automatically; no ``make clean`` is needed.

Steps
-----

1. **Launch the GUI (or run batch xsim):**

   .. code-block:: bash

      make gui

   For a headless batch run, name your co-sim testbench and let the simulation
   free-run so the peer can connect and drive it:

   .. code-block:: bash

      make xsim VIVADO_PROJECT_SIM=<MyCoSimTb>

   When ``VIVADO_PROJECT_SIM`` is set, the batch path elaborates it as the
   ``sim_1`` top instead of the top set in ``ruckus.tcl``, so here it names
   the co-sim testbench. The run length is
   ``VIVADO_PROJECT_SIM_TIME``, whose default ``all`` free-runs until the
   testbench calls ``$finish``/``$stop`` or is interrupted. A co-sim
   testbench typically has neither, so the run does not self-terminate: background
   it, wait for the ``Listening on ports N & N+1`` print, start the peer, then
   stop the simulation once the peer reports its result. To bound a run
   instead, pass a time value, e.g. ``VIVADO_PROJECT_SIM_TIME="1000 ns"``.

   Either target triggers ruckus's pre-compile hook
   (``vivado/run/pre/xsim.tcl``), which detects any of
   ``RogueTcpStream.vhd``, ``RogueTcpMemory.vhd``, or ``RogueSideBand.vhd`` in
   the simulation sources and builds the combined ``libRogueSimLinkDpi.so``
   via ``xsc``. The matching ``-sv_lib libRogueSimLinkDpi`` elaboration
   binding is registered at project generation by ``vivado/sources.tcl``, so
   there is no manual build step.

2. **Watch the console for the build and bind:**

   Confirm the ``pkg-config``/``xsc`` build messages appear with no errors,
   and, after ``launch_simulation``/``run``, the module's one-time
   ``Listening on ports N & N+1`` print, which is the ready-for-peer signal.

3. **Start the matching Rogue peer script:**

   .. code-block:: bash

      python3 <my_peer_script>.py

   Run this in a separate terminal, pointed at the same host/port the
   testbench is listening on. Ruckus and the DPI hook are entirely automatic
   up to this point; starting the peer and, if switching modules, selecting
   the desired top-level testbench in the target's ``ruckus.tcl``
   (``set_property top``) are the only manual steps.

4. **Observe the waveform:**

   Data movement between the DPI adapter and the peer confirms the round
   trip.

Key Variables
-------------

.. list-table::
   :header-rows: 1
   :widths: 22 15 63

   * - Variable
     - Default
     - Description
   * - ``VIVADO_PROJECT_SIM``
     - (empty)
     - Top module for Vivado simulation. When empty, the ``sim_1`` top set in
       ``ruckus.tcl`` is used. Set it to your co-sim testbench for a batch
       ``make xsim`` co-sim run.
   * - ``VIVADO_PROJECT_SIM_TIME``
     - ``all``
     - Simulation run length. The default ``all`` free-runs until the
       testbench calls ``$finish``/``$stop`` or is interrupted, which co-sim
       requires so the external peer can drive the testbench. Pass a time value
       (e.g. ``1000 ns``) to bound the run instead.

There is no co-sim-specific variable: the DPI hook auto-registers and
auto-detects, so the existing simulation variables above are the only ones
relevant to this flow.

Troubleshooting
----------------

**"libzmq package was not found"**
   .. code-block:: text

      libzmq package was not found
      Please make sure that you have libzmq installed
      or have sourced the necessary rogue setup scripts

   Install libzmq, or source the Rogue setup scripts that put it on
   ``PKG_CONFIG_PATH``, then re-run ``make gui``/``make xsim``.

**"this surf has no simlink/xsim/ DPI co-simulation backend" at compile**
   The surf version in your project predates the xsim DPI backend (legacy
   ``axi/simlink/sim`` + ``src`` VHPI layout). The Vivado xsim co-sim requires
   a surf that provides ``simlink/xsim/``. Use ``make vcs`` for VCS
   co-simulation with that surf version, or update surf.

**"DPI function ... not found" at elaboration**
   The ``.so`` is stale, ``-sv_lib`` was not bound, or the module-detection
   guard did not fire because none of the three Rogue ``.vhd`` files are
   present in the simulation sources. Confirm the module's source is in the
   sim compile order and re-run the build.

**Waveform runs with no data movement**
   The peer script has not connected. Confirm it is running against the
   correct host/port pair and that push/pull directions are not swapped (see
   the port documentation under ``simlink/`` in surf, starting from
   ``simlink/README.md``).
