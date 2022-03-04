##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_DIR)/shared/proc.tcl

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
