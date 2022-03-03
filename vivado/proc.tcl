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
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/project_management.tcl
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/debug_probes.tcl
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/vivado/proc/code_loading.tcl

## Function to build all the IP cores
proc BuildIpCores { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

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
         launch_runs -quiet ${ipCoreList} -jobs [GetCpuNumber]
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

## Generate Verilog simulation models for a specific .dcp file
proc DcpToVerilogSim {dcpName} {
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   set filePntr [get_files ${dcpName}.dcp]
   if { [file extension ${filePntr}] == ".dcp" } {
      ## Open the check point
      open_checkpoint ${filePntr}
      ## Generate the output file path
      set simName [file tail ${filePntr}]
      set simName [string map {".dcp" "_sim.v"} ${simName}]
      set simFile ${OUT_DIR}/${PROJECT}_project.sim/${simName}
      ## Write the simulation model to the build tree
      write_verilog -force -mode funcsim -file ${simFile}
      ## close the check point
      close_design
      # Add the Simulation Files
      add_files -quiet -fileset sim_1 ${simFile}
      # Force Absolute Path (not relative to project)
      set_property PATH_MODE AbsoluteFirst [get_files ${simFile}]
   }
}

## Generate .vho files for all .DCP in a project
proc CreateDcpVhoFiles {} {
   # Get a list of .bd files
   set dcpList [get_files {*.dcp}]
   # Check if any .bd files exist
   if { ${dcpList} != "" } {
      # Loop through the has block designs
      foreach dcppath ${dcpList} {
         # Get the base name
         set fbasename [file rootname ${dcppath}]
         # Open the check point
         open_checkpoint ${dcppath}
         # Write the simulation model to the build tree
         write_vhdl -force -mode pin_planning ${fbasename}.vho
         # close the check point
         close_design
         # Put the .vho file in a list and remove "extra" spaces and remove lines with `-`
         set vhoFile [lsearch -regexp -inline -all [lreplace [split [read [open ${fbasename}.vho r]] "\n"] end end] {^[^-]}]
         # Format for component declaration
         set vhoFile [string map {entity component} $vhoFile]
         set vhoFile [string map {end "end component"} $vhoFile]
         # Remove the first 3 lines and last 3 lines
         set vhoFile [lreplace [lreplace $vhoFile 0 3] end-2 end]
         # Write to overwrite the existing .vho file
         set fp [open ${fbasename}.vho w]
         foreach vhoLine ${vhoFile} {puts $fp $vhoLine}
         close $fp
      }
   }
}

## Create .MCS PROM
proc CreatePromMcs { } {
   if { [file exists $::env(PROJ_DIR)/vivado/promgen.tcl] == 1 } {
      source $::env(RUCKUS_DIR)/vivado/promgen.tcl
   }
}

## Create .BIT file
proc CreateFpgaBit { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl
   set imagePath "${IMAGES_DIR}/$::env(IMAGENAME)"
   set topModule [file rootname [file tail [glob -dir ${IMPL_DIR} *.bit]]]

   # Copy the .BIT file to image directory
   exec cp -f ${IMPL_DIR}/${topModule}.bit ${imagePath}.bit
   puts "Bit file copied to ${imagePath}.bit"

   # Check if gzip-ing the image files
   if { $::env(GZIP_BUILD_IMAGE) != 0 } {
      exec gzip -c -f -9 ${IMPL_DIR}/${topModule}.bit > ${imagePath}.bit.gz
   }

   # Copy the .BIN file to image directory
   if { $::env(GEN_BIN_IMAGE) != 0 } {
      exec cp -f ${IMPL_DIR}/${topModule}.bin ${imagePath}.bin
      if { $::env(GZIP_BUILD_IMAGE) != 0 } {
         exec gzip -c -f -9 ${IMPL_DIR}/${topModule}.bin > ${imagePath}.bin.gz
      }
   }

   # Copy the .ltx file (if it exists)
   CopyLtxFile

   # Check for Vivado 2019.2 (or newer)
   if { [VersionCompare 2019.2] >= 0 } {
      # Try to generate the .XSA file
      set src_rc [catch { write_hw_platform -fixed -force -include_bit -file ${imagePath}.xsa } _RESULT]

   # Else Vivado 2019.1 (or older)
   } else {
      # Try to generate the .HDF file
      write_hwdef -force -file ${imagePath}.hdf
   }

   # Create the MCS file (if target/vivado/promgen.tcl exists)
   CreatePromMcs
}

## Create Versal Output files
proc CreateVersalOutputs { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl
   set imagePath "${IMAGES_DIR}/$::env(IMAGENAME)"
   set topModule [file rootname [file tail [glob -dir ${IMPL_DIR} *.pdi]]]

   # Copy the .pdi file to image directory
   exec cp -f ${IMPL_DIR}/${topModule}.pdi ${imagePath}.pdi
   puts "PDI file copied to ${imagePath}.pdi"

   # Check if gzip-ing the image files
   if { $::env(GZIP_BUILD_IMAGE) != 0 } {
      exec gzip -c -f -9 ${IMPL_DIR}/${topModule}.pdi > ${imagePath}.pdi.gz
   }

   # Copy the .ltx file (if it exists)
   CopyLtxFile
}

## Create tar.gz of all cpsw files in firmware
proc CreateCpswTarGz { } {
   if { [file exists $::env(PROJ_DIR)/yaml/000TopLevel.yaml] == 1 } {
      source $::env(RUCKUS_DIR)/vivado/cpsw.tcl
   } else {
      puts "$::env(PROJ_DIR)/yaml/000TopLevel.yaml does not exist"
   }
}

## Create tar.gz of all pyrogue files in firmware
proc CreatePyRogueTarGz { } {
   source $::env(RUCKUS_DIR)/vivado/pyrogue.tcl
}



## Checking Timing Function
proc CheckTiming { {printTiming true} } {
   # Get the timing/routing results
   set WNS [get_property STATS.WNS [get_runs impl_1]]
   set TNS [get_property STATS.TNS [get_runs impl_1]]
   set WHS [get_property STATS.WHS [get_runs impl_1]]
   set THS [get_property STATS.THS [get_runs impl_1]]
   set TPWS [get_property STATS.TPWS [get_runs impl_1]]
   set FAILED_NETS [get_property STATS.FAILED_NETS [get_runs impl_1]]

   # Check for timing and routing errors
   if { ${WNS}<0.0 || ${TNS}<0.0 }  { set setupError true } else { set setupError false }
   if { ${WHS}<0.0 || ${THS}<0.0 }  { set holdError  true } else { set holdError  false }
   if { ${TPWS}<0.0 }               { set pulseError true } else { set pulseError false }
   if { ${FAILED_NETS}>0.0 }        { set failedNet  true } else { set failedNet  false }

   # Check if any timing/routing error detected
   if { ${setupError} || ${holdError} || ${pulseError} || ${failedNet} } {

      # Check if we are printing out the results
      if { ${printTiming} == true } {
         puts "\n\n\n\n\n********************************************************"
         puts "********************************************************"
         puts "********************************************************"
         puts "The design did not meet timing or unable to route:"
         puts "\tSetup: Worst Negative Slack (WNS): ${WNS} ns"
         puts "\tSetup: Total Negative Slack (TNS): ${TNS} ns"
         puts "\tHold: Worst Hold Slack (WHS): ${WHS} ns"
         puts "\tHold: Total Hold Slack (THS): ${THS} ns"
         puts "\tPulse Width: Total Pulse Width Negative Slack (TPWS): ${TPWS} ns"
         puts "\tRouting: Number of Failed Nets: ${FAILED_NETS}"
         puts "********************************************************"
         puts "********************************************************"
         puts "********************************************************\n\n\n\n\n"
      }

      # Get the value of all the timing ignore flags
      set tigAll   [expr {[info exists ::env(TIG)]       && [string is true -strict $::env(TIG)]}]
      set tigSetup [expr {[info exists ::env(TIG_SETUP)] && [string is true -strict $::env(TIG_SETUP)]}]
      set tigHold  [expr {[info exists ::env(TIG_HOLD)]  && [string is true -strict $::env(TIG_HOLD)]}]
      set tigPulse [expr {[info exists ::env(TIG_PULSE)] && [string is true -strict $::env(TIG_PULSE)]}]

      # Override the flags
      if { ${tigSetup} == 1 } { set setupError false }
      if { ${tigHold}  == 1 } { set holdError  false }
      if { ${tigPulse} == 1 } { set pulseError false }
      if { ${tigAll}   == 1 } {
         set setupError false
         set holdError  false
         set pulseError false
      }

      # Recheck the flags after the custom overrides
      if { ${setupError} || ${holdError} || ${pulseError} || ${failedNet} } {
         return false

      # Else overriding the timing error flag
      } else {
         return true
      }

   # Else no timing or routing errors detected
   } else {
      return true
   }
}

## Check if SDK_SRC_PATH (or VITIS_SRC_PATH) exist, then it checks for a valid path
proc CheckSdkSrcPath { } {

   # Check for Vivado 2019.2 (or newer)
   if { [VersionCompare 2019.2] > 0 } {
      if { [expr [info exists ::env(VITIS_SRC_PATH)]] == 1 } {
         if { [expr [file exists $::env(VITIS_SRC_PATH)]] == 0 } {
            puts "\n\n\n\n\n********************************************************"
            puts "********************************************************"
            puts "********************************************************"
            puts "VITIS_SRC_PATH: $::env(VITIS_SRC_PATH) does not exist"
            puts "********************************************************"
            puts "********************************************************"
            puts "********************************************************\n\n\n\n\n"
            return false
         }
      }

   # Else Vivado 2019.1 (or older)
   } else {
      if { [expr [info exists ::env(SDK_SRC_PATH)]] == 1 } {
         if { [expr [file exists $::env(SDK_SRC_PATH)]] == 0 } {
            puts "\n\n\n\n\n********************************************************"
            puts "********************************************************"
            puts "********************************************************"
            puts "SDK_SRC_PATH: $::env(SDK_SRC_PATH) does not exist"
            puts "********************************************************"
            puts "********************************************************"
            puts "********************************************************\n\n\n\n\n"
            return false
         }
      }
   }

   return true
}


## Print Message for users to open GUI if error detected
proc PrintOpenGui { errMsg } {
   puts "\n\n\n\n\n********************************************************"
   puts ${errMsg}
   puts "Please open the GUI ('make gui') and view the 'Messages' tab for list of all errors"
   puts "********************************************************\n\n\n\n\n"
}

## Check if the Synthesize is completed
proc CheckSynth { {flags ""} } {
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   if { ${flags} != "" } {
      # Loop through the synth runs
      foreach sythRun [get_runs {*synth_1}] {
         # Set the synthesis log file path
         set synthLog "${OUT_DIR}/${VIVADO_PROJECT}.runs/${sythRun}/runme.log"
         # Check if log file exists
         if { [file exists ${synthLog}] == 1 } {
            # Check for errors during synthesis
            set NumErr [llength [lsearch -all -regexp [split [read [open ${synthLog}]]] "^ERROR:"]]
            if { ${NumErr} != 0 } {
               set errReport [read [open ${synthLog}]]
               set errReport [split ${errReport} "\n"]
               set listErr ""
               foreach msg ${errReport} {
                  if { [string match {*ERROR:*} ${msg}] == 1 } {
                     set trim1 ""
                     set trim2 ""
                     regexp {([^\]]+):?(/.*)} "${msg}" trim1 trim2
                     if { ${trim1} != "" } {
                        set listErr "${listErr}\n${trim1}"
                     } else {
                        set listErr "${listErr}\n${msg}"
                     }
                  }
               }
               puts "\n\n\n\n\n********************************************************"
               puts "********************************************************"
               puts "********************************************************"
               puts "The following error(s) were detected during synthesis:${listErr}"
               puts "********************************************************"
               puts "********************************************************"
               puts "********************************************************\n\n\n\n\n"
               return false
            }
         }
      }
   }
   if { [get_property NEEDS_REFRESH [get_runs synth_1]] == 1 } {
      set errmsg "\t\[get_property NEEDS_REFRESH \[get_runs synth_1\]\] == 1,\n"
      set errmsg "${errmsg}\twhich means the synthesis is now \"out-of-date\".\n"
      set errmsg "${errmsg}\t\"out-of-date\" typically happens when editing\n"
      set errmsg "${errmsg}\tsource code during synthesis process."
   } elseif { [get_property PROGRESS [get_runs synth_1]] != "100\%" } {
      set errmsg "\t\[get_property PROGRESS \[get_runs synth_1\]\] != 100\%\n"
   } elseif { [get_property STATUS [get_runs synth_1]] != "synth_design Complete!" } {
      set errmsg "\t\[get_property STATUS \[get_runs synth_1\]\] != \"synth_design Complete!\"\n"
   } else {
      # Check if tracking GIT hash in build system
      if { $::env(GIT_BYPASS) == 0 } {
         # Check if file exists
         if { [file exists ${SYN_DIR}/git.hash] == 1 } {
            # Git the GIT Hash saved in the synth_1 directory
            set gitHash [string trim [read [open ${SYN_DIR}/git.hash]]]
            # Compare the file's hash to current Makefile hash
            if { [string match $::env(GIT_HASH_LONG) ${gitHash}] != 1 } {
               # puts "GIT HASH mismatch detected"
               return false
            } else {
               # puts "GIT HASH match detected"
               return true
            }
         } else {
            # Error: File does not exist
            return false;
         }
      } else {
         # Bypassing GIT hash tracking
         return true
      }
   }
   if { ${flags} != "" } {
      puts "\n\nSynthesize is incompleted due to the following:"
      puts "${errmsg}\n\n"
   }
   return false
}

## Check if the Synthesize is completed
proc CheckIpSynth { ipSynthRun {flags ""} } {
   if { [get_property NEEDS_REFRESH [get_runs ${ipSynthRun}]] == 1 } {
      set errmsg "\t\[get_property NEEDS_REFRESH \[get_runs ${ipSynthRun}\]\] == 1,\n"
      set errmsg "${errmsg}\twhich means the synthesis is now \"out-of-date\".\n"
      set errmsg "${errmsg}\t\"out-of-date\" typically happens when editing\n"
      set errmsg "${errmsg}\tsource code during synthesis process."
   } elseif { [get_property PROGRESS [get_runs ${ipSynthRun}]] != "100\%" } {
      set errmsg "\t\[get_property PROGRESS \[get_runs ${ipSynthRun}\]\] != 100\%\n"
   } elseif { [get_property STATUS [get_runs ${ipSynthRun}]] != "synth_design Complete!" } {
      set errmsg "\t\[get_property STATUS \[get_runs ${ipSynthRun}\]\] != \"synth_design Complete!\"\n"
   } else {
      return true
   }
   if { ${flags} != "" } {
      puts "\n\nSynthesize's ${ipSynthRun} run is incompleted due to the following:"
      puts "${errmsg}\n\n"
   }
   return false
}

## Check if the Implementation is completed
proc CheckImpl { {flags ""} } {
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl
   # Check for errors during synthesis
   if { ${flags} != "" } {
      set NumErr [llength [lsearch -all -regexp [split [read [open ${IMPL_DIR}/runme.log]]] "^ERROR:"]]
      if { ${NumErr} != 0 } {
         set errReport [read [open ${IMPL_DIR}/runme.log]]
         set errReport [split ${errReport} "\n"]
         set listErr ""
         foreach msg ${errReport} {
            if { [string match {*ERROR:*} ${msg}] == 1 } {
               set listErr "${listErr}\n${msg}"
            }
         }
         puts "\n\n\n\n\n********************************************************"
         puts "********************************************************"
         puts "********************************************************"
         puts "The following error(s) were detected during implementation:${listErr}"
         # Check for DRC error during routing
         if { [string match {*\[Vivado_Tcl 4-16\]*} ${listErr}] == 1 } {
            puts "# open_checkpoint ${IMPL_DIR}/${PROJECT}_routed_error.dcp"
            open_checkpoint -quiet ${IMPL_DIR}/${PROJECT}_routed_error.dcp
            puts "# report_drc -ruledecks {default}"
            set drcReport [report_drc -ruledecks {default} -verbose -return_string]
            puts ${drcReport}
            close_design
         }
         puts "********************************************************"
         puts "********************************************************"
         puts "********************************************************\n\n\n\n\n"
         return false
      }
   }

   if { [isVersal] } {
      set completeMsg "write_device_image Complete!"
   } else {
      set completeMsg "write_bitstream Complete!"
   }

   if { [get_property PROGRESS [get_runs impl_1]] != "100\%" } {
      set errmsg "\t\[get_property PROGRESS \[get_runs impl_1\]\] != 100\%\n"
   } elseif { [get_property STATUS [get_runs impl_1]] != ${completeMsg} } {
      set errmsg "\t\[get_property STATUS \[get_runs impl_1\]\] != \"${completeMsg}\"\n"
   } else {
      return true
   }
   if { ${flags} != "" } {
      puts "\n\nImplementation is incompleted due to the following:"
      puts "${errmsg}\n\n"
   }
   return false
}

## Print the VCS build complete message
proc VcsCompleteMessage {dirPath rogueSim} {
   puts "\n\n********************************************************"
   puts "The VCS simulation script has been generated."
   puts "To compile and run the simulation:"
   puts "\t\$ cd ${dirPath}/"
   if { ${rogueSim} == true } {
      if { $::env(SHELL) != "/bin/bash" } {
         puts "\t\$ source setup_env.csh"
      } else {
         puts "\t\$ source setup_env.sh"
      }
   }
   puts "\t\$ ./sim_vcs_mx.sh"
   puts "\t\$ ./simv -gui=dve (or $ ./simv -gui=verdi -verdi_opts -sx)"
   puts "********************************************************\n\n"
}

## Print the DCP build complete message
proc DcpCompleteMessage { filename } {
   puts "\n\n********************************************************"
   puts "The new .dcp file is located here:"
   puts ${filename}
   puts "********************************************************\n\n"
}

###############################################################
#### Partial Reconfiguration Functions ########################
###############################################################

## Import static checkpoint
proc ImportStaticReconfigDcp { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Check for valid file path
   if { [file exists ${RECONFIG_CHECKPOINT}] != 1 } {
      puts "\n\n\n\n\n********************************************************"
      puts "${RECONFIG_CHECKPOINT} doesn't exist"
      puts "********************************************************\n\n\n\n\n"
   }

   # Backup the Partial Reconfiguration RTL Block checkpoint and reports
   exec cp -f ${SYN_DIR}/${PRJ_TOP}.dcp                   ${SYN_DIR}/${PRJ_TOP}_backup.dcp
   exec mv -f ${SYN_DIR}/${PRJ_TOP}_utilization_synth.rpt ${SYN_DIR}/${PRJ_TOP}_utilization_synth_backup.rpt
   exec mv -f ${SYN_DIR}/${PRJ_TOP}_utilization_synth.pb  ${SYN_DIR}/${PRJ_TOP}_utilization_synth_backup.pb

   # Open the static design check point
   open_checkpoint ${RECONFIG_CHECKPOINT}

   # Clear out the targeted reconfigurable module logic
   if { [get_property IS_BLACKBOX [get_cells ${RECONFIG_ENDPOINT}]]  != 1 } {
      update_design -cell ${RECONFIG_ENDPOINT} -black_box
   }

   # Lock down all placement and routing of the static design
   lock_design -level routing

   # Read the targeted reconfiguration RTL block's checkpoint
   read_checkpoint -cell ${RECONFIG_ENDPOINT} ${SYN_DIR}/${PRJ_TOP}.dcp

   # Check for DRC
   report_drc -file ${SYN_DIR}/${PRJ_TOP}_reconfig_drc.txt

   # Overwrite the existing synth_1 checkpoint, which is the
   # checkpoint that impl_1 will refer to
   write_checkpoint -force ${SYN_DIR}/${PRJ_TOP}.dcp

   # Generate new top level reports to update GUI display
   report_utilization -file ${SYN_DIR}/${PRJ_TOP}_utilization_synth.rpt -pb ${SYN_DIR}/${PRJ_TOP}_utilization_synth.pb

   # Get the name of the static build before closing .DCP file
   set staticTop [get_property  TOP [current_design]]

   # Close the opened design before launching the impl_1
   close_design

   # Set the top-level RTL (required for Ultrascale)
   set_property top ${staticTop} [current_fileset]

   # SYNTH is not out-of-date
   set_property NEEDS_REFRESH false [get_runs synth_1]
}

## Export partial configuration bin file
proc ExportStaticReconfigDcp { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Make a copy of the .dcp file with a "_static" suffix
   exec cp -f ${IMPL_DIR}/${PROJECT}_routed.dcp ${IMAGES_DIR}/$::env(IMAGENAME)_static.dcp

   # Get a list of all the clear bin files
   set clearList [glob -nocomplain ${IMPL_DIR}/*_partial_clear.bin]
   if { ${clearList} != "" } {
      foreach clearFile ${clearList} {
         exec cp -f ${clearFile} ${IMAGES_DIR}/$::env(IMAGENAME)_clear.bin
      }
   }

   # Get a list of all the clear bit files
   set clearList [glob -nocomplain ${IMPL_DIR}/*_partial_clear.bit]
   if { ${clearList} != "" } {
      foreach clearFile ${clearList} {
         exec cp -f ${clearFile} ${IMAGES_DIR}/$::env(IMAGENAME)_clear.bit
      }
   }
}

## Export partial configuration bin file
proc ExportPartialReconfigBin { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Define the build output .bit file paths
   set partialBinFile ${IMPL_DIR}/${PRJ_TOP}_${RECONFIG_PBLOCK}_partial.bin
   set clearBinFile   ${IMPL_DIR}/${PRJ_TOP}_${RECONFIG_PBLOCK}_partial_clear.bin

   # Overwrite the build output's ${PROJECT}.bit
   exec cp -f ${partialBinFile} ${IMPL_DIR}/${PROJECT}.bin

   # Check for partial_clear.bit (generated for Ultrascale FPGAs)
   if { [file exists ${clearBinFile}] == 1 } {
      exec cp -f ${clearBinFile} ${IMAGES_DIR}/$::env(IMAGENAME)_clear.bin
   }
}

## Export partial configuration bit file
proc ExportPartialReconfigBit { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado/messages.tcl

   # Define the build output .bit file paths
   set partialBitFile ${IMPL_DIR}/${PRJ_TOP}_${RECONFIG_PBLOCK}_partial.bit
   set clearBitFile   ${IMPL_DIR}/${PRJ_TOP}_${RECONFIG_PBLOCK}_partial_clear.bit

   # Overwrite the build output's ${PROJECT}.bit
   exec cp -f ${partialBitFile} ${IMPL_DIR}/${PROJECT}.bit

   # Check for partial_clear.bit (generated for Ultrascale FPGAs)
   if { [file exists ${clearBitFile}] == 1 } {
      exec cp -f ${clearBitFile} ${IMAGES_DIR}/$::env(IMAGENAME)_clear.bit
   }
}

###############################################################
#### Hardware Debugging Functions #############################
###############################################################
