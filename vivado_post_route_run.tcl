##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Get variables and Custom Procedures
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_messages.tcl

# Copy the image from build tree to source tree
exec cp -f $::env(IMPL_DIR)/$::env(PROJECT).bit $::env(IMAGES_DIR)/$::env(IMAGENAME).bit

# Create a compressed version of the image file
exec gzip -c -f -9 $::env(IMAGES_DIR)/$::env(IMAGENAME).bit > $::env(IMAGES_DIR)/$::env(IMAGENAME).bit.gz

# Copy the .ltx file from build tree to source tree
set filePath "$::env(OUT_DIR)/debugProbes.ltx"; # Vivado 2016 (or earlier)
if { [file exists ${filePath}] == 1 } {
   exec cp -f ${filePath} $::env(IMAGES_DIR)/$::env(IMAGENAME).ltx
}
set filePath "$::env(IMPL_DIR)/debug_nets.ltx"; # Vivado 2017 (or later)
if { [file exists ${filePath}] == 1 } {
   exec cp -f ${filePath} $::env(IMAGES_DIR)/$::env(IMAGENAME).ltx
}

# Generate the PROM file
if { [file exists $::env(VIVADO_DIR)/promgen.tcl] == 1 } {
   source $::env(RUCKUS_DIR)/vivado_promgen.tcl
}
