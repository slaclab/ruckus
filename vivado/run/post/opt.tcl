##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/run/post/opt.tcl

########################################################
## Get variables and Custom Procedures
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

if { [VersionCompare 2020.1] >= 0 } {
   report_qor_assessment  -file ${IMPL_DIR}/${PROJECT}_qor_assessment_opted.rpt
   report_qor_suggestions -file ${IMPL_DIR}/${PROJECT}_qor_suggestions_opted.rpt
}

# Target specific script
SourceTclFile ${VIVADO_DIR}/post_opt_run.tcl
