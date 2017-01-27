##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Sources Batch-Mode Build Script

########################################################
## Get variables and Custom Procedures
########################################################
set RUCKUS_DIR $::env(RUCKUS_DIR)
source -quiet ${RUCKUS_DIR}/vivado_env_var.tcl
source -quiet ${RUCKUS_DIR}/vivado_proc.tcl

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# By default, set the Top Level file same as project name
set_property top ${PROJECT} [current_fileset]
set_property top "glbl"     [get_filesets sim_1]

# Init the global variable
set ::DIR_PATH ""

# Load the top-level ruckus.tcl file
loadRuckusTcl ${PROJ_DIR}

# Check if SDK_SRC_PATH is a valid path
if { [CheckSdkSrcPath] != true } {
   close_project
   exit -1
}

# Close and reopen project
VivadoRefresh ${VIVADO_PROJECT}

# Check if we can upgrade IP cores
set ipList [get_ips]
if { ${ipList} != "" } {
   foreach ipPntr ${ipList} {
      generate_target all [get_ips ${ipPntr}]
      # Build the IP Core
      puts "\nUpgrading ${ipPntr}.xci IP Core ..."
      upgrade_ip [get_ips ${ipPntr}]
      puts "... Upgrade Complete!\n"
      # Check if we need to create the IP_run
      set ipSynthRun ${ipPntr}_synth_1
      if { [get_runs ${ipSynthRun}] != ${ipSynthRun}} {
         create_ip_run [get_ips ${ipPntr}]      
      }
   }
}

# Target specific source setup script
VivadoRefresh ${VIVADO_PROJECT}
SourceTclFile ${VIVADO_DIR}/sources.tcl

# Remove all unused code
update_compile_order -quiet -fileset sources_1
update_compile_order -quiet -fileset sim_1
if { [expr [info exists ::env(KEEP_UNUSED_CODE)]] != 1 } {
   RemoveUnsuedCode
}

# Close the project
close_project
