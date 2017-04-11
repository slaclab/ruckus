##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Post-Route Build Script

########################################################
## Get variables and Custom Procedures
########################################################
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl
set topLevel [get_property top [current_fileset]]

########################################################
## Check if passed timing
########################################################
if { [CheckTiming false] == true } {
   # Make the GIT build tag
   GitBuildTag

   ########################################################
   ## Make a copy of the routed .DCP file for future use 
   ## in an "incremental compile" build
   ########################################################
   if { ${VIVADO_VERSION} >= 2015.3 } {
      exec cp -f ${IMPL_DIR}/${topLevel}_routed.dcp ${OUT_DIR}/IncrementalBuild.dcp
   }
   
   #########################################################
   ## Check if need to include YAML files with the .BIT file
   #########################################################
   source ${RUCKUS_DIR}/vivado_pyrogue.tcl
   if { [file exists ${PROJ_DIR}/yaml/000TopLevel.yaml] == 1 } {
      source ${RUCKUS_DIR}/vivado_cpsw.tcl
   }
   
   #########################################################
   ## Check if SDK's .sysdef file exists
   #########################################################
   # Check if SDK_SRC_PATH is a valid path
   if { [expr [info exists ::env(SDK_SRC_PATH)]] == 1 } {
      # Check for .sysdef file (generated when using Microblaze)
      if { [file exists ${OUT_DIR}/${VIVADO_PROJECT}.runs/impl_1/${PROJECT}.sysdef] == 1 } {
         # Check if custom SDK exist
         if { [file exists ${VIVADO_DIR}/sdk.tcl] == 1 } {   
            source ${VIVADO_DIR}/sdk.tcl
         } else {
            set SDK_PRJ_RDY false
            while { ${SDK_PRJ_RDY} != true } {
               set src_rc [catch {exec xsdk -batch -source ${RUCKUS_DIR}/vivado_sdk_prj.tcl >@stdout}]       
               if {$src_rc} {
                  puts "Retrying to build SDK project"
                  exec rm -rf ${SDK_PRJ}
               } else {
                  set SDK_PRJ_RDY true
               }         
            }
            # Generate .ELF
            set src_rc [catch {exec xsdk -batch -source ${RUCKUS_DIR}/vivado_sdk_elf.tcl >@stdout}]    
            # Add .ELF to the .bit file
            source ${RUCKUS_DIR}/vivado_sdk_bit.tcl       
         }
      }
   }

   # Target specific post_route script
   SourceTclFile ${VIVADO_DIR}/post_route.tcl
}