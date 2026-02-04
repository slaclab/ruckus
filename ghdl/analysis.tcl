#!/usr/bin/tclsh
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

if {[file exist $::env(OUT_DIR)/SRC_VHDL]} {
   set srcRoot [file normalize $::env(OUT_DIR)/SRC_VHDL]
   set vhdlDir ""
   foreach dir [glob -type d ${srcRoot}/*] {
      set vhdlLib [file tail ${dir}]
      set vhdlDir "${vhdlDir} -x ${vhdlLib}:${dir}"
   }
   exec bash -c "vhdeps dump ${vhdlDir} -o $::env(OUT_DIR)/SRC_VHDL/order"
   set fp [open $::env(OUT_DIR)/SRC_VHDL/order r]
   set file_data  [read $fp]
   close $fp
   set vhdlOrderList [split $file_data "\n"]
   foreach line ${vhdlOrderList} {
      if { ${line} != ""} {
         set vhdlLib  [lindex [split ${line}] 1]
         set filePath [lindex [split ${line}] 3]
         puts "ghdl -a ${filePath}"
         exec bash -c "ghdl -a $::env(GHDLFLAGS) -P$::env(OUT_DIR) --work=${vhdlLib} ${filePath}"
      }
   }
}

if {[file exist $::env(OUT_DIR)/SRC_VERILOG]} {

   # SRC_VERILOG: Not Support in GHDL (yet)
   set notSupported 1

}

if {[file exist $::env(OUT_DIR)/SRC_SVERILOG]} {

   # SRC_SVERILOG: Not Support in GHDL (yet)
   set notSupported 1

}
