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

# Check if you have write permission
CheckWritePermission

# Check if image directory doesn't exist
if { [file exists ${IMAGES_DIR}] != 1 } {   
   exec mkdir ${IMAGES_DIR}
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
set ::DIR_LIST ""
set ::IP_LIST  ""
set ::IP_FILES ""
set ::BD_FILES ""

# Load the top-level ruckus.tcl file
loadRuckusTcl ${PROJ_DIR}

# Change to AbsoluteFirst for source, simulation and constraint file sets
if { [get_files -of_objects [get_filesets {sources_1}]] != "" } {
   set_property PATH_MODE AbsoluteFirst [get_files -of_objects [get_filesets {sources_1}]]
}
if { [get_files -of_objects [get_filesets {sim_1}]] != "" } {
   set_property PATH_MODE AbsoluteFirst [get_files -of_objects [get_filesets {sim_1}]]
}
if { [get_files -of_objects [get_filesets {constrs_1}]] != "" } {
   set_property PATH_MODE AbsoluteFirst [get_files -of_objects [get_filesets {constrs_1}]]
}

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
if { $::env(REMOVE_UNUSED_CODE) != 0 } {
   RemoveUnsuedCode
}

# Write the DIR list
exec rm -f {${OUT_DIR}/dirList.txt}
set dirList [open ${OUT_DIR}/dirList.txt  w]
if { $::DIR_LIST != "" } {
   foreach dirPntr $::DIR_LIST {
      puts ${dirList} ${dirPntr}
   }
}
close ${dirList}

# Write the IP list
exec rm -f {${OUT_DIR}/ipList.txt}
set ipList [open ${OUT_DIR}/ipList.txt  w]
if { $::IP_FILES != "" } {
   foreach ipPntr $::IP_FILES {
      puts ${ipList} ${ipPntr}
   }
}
close ${ipList}

# Write the BD list
exec rm -f {${OUT_DIR}/bdList.txt}
set bdList [open ${OUT_DIR}/bdList.txt  w]
if { $::BD_FILES != "" } {
   foreach bdPntr $::BD_FILES {
      puts ${bdList} ${bdPntr}
   }
}
close ${bdList}

# Check if this is a dynamic partial reconfiguration build
if { ${RECONFIG_CHECKPOINT} != "" } {
   set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
}

# Close the project
close_project
