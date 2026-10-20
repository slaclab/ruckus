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

Prerequisites
-------------

- VS Code 1.90 or newer (local, or Remote-SSH on a Linux build server).
- ``tclsh`` on PATH (or set ``ruckus.tclsh``). macOS and most Linux
  distributions already include it.
- To build the extension from source: Node.js 18 or newer and ``npm``.

Install
-------

Build the ``.vsix`` package and install it with the ``code`` command:

.. code-block:: bash

   cd ruckus/vscode-plugin
   ./scripts/install.sh               # builds if needed, then code --install-extension
   ./scripts/install.sh --uninstall

``./scripts/build.sh`` only builds the package
(``slac-ruckus-plugin-<version>.vsix``). You can install that file from the
Extensions view (``...`` > *Install from VSIX...*). CI builds the same file
in the ``vscode_plugin`` job of ``ruckus_ci.yml`` and uploads it as an
artifact.

.. tip::

   With Remote-SSH, run ``install.sh`` in a terminal on the remote host. The
   ``code`` command there installs the extension on the server, where your
   firmware is.

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

All views are in the **Ruckus** activity-bar container.

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
   ``ruckus.tcl:line`` that loaded it. Load problems (missing directory, bad
   extension, Tcl error) also appear in the Problems panel. The view also
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
   language server.

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
``ruckus.env``                   ``{}``       Extra variables for the scan, e.g.
                                              ``{"RUCKUS_SIM_BACKEND": "vcs"}``
``ruckus.saveMakeLog``           ``true``     Copy make output to ``build/logs/``
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
