##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vitis/elf.tcl
# \brief This script builds the .elf file

# Get build system variables 
source $::env(RUCKUS_DIR)/vivado_env_var.tcl

# Generate .ELF
setws ${VITIS_PRJ}
app build -name app_0

# Copy over .ELF file to image directory
exec cp -f ${VITIS_PRJ}/app_0/Release/app_0.elf ${VITIS_ELF} 
exec chmod 664 ${VITIS_ELF} 

# Exit the `xsct -interactive`
exit
