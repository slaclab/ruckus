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

## Update source file lists
proc UpdateSrcFileLists {filepath lib} {
   set path ${filepath}
   set fileExt [file extension ${path}]
   set fbasename [file tail ${path}]
   if { ${fileExt} eq {.vhd} ||
        ${fileExt} eq {.vhdl} } {
      set SRC_TYPE "SRC_VHDL"
   } elseif {
        ${fileExt} eq {.v} ||
        ${fileExt} eq {.vh} } {
      set SRC_TYPE "SRC_VERILOG"
   } else {
      set SRC_TYPE "SRC_SVERILOG"
   }
   exec mkdir -p $::env(OUT_DIR)/${SRC_TYPE}
   exec mkdir -p $::env(OUT_DIR)/${SRC_TYPE}/${lib}
   exec ln -s ${path} $::env(OUT_DIR)/${SRC_TYPE}/${lib}/${fbasename}
}

## Analyze source file lists
proc AnalyzeSrcFileLists { } {

   if {[file exist $::env(OUT_DIR)/SRC_VHDL]} {

      set vhdlDir ""
      foreach dir [glob -type d $::env(OUT_DIR)/SRC_VHDL/*] {
         set vhdlLib [file tail ${dir}]
         set vhdlDir "${vhdlDir} -x ${vhdlLib}:${dir}"
      }
      exec cd $::env(OUT_DIR)/SRC_VHDL; vhdeps dump "${vhdlDir}" -o $::env(OUT_DIR)/SRC_VHDL/order

      set vhdlList ""
      set in [open $::env(OUT_DIR)/SRC_VHDL/order r]
      while { [eof ${in}] != 1 } {
         gets ${in} line
         set vhdlLib  [lindex [split ${line}] 1]
         set filePath [lindex [split ${line}] 3]
         read_hdl -language vhdl -library ${vhdlLib} ${filePath}
      }

   }

   if {[file exist $::env(OUT_DIR)/SRC_VERILOG]} {

      set srcList ""
      foreach dir [glob -type d $::env(OUT_DIR)/SRC_VERILOG/*] {
         foreach filePath [glob -type f ${dir}/*] {
            set srcList "${srcList} ${filePath}"
         }
      }
      read_hdl ${srcList}

   }

   if {[file exist $::env(OUT_DIR)/SRC_SVERILOG]} {

      set srcList ""
      foreach dir [glob -type d $::env(OUT_DIR)/SRC_SVERILOG/*] {
         foreach filePath [glob -type f ${dir}/*] {
            set srcList "${srcList} ${filePath}"
         }
      }
      read_hdl -sv ${srcList}

   }

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
            UpdateSrcFileLists $params(-path) ${lib}
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
               UpdateSrcFileLists ${pntr} ${lib}
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
