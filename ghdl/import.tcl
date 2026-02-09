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

if {[file exists "$::env(OUT_DIR)/SRC_VHDL"]} {

   set srcRoot [file normalize "$::env(OUT_DIR)/SRC_VHDL"]

   foreach vhdlLibDir [glob -type d "${srcRoot}/*"] {

      set vhdlLibName [file tail $vhdlLibDir]
      set realLibDir  [GetRealPath $vhdlLibDir]

      set vhdlFiles [glob -nocomplain -types f -directory $realLibDir *.vhd]

      set realFiles {}
      foreach f $vhdlFiles {
         lappend realFiles [GetRealPath $f]
      }

      # puts "$::env(GHDL_CMD) -i $::env(GHDLFLAGS) --work=${vhdlLibName} $realFiles"
      exec $::env(GHDL_CMD) -i {*}$::env(GHDLFLAGS) --work=${vhdlLibName} {*}$realFiles
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
