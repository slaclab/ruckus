Output Artifacts and Hook Scripts
===================================

.. note::

   This page is a placeholder. Full content will be added in the next plan iteration.

When a ruckus Vivado build completes successfully, output artifacts are written to the
``images/`` directory of the target. The filename encodes the project name, firmware
version, build timestamp, username, and git commit hash.

Output Filename Format
-----------------------

The canonical output filename follows this pattern:

.. code-block:: none

   <ProjectName>-<PRJ_VERSION>-<timestamp>-<user>-<git-hash>.<ext>

Example:

.. code-block:: none

   Simple10GbeRudpKcu105Example-0x02180000-20240315143022-jsmith-a1b2c3d.bit

If the git working tree has uncommitted changes at build time, ``<git-hash>`` is
replaced with ``dirty``.

Hook Scripts
-------------

ruckus supports hook scripts that fire at defined points in the build pipeline. Place
TCL files in the target directory with the following names:

- ``vivado/pre_synthesis.tcl`` — runs before synthesis starts
- ``vivado/post_synthesis.tcl`` — runs after synthesis completes
- ``vivado/post_route.tcl`` — runs after routing completes
- ``vivado/post_bit.tcl`` — runs after bitstream generation
- ``vivado/post_build.tcl`` — runs after the entire build completes
