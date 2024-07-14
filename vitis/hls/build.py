#!/usr/bin/env python3
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import vitis
import os

# Project variables
workspace = os.getenv("OUT_DIR")
comp_name = os.getenv("PROJECT")

# Create a client object
client = vitis.create_client()

# Set workspace
client.set_workspace(workspace)

# Set the component
hls_test_comp = client.get_component(comp_name)

# Run c-simulation on the component
hls_test_comp.run('C_SIMULATION')

# Run synthesis on the component
hls_test_comp.run('SYNTHESIS')

# Run co-simulation on the component
hls_test_comp.run('CO_SIMULATION')

# Run package on the component
hls_test_comp.run('PACKAGE')

# Close the client connection and terminate the vitis server
vitis.dispose()
