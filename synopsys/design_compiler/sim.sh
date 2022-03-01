#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

# --- Compile StdCells
vlogan $SIM_CARGS_VERILOG $STD_CELL_LIB

# Check for custom user source code setup
if [ -f "$PROJ_DIR/sim/sim.sh" ]; then
   source $PROJ_DIR/sim/sim.sh

# Else use the default simulation code structure
else
   # --- Compile PnR sources
   vlogan $SIM_CARGS_VERILOG $SYN_OUT_DIR/${PROJECT}_g.v

   # --- Compile the system verilog simulation testbed
   vlogan -sverilog $SIM_CARGS_VERILOG $SIM_SV_TESTBBED
fi

# Run the testbench
vcs tb_${PROJECT} $SIM_VCS_FLAGS -fgp -timescale=$SIM_TIMESCALE
./simv -gui=dve -fgp=num_threads:$MAX_CORES +vcs+initreg+0
