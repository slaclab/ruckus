##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Custom Procedure Script

package require cmdline

###############################################################
#### General Functions ########################################
###############################################################

# Refresh a Vivado project
proc VivadoRefresh { vivadoProject } {
   close_project
   open_project -quiet ${vivadoProject}
}

# Achieve a Vivado Project
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

# Custom TLC source function
proc SourceTclFile { filePath } {
   if { [file exists ${filePath}] == 1 } {
      source ${filePath}
      return true;
   } else {
      return false;
   }
}

proc getFpgaFamily { } {
   return [get_property FAMILY [get_property {PART} [current_project]]]
}

# Get the number of CPUs available on the Linux box
proc GetCpuNumber { } {
   return [exec cat /proc/cpuinfo | grep processor | wc -l]
}

# Function for putting the TCL script into a wait (in units of seconds)
proc sleep {N} {
   after [expr {int($N * 1000)}]
}

proc BuildIpCores { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl

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
   VivadoRefresh ${VIVADO_PROJECT}   
}

# Copies all IP cores from the build tree to source tree
proc CopyIpCores { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl   
   
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
               # Overwrite the existing .dcp file in the source tree               
               set SRC [string map {.xci .dcp} ${SRC}]
               set DST [string map {.xci .dcp} ${DST}]
               exec cp ${SRC} ${DST}    
               puts "exec cp ${SRC} ${DST}"    
            }
         }        
      }
   }
}  

# Copies all IP cores from the build tree to source tree (with source code)
proc CopyIpCoresDebug { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl   
   
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

# Copies all block designs from the build tree to source tree
proc CopyBdCores { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl   
   
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
            }
         }        
      }
   }
} 

# Copies all block designs from the build tree to source tree (with source code)
proc CopyBdCoresDebug { } {
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl   
   
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

proc CreateFpgaBit { } {   
   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl
   #########################################################
   ## Check if need to include YAML files with the .BIT file
   #########################################################
   exec cp -f ${IMPL_DIR}/${PROJECT}.bit ${IMAGES_DIR}/$::env(IMAGENAME).bit
   exec gzip -c -f -9 ${IMPL_DIR}/${PROJECT}.bit > ${IMAGES_DIR}/$::env(IMAGENAME).bit.gz
}

# Create tar.gz of all cpsw files in firmware
proc CreateCpswTarGz { } {   
   if { [file exists $::env(PROJ_DIR)/yaml/000TopLevel.yaml] == 1 } {
      source $::env(RUCKUS_DIR)/vivado_cpsw.tcl
   } else {
      puts "$::env(PROJ_DIR)/yaml/000TopLevel.yaml does not exist"
   }
}

# Create tar.gz of all pyrogue files in firmware
proc CreatePyRogueTarGz { } {   
   source $::env(RUCKUS_DIR)/vivado_pyrogue.tcl
}

# Create .MCS PROM
proc CreatePromMcs { } {   
   if { [file exists $::env(PROJ_DIR)/vivado/promgen.tcl] == 1 } {
      source $::env(RUCKUS_DIR)/vivado_promgen.tcl
   }
}   
   
# Remove unused code   
proc RemoveUnsuedCode { } { 
   remove_files [get_files -filter {IS_AUTO_DISABLED}]
}

# GIT Build TAG   
proc GitBuildTag { } { 
   set git_rc [catch {
      if { $::env(GIT_TAG_MSG) != "" } {
         set CMD "cd $::env(PROJ_DIR); git tag -a $::env(GIT_TAG_NAME) $::env(GIT_TAG_MSG)"
         exec tcsh -e -c "${CMD}" >@stdout 
         exec rm -f $::env(PROJ_DIR)/build.info
         set CMD "cd $::env(PROJ_DIR); git show $::env(GIT_TAG_NAME) -- > $::env(PROJ_DIR)/build.info"
         exec tcsh -e -c "${CMD}" >@stdout
      }   
   } _RESULT]
   if {$git_rc} {
      puts "\n\n\n\n\n********************************************************"
      puts "CRITICAL WARNING: Failed to generate the build TAG during GitBuildTag():"
      puts ${_RESULT}
      puts "********************************************************\n\n\n\n\n" 
   }
}

# Checking Timing Function
proc CheckTiming { {printTiming true} } {
   # Check for timing and routing errors 
   set WNS [get_property STATS.WNS [get_runs impl_1]]
   set TNS [get_property STATS.TNS [get_runs impl_1]]
   set WHS [get_property STATS.WHS [get_runs impl_1]]
   set THS [get_property STATS.THS [get_runs impl_1]]
   set TPWS [get_property STATS.TPWS [get_runs impl_1]]
   set FAILED_NETS [get_property STATS.FAILED_NETS [get_runs impl_1]]

   if { ${WNS}<0.0 || ${TNS}<0.0 \
      || ${WHS}<0.0 || ${THS}<0.0 \
      || ${TPWS}<0.0 || ${FAILED_NETS}>0.0 } {
      
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
      
      # Check the TIG variable
      set retVar [expr {[info exists ::env(TIG)] && [string is true -strict $::env(TIG)]}]  
      if { ${retVar} == 1 } {
         return true
      } else {
         return false
      }    
      
   } else {
      return true
   }
}

# Check if SDK_SRC_PATH exist, then it checks for a valid path 
proc CheckSdkSrcPath { } {
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
   return true
}

# Check project configuration for errors
proc CheckPrjConfig { } {

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

   # Check for empty GIT HASH string
   if { $::env(GIT_HASH_LONG) == "" } {
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
   
   # Check for syntax errors
   set syntaxReport [check_syntax -fileset sources_1 -return_string -quiet -verbose]
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
   
   # Check SDK
   return [CheckSdkSrcPath]
}

# Check if the Synthesize is completed
proc CheckSynth { {flags ""} } {
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   if { ${flags} != "" } {
      # Check for errors during synthesis
      set NumErr [llength [lsearch -all -regexp [split [read [open ${SYN_DIR}/runme.log]]] "^ERROR:"]]
      if { ${NumErr} != 0 } {
         set errReport [read [open ${SYN_DIR}/runme.log]]
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

# Check if the Synthesize is completed
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

# Check if the Implementation is completed
proc CheckImpl { {flags ""} } {
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl
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
proc VcsCompleteMessage {dirPath sharedMem} {
   puts "\n\n********************************************************"
   puts "The VCS simulation script has been generated."
   puts "To compile and run the simulation:"
   puts "\t\$ cd ${dirPath}/"    
   puts "\t\$ ./sim_vcs_mx.sh"
   puts "\t\$ source setup_env.csh"
   puts "\t\$ ./simv"   
   puts "********************************************************\n\n" 
}

proc DcpCompleteMessage { filename } {
   puts "\n\n********************************************************"
   puts "The new .dcp file is located here:"
   puts ${filename}
   puts "********************************************************\n\n" 
}

proc HlsVersionCheck { } {
   set VersionNumber [version -short]
   if { ${VersionNumber} == 2014.2 } {
      puts "\n\n****************************************************************"
      puts "Vivado_HLS Version = ${VersionNumber} is not support in this build system."
      puts "****************************************************************\n\n" 
      return -1
   } else {
      return 0
   }
}

proc VersionCheck { lockVersion } {
   set VersionNumber [version -short]
   if { ${VersionNumber} < ${lockVersion} } {
      puts "\n\n*********************************************************"
      puts "Your Vivado Version Vivado   = ${VersionNumber}"
      puts "However, Vivado Version Lock = ${lockVersion}"
      puts "You need to change your Vivado software to Version ${lockVersion}"
      puts "*********************************************************\n\n" 
      return -1
   } elseif { ${VersionNumber} == ${lockVersion} } {
      return 0
   } else { 
      return 1
   }
}

###############################################################
#### Partial Reconfiguration Functions ########################
###############################################################

# Check if RECONFIG_NAME environmental variable
proc CheckForReconfigName { } {
   if { [info exists ::env(RECONFIG_NAME)] } {
      return true
   } else {
      puts "\n\nNo RECONFIG_NAME environmental variable was found."
      puts "Please check the project's Makefile\n\n"
      return false   
   }
}

# Check if RECONFIG_CHECKPOINT environmental variable exists
proc CheckForReconfigCheckPoint { } {
   if { [info exists ::env(RECONFIG_CHECKPOINT)] } {
      return true
   } else {
      puts "\n\nNo RECONFIG_CHECKPOINT environmental variable was found."
      puts "Please check the project's Makefile\n\n"
      return false   
   }
}

# Generate Partial Reconfiguration RTL Block's checkpoint
proc GenPartialReconfigDcp {rtlName} {

   puts "\n\nGenerating ${rtlName} RTL ... \n\n"

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl
  
   # Get a list of all runs  
   set LIST_RUNS [get_runs]   
   
   # Check if RTL synthesis run already exists
   if { [lsearch ${LIST_RUNS} ${rtlName}_1] == -1 } {
      # create a RTL synthesis run
      create_run -flow {Vivado Synthesis 2013} ${rtlName}_1
   } else {
      # Clean up the run
      reset_run ${rtlName}_1   
   }
   
   # Disable all constraint file 
   set_property is_enabled false [get_files *.xdc]
   
   # Only enable the targeted XDC file
   set_property is_enabled true [get_files ${rtlName}.xdc]   
   
   # Don't flatten the hierarchy
   set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs ${rtlName}_1]
   
   # Prevents I/O insertion for synthesis and downstream tools
   set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs ${rtlName}_1]   
   
   # Set the top level RTL
   set_property top ${rtlName} [current_fileset]
   
   # Synthesize
   launch_runs ${rtlName}_1
   set src_rc [catch { 
      wait_on_run ${rtlName}_1
   } _RESULT]    
}

# Insert the Partial Reconfiguration RTL Block(s) into top level checkpoint checkpoint
proc InsertStaticReconfigDcp { } {

   # Get variables
   set RECONFIG_NAME    $::env(RECONFIG_NAME)
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl
   
   # Set common variables
   set SYNTH_DIR ${OUT_DIR}/${PROJECT}_project.runs/synth_1
   
   # Enable the RTL Blocks(s) Logic
   foreach rtlPntr ${RECONFIG_NAME} {
      set_property is_enabled true [get_files *${rtlPntr}.vhd]
   }      
   
   # Disable the top level HDL
   set_property is_enabled false [get_files ${PROJECT}.vhd]
   
   # Generate Partial Reconfiguration RTL Block(s) checkpoints
   foreach rtlPntr ${RECONFIG_NAME} {
      GenPartialReconfigDcp ${rtlPntr}
   }

   # Reset all the Partial Reconfiguration RTL Block(s) and 
   # their XDC files to disabled
   foreach rtlPntr ${RECONFIG_NAME} {
      set_property is_enabled false [get_files ${rtlPntr}.vhd]
      set_property is_enabled false [get_files ${rtlPntr}.xdc]
   }   
   
   # Reset the top level module
   set_property is_enabled true [get_files ${PROJECT}.vhd]
   set_property is_enabled true [get_files ${PROJECT}.xdc]
   set_property top ${PROJECT} [current_fileset]
   
   # Reset the "needs_refresh" flag because of top level assignment juggling
   set_property needs_refresh false [get_runs synth_1]
   foreach rtlPntr ${RECONFIG_NAME} {
      set_property needs_refresh false [get_runs ${rtlPntr}_1]
   }   
   
   # Backup the top level checkpoint and reports
   file copy   -force ${SYNTH_DIR}/${PROJECT}.dcp                   ${SYNTH_DIR}/${PROJECT}_backup.dcp
   file rename -force ${SYNTH_DIR}/${PROJECT}_utilization_synth.rpt ${SYNTH_DIR}/${PROJECT}_utilization_synth_backup.rpt
   file rename -force ${SYNTH_DIR}/${PROJECT}_utilization_synth.pb  ${SYNTH_DIR}/${PROJECT}_utilization_synth_backup.pb
   
   # open the top level check point
   open_checkpoint ${SYNTH_DIR}/${PROJECT}.dcp   

   # Load the top-level constraint file
   read_xdc [lsearch -all -inline ${XDC_FILES} *${PROJECT}.xdc]

   # Load the synthesized Partial Reconfiguration RTL Block's check points
   foreach rtlPntr ${RECONFIG_NAME} {
      read_checkpoint -cell ${rtlPntr}_Inst ${SYNTH_DIR}/../${rtlPntr}_1/${rtlPntr}.dcp
   }

   # Define each of these sub-modules as partially reconfigurable
   foreach rtlPntr ${RECONFIG_NAME} {
      set_property HD.RECONFIGURABLE 1 [get_cells ${rtlPntr}_Inst]
   }

   # Check for DRC
   report_drc -file ${SYNTH_DIR}/${PROJECT}_reconfig_drc.txt

   # Overwrite the existing synth_1 checkpoint, which is the 
   # checkpoint that impl_1 will refer to
   write_checkpoint -force ${SYNTH_DIR}/${PROJECT}.dcp   
   
   # Generate new top level reports to update GUI display
   report_utilization -file ${SYNTH_DIR}/${PROJECT}_utilization_synth.rpt -pb ${SYNTH_DIR}/${PROJECT}_utilization_synth.pb
   
   # Close the opened design before launching the impl_1
   close_design
}

# Export static checkpoint
proc ExportStaticReconfigDcp { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl
   
   # Set common variables
   set IMPL_DIR ${OUT_DIR}/${PROJECT}_project.runs/impl_1
   
   # Make a copy of the .dcp file with a "_static" suffix for 
   # the Makefile system to copy over
   file copy -force ${IMPL_DIR}/${PROJECT}_routed.dcp ${IMPL_DIR}/${PROJECT}_static.dcp   
   
   # Make a copy of the .bit file with a "_static" suffix for 
   # the Makefile system to copy over
   file copy -force ${IMPL_DIR}/${PROJECT}.bit ${IMPL_DIR}/${PROJECT}_static.bit
}

# Import static checkpoint
proc ImportStaticReconfigDcp { } {

   # Get variables
   set RECONFIG_CHECKPOINT $::env(RECONFIG_CHECKPOINT)
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl
   
   # Set common variables
   set SYNTH_DIR ${OUT_DIR}/${PROJECT}_project.runs/synth_1
   
   # Backup the Partial Reconfiguration RTL Block checkpoint and reports
   file copy   -force ${SYNTH_DIR}/${PROJECT}.dcp                   ${SYNTH_DIR}/${PROJECT}_backup.dcp
   file rename -force ${SYNTH_DIR}/${PROJECT}_utilization_synth.rpt ${SYNTH_DIR}/${PROJECT}_utilization_synth_backup.rpt
   file rename -force ${SYNTH_DIR}/${PROJECT}_utilization_synth.pb  ${SYNTH_DIR}/${PROJECT}_utilization_synth_backup.pb
   
   # Open the static design check point
   open_checkpoint ${RECONFIG_CHECKPOINT}   
   
   # Clear out the targeted reconfigurable module logic
   update_design -cell ${PROJECT}_Inst -black_box 
   
   # Lock down all placement and routing of the static design
   lock_design -level routing     

   # Read the targeted reconfiguration RTL block's checkpoint
   read_checkpoint -cell ${PROJECT}_Inst ${SYNTH_DIR}/${PROJECT}.dcp   
   
   # Check for DRC
   report_drc -file ${SYNTH_DIR}/${PROJECT}_reconfig_drc.txt   

   # Overwrite the existing synth_1 checkpoint, which is the 
   # checkpoint that impl_1 will refer to
   write_checkpoint -force ${SYNTH_DIR}/${PROJECT}.dcp   
   
   # Generate new top level reports to update GUI display
   report_utilization -file ${SYNTH_DIR}/${PROJECT}_utilization_synth.rpt -pb ${SYNTH_DIR}/${PROJECT}_utilization_synth.pb
   
   # Close the opened design before launching the impl_1
   close_design
}

# Export partial configuration bit file
proc ExportPartialReconfigBit { } {

   # Get variables
   source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
   source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl
   
   # Set common variables
   set IMPL_DIR ${OUT_DIR}/${PROJECT}_project.runs/impl_1
 
   # Make a copy of the partial .bit file with a "_static" suffix for 
   # the Makefile system to copy over
   if { ${VIVADO_VERSION} >= 2016.3 } {
      set topLevel [get_property top [current_fileset]]
      exec cp -f ${IMPL_DIR}/${topLevel}.bit ${IMPL_DIR}/${PROJECT}_dynamic.bit
   } else {
      file copy -force ${IMPL_DIR}/${PROJECT}_pblock_${PROJECT}_partial.bit ${IMPL_DIR}/${PROJECT}_dynamic.bit
   }    
}

###############################################################
#### Hardware Debugging Functions #############################
###############################################################

# Create a Debug Core Function
proc CreateDebugCore {ilaName} {
   
   # Delete the Core if it already exist
   delete_debug_core -quiet [get_debug_cores ${ilaName}]

   # Create the debug core
   create_debug_core ${ilaName} labtools_ila_v3
   set_property C_DATA_DEPTH 1024       [get_debug_cores ${ilaName}]
   set_property C_INPUT_PIPE_STAGES 2   [get_debug_cores ${ilaName}]
   
   # set_property C_EN_STRG_QUAL true     [get_debug_cores ${ilaName}]
   
   # Force a reset of the implementation
   reset_run impl_1
}

# Sets the clock on the debug core
proc SetDebugCoreClk {ilaName clkNetName} {
   set_property port_width 1 [get_debug_ports  ${ilaName}/clk]
   connect_debug_port ${ilaName}/clk [get_nets ${clkNetName}]
}

# Get Current Debug Probe Function
proc GetCurrentProbe {ilaName} {
   return ${ilaName}/probe[expr [llength [get_debug_ports ${ilaName}/probe*]] - 1]
}

# Probe Configuring function
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

# Write the port map file
proc WriteDebugProbes {ilaName filePath} {

   # Delete the last unused port
   delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

   # Write the port map file
   write_debug_probes -force ${filePath}
}

###############################################################
#### Loading Source Code Functions ############################
###############################################################

# Open ruckus.tcl file
proc loadRuckusTcl { filePath {flags ""} } {
   puts "loadRuckusTcl: ${filePath} ${flags}"
   # Make a local copy of global variable
   set LOC_PATH $::DIR_PATH
   # Make a local copy of global variable
   set ::DIR_PATH ${filePath}
   # Open the TCL file
   if { [file exists ${filePath}/ruckus.tcl] == 1 } {
      if { ${flags} == "" } {
         source ${filePath}/ruckus.tcl
      } else {
         source -quiet ${filePath}/ruckus.tcl
      }
   } else {
      return -code error "loadRuckusTcl: ${filePath}/ruckus.tcl doesn't exist"
   }
   # Revert the global variable back to orginal value
   set ::DIR_PATH ${LOC_PATH}
   # Keep a history of all the load paths
   set ::DIR_LIST "$::DIR_LIST ${filePath}"
}

# Function to load RTL files
proc loadSource args {
   set options {
      {sim_only    "flag for tagging simulation file(s)"}
      {path.arg "" "path to a single file"}
      {dir.arg  "" "path to a directory of file(s)"}
   }
   set usage ": loadSource \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path [expr {[string length $params(path)] > 0}]
   set has_dir  [expr {[string length $params(dir)] > 0}]
   if { $params(sim_only) } { 
      set fileset "sim_1" 
   } else {
      set fileset "sources_1" 
   }
   # Check for error state
   if {${has_path} && ${has_dir}} {
      return -code error "loadSource: Cannot specify both -path and -dir"
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {   
         return -code error "loadSource: $params(path) doesn't exist"
      } else {
         # Add the RTL Files
         add_files -quiet -fileset ${fileset} $params(path)
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {   
         return -code error "loadSource: $params(dir) doesn't exist"
      } else {  
         # Get a list of all RTL files
         set list [glob -directory $params(dir) *.vhd *.v *.vh *.sv *.dcp]
         # Load all the RTL files
         if { ${list} != "" } {
            foreach pntr ${list} {
               # Add the RTL Files
               add_files -quiet -fileset ${fileset} ${pntr}
            }
         }
      }
   }
} 

# Function to load IP core files
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
      return -code error "loadIpCore: Cannot specify both -path and -dir"
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {   
         return -code error "loadIpCore: $params(path) doesn't exist"
      } else {
         # Add the IP core file
         import_ip -quiet -srcset sources_1 $params(path)
         # Update the global list
         set strip [file rootname [file tail $params(path)]]
         set ::IP_LIST "$::IP_LIST ${strip}"         
         set ::IP_FILES "$::IP_FILES $params(path)"
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {   
         return -code error "loadIpCore: $params(dir) doesn't exist"
      } else {  
         # Get a list of all IP core files
         set list [glob -directory $params(dir) *.xci]
         # Load all the IP core files
         if { ${list} != "" } {
            foreach pntr ${list} {
               # Add the IP core file
               import_ip -quiet -srcset sources_1 ${pntr}
               # Update the global list
               set strip [file rootname [file tail ${pntr}]]
               set ::IP_LIST "$::IP_LIST ${strip}"
               set ::IP_FILES "$::IP_FILES ${pntr}"
            }
         }
      }
   }
} 

# Function to load block design files
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
      return -code error "loadBlockDesign: Cannot specify both -path and -dir"
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {   
         return -code error "loadBlockDesign: $params(path) doesn't exist"
      } else {
         # Update the global list
         set ::BD_FILES "$::BD_FILES $params(path)"
         # Check if the block design file has already been loaded
         if { [get_files -quiet [file tail $params(path)]] == ""} {
            # Add block design file
            set locPath [import_files -force -norecurse $params(path)]
            export_ip_user_files -of_objects [get_files ${locPath}] -force -quiet   
         }
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {   
         return -code error "loadBlockDesign: $params(dir) doesn't exist"
      } else {  
         # Get a list of all block design files
         set list [glob -directory $params(dir) *.bd]
         # Load all the block design files
         if { ${list} != "" } {
            foreach pntr ${list} {
               # Update the global list
               set ::BD_FILES "$::BD_FILES ${pntr}"
               # Check if the block design file has already been loaded
               if { [get_files -quiet [file tail ${pntr}]] == ""} {            
                  # Add block design file
                  set locPath [import_files -force -norecurse ${pntr}]
                  export_ip_user_files -of_objects [get_files ${locPath}] -force -quiet      
               }
            }
         }
      }
   }
}

# Function to load constraint files
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
      return -code error "loadConstraints: Cannot specify both -path and -dir"
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {   
         return -code error "loadConstraints: $params(path) doesn't exist"
      } else {
         # Add the constraint Files
         add_files -quiet -fileset constrs_1 $params(path)
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {   
         return -code error "loadConstraints: $params(dir) doesn't exist"
      } else {   
         # Get a list of all constraint files
         set list [glob -directory $params(dir) *.xdc *.tcl]
         # Load all the constraint files
         foreach pntr ${list} {
            # Add the RTL Files
            add_files -quiet -fileset constrs_1 ${pntr}
         }
      }
   }
} 
