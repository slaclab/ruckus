##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

########################################################
## Get variables and Custom Procedures
########################################################
set RUCKUS_DIR $::env(RUCKUS_DIR)
source -quiet ${RUCKUS_DIR}/vivado_env_var.tcl
source -quiet ${RUCKUS_DIR}/vivado_proc.tcl

# Check project configuration for errors
if { [CheckPrjConfig] != true } {
   exit -1
}

# Open the project
open_project -quiet ${VIVADO_PROJECT}

########################################################
## Setup the top-level generics
########################################################

# Generate the build string 
binary scan [encoding convertto ascii $::env(BUILD_STRING)] c* bstrAsic
set buildString ""
foreach decChar ${bstrAsic} {
   set hexChar [format %02X ${decChar}]
   set buildString ${buildString}${hexChar}
}
for {set n [string bytelength ${buildString}]} {$n < 512} {incr n} {
   set padding "0"
   set buildString ${buildString}${padding}
}

# Generate the Firmware Version string
scan ${PRJ_VERSION} %x decVer
set fwVersion [format %08X ${decVer}]

# Generate the GIT SHA-1 string
set gitHash $::env(GIT_HASH_LONG)

# Set the top-level generic values
set buildInfo "BUILD_INFO_G=2240'h${gitHash}${fwVersion}${buildString}"
set_property generic ${buildInfo} -objects [current_fileset]

########################################################
## Load the source code
########################################################

# By default, set the Top Level file same as project name
set_property top ${PROJECT} [current_fileset]
set_property top "glbl"     [get_filesets sim_1]

# Init the global variable
set ::DIR_PATH ""
set ::IP_LIST  ""

# Load the top-level ruckus.tcl file
loadRuckusTcl ${PROJ_DIR}

# Close and reopen project
VivadoRefresh ${VIVADO_PROJECT}

# Check if we can upgrade IP cores
if { $::IP_LIST != "" } {
   foreach ipPntr $::IP_LIST {
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
if { [expr [info exists ::env(REMOVE_UNUSED_CODE)]] == 1 } {
   RemoveUnsuedCode
}

# Close the project
close_project
