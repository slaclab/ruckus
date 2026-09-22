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

# Check if CDC violations are not allowed
# Note: This check runs after opt_design (instead of after synthesis) because the
#       out-of-context IP netlists and their XDC constraints are not linked into
#       the design until implementation.  Clocks generated inside the IP (for
#       example the GT recovered and transmit clocks) do not exist yet at the end
#       of synthesis, and report_cdc only analyzes paths where clocks are defined
#       on both the source and destination sides.
# Note: ALLOW_CDC_VIOLATIONS is optional for now.  If the variable is undefined,
#       the CDC report and the CDC check are both skipped.  In the future the
#       variable will be required and the CDC check will always be executed.
if { [info exists ::env(ALLOW_CDC_VIOLATIONS)] && [VersionCompare 2018.1] >= 0 } {
   # Any value other than zero (or false) bypasses the CDC check
   set AllowCdcViolations [expr {![string is false -strict $::env(ALLOW_CDC_VIOLATIONS)]}]
   if { ${AllowCdcViolations} != 1 } {
      # Run the CDC reporter
      report_cdc -details -all_checks_per_endpoint -severity "Critical" -file ${IMPL_DIR}/${PROJECT}_cdc_impl.rpt
      # Get the un-waived CDC violations with a "Critical" severity
      set CdcViolations [get_cdc_violations -quiet -filter {SEVERITY == "Critical" && !IS_WAIVED}]
      # Check if any critical CDC violations during implementation
      if { [llength ${CdcViolations}] > 0 } {
         puts "\n\n\nCritical CDC violations detected during implementation!!!\n"
         # Dump the CDC report to the terminal for the user to review
         set fdCdc [open ${IMPL_DIR}/${PROJECT}_cdc_impl.rpt r]
         puts [read ${fdCdc}]
         close ${fdCdc}
         puts "\nRefer to ${IMPL_DIR}/${PROJECT}_cdc_impl.rpt for the full CDC report\n\n"
         exit -1
      }
   }
}

if { [VersionCompare 2020.1] >= 0  && $::env(REPORT_QOR) == 1 } {
   report_qor_assessment  -file ${IMPL_DIR}/${PROJECT}_qor_assessment_opted.rpt
   report_qor_suggestions -file ${IMPL_DIR}/${PROJECT}_qor_suggestions_opted.rpt
}

# Target specific script
SourceTclFile ${VIVADO_DIR}/post_opt_run.tcl
