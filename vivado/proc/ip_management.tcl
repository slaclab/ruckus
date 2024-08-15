##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## Function to build all the IP cores
proc BuildIpCores { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Attempt to upgrade before building IP cores
   upgrade_ip [get_ips]

   # Check if the target project has IP cores
   if { [get_ips] != "" } {
      # Clear the list of IP cores
      set ipCoreList ""
      set ipList ""
      # Loop through each IP core
      foreach corePntr [get_ips] {
         # Set the IP core synthesis run name
         set ipSynthRun ${corePntr}_synth_1
         # Check if we need to build the IP core
         if { [get_runs ${ipSynthRun}] == ${ipSynthRun} } {
            if { [CheckIpSynth ${ipSynthRun}] != true } {
               reset_run  ${ipSynthRun}
               append ipSynthRun " "
               append ipCoreList ${ipSynthRun}
               append ipList ${corePntr}
               append ipList " "
            }
         }
      }
      # Check for IP cores to build
      if { ${ipCoreList} != "" } {
         # Build the IP Core
         launch_runs -quiet ${ipCoreList} -jobs $::env(PARALLEL_SYNTH)
         foreach waitPntr ${ipCoreList} {
            set src_rc [catch {
               wait_on_run ${waitPntr}
            } _RESULT]
         }
      }
#      foreach corePntr ${ipList} {
#         # Disable the IP Core's XDC (so it doesn't get implemented at the project level)
#         set xdcPntr [get_files -quiet -of_objects [get_files ${corePntr}.xci] -filter {FILE_TYPE == XDC}]
#         if { ${xdcPntr} != "" } {
#            set_property is_enabled false [get_files ${xdcPntr}]
#         }
#         # Set the IP core synthesis run name
#         set ipSynthRun ${corePntr}_synth_1
#         # Reset the "needs_refresh" flag
#         set_property needs_refresh false [get_runs ${ipSynthRun}]
#      }
   }
   # Refresh the project
   update_compile_order -quiet -fileset sources_1
}

## Copies all IP cores from the build tree to source tree
proc CopyIpCores { {copyDcp true} {copySourceCode false} } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Make sure the IP Cores have been built
   BuildIpCores

   # Get the IP list
   set ipList [read [open ${OUT_DIR}/ipList.txt]]

   # Check if the target project has IP cores
   if { ${ipList} != "" } {
      # Loop through the IP cores
      foreach corePntr [get_ips] {
         # Create a copy of the IP Core in the source tree
         foreach coreFilePntr ${ipList} {
            if { [ string match *${corePntr}* ${coreFilePntr} ] } {
               # Overwrite the existing .xci file in the source tree
               set SRC [get_files ${corePntr}.xci]
               set DST ${coreFilePntr}
               exec cp ${SRC} ${DST}
               puts "exec cp ${SRC} ${DST}"
               # Check if copying .DCP output
               if { ${copyDcp} } {
                  # Overwrite the existing .dcp file in the source tree
                  if { $::env(VIVADO_VERSION) >= 2020.2 } {
                     set SRC "${OUT_DIR}/${VIVADO_PROJECT}.runs/${corePntr}_synth_1/${corePntr}.dcp"
                  } else {
                     set SRC [string map {.xci .dcp} ${SRC}]
                  }
                  set DST [string map {.xci .dcp} ${DST}]
                  exec cp ${SRC} ${DST}
                  puts "exec cp ${SRC} ${DST}"
               }
               # Check if copying IP Core's the source code
               if { ${copySourceCode} } {
                  set SRC [get_files ${corePntr}.xci]
                  set DST ${coreFilePntr}
                  set SRC  [string trim ${SRC} ${corePntr}.xci]
                  set DST  [string trim ${DST} ${corePntr}.xci]
                  exec cp -rf ${SRC} ${DST}
                  puts "exec cp -rf ${SRC} ${DST}"
               }
            }
         }
      }
   }
}

## Copies all block designs from the build tree to source tree
proc CopyBdCores { {createTcl true} {copySourceCode false} } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Get the BD list
   set bdList [read [open ${OUT_DIR}/bdList.txt]]

   # Check if the target project has block designs
   if { ${bdList} != "" } {
      # Loop through the has block designs
      foreach bdPntr [get_files {*.bd}] {
         # Create a copy of the IP Core in the source tree
         foreach bdFilePntr ${bdList} {
            set strip [file rootname [file tail ${bdPntr}]]
            if { [ string match *${strip}.bd ${bdFilePntr} ] } {
               # Overwrite the existing .bd file in the source tree
               set SRC ${bdPntr}
               set DST ${bdFilePntr}
               exec cp ${SRC} ${DST}
               puts "exec cp ${SRC} ${DST}"
               # Check if creating a .TCL file for the source tree
               if { ${createTcl} } {
                  set fbasename [file rootname ${bdFilePntr}]
                  write_bd_tcl -force ${fbasename}.tcl
               }
               # Check if copying block design's the source code
               if { ${copySourceCode} } {
                  set SRC ${bdPntr}
                  set DST ${bdFilePntr}
                  set SRC  [string trim ${SRC} ${strip}.bd]
                  set DST  [string trim ${DST} ${strip}.bd]
                  exec cp -rf ${SRC} ${DST}
                  puts "exec cp -rf ${SRC} ${DST}"
               }
            }
         }
      }
   }
}

## Generate the wrappers for all the BD files and add them to sources_1 fileset
proc GenerateBdWrappers { } {

   # Get a list of .bd files
   set bdList [get_files {*.bd}]

   # Check if any .bd files exist
   if { ${bdList} != "" } {
      # Loop through the has block designs
      foreach bdpath ${bdList} {
         # Create the wrapper
         set wrapper_path [make_wrapper -force -files [get_files $bdpath] -top]
         # Add the VHDL (or Verilog) to the project
         add_files -force -fileset sources_1 ${wrapper_path}
      }
   }

}
