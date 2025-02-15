##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/proc.tcl
# \brief This script contains all the custom TLC procedures for Vivado

source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/shared/proc.tcl

source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/checking.tcl
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/code_loading.tcl
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/debug_probes.tcl
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/Dynamic_Function_eXchange.tcl
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/ip_management.tcl
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/output_files.tcl
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/project_management.tcl
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/sim_management.tcl
