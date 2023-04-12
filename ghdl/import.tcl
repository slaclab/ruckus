#!/usr/bin/tclsh
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Init the global variable
set ::DIR_PATH ""

# Remove the existing source directories
exec rm -rf $::env(OUT_DIR)

# Create a new directory
exec mkdir $::env(OUT_DIR)

# Load ruckus library (ruckus.BuildInfoPkg.vhd only)
GenBuildString $::env(OUT_DIR)

# Load the top-level ruckus.tcl
loadRuckusTcl $::env(PROJ_DIR)
