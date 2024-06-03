##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

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
   if { [VersionCompare 2024.1.0] > 0 } {
      puts "\n\n\n\n\n********************************************************"
      puts "ruckus has NOT been regression tested with this Vivado $::env(VIVADO_VERSION) release yet"
      puts "https://confluence.slac.stanford.edu/x/n4-jCg"
      puts "********************************************************\n\n\n\n\n"
   }
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

   if { ${PRJ_TOP} != $::env(PROJECT) &&
      [string match "*_wrapper" ${PRJ_TOP}] != 1 } {
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

## Check the Vivado version number to a user defined value
proc VersionCheck { lockVersion {mustBeExact ""} } {
   # Get the Vivado version
   set VersionNumber [version -short]
   if { [info exists ::env(BYPASS_VERSION_CHECK)] != 1 || $::env(BYPASS_VERSION_CHECK) == 0 } {
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
   } else {
      # Generate warning message
      set warnMsg "\n\n*********************************************************\n"
      set warnMsg "${warnMsg}Your Vivado Version Vivado   = ${VersionNumber}\n"
      set warnMsg "${warnMsg}The Vivado Version Lock = ${lockVersion}\n"
      set warnMsg "${warnMsg}However, BYPASS_VERSION_CHECK = 1\n"
      set warnMsg "${warnMsg}*********************************************************\n\n"
      puts ${warnMsg}
      return 0
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
   if { [isVersal] } {
      set WRITE_PRE     [get_property {STEPS.WRITE_DEVICE_IMAGE.TCL.PRE}  [get_runs impl_1]]
      set WRITE_POST    [get_property {STEPS.WRITE_DEVICE_IMAGE.TCL.POST} [get_runs impl_1]]
   } else {
      set WRITE_PRE     [get_property {STEPS.WRITE_BITSTREAM.TCL.PRE}     [get_runs impl_1]]
      set WRITE_POST    [get_property {STEPS.WRITE_BITSTREAM.TCL.POST}    [get_runs impl_1]]
   }

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
   if { [isVersal] } {
      set_property STEPS.WRITE_DEVICE_IMAGE.TCL.PRE  "" [get_runs impl_1]
      set_property STEPS.WRITE_DEVICE_IMAGE.TCL.POST "" [get_runs impl_1]
   } else {
      set_property STEPS.WRITE_BITSTREAM.TCL.PRE     "" [get_runs impl_1]
      set_property STEPS.WRITE_BITSTREAM.TCL.POST    "" [get_runs impl_1]
   }

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
   if { [isVersal] } {
      set_property STEPS.WRITE_DEVICE_IMAGE.TCL.PRE  ${WRITE_PRE}  [get_runs impl_1]
      set_property STEPS.WRITE_DEVICE_IMAGE.TCL.POST ${WRITE_POST} [get_runs impl_1]

   } else {
      set_property STEPS.WRITE_BITSTREAM.TCL.PRE     ${WRITE_PRE}  [get_runs impl_1]
      set_property STEPS.WRITE_BITSTREAM.TCL.POST    ${WRITE_POST} [get_runs impl_1]
   }
}

## Set the synthesis to "out of context"
proc SetSynthOutOfContext { } {
   set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
}

## Remove unused code
proc RemoveUnsuedCode { } {
   update_compile_order -quiet -fileset sources_1
   update_compile_order -quiet -fileset sim_1
   remove_files [get_files -filter {IS_AUTO_DISABLED}]
}
