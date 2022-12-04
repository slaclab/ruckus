##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

source $::env(RUCKUS_DIR)/shared/proc.tcl

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

proc CopyBitstream { } {
   exec mkdir -p $::env(IMAGES_DIR)
   set binFile [glob -directory $::env(OUT_DIR)/user_design *.bin]
   exec cp -f ${binFile} $::env(IMAGES_DIR)/$::env(IMAGENAME).bin
   puts "\n\nBitstream file copied to $::env(IMAGES_DIR)/$::env(IMAGENAME).bin\n\n"
}

proc CopyFabricHdlFiles { } {
   exec rm   -rf $::env(HDL_DIR)
   exec mkdir -p $::env(HDL_DIR)

   if { $::env(HDL_TYPE) == "verilog" } {
      set fileExt ".v"
   } else {
      set fileExt ".vhdl"
   }

   foreach filePath [exec find $::env(OUT_DIR)/Tile -name *${fileExt}] {
      exec cp -f ${filePath} $::env(HDL_DIR)/.
   }

   foreach filePath [exec find $::env(OUT_DIR)/Fabric -name *${fileExt}] {
      exec cp -f ${filePath} $::env(HDL_DIR)/.
   }

   puts "\n\neFPGA HDL files copied to $::env(HDL_DIR)\n\n"
}

# Copy over the user design files
proc CopyUserDesign { } {
   exec rm -rf $::env(OUT_DIR)/user_design
   if { [file exists $::env(PROJ_DIR)/user_design] != 1 } {
      puts "\n\n$::env(PROJ_DIR)/user_design does NOT exist!!\n\n"
      return -1
   } else {
      exec cp -rf $::env(PROJ_DIR)/user_design $::env(OUT_DIR)/user_design
      return 1
   }
}

###############################################################
#### Loading Source Code Functions ############################
###############################################################
