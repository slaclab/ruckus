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

###############################################################
#### General Functions ########################################
###############################################################

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
   # Legacy Vivado function: not-supported
   return "not-supported"
}

## Returns the FPGA family string
proc getFpgaArch { } {
   # Legacy Vivado function: not-supported
   return "not-supported"
}

## Returns true is Versal
proc isVersal { } {
   # Legacy Vivado function: not-supported
   return false;
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

   # # Get the submodule status string
   # set retVar [catch {set submodule [exec git -C $::env(MODULES) submodule status -- ${name}]} _RESULT]
   # if {$retVar} {
      # puts "\n\n\n\n\n********************************************************"
      # puts "SubmoduleCheck(name=$name): ${_RESULT}"
      # puts "********************************************************\n\n\n\n\n"
      # return -1
   # }

   # # Scan for the hash, name, and tag portions of the string (assumes a 'v' prefix to start with)
   # if { [scan $submodule "%s %s (v%s)" hash temp tag] != 3 } {
      # # Check again with 'v' prefix
      # set prefix ""
      # scan $submodule "%s %s (%s)" hash temp tag
   # } else {
      # set prefix "v"
   # }
   # scan $tag "%d.%d.%d%s" major minor patch d
   # set tag [string map [list $d ""] $tag]
   # set tag "${major}.${minor}.${patch}"
   # scan $lockTag "%d.%d.%d" majorLock minorLock patchLock

   # # Compare the tags
   # set validTag [CompareTags ${tag} ${lockTag}]

   # # Check the validTag flag
   # if { ${validTag} != 1 } {
      # puts "\n\n*********************************************************"
      # puts "Your git clone ${name} = ${prefix}${tag}"
      # puts "However, ${name} Lock  = ${prefix}${lockTag}"
      # puts "Please update this submodule tag to ${prefix}${lockTag} (or later)"
      # puts "*********************************************************\n\n"
      # return -1
   # } elseif { ${major} == ${majorLock} && ${minor} == ${minorLock} && ${patch} == ${patchLock} } {
      # return 0
   # } elseif { ${mustBeExact} == "mustBeExact" } {
      # puts "\n\n*********************************************************"
      # puts "Your git clone ${name} = ${prefix}${tag}"
      # puts "However, ${name} Lock  = ${prefix}${lockTag}"
      # puts "Please update this submodule tag to ${prefix}${lockTag}"
      # puts "*********************************************************\n\n"
      # return -1
   # } else {
      # return 1
   # }

   return 1
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
      source ${filePath}/ruckus.tcl
   } else {
      puts "\n\n\n\n\n********************************************************"
      puts "loadRuckusTcl: ${filePath}/ruckus.tcl doesn't exist"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   # Revert the global variable back to original value
   set ::DIR_PATH ${LOC_PATH}
}

## Reset source file lists
proc ResetSrcFileLists {} {
   set ::SRC_VHDL     ""
   set ::SRC_VERILOG  ""
   set ::SRC_SVERILOG ""
}

## Update source file lists
proc UpdateSrcFileLists {filepath} {
   set fileExt [file extension ${filepath}]
   if { ${fileExt} eq {.vhd} ||
        ${fileExt} eq {.vhdl} } {
      set ::SRC_VHDL "$::SRC_VHDL ${filepath}"
   } elseif {
        ${fileExt} eq {.v} ||
        ${fileExt} eq {.vh} } {
      set ::SRC_VERILOG "$::SRC_VERILOG ${filepath}"
   } else {
      set ::SRC_SVERILOG "$::SRC_SVERILOG ${filepath}"
   }
}

## Analyze source file lists
proc AnalyzeSrcFileLists args {
   # Parse the list of args
   array set params $args

   # Initialize local variables
   set vhdlTop ""
   set verilogTop ""
   set systemVerilogTop ""
   set vhdlLib ""
   set verilogLib ""
   set systemVerilogLib ""

   if {[info exists params(-vhdlTop)]} {
     set vhdlTop "$params(-vhdlTop)"
   }

   if {[info exists params(-verilogTop)]} {
      set verilogTop "$params(-verilogTop)"
   }

   if {[info exists params(-systemVerilogTop)]} {
      set systemVerilogTop "$params(-systemVerilogTop)"
   }

   if {[info exists params(-vhdlLib)]} {
      set vhdlLib "$params(-vhdlLib)"
   }

   if {[info exists params(-verilogLib)]} {
      set verilogLib "$params(-verilogLib)"
   }

   if {[info exists params(-systemVerilogLib)]} {
      set systemVerilogLib "$params(-systemVerilogLib)"
   }

   # Load VHDL code to memory
   if { $::SRC_VHDL  != "" } {
      # analyze -format vhdl ${vhdlLib} ${vhdlTop} -autoread $::SRC_VHDL
      analyze -format vhdl -library ${vhdlLib} -top ${vhdlTop} -autoread $::SRC_VHDL
   }

   # Load Verilog code to memory
   if { $::SRC_VERILOG  != "" } {
      analyze -format verilog -library ${verilogLib} -top ${verilogTop} -autoread $::SRC_VERILOG
   }

   # Load System Verilog code to memory
   if { $::SRC_SVERILOG  != "" } {
      analyze -format verilog -library ${systemVerilogLib} -top ${systemVerilogTop} -autoread $::SRC_SVERILOG
   }

   # Reset source file lists
   ResetSrcFileLists
}

## Function to load RTL files
proc loadSource args {

   # Strip out the -sim_only flag
   if {[string match {*-sim_only*} $args]} {
      set args [string map {"-sim_only" ""} $args]
      # Not support simulation source code in design compiler yet
      return
   }

   # Parse the list of args
   array set params $args

   if {![info exists params(-path)]} {
      set has_path 0
   } else {
      set has_path 1
   }

   if {![info exists params(-dir)]} {
      set has_dir 0
   } else {
      set has_dir 1
   }

   if {![info exists params(-lib)]} {
      set lib "work"
   } else {
      set lib $params(-lib)
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
      if { [file exists $params(-path)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadSource: $params(-path) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Check the file extension
         set fileExt [file extension $params(-path)]
         if { ${fileExt} eq {.vhd} ||
              ${fileExt} eq {.vhdl}||
              ${fileExt} eq {.v}   ||
              ${fileExt} eq {.vh}  ||
              ${fileExt} eq {.sv} } {
            # Update source file list
            UpdateSrcFileLists $params(-path)
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadSource: $params(-path) does not have a \[.vhd,.vhdl,.v,.vh,.sv\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(-dir)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadSource: $params(-dir) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Get a list of all RTL files
         set list ""
         set list_rc [catch {
            set list [glob -directory $params(-dir) *.vhd *.vhdl *.v *.vh *.sv]
         } _RESULT]
         # Load all the RTL files
         if { ${list} != "" } {
            foreach pntr ${list} {
               # Update source file list
               UpdateSrcFileLists ${pntr}
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadSource: $params(-dir) directory does not have any \[.vhd,.vhdl,.v,.vh,.sv,.dat,.coe,.mem,.edif,.dcp\] files"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   }
}
