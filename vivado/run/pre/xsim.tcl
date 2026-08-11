##############################################################################
## This file is an addition to the 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/run/pre/xsim.tcl
# \brief Vivado xsim pre-compile hook (xsim.compile.tcl.pre, registered
# unconditionally by project.tcl). Detects the Rogue TCP/SideBand co-sim
# sources, builds their DPI shared library via xsc, and binds it to xelab.
# This script IS the guard: a non-Rogue xsim project is a fast no-op.
# Fires for both "make gui" -> Run Simulation and "make xsim" (batch),
# since project.tcl runs ahead of both launch paths.

########################################################
## Custom procs. Sourced before the guard (so the guard can use them) because
## this compile hook may run in a fresh Tcl interpreter without proc.tcl.
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado/proc/sim_management.tcl

########################################################
## Guard: only act when a Rogue co-sim source is present
########################################################
set rogueSimPath [RogueSimSources xsim]
if { ${rogueSimPath} == "" } {
   return
}

########################################################
## Locate the surf simlink/xsim/ build directory (../xsim/ sibling of the
## detected RogueTcpStream.vhd, mirroring vcs.tcl's ../vcs/ resolution). Older
## surf predates the xsim DPI backend (legacy axi/simlink/sim + src VHPI
## layout) and has no xsim/ directory: the Vivado xsim Rogue co-sim cannot run
## there. Fail fast with a clear pointer to "make vcs" instead of dying later
## on a missing Makefile or an elaboration error.
########################################################
set simTbDirName [file dirname [lindex ${rogueSimPath} 0]]
set simLinkDir ${simTbDirName}/../xsim/
if { ![file exists ${simLinkDir}] } {
   puts "*********************************************************************"
   puts "ERROR: this surf has no simlink/xsim/ DPI co-simulation backend."
   puts "  Rogue co-sim source found: [file normalize [lindex ${rogueSimPath} 0]]"
   puts "  The Vivado xsim (DPI-C) Rogue co-simulation requires a surf version"
   puts "  that provides an xsim/ directory beside the Rogue co-sim sources."
   puts "  Use 'make vcs' for VCS co-simulation with this (older) surf version."
   puts "*********************************************************************"
   exit -1
}

########################################################
## Version lock: the Rogue xsim DPI co-sim requires Vivado 2023.1+ (older xsc
## link drivers cannot resolve the host multiarch crt/libs for the DPI library).
## Sourced/checked only inside this Rogue-only path, so a non-Rogue xsim
## project on an older Vivado is completely unaffected. Covers both
## "make gui" -> Run Simulation and "make xsim", since this hook fires for both.
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado/proc/project_management.tcl
if { [VersionCheck 2023.1] < 0 } {
   exit -1
}

########################################################
## Check the zeromq library exists and its version
########################################################
RogueCheckLibZmq

########################################################
## Vivado's current working directory at compile-hook time
## is the simulation run directory; stage the built .so there
########################################################
set simOutDir [pwd]

########################################################
## Build libRogueSimLinkDpi.so via xsc (surf simlink/xsim/Makefile)
########################################################
cd ${simLinkDir}
exec make
exec cp -f [glob -directory ${simLinkDir} *.so] ${simOutDir}/.
exec make clean
cd $::env(PROJ_DIR)

########################################################
## GLIBCXX runtime fix fallback: LD_PRELOAD a libstdc++ new enough for the
## co-sim's libzmq (see RoguePreloadLibStdCpp). This compile-stage hook fires
## after launch_simulation has already frozen the xsim subprocess environment,
## so the effective fix is applied earlier: vivado/gui.tcl for the interactive
## "Run Simulation" path and vivado/xsim.tcl for the batch path. This call is
## kept as belt-and-suspenders for any flow that reaches the hook first.
########################################################
RoguePreloadLibStdCpp

########################################################
## The xelab "-sv_lib libRogueSimLinkDpi" binding is intentionally NOT set here.
## Vivado builds elaborate.sh from xsim.elaborate.xelab.more_options at
## launch_simulation start -- BEFORE this compile-stage (xsim.compile.tcl.pre)
## hook runs -- so a set_property here never reaches the xelab command line.
## The binding is registered at project-generation time in vivado/sources.tcl
## (guarded on the xsim RogueTcpStream backend) so it persists into the .xpr
## and is baked into the generated elaborate.sh. This hook only builds and
## stages libRogueSimLinkDpi.so, which must exist before elaboration.
########################################################
