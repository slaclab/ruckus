##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
## Hierarchical utilization of an implemented design, used by the VS Code
## "Resources" view:
##    vivado -mode batch -source ruckus_hier_util.tcl -tclargs <dcp> <rpt> [<depth>]

if { [llength $argv] < 2 } {
   puts "\n\n*********************************************************"
   puts "ruckus_hier_util.tcl: usage: -tclargs <checkpoint.dcp> <report.rpt> \[depth\]"
   puts "*********************************************************\n\n"
   exit -1
}
set dcp   [lindex $argv 0]
set rpt   [lindex $argv 1]
set depth [expr {[llength $argv] > 2 ? [lindex $argv 2] : 8}]

open_checkpoint ${dcp}
# Write to a temporary file so a partial report is never picked up
report_utilization -hierarchical -hierarchical_depth ${depth} -file ${rpt}.tmp
file rename -force ${rpt}.tmp ${rpt}
close_design
exit 0
