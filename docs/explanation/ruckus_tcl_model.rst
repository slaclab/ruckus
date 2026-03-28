The ruckus.tcl Recursive Loading Model
========================================

Every firmware project using ruckus has a ``ruckus.tcl`` file in the target directory. This
file is the project manifest — it declares what source files, IP cores, and constraint files
belong to the project. When a project depends on submodule libraries, those libraries each
have their own ``ruckus.tcl``. ruckus loads them all recursively by following
``loadRuckusTcl`` calls.

Understanding this recursive model — and specifically the ``::DIR_PATH`` variable that makes
it work — is essential for writing correct ``ruckus.tcl`` files.


The loadRuckusTcl Procedure
-----------------------------

``loadRuckusTcl`` takes a directory path as its argument. Before sourcing the ``ruckus.tcl``
inside that directory, it saves the current value of ``::DIR_PATH``, sets ``::DIR_PATH`` to
the target directory, and restores the original value after the sourced file returns. This is
a manual call-stack discipline in a language (TCL) that has no native per-call scope for
global variables.

The exact implementation from ``vivado/proc/code_loading.tcl``:

.. code-block:: tcl

   proc loadRuckusTcl { filePath {flags ""} } {
      # Save the caller's DIR_PATH
      set LOC_PATH $::DIR_PATH
      # Set DIR_PATH to the directory being loaded
      set ::DIR_PATH ${filePath}
      # Source the ruckus.tcl in that directory
      source ${filePath}/ruckus.tcl -notrace
      # Restore the caller's DIR_PATH after return
      set ::DIR_PATH ${LOC_PATH}
      # Accumulate directory into DIR_LIST
      set ::DIR_LIST "$::DIR_LIST ${filePath}"
   }

Three operations happen in sequence around the ``source`` call:

1. ``set LOC_PATH $::DIR_PATH`` — saves the caller's current directory path into a local variable
2. ``set ::DIR_PATH ${filePath}`` — sets the global to the directory being entered
3. ``source ${filePath}/ruckus.tcl -notrace`` — executes the child ``ruckus.tcl``
4. ``set ::DIR_PATH ${LOC_PATH}`` — restores the caller's directory path after return

The result is that ``::DIR_PATH`` always holds the directory of the ``ruckus.tcl`` file that
is currently executing, for the lifetime of that file's execution.


The ::DIR_PATH Variable
-------------------------

``::DIR_PATH`` is a TCL global variable with a precise, invariant meaning:

- Its value is always the absolute path to the directory containing the currently-executing
  ``ruckus.tcl`` file.
- It is set by ``loadRuckusTcl`` before sourcing each ``ruckus.tcl``, and restored after.
- It is initialized to ``""`` in ``vivado/sources.tcl`` before the first
  ``loadRuckusTcl ${PROJ_DIR}`` call. The first ``loadRuckusTcl`` call immediately sets it
  to the project target directory.
- It accumulates a history of all loaded directories in ``::DIR_LIST`` (appended after each
  sourced file returns).

Because ``::DIR_PATH`` is a TCL global (not a local variable), any code inside a
``ruckus.tcl`` file can read it without passing it as an argument. This is the design
trade-off: global state is easier to access in TCL than threaded arguments, but requires the
save/restore discipline to remain correct across recursive calls.


Why Every loadSource Call Must Use $::DIR_PATH
------------------------------------------------

The ``loadSource`` (and ``loadConstraints``, ``loadIpCore``, ``loadBlockDesign``) procedures
accept file paths or directory paths as arguments. Those paths are evaluated inside Vivado's
TCL interpreter, whose current working directory is the Vivado project output directory
(``OUT_DIR``), not the firmware source tree.

The CORRECT pattern anchors every path to the module's own directory using ``$::DIR_PATH``:

.. code-block:: tcl

   # CORRECT: path is anchored to the module directory
   loadSource      -dir "$::DIR_PATH/hdl"
   loadConstraints -dir "$::DIR_PATH/hdl"

The WRONG pattern uses a bare relative path:

.. code-block:: tcl

   # WRONG: path resolves against Vivado's working directory (OUT_DIR), not the module
   loadSource      -dir "hdl"
   loadConstraints -dir "hdl"

When ``loadSource`` receives the path ``"hdl"``, TCL resolves it relative to Vivado's current
working directory. That directory is the build output directory (the ``OUT_DIR`` path, which
looks like ``build/Simple10GbeRudpKcu105Example/``). There is no ``hdl`` subdirectory there.
``loadSource`` will detect that the directory does not exist and call ``exit -1``, aborting
the build.

The failure mode without ``$::DIR_PATH/`` is always an error — either an immediate
``exit -1`` from ``loadSource``'s directory-existence check, or (for single file paths with
``-path``) a similar check that the named file exists. There is no silent data loss: a missing
prefix will always produce a build failure before any synthesis starts.


A Worked Example: Two-Level Recursion
----------------------------------------

The ``Simple-10GbE-RUDP-KCU105-Example`` project shows the save/restore mechanism in action
across two levels of recursion. The project depends on the ``surf`` library and a local
``shared`` directory, each with its own ``ruckus.tcl``.

The call sequence when ``make bit`` is run:

.. code-block:: none

   sources.tcl: set ::DIR_PATH ""; loadRuckusTcl $PROJ_DIR
     ::DIR_PATH = firmware/targets/Simple10GbeRudpKcu105Example/
     ruckus.tcl: loadRuckusTcl $::env(TOP_DIR)/submodules/surf
       ::DIR_PATH = firmware/submodules/surf/         <- saved, then set
       surf/ruckus.tcl: loadSource -dir "$::DIR_PATH/hdl"
                           ^ resolves to firmware/submodules/surf/hdl/   OK
       ::DIR_PATH = firmware/targets/Simple10GbeRudpKcu105Example/   <- restored
     ruckus.tcl: loadRuckusTcl $::env(TOP_DIR)/shared
       ::DIR_PATH = firmware/shared/                  <- saved, then set
       shared/ruckus.tcl: loadSource -dir "$::DIR_PATH/rtl"
                              ^ resolves to firmware/shared/rtl/   OK
       ::DIR_PATH = firmware/targets/Simple10GbeRudpKcu105Example/   <- restored
     ruckus.tcl: loadSource -dir "$::DIR_PATH/hdl"
                    ^ resolves to firmware/targets/Simple10GbeRudpKcu105Example/hdl/   OK

Each ``ruckus.tcl`` sees its own directory in ``$::DIR_PATH`` for the duration of its
execution. The surf library's ``$::DIR_PATH/hdl`` resolves to ``firmware/submodules/surf/hdl/``;
the shared module's ``$::DIR_PATH/rtl`` resolves to ``firmware/shared/rtl/``; the top-level
target's ``$::DIR_PATH/hdl`` resolves to
``firmware/targets/Simple10GbeRudpKcu105Example/hdl/``. All three are correct because
``loadRuckusTcl`` sets and restores ``::DIR_PATH`` around each ``source`` call.

The key invariant: at any point during the recursive load, ``$::DIR_PATH`` equals the
directory of the ``ruckus.tcl`` that is currently running. Writing ``$::DIR_PATH/`` as a
prefix on every path argument is not optional — it is the mechanism that makes the recursive
loading model correct.
