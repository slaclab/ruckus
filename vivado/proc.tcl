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

package require cmdline

###############################################################
#### General Functions ########################################
###############################################################

## Refresh a Vivado project
proc VivadoRefresh { vivadoProject } {
   close_project
   open_project -quiet ${vivadoProject}
}

## Achieve a Vivado Project
proc ArchiveProject { } {
   ## Make a copy of the TCL configurations
   set SYNTH_PRE     [get_property {STEPS.SYNTH_DESIGN.TCL.PRE}                 [get_runs synth_1]]
   set SYNTH_POST    [get_property {STEPS.SYNTH_DESIGN.TCL.POST}                [get_runs synth_1]]
   set OPT_PRE       [get_property {STEPS.OPT_DESIGN.TCL.PRE}                   [get_runs impl_1]]
   set OPT_POST      [get_property {STEPS.OPT_DESIGN.TCL.POST}                  [get_runs impl_1]]
   set PWR_PRE       [get_property {STEPS.POWER_OPT_DESIGN.TCL.PRE}             [get_runs impl_1]]
   set PWR_POST      [get_property {STEPS.POWER_OPT_DESIGN.TCL.POST}            [get_runs impl_1]]
   set PLACE_PRE     [get_property {STEPS.PLACE_DESIGN.TCL.PRE}                 [get_runs impl_1]]
   set PLACE_POST    [get_property {STEPS.PLACE_DESIGN.TCL.POST}                [get_runs impl_1]]
   set PWR_OPT_PRE   [get_property {STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.PRE}  [get_runs impl_1]]
   set PWR_OPT_POST  [get_property {STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.POST} [get_runs impl_1]]
   set PHYS_OPT_PRE  [get_property {STEPS.PHYS_OPT_DESIGN.TCL.PRE}              [get_runs impl_1]]
   set PHYS_OPT_POST [get_property {STEPS.PHYS_OPT_DESIGN.TCL.POST}             [get_runs impl_1]]
   set ROUTE_PRE     [get_property {STEPS.ROUTE_DESIGN.TCL.PRE}                 [get_runs impl_1]]
   set ROUTE_POST    [get_property {STEPS.ROUTE_DESIGN.TCL.POST}                [get_runs impl_1]]
   set WRITE_PRE     [get_property {STEPS.WRITE_BITSTREAM.TCL.PRE}              [get_runs impl_1]]
   set WRITE_POST    [get_property {STEPS.WRITE_BITSTREAM.TCL.POST}             [get_runs impl_1]]

   ## Remove the TCL configurations
   set_property STEPS.SYNTH_DESIGN.TCL.PRE                 "" [get_runs synth_1]
   set_property STEPS.SYNTH_DESIGN.TCL.POST                "" [get_runs synth_1]
   set_property STEPS.OPT_DESIGN.TCL.PRE                   "" [get_runs impl_1]
   set_property STEPS.OPT_DESIGN.TCL.POST                  "" [get_runs impl_1]
   set_property STEPS.POWER_OPT_DESIGN.TCL.PRE             "" [get_runs impl_1]
   set_property STEPS.POWER_OPT_DESIGN.TCL.POST            "" [get_runs impl_1]
   set_property STEPS.PLACE_DESIGN.TCL.PRE                 "" [get_runs impl_1]
   set_property STEPS.PLACE_DESIGN.TCL.POST                "" [get_runs impl_1]
   set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.PRE  "" [get_runs impl_1]
   set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.POST "" [get_runs impl_1]
   set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE              "" [get_runs impl_1]
   set_property STEPS.PHYS_OPT_DESIGN.TCL.POST             "" [get_runs impl_1]
   set_property STEPS.ROUTE_DESIGN.TCL.PRE                 "" [get_runs impl_1]
   set_property STEPS.ROUTE_DESIGN.TCL.POST                "" [get_runs impl_1]
   set_property STEPS.WRITE_BITSTREAM.TCL.PRE              "" [get_runs impl_1]
   set_property STEPS.WRITE_BITSTREAM.TCL.POST             "" [get_runs impl_1]

   ## Archive the project
   archive_project $::env(IMAGES_DIR)/$::env(PROJECT)_project.xpr.zip -force -include_config_settings

   ## Restore the TCL configurations
   set_property STEPS.SYNTH_DESIGN.TCL.PRE                 ${SYNTH_PRE}     [get_runs synth_1]
   set_property STEPS.SYNTH_DESIGN.TCL.POST                ${SYNTH_POST}    [get_runs synth_1]
   set_property STEPS.OPT_DESIGN.TCL.PRE                   ${OPT_PRE}       [get_runs impl_1]
   set_property STEPS.OPT_DESIGN.TCL.POST                  ${OPT_POST}      [get_runs impl_1]
   set_property STEPS.POWER_OPT_DESIGN.TCL.PRE             ${PWR_PRE}       [get_runs impl_1]
   set_property STEPS.POWER_OPT_DESIGN.TCL.POST            ${PWR_POST}      [get_runs impl_1]
   set_property STEPS.PLACE_DESIGN.TCL.PRE                 ${PLACE_PRE}     [get_runs impl_1]
   set_property STEPS.PLACE_DESIGN.TCL.POST                ${PLACE_POST}    [get_runs impl_1]
   set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.PRE  ${PWR_OPT_PRE}   [get_runs impl_1]
   set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.POST ${PWR_OPT_POST}  [get_runs impl_1]
   set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE              ${PHYS_OPT_PRE}  [get_runs impl_1]
   set_property STEPS.PHYS_OPT_DESIGN.TCL.POST             ${PHYS_OPT_POST} [get_runs impl_1]
   set_property STEPS.ROUTE_DESIGN.TCL.PRE                 ${ROUTE_PRE}     [get_runs impl_1]
   set_property STEPS.ROUTE_DESIGN.TCL.POST                ${ROUTE_POST}    [get_runs impl_1]
   set_property STEPS.WRITE_BITSTREAM.TCL.PRE              ${WRITE_PRE}     [get_runs impl_1]
   set_property STEPS.WRITE_BITSTREAM.TCL.POST             ${WRITE_POST}    [get_runs impl_1]
}

## Custom TLC source function
proc SourceTclFile { filePath } {
   if { [file exists ${filePath}] == 1 } {
      source ${filePath}
      return true;
   } else {
      return false;
   }
}

## Returns the FPGA family string
proc getFpgaFamily { } {
   return [get_property FAMILY [get_property {PART} [current_project]]]
}

## Get the number of CPUs available on the Linux box
proc GetCpuNumber { } {
   return [exec cat /proc/cpuinfo | grep processor | wc -l]
}

## Function for putting the TCL script into a wait (in units of seconds)
proc sleep {N} {
   after [expr {int($N * 1000)}]
}

## Function for comparing two list
proc ListComp { List1 List2 } {
   # Refer to https://wiki.tcl.tk/15489 under "[tcl_hack] - 2015-08-14 13:52:07"
   set DiffList {}
   foreach Item $List1 {
      if { [ lsearch -exact $List2 $Item ] == -1 } {
         lappend DiffList $Item
      }
   }
   foreach Item $List2 {
      if { [ lsearch -exact $List1 $Item ] == -1 } {
         if { [ lsearch -exact $DiffList $Item ] == -1 } {
            lappend DiffList $Item
         }
      }
   }
   return $DiffList
}

proc ::findFiles { baseDir pattern } {
   set dirs [ glob -nocomplain -type d [ file join $baseDir * ] ]
   set files {}
   foreach dir $dirs {
      lappend files {*}[ findFiles $dir $pattern ]
   }
   lappend files {*}[ glob -nocomplain -type f [ file join $baseDir $pattern ] ]
   return $files
}

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
      foreach corePntr ${ipList} {
         # Disable the IP Core's XDC (so it doesn't get implemented at the project level)
         set xdcPntr [get_files -quiet -of_objects [get_files ${corePntr}.xci] -filter {FILE_TYPE == XDC}]
         if { ${xdcPntr} != "" } {
            set_property is_enabled false [get_files ${xdcPntr}]
         }
         # Set the IP core synthesis run name
         set ipSynthRun ${corePntr}_synth_1
         # Reset the "needs_refresh" flag
         set_property needs_refresh false [get_runs ${ipSynthRun}]
      }
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
                  set SRC [string map {.xci .dcp} ${SRC}]
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
         make_wrapper -force -files [get_files $bdpath] -top
         # Get the base dir and file name
         set bd_wrapper_path [file dirname [lindex ${bdpath} 0]]
         set wrapperFileName [lsearch -inline [exec ls ${bd_wrapper_path}/hdl/] *_wrapper.vhd]
         # Add the VHDL (or Verilog) to the project
         add_files -force -fileset sources_1 ${bd_wrapper_path}/hdl/${wrapperFileName}
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
   if { [file exists ${OUT_DIR}/debugProbes.ltx] == 1 } {
      exec cp -f ${OUT_DIR}/debugProbes.ltx ${imagePath}.ltx
      puts "Debug Probes file copied to ${imagePath}.ltx"
   } elseif { [file exists ${IMPL_DIR}/debug_nets.ltx] == 1 } {
      exec cp -f ${IMPL_DIR}/debug_nets.ltx ${imagePath}.ltx
      puts "Debug Probes file copied to ${imagePath}.ltx"
   } else {
      puts "No Debug Probes found"
   }

   # Check for Vivado 2019.2 (or newer)
   if { [VersionCompare 2019.2] > 0 } {
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

## Remove unused code
proc RemoveUnsuedCode { } {
   update_compile_order -quiet -fileset sources_1
   update_compile_order -quiet -fileset sim_1
   remove_files [get_files -filter {IS_AUTO_DISABLED}]
}

## Build INFO
proc BuildInfo { } {
   exec rm -f $::env(PROJ_DIR)/build.info
   set fp [open "$::env(PROJ_DIR)/build.info" w+]
   puts $fp "PROJECT: $::env(PROJECT)"
   puts $fp "FW_VERSION: $::env(PRJ_VERSION)"
   puts $fp "BUILD_STRING: $::env(BUILD_STRING)"
   puts $fp "GIT_HASH: $::env(GIT_HASH_LONG)"
   close $fp
}

## Check if you have write permission
proc CheckWritePermission { } {
   set src_rc [catch {exec touch $::env(MODULES)/ruckus/LICENSE.txt}]
   if {$src_rc} {
      puts "\n\n\n\n\n********************************************************"
      puts "********************************************************"
      puts "********************************************************"
      puts "Unable to touch $::env(MODULES)/ruckus/LICENSE.txt"
      puts "Please verify that your Unix session has not expired"
      puts "********************************************************"
      puts "********************************************************"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
}

## Check for unsupported versions that ruckus does NOT support (https://confluence.slac.stanford.edu/x/n4-jCg)
proc CheckVivadoVersion { } {
   # Check for unsupported versions of ruckus
   if { [VersionCompare 2017.1] == 0 ||
        [VersionCompare 2014.1] < 0 } {
      puts "\n\n\n\n\n********************************************************"
      puts "ruckus does NOT support Vivado $::env(VIVADO_VERSION)"
      puts "https://confluence.slac.stanford.edu/x/n4-jCg"
      puts "********************************************************\n\n\n\n\n"
      return -code error
   }
   # Check for unsupported versions of ruckus + Vitis
   if { [VersionCompare 2019.1] > 0 &&
        [VersionCompare 2019.3] < 0 &&
        [expr [info exists ::env(VITIS_SRC_PATH)]] == 1 } {
      # Here's why Vitis 2019.2 not supported in ruckus
      # https://forums.xilinx.com/t5/Embedded-Development-Tools/SDK-banned-from-Vivado-2019-2/td-p/1042059
      puts "\n\n\n\n\n********************************************************"
      puts "ruckus does NOT support Vitis $::env(VIVADO_VERSION)"
      puts "https://confluence.slac.stanford.edu/x/n4-jCg"
      puts "********************************************************\n\n\n\n\n"
      return -code error
   }
   # Check if version is newer than what official been tested
   if { [VersionCompare 2020.1.0] > 0 } {
      puts "\n\n\n\n\n********************************************************"
      puts "ruckus has NOT been regression tested with this Vivado $::env(VIVADO_VERSION) release yet"
      puts "https://confluence.slac.stanford.edu/x/n4-jCg"
      puts "********************************************************\n\n\n\n\n"
   }
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

## Check project configuration for errors
proc CheckPrjConfig { fileset } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl

   # Check for empty Firwmare Version string
   if { $::env(PRJ_VERSION) == "" } {
      puts "\n\n\n\n\n********************************************************"
      puts "********************************************************"
      puts "********************************************************"
      puts "Error: PRJ_VERSION is not defined in the Makefile"
      puts "********************************************************"
      puts "********************************************************"
      puts "********************************************************\n\n\n\n\n"
      return false
   }

   # Check for empty GIT HASH string and not doing a synthesis only build
   if { $::env(GIT_HASH_LONG) == "" && [info exists ::env(SYNTH_ONLY)] != 1} {
      puts "\n\n\n\n\n********************************************************"
      puts "********************************************************"
      puts "********************************************************"
      puts "Error: The following files are not committed in GIT:"
      foreach filePath $::env(GIT_STATUS) {
         puts "\t${filePath}"
      }
      puts "********************************************************"
      puts "********************************************************"
      puts "********************************************************\n\n\n\n\n"
      return false
   }

   # Check the Vivado version (check_syntax added to Vivado in 2016.1)
   if { [VersionCompare 2016.1] >= 0 } {
      # Check for syntax errors
      set syntaxReport [check_syntax -fileset ${fileset} -return_string -quiet -verbose]
      set syntaxReport [split ${syntaxReport} "\n"]
      set listErr ""
      foreach msg ${syntaxReport} {
         if { [string match {*Syntax error *} ${msg}] == 1 } {
            set listErr "${listErr}\n${msg}"
         }
      }
      if { ${listErr} != "" } {
         set listErr [string map {"ERROR: \[#UNDEF\]" ""} ${listErr} ]
         set listErr [string map {"CRITICAL WARNING: \[HDL 9-806\]" ""} ${listErr} ]
         puts "\n\n\n\n\n********************************************************"
         puts "********************************************************"
         puts "********************************************************"
         puts "The following syntax error(s) were detected before synthesis:${listErr}"
         puts "********************************************************"
         puts "********************************************************"
         puts "********************************************************\n\n\n\n\n"
         return false
      }
   }

   if { ${PRJ_TOP} != $::env(PROJECT) } {
      # Check if not a dynamic build of partial reconfiguration,
      # which usually ${PRJ_TOP} != $::env(PROJECT)
      if { ${RECONFIG_CHECKPOINT} == 0 } {
         puts "\n\n\n\n\n********************************************************"
         puts "********************************************************"
         puts "********************************************************"
         puts "WARNING: Your top-level firmware is defined as ${PRJ_TOP}"
         puts "Please double check that ${PRJ_TOP} is actually your top-level HDL"
         puts "********************************************************"
         puts "********************************************************"
         puts "********************************************************\n\n\n\n\n"
         sleep 5
      }
   }

   # Check SDK
   return [CheckSdkSrcPath]
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
   if { [get_property PROGRESS [get_runs impl_1]] != "100\%" } {
      set errmsg "\t\[get_property PROGRESS \[get_runs impl_1\]\] != 100\%\n"
   } elseif { [get_property STATUS [get_runs impl_1]] != "write_bitstream Complete!" } {
      set errmsg "\t\[get_property STATUS \[get_runs impl_1\]\] != \"write_bitstream Complete!\"\n"
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
   puts "\t\$ ./sim_vcs_mx.sh"
   if { ${rogueSim} == true } {
      if { $::env(SHELL) != "/bin/bash" } {
         puts "\t\$ source setup_env.csh"
      } else {
         puts "\t\$ source setup_env.sh"
      }
   }
   puts "\t\$ ./simv -gui &"
   puts "********************************************************\n\n"
}

## Print the DCP build complete message
proc DcpCompleteMessage { filename } {
   puts "\n\n********************************************************"
   puts "The new .dcp file is located here:"
   puts ${filename}
   puts "********************************************************\n\n"
}

## Check the Vivado version number to a user defined value
proc VersionCheck { lockVersion {mustBeExact ""} } {
   # Get the Vivado version
   set VersionNumber [version -short]
   # Generate error message
   set errMsg "\n\n*********************************************************\n"
   set errMsg "${errMsg}Your Vivado Version Vivado   = ${VersionNumber}\n"
   set errMsg "${errMsg}However, Vivado Version Lock = ${lockVersion}\n"
   set errMsg "${errMsg}You need to change your Vivado software to Version ${lockVersion}\n"
   set errMsg "${errMsg}*********************************************************\n\n"
   # Check for less than
   if { ${VersionNumber} < ${lockVersion} } {
      puts ${errMsg}
      return -1
   # Check for equal to
   } elseif { ${VersionNumber} == ${lockVersion} } {
      return 0
   # Check for greater than but must be exact
   } elseif { ${mustBeExact} == "mustBeExact" } {
      puts ${errMsg}
      return -1
   # Else for greater than and not exact
   } else {
      return 1
   }
}

## Compares the tag release to a user defined value
proc CompareTags { tag lockTag } {

   # Blowoff everything except for the major, minor, and patch numbers
   scan $tag     "%d.%d.%d" major minor patch
   scan $lockTag "%d.%d.%d" majorLock minorLock patchLock

   ###################################################################
   # Major Number Checking
   ###################################################################
   # major.X.X < majorLock.X.X
   if { [expr { ${major} < ${majorLock} }] } {
      set validTag 0
   # major.X.X = majorLock.X.X
   } elseif { [expr { ${major} == ${majorLock} }] } {
      ################################################################
      # Minor Number Checking
      ################################################################
      # major.minor.X < major.minorLock.X
      if { [expr { ${minor} < ${minorLock} }] } {
         set validTag 0
      # major.minor.X = major.minorLock.X
      } elseif { [expr { ${minor} == ${minorLock} }] } {
         #############################################################
         # Patch Number Checking
         #############################################################
         # major.minor.patch < major.minor.patchLock
         if { [expr { ${patch} < ${patchLock} }] } {
            set validTag 0
         # major.minor.patch = major.minor.patchLock
         } elseif { [expr { ${patch} == ${patchLock} }] } {
            set validTag 1
         # major.minor.patch > major.minor.patchLock
         } else {
            set validTag 1
         }
      ################################################################
      # major.minor.X > major.minorLock.X
      } else {
         set validTag 1
      }
   ###################################################################
   # major.X.X > majorLock.X.X
   } else {
      set validTag 1
   }

   return ${validTag}
}

## Check the git and git-lfs versions
proc CheckGitVersion { } {
   ######################################
   # Define the git/git-lfs version locks
   ######################################
   set gitLockTag    {2.9.0}
   set gitLfsLockTag {2.1.1}
   ######################################

   # Get the git version
   set gitStr [exec git version]
   scan $gitStr "%s %s %s" name temp gitTag

   # Get the git-lfs version
   set gitStr [exec git-lfs version]
   scan $gitStr "git-lfs/%s %s" gitLfsTag temp

   # Compare the tags
   set validGitTag    [CompareTags ${gitTag}    ${gitLockTag}]
   set validGitLfsTag [CompareTags ${gitLfsTag} ${gitLfsLockTag}]

   # Check the validGitTag flag
   if { ${validGitTag} == 0 } {
      puts "\n\n*********************************************************"
      puts "Your git version = v${gitTag}"
      puts "However, ruckus git version Lock = v${gitLockTag}"
      puts "Please update this git version v${gitLockTag} (or later)"
      puts "*********************************************************\n\n"
      exit -1
   }

   # Check the validGitLfsTag flag
   if { ${validGitLfsTag} == 0 } {
      puts "\n\n*********************************************************"
      puts "Your git-lfs version = v${gitLfsTag}"
      puts "However, ruckus git-lfs version Lock = v${gitLfsLockTag}"
      puts "Please update this git-lfs version v${gitLfsLockTag} (or later)"
      puts "*********************************************************\n\n"
      exit -1
   }
}

## Checks the submodule tag release to a user defined value
proc SubmoduleCheck { name lockTag  {mustBeExact ""} } {

   # Get the full git submodule string for a particular module
   set submodule [exec git -C $::env(MODULES) submodule status -- ${name}]

   # Scan for the hash, name, and tag portions of the string
   scan $submodule "%s %s (v%s)" hash temp tag
   scan $tag "%d.%d.%d%s" major minor patch d
   set tag [string map [list $d ""] $tag]
   set tag "${major}.${minor}.${patch}"
   scan $lockTag "%d.%d.%d" majorLock minorLock patchLock

   # Compare the tags
   set validTag [CompareTags ${tag} ${lockTag}]

   # Check the validTag flag
   if { ${validTag} != 1 } {
      puts "\n\n*********************************************************"
      puts "Your git clone ${name} = v${tag}"
      puts "However, ${name} Lock  = v${lockTag}"
      puts "Please update this submodule tag to v${lockTag} (or later)"
      puts "*********************************************************\n\n"
      return -1
   } elseif { ${major} == ${majorLock} && ${minor} == ${minorLock} && ${patch} == ${patchLock} } {
      return 0
   } elseif { ${mustBeExact} == "mustBeExact" } {
      puts "\n\n*********************************************************"
      puts "Your git clone ${name} = v${tag}"
      puts "However, ${name} Lock  = v${lockTag}"
      puts "Please update this submodule tag to v${lockTag}"
      puts "*********************************************************\n\n"
      return -1
   } else {
      return 1
   }
}

## Compares currnet vivado version to a argument value
proc VersionCompare { versionLock } {

   # Check if missing patch version number field
   if { [expr {[llength [split $::env(VIVADO_VERSION) .]] - 1}] == 1 } {
      set tag "$::env(VIVADO_VERSION).0"
   } else {
      set tag $::env(VIVADO_VERSION)
   }

   # Check if missing patch version number field
   if { [expr {[llength [split ${versionLock} .]] - 1}] == 1 } {
      set lockTag "${versionLock}.0"
   } else {
      set lockTag ${versionLock}
   }

   # Parse the strings
   scan $tag     "%d.%d.%d" major minor patch
   scan $lockTag "%d.%d.%d" majorLock minorLock patchLock

   # Compare the tags
   set validTag [CompareTags ${tag} ${lockTag}]

   # # Debug Messages
   # puts "VIVADO_VERSION: ${tag}"
   # puts "compareVersion: ${lockTag}"
   # puts "validTag:       ${validTag}"

   # Check the validTag flag
   if { ${validTag} != 1 } {
      # compareVersion > VIVADO_VERSION
      return -1
   } elseif { ${major} == ${majorLock} && ${minor} == ${minorLock} && ${patch} == ${patchLock} } {
      # compareVersion = VIVADO_VERSION
      return 0
   } else {
      # compareVersion < VIVADO_VERSION
      return 1
   }
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

## Create a Debug Core Function
proc CreateDebugCore {ilaName} {

   # Delete the Core if it already exist
   delete_debug_core -quiet [get_debug_cores ${ilaName}]

   # Create the debug core
   if { [VersionCompare 2017.2] <= 0 } {
      create_debug_core ${ilaName} labtools_ila_v3
   } else {
      create_debug_core ${ilaName} ila
   }
   set_property C_DATA_DEPTH 1024       [get_debug_cores ${ilaName}]
   set_property C_INPUT_PIPE_STAGES 2   [get_debug_cores ${ilaName}]

   # Force a reset of the implementation
   reset_run impl_1
}

## Sets the clock on the debug core
proc SetDebugCoreClk {ilaName clkNetName} {
   set_property port_width 1 [get_debug_ports  ${ilaName}/clk]
   connect_debug_port ${ilaName}/clk [get_nets ${clkNetName}]
}

## Get Current Debug Probe Function
proc GetCurrentProbe {ilaName} {
   return ${ilaName}/probe[expr [llength [get_debug_ports ${ilaName}/probe*]] - 1]
}

## Probe Configuring function
proc ConfigProbe {ilaName netName} {

   # determine the probe index
   set probeIndex ${ilaName}/probe[expr [llength [get_debug_ports ${ilaName}/probe*]] - 1]

   # get the list of netnames
   set probeNet [lsort -increasing -dictionary [get_nets ${netName}]]

   # calculate the probe width
   set probeWidth [llength ${probeNet}]

   # set the width of the probe
   set_property port_width ${probeWidth} [get_debug_ports ${probeIndex}]

   # connect the probe to the ila module
   connect_debug_port ${probeIndex} ${probeNet}

   # increment the probe index
   create_debug_port ${ilaName} probe
}

## Write the port map file
proc WriteDebugProbes {ilaName {filePath ""}} {

   # Delete the last unused port
   delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

   # Check if write_debug_probes is support
   if { [VersionCompare 2017.2] <= 0 } {
      # Write the port map file
      write_debug_probes -force ${filePath}
   } else {
      # Check if not empty string
      if { ${filePath} != "" } {
         puts "\n\n\n\n\n********************************************************"
         puts "WriteDebugProbes(): Vivado's 'write_debug_probes' procedure has been deprecated in 2017.3"
         puts "Instead the debug_probe file will automatically get copied in the ruckus/system_vivado.mk COPY_PROBES_FILE() function"
         puts "********************************************************\n\n\n\n\n"
      }
   }
}

###############################################################
#### Loading Source Code Functions ############################
###############################################################

## Open ruckus.tcl file
proc loadRuckusTcl { filePath {flags ""} } {
   puts "loadRuckusTcl: ${filePath} ${flags}"
   # Make a local copy of global variable
   set LOC_PATH $::DIR_PATH
   # Make a local copy of global variable
   set ::DIR_PATH ${filePath}
   # Open the TCL file
   if { [file exists ${filePath}/ruckus.tcl] == 1 } {
      if { ${flags} == "debug" } {
         source ${filePath}/ruckus.tcl
      } else {
         source ${filePath}/ruckus.tcl -notrace
      }
   } else {
      puts "\n\n\n\n\n********************************************************"
      puts "loadRuckusTcl: ${filePath}/ruckus.tcl doesn't exist"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   # Revert the global variable back to orginal value
   set ::DIR_PATH ${LOC_PATH}
   # Keep a history of all the load paths
   set ::DIR_LIST "$::DIR_LIST ${filePath}"
}

## Function to load RTL files
proc loadSource args {
   set options {
      {sim_only         "flag for tagging simulation file(s)"}
      {path.arg      "" "path to a single file"}
      {dir.arg       "" "path to a directory of file(s)"}
      {lib.arg       "" "library for file(s)"}
      {fileType.arg  "" "library for file(s)"}
   }
   set usage ": loadSource \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path      [expr {[string length $params(path)]     > 0}]
   set has_dir       [expr {[string length $params(dir)]      > 0}]
   set has_lib       [expr {[string length $params(lib)]      > 0}]
   set has_fileType  [expr {[string length $params(fileType)] > 0}]
   if { $params(sim_only) } {
      set fileset "sim_1"
   } else {
      set fileset "sources_1"
   }
   # Check for error state
   if {${has_path} && ${has_dir}} {
      puts "\n\n\n\n\n********************************************************"
      puts "loadSource: Cannot specify both -path and -dir"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadSource: $params(path) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Check the file extension
         set fileExt [file extension $params(path)]
         if { ${fileExt} eq {.vhd} ||
              ${fileExt} eq {.vhdl}||
              ${fileExt} eq {.v}   ||
              ${fileExt} eq {.vh}  ||
              ${fileExt} eq {.sv}  ||
              ${fileExt} eq {.dat} ||
              ${fileExt} eq {.coe} ||
              ${fileExt} eq {.mem} ||
              ${fileExt} eq {.edif}||
              ${fileExt} eq {.dcp} } {
            # Check if file doesn't exist in project
            if { [get_files -quiet $params(path)] == "" } {
               # Add the RTL Files
               set src_rc [catch {add_files -fileset ${fileset} $params(path)} _RESULT]
               if {$src_rc} {
                  puts "\n\n\n\n\n********************************************************"
                  puts ${_RESULT}
                  set gitLfsCheck "Runs 36-335"
                  if { [ string match *${gitLfsCheck}* ${_RESULT} ] } {
                     puts "Here's what the .DCP file looks like right now:"
                     puts [exec cat $params(path)]
                     puts "\nPlease do the following commands:"
                     puts "$ git-lfs install"
                     puts "$ git-lfs pull"
                     puts "$ git submodule foreach git-lfs pull"
                  }
                  puts "********************************************************\n\n\n\n\n"
                  exit -1
               }
               if { ${has_lib} } {
                  # Check if VHDL file
                  if { ${fileExt} eq {.vhd} ||
                       ${fileExt} eq {.vhdl} } {
                     set_property LIBRARY $params(lib) [get_files $params(path)]
                  }
               }
               if { ${has_fileType} } {
                  set_property FILE_TYPE $params(fileType) [get_files $params(path)]
               }
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadSource: $params(path) does not have a \[.vhd,.vhdl,.v,.vh,.sv,.dat,.coe,.mem,.edif,.dcp\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadSource: $params(dir) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Get a list of all RTL files
         set list ""
         set list_rc [catch {
            set list [glob -directory $params(dir) *.vhd *.vhdl *.v *.vh *.sv *.dat *.coe *.mem *.edif *.dcp]
         } _RESULT]
         # Load all the RTL files
         if { ${list} != "" } {
            foreach pntr ${list} {
               # Check if file doesn't exist in project
               if { [get_files -quiet ${pntr}] == "" } {
                  # Add the RTL Files
                  set src_rc [catch {add_files -fileset ${fileset} ${pntr}} _RESULT]
                  if {$src_rc} {
                     puts "\n\n\n\n\n********************************************************"
                     puts ${_RESULT}
                     set gitLfsCheck "Runs 36-335"
                     if { [ string match *${gitLfsCheck}* ${_RESULT} ] } {
                        puts "Here's what the .DCP file looks like right now:"
                        puts [exec cat ${pntr}]
                        puts "\nPlease do the following commands:"
                        puts "$ git-lfs install"
                        puts "$ git-lfs pull"
                        puts "$ git submodule foreach git-lfs pull"
                     }
                     puts "********************************************************\n\n\n\n\n"
                     exit -1
                  }
                  if { ${has_lib} } {
                     # Check if VHDL file
                     set fileExt [file extension ${pntr}]
                     if { ${fileExt} eq {.vhd} ||
                          ${fileExt} eq {.vhdl} } {
                        set_property LIBRARY $params(lib) [get_files ${pntr}]
                     }
                  }
                  if { ${has_fileType} } {
                     set_property FILE_TYPE $params(fileType) [get_files ${pntr}]
                  }
               }
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadSource: $params(dir) directory does not have any \[.vhd,.vhdl,.v,.vh,.sv,.dat,.coe,.mem,.edif,.dcp\] files"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   }
}

## Function to load IP core files
proc loadIpCore args {
   set options {
      {path.arg "" "path to a single file"}
      {dir.arg  "" "path to a directory of files"}
   }
   set usage ": loadIpCore \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path [expr {[string length $params(path)] > 0}]
   set has_dir  [expr {[string length $params(dir)] > 0}]
   # Check for error state
   if {${has_path} && ${has_dir}} {
      puts "\n\n\n\n\n********************************************************"
      puts "loadIpCore: Cannot specify both -path and -dir"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadIpCore: $params(path) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Check the file extension
         set fileExt [file extension $params(path)]
         if { ${fileExt} eq {.xci} ||
              ${fileExt} eq {.xcix} } {
            # Check if file doesn't exist in project
            if { [get_files -quiet $params(path)] == "" } {
               # Add the IP core file
               import_ip -quiet -srcset sources_1 $params(path)
            }
            # Update the global list
            set strip [file rootname [file tail $params(path)]]
            set ::IP_LIST "$::IP_LIST ${strip}"
            set ::IP_FILES "$::IP_FILES $params(path)"
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadIpCore: $params(path) does not have a \[.xci,.xcix\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadIpCore: $params(dir) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Get a list of all IP core files
         set list ""
         set list_rc [catch {
            set list [glob -directory $params(dir) *.xci *.xcix]
         } _RESULT]
         # Load all the IP core files
         if { ${list} != "" } {
            foreach pntr ${list} {
               # Check if file doesn't exist in project
               if { [get_files -quiet ${pntr}] == "" } {
                  # Add the IP core file
                  import_ip -quiet -srcset sources_1 ${pntr}
               }
               # Update the global list
               set strip [file rootname [file tail ${pntr}]]
               set ::IP_LIST "$::IP_LIST ${strip}"
               set ::IP_FILES "$::IP_FILES ${pntr}"
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadIpCore: $params(dir) directory does not have any \[.xci,.xcix\] files"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   }
}

## Function to load block design files
proc loadBlockDesign args {
   set options {
      {path.arg "" "path to a single file"}
      {dir.arg  "" "path to a directory of files"}
   }
   set usage ": loadBlockDesign \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path [expr {[string length $params(path)] > 0}]
   set has_dir  [expr {[string length $params(dir)] > 0}]
   # Check for error state
   if {${has_path} && ${has_dir}} {
      puts "\n\n\n\n\n********************************************************"
      puts "loadBlockDesign: Cannot specify both -path and -dir"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadBlockDesign: $params(path) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Check the file extension
         set fileExt [file extension $params(path)]
         if { ${fileExt} eq {.bd} ||
              ${fileExt} eq {.tcl} } {
            # Update the global list
            set fbasename [file rootname $params(path)]
            set ::BD_FILES "$::BD_FILES ${fbasename}.bd"
            # Check for .bd extension
            if { ${fileExt} eq {.bd} } {
               # Check if the block design file has already been loaded
               if { [get_files -quiet [file tail $params(path)]] == ""} {
                  # Add block design file
                  set locPath [import_files -force -norecurse $params(path)]
                  export_ip_user_files -of_objects [get_files ${locPath}] -force -quiet
               }
            # Else it's a .TCL extension
            } else {
               # Always load the block design TCL file
               source $params(path)
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadBlockDesign: $params(path) does not have a \[.bd,.tcl\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadBlockDesign: $params(dir) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Get a list of all block design files
         set list ""
         set list_rc [catch {
            set list [glob -directory $params(dir) *.bd *.tcl]
         } _RESULT]
         # Load all the block design files
         if { ${list} != "" } {
            foreach pntr ${list} {
               # Update the global list
               set fbasename [file rootname ${pntr}]
               set ::BD_FILES "$::BD_FILES ${fbasename}.bd"
               # Check for .bd extension
               set fileExt [file extension ${pntr}]
               if { ${fileExt} eq {.bd} } {
                  # Check if the block design file has already been loaded
                  if { [get_files -quiet [file tail ${pntr}]] == ""} {
                     # Add block design file
                     set locPath [import_files -force -norecurse ${pntr}]
                     export_ip_user_files -of_objects [get_files ${locPath}] -force -quiet
                  }
               # Else it's a .TCL extension
               } else {
                  # Always load the block design TCL file
                  source ${pntr}
               }
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadBlockDesign: $params(dir) directory does not have any \[.bd,.tcl\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   }
}

## Function to load constraint files
proc loadConstraints args {
   set options {
      {path.arg "" "path to a single file"}
      {dir.arg  "" "path to a directory of files"}
   }
   set usage ": loadConstraints \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path [expr {[string length $params(path)] > 0}]
   set has_dir  [expr {[string length $params(dir)] > 0}]
   # Check for error state
   if {${has_path} && ${has_dir}} {
      puts "\n\n\n\n\n********************************************************"
      puts "loadConstraints: Cannot specify both -path and -dir"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadConstraints: $params(path) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Check the file extension
         set fileExt [file extension $params(path)]
         if { ${fileExt} eq {.xdc} ||
              ${fileExt} eq {.tcl} } {
            # Check if file doesn't exist in project
            if { [get_files -quiet $params(path)] == "" } {
               # Add the constraint Files
               add_files -fileset constrs_1 $params(path)
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadConstraints: $params(path) does not have a \[.xdc,.tcl\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadConstraints: $params(dir) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Get a list of all constraint files
         set list ""
         set list_rc [catch {
            set list [glob -directory $params(dir) *.xdc *.tcl]
         } _RESULT]
         # Load all the block design files
         if { ${list} != "" } {
            # Load all the constraint files
            foreach pntr ${list} {
               # Check if file doesn't exist in project
               if { [get_files -quiet ${pntr}] == "" } {
                  # Add the RTL Files
                  add_files -fileset constrs_1 ${pntr}
               }
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadConstraints: $params(dir) directory does not have any \[.xdc,.tcl\] files"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   }
}

## Function to load ZIP IP cores
proc loadZipIpCore args {
   set options {
      {path.arg       "" "path to a single file"}
      {dir.arg        "" "path to a directory of files"}
      {repo_path.arg  "" "path to a repo directory"}
   }
   set usage ": loadZipIpCore \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path [expr {[string length $params(path)] > 0}]
   set has_dir  [expr {[string length $params(dir)] > 0}]
   set has_repo [expr {[string length $params(repo_path)] > 0}]

   # Check for error state
   if {${has_path} && ${has_dir}} {
      puts "\n\n\n\n\n********************************************************"
      puts "loadZipIpCore: Cannot specify both -path and -dir"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   } elseif {$has_repo} {
      # Load a single file
      if {$has_path} {
         # Check if file doesn't exist
         if { [file exists $params(path)] != 1 } {
            puts "\n\n\n\n\n********************************************************"
            puts "loadZipIpCore: $params(path) doesn't exist"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         } else {
            # Check the file extension
            set fileExt [file extension $params(path)]
            if { ${fileExt} eq {.zip} ||
                 ${fileExt} eq {.ZIP} } {
               # Check if directory doesn't exist yet
               set strip [file rootname [file tail $params(path)]]
               set dirPath "$params(repo_path)/${strip}"
               if { [file isdirectory [file rootname ${dirPath}]] == 0 } {
                  # Add achieved .zip to repo path
                  update_ip_catalog -add_ip $params(path) -repo_path $params(repo_path)
               }
            } else {
               puts "\n\n\n\n\n********************************************************"
               puts "loadZipIpCore: $params(path) does not have a \[.zip,.ZIP\] file extension"
               puts "********************************************************\n\n\n\n\n"
               exit -1
            }
         }
      # Load all files from a directory
      } elseif {$has_dir} {
         # Check if directory doesn't exist
         if { [file exists $params(dir)] != 1 } {
            puts "\n\n\n\n\n********************************************************"
            puts "loadZipIpCore: $params(dir) doesn't exist"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         } else {
            # Get a list of all constraint files
            set list ""
            set list_rc [catch {
               set list [glob -directory $params(dir) *.zip *.ZIP]
            } _RESULT]
            # Load all the block design files
            if { ${list} != "" } {
               # Load all the constraint files
               foreach pntr ${list} {
                  # Check if directory doesn't exist yet
                  set strip [file rootname [file tail ${pntr}]]
                  set dirPath "$params(repo_path)/${strip}"
                  if { [file isdirectory [file rootname ${dirPath}]] == 0 } {
                     # Add achieved .zip to repo path
                     update_ip_catalog -add_ip ${pntr} -repo_path $params(repo_path)
                  }
               }
            } else {
               puts "\n\n\n\n\n********************************************************"
               puts "loadZipIpCore: $params(dir) directory does not have any \[.zip,.ZIP\] files"
               puts "********************************************************\n\n\n\n\n"
               exit -1
            }
         }
      }
   } else {
      puts "\n\n\n\n\n********************************************************"
      puts "loadZipIpCore: -repo_path not defined"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
}
