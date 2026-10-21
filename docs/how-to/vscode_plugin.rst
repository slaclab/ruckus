How to Use the ruckus VS Code Extension
=======================================

**Goal:** Browse, build, and simulate a ruckus firmware project from VS Code.
The extension shows the design hierarchy, the files every ``ruckus.tcl``
loads, and the ``make`` targets of the selected top level.

The extension lives in the ``vscode-plugin/`` directory of the ruckus
repository. It is versioned with ruckus because it copies the behavior of the
ruckus loader procedures (``loadRuckusTcl``, ``loadSource``, ...) and parses the
``system_*.mk`` files.

.. note::

   Opening and browsing a project does not need Vivado. The extension runs
   the ``ruckus.tcl`` tree with plain ``tclsh``, using stub versions of the
   ruckus procedures. You only need Vivado (or GHDL, Icarus Verilog, ...) to
   run ``make``.

Features
--------

- **Design Hierarchy**: instance tree of the synthesis and simulation tops,
  parsed from the HDL loaded by ``ruckus.tcl``.
- **Sources** and **Libraries & Categories**: every file each ``ruckus.tcl``
  loads, with its library, ``sim`` tag and the line that loaded it.
- **Make Targets**: run ``make bit``, ``make xsim``, ... as VS Code tasks, after
  sourcing the firmware setup script with the selected Vivado version.
- **Simulate Current File**: simulate the testbench open in the editor.
- **Build reports** (bottom panel): *Log Report* (filterable Vivado
  messages), *Timing* (slack summary, failing clocks and paths) and
  *Resources* (utilization, also per instance).
- **Set Up Workspace**: ``.vscode`` settings and tasks, and ``vhdl_ls.toml``
  for the VHDL language server.

Prerequisites
-------------

- VS Code 1.90 or newer.
- ``tclsh`` on PATH (or set ``ruckus.tclsh``). macOS and most Linux
  distributions already include it.
- To build the extension from source: Node.js 18 or newer and ``npm``. If the
  system Node.js is older, install one with conda:

  .. code-block:: bash

     conda create -y -n node20 -c conda-forge nodejs=20
     conda activate node20
     node -v && npm -v

Build and Install
-----------------

The extension runs where the firmware is: on your machine for a local
checkout, on the server for VS Code Remote (SSH, containers, WSL). Build the
package there:

.. code-block:: bash

   cd ruckus/vscode-plugin
   ./scripts/build.sh            # npm install, compile, package slac-ruckus-plugin-<version>.vsix
   ./scripts/build.sh --compile  # compile only (out/), no package

Then install it, with one of:

- ``./scripts/install.sh`` (builds if needed, then runs
  ``code --install-extension``). ``./scripts/install.sh --uninstall``
  removes it.
- The Extensions view: ``...`` > *Install from VSIX...*, then pick the
  ``.vsix`` file.

Run **Developer: Reload Window** afterwards. CI builds the same ``.vsix`` in
the ``vscode_plugin`` job of ``ruckus_ci.yml`` and uploads it as an artifact,
so you can also download it instead of building.

.. tip::

   **VS Code Remote:** connect to the server first, then run ``install.sh``
   in a VS Code integrated terminal. That terminal provides a ``code``
   command that installs on the server. A plain SSH shell has no ``code``
   command: use *Install from VSIX...* while connected instead (the
   ``.vsix`` can be built on either side). The Extensions view lists the
   extension under *SSH: <host> - Installed*. ``tclsh``, ``make`` and Vivado
   must be available on the server.

Select a Top Level
------------------

Open the firmware repository (the folder that contains ``firmware/``) in VS
Code. The extension starts when the workspace contains a ``ruckus.tcl`` file.
If there is only one target, the extension selects it. If not, click the
status-bar item or run **Ruckus: Select Top Level**. A top level is a
directory with a ``Makefile`` that includes a ruckus ``system_*.mk`` file, plus
a ``ruckus.tcl``, usually ``firmware/targets/<Target>``. You can also
right-click a folder and choose **Ruckus: Use as Top Level**.

The extension evaluates the target ``Makefile`` (``TOP_DIR``, ``PRJ_PART``,
``shared_version.mk``, the ``system_*.mk`` include, ...) without running
``make``. Then it runs ``ruckus.tcl`` with those variables in the environment.
``getFpgaArch`` is derived from ``PRJ_PART``, so family-dependent branches
pick the same files as a real build.

Views
-----

The tree views are in the **Ruckus** activity-bar container (the build
reports are panel tabs, see `Build Reports`_).

Design Hierarchy
   The tree of instances under the synthesis top (``set_property top``,
   otherwise ``PROJECT``) and the simulation top (``sim_1``). It shows
   instances, generate blocks, and processes. Instances are resolved
   using the ``-lib`` libraries. Units that cannot be found are flagged.
   Generics are not elaborated, so the tree shows every branch of an
   ``if generate`` and shows each ``for generate`` once.

Sources (ruckus.tcl)
   The ``loadRuckusTcl`` tree, with one node per ``ruckus.tcl``. For each
   loaded file it shows the library, the ``sim`` tag, and the
   ``ruckus.tcl:line`` that loaded it. Load problems also appear in the
   Problems panel: a missing directory, a bad extension, a Tcl error, an
   ``exit`` call (where a real build aborts), and a relative ``-path`` or
   ``-dir`` (Vivado resolves it against ``OUT_DIR``, not the source tree; use
   ``$::DIR_PATH``). The view also
   lists the project's hook scripts (see :doc:`../reference/hook_scripts`).

Libraries & Categories
   Top modules, submodules, HDL libraries, VHDL/SV packages, constraints, IP
   cores, block designs, netlists, simulation sources, and C/C++ files.

Make Targets
   The targets of the selected top level, mostly from the ruckus
   ``system_*.mk`` files (see :doc:`../reference/makefile_reference`).
   Clicking ▶ runs ``make <target>`` as a VS Code task in a dedicated
   terminal. **Run with Variables...** adds variables such as
   ``VIVADO_PROJECT_SIM=MyTb``.

Run make
--------

Before ``make``, every task sources the firmware's ``setup_env_slac.sh`` (or
``ruckus.setupScript``) with the selected Vivado version as its argument.
To choose the version, click the Vivado item in the status bar. The
make output is also saved to ``build/logs/<target>_<goal>.log``. To tail that
log, or any Vivado log in the build directory, run
**Ruckus: Follow Build Log...**.

The problem matcher depends on the backend, so errors and warnings with a
file location appear in the Problems panel:

=============== =====================================================
Backend         Parsed output
=============== =====================================================
Vivado          ``ERROR|CRITICAL WARNING|WARNING: [Id] msg [file:line]``
GHDL            ``file.vhd:line:col: msg``
Icarus Verilog  ``file.v:line: error|warning: msg``
Verilator       ``%Error|%Warning-CODE: file.v:line:col: msg``
=============== =====================================================

Build Reports
-------------

Three tabs in the bottom panel, next to the terminal, show the results of
the last build of the selected top level. They refresh while visible and
when a ``ruckus`` task ends. Run **Ruckus: Show Log Report**,
**Ruckus: Show Timing Summary** or **Ruckus: Show Resource Utilization**
to open them.

*Ruckus: Log Report*
   The messages of ``vivado.log`` and the ``synth_1`` / ``impl_1``
   ``runme.log`` files, like the Vivado *Messages* window. Toggle errors,
   critical warnings, warnings and infos independently, filter by text (a
   ``-word`` excludes), and group by message ID, build step or source file.
   The *Logs* menu also offers the out-of-context IP runs and the saved
   ``make xsim/vcs/msim`` output. Click a message to open its source
   location; :kbd:`Alt`-click opens the log line. For GHDL, Icarus Verilog
   and Verilator targets the view reads the make output saved in
   ``build/logs/``.

*Ruckus: Timing*
   ``impl_1/<top>_timing_summary_routed.rpt``: WNS/TNS, WHS/THS and
   WPWS/TPWS, the *check_timing* issues, the intra-clock table (generated
   clocks indented below their master), inter-clock and path-group tables,
   and the worst paths sorted by slack. Negative slack, failing clocks and
   violated paths are highlighted, and *Only failing* hides the rest. Click a
   path to open its detail in the report.

*Ruckus: Resources*
   The placed (*Implementation*) and *Synthesis* utilization reports, with
   the headline resources as bars, sorted by utilization, and every report
   table. The *Hierarchy* tab shows utilization per instance. Vivado does
   not write that report during the build, so **Generate hierarchical
   utilization** (also **Ruckus: Generate Hierarchical Utilization**) runs
   Vivado in batch mode on the routed checkpoint
   (``report_utilization -hierarchical``, depth set by
   ``ruckus.hierUtilizationDepth``) and writes
   ``build/<target>/<target>_utilization_hierarchical.rpt``.

Simulate the Current File
-------------------------

To simulate the testbench in the active editor, open it and click the
beaker icon in the editor title bar. You can also run
**Ruckus: Simulate Current File** from the command palette or the editor
context menu. The extension finds the entity or module defined in the file,
and prefers testbench units when the file has several. It then runs the
target's simulation flow with that unit as the top:

=============== ===================================================
Backend         Command
=============== ===================================================
Vivado          ``make xsim VIVADO_PROJECT_SIM=<unit>``
GHDL            ``make tb PROJECT=<unit>``
Icarus Verilog  ``make tb SIM_TOP=<unit>``
Verilator       ``make tb SIM_TOP=<unit>``
=============== ===================================================

For Vivado targets, ``ruckus.simulateTarget`` selects ``xsim``, ``vcs``, or
``msim``. **Simulate Current File with Variables...** asks for extra
variables, such as ``VIVADO_PROJECT_SIM_TIME=10us`` or
``GHDL_STOP_TIME=1us``.

The file must be loaded by the selected target's ``ruckus.tcl``, usually
with ``loadSource -sim_only``. Otherwise the simulator cannot find the unit.

.. note::

   GHDL derives ``OUT_DIR`` from ``PROJECT``, so each simulated unit gets its
   own ``build/<unit>`` directory.

Set Up the Workspace
--------------------

**Ruckus: Set Up Workspace** (in the *Sources* view ``...`` menu) writes
project files that are also useful without the extension:

``.vscode/settings.json``
   - ``python.analysis.extraPaths`` and ``PYTHONPATH`` for the integrated
     terminal. They list every ``submodules/<name>/python`` directory (for
     example ``surf/python``) and the repository's ``python/`` or
     ``software/python/`` directory. Pylance can then resolve
     ``import surf`` and the project's Rogue device trees.
   - Excludes the Vivado ``build/`` tree and ``.Xil`` from the file watcher
     and search. These directories hold hundreds of thousands of files.
   - Opens ``ruckus.tcl`` and ``.xdc`` files in Tcl mode.

``.vscode/tasks.json``
   ``ruckus`` tasks for the selected target: the default build task
   (``bit``, or ``tb`` for simulation-only backends, which runs with
   :kbd:`Ctrl+Shift+B`), *simulate current file*, a variant that asks for
   extra variables, and ``clean``.

``vhdl_ls.toml`` (optional)
   The VHDL library mapping of every loaded file, for the VHDL-LS / rust_hdl
   language server. VHDL-LS reserves ``work``, so files loaded without
   ``-lib`` go to ``xil_defaultlib``, the Vivado default library. The
   ``unisim``, ``unimacro`` and ``xpm`` libraries map to the VHDL sources of
   the Vivado installation (``ruckus.vivadoPath``, otherwise
   ``$XILINX_VIVADO``, the ``settings64.sh`` sourced by the setup script, or
   ``ruckus.vivadoVersion`` under the usual install roots).

The command never changes existing settings or tasks. It only adds missing
keys and tasks with new labels, so you can run it again after you add a
submodule. If a file contains comments, the command does not rewrite it.
Instead, it opens the proposed entries in an editor so you can merge them by
hand.

You can also write ``ruckus`` tasks by hand. ``dir`` and ``args`` support
``${workspaceFolder}``, ``${topDir}``, ``${targetDir}``, ``${file}`` and
``${fileBasenameNoExtension}``. An ``${input:...}`` argument is passed to the
shell without quotes, so a prompt can hold several ``VAR=value`` words:

.. code-block:: json

   {
       "label": "xsim this file",
       "type": "ruckus",
       "target": "xsim",
       "dir": "${workspaceFolder}/firmware/targets/MyTarget",
       "args": ["VIVADO_PROJECT_SIM=${fileBasenameNoExtension}", "${input:ruckusMakeVars}"],
       "group": "test"
   }

Settings
--------

================================ ============ ================================================
Setting                          Default      Description
================================ ============ ================================================
``ruckus.tclsh``                 ``tclsh``    Tcl shell used for the scan
``ruckus.setupScript``           (empty)      Script sourced before ``make``; the Vivado
                                              version is passed as ``$1``
``ruckus.autoSourceSetupScript`` ``true``     Source ``setup_env_slac.sh`` when
                                              ``setupScript`` is empty
``ruckus.vivadoVersion``         (empty)      Vivado version for the setup script and scan
``ruckus.vivadoPath``            (empty)      Vivado install used for ``unisim``/``xpm`` in
                                              ``vhdl_ls.toml``
``ruckus.env``                   ``{}``       Extra variables for the scan, e.g.
                                              ``{"RUCKUS_SIM_BACKEND": "vcs"}``
``ruckus.saveMakeLog``           ``true``     Copy make output to ``build/logs/``
``ruckus.hierUtilizationDepth``  ``8``        Depth of the hierarchical utilization report
``ruckus.simulateTarget``        ``xsim``     Vivado simulator for *Simulate Current File*
``ruckus.commonMakeTargets``     bit, ...     Order of the *Common* make targets
``ruckus.grouping``              hierarchy    Sources view grouping
``ruckus.showSimFiles``          ``true``     Show ``-sim_only`` files
================================ ============ ================================================

Limitations
-----------

- Logic that depends on real Vivado state, such as ``get_files`` results or IP
  properties, evaluates as empty during the scan.
- ``$(shell ...)`` in Makefiles is not executed.
- To scan a different branch of a conditional ``ruckus.tcl``, override
  variables with ``ruckus.env``.

Maintaining the Extension
-------------------------

The scanner ``vscode-plugin/resources/ruckus_scan.tcl`` replaces every public
loader procedure with a recorder. When you add a loader procedure or option
to ``vivado/proc/code_loading.tcl``, add the same procedure or option to the
scanner in the same change. Otherwise the extension reports
``unknown option`` warnings or misses files. When you add a make target that
needs a description, add it to ``RUCKUS_TARGET_DOCS`` in
``vscode-plugin/src/core/project.ts``.

Development commands, run in ``vscode-plugin/``:

.. code-block:: bash

   npm install
   npm run compile                       # or: npm run watch
   node out/test/smoke.js <target dir>   # print the project model, no VS Code needed
   npm test -- <firmware dir>            # integration test inside VS Code

To start an Extension Development Host, open ``vscode-plugin/`` in VS Code
and press :kbd:`F5`.
