##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Warning : Declaration is ignored for synthesis. [VHDL-667]
# Declaration 'TPD_G' of physical type 'TIME'
suppress_messages { VHDL-667 }

# Warning : Ignoring 'after' clause in signal assignment. [VHDL-616]
suppress_messages { VHDL-616 }

# Warning : Assertion statements are ignored for synthesis. [VHDL-644]
suppress_messages { VHDL-644 }

# Warning : Concurrent assertion statements are ignored for synthesis. [VHDL-645]
suppress_messages { VHDL-645 }

# Warning : Initial values are ignored for synthesis. [VHDL-639]
suppress_messages { VHDL-639 }

# Warning : Report statements are ignored for synthesis. [VHDL-643]
suppress_messages { VHDL-643 }

# Warning : Ignoring unsynthesizable delay specifier (#<n>) mentioned in verilog file.
# These delay numbers are for simulation purpose only. [VLOGPT-35]
# in file 'surf/i2cSlave.sv' on line 401, column 20.
suppress_messages { VLOGPT-35 }

# Warning : Real value rounded to nearest integral value. [CDFG-371]
# : Real value XXX.000000 rounded to nearest integer value XXX
suppress_messages { CDFG-371 }

# Check for user messages.tcl script
if { [file exists $::env(PROJ_DIR)/syn/messages.tcl] == 1 } {
   source $::env(PROJ_DIR)/syn/messages.tcl
}
