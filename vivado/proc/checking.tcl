##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

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

## Print Message for users to open GUI if error detected
proc PrintOpenGui { errMsg } {
   puts "\n\n\n\n\n********************************************************"
   puts ${errMsg}
   puts "Please open the GUI ('make gui') and view the 'Messages' tab for list of all errors"
   puts "********************************************************\n\n\n\n\n"
}

## Print the DCP build complete message
proc DcpCompleteMessage { filename } {
   puts "\n\n********************************************************"
   puts "The new .dcp file is located here:"
   puts ${filename}
   puts "********************************************************\n\n"
}
