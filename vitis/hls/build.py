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
import shutil
import zipfile

# Project variables
workspace = os.getenv("OUT_DIR")
comp_name = os.getenv("PROJECT")
proj_zip  = f'{workspace}/{comp_name}/{comp_name}/{comp_name}.zip'
build_zip = f'{os.getenv("PROJ_DIR")}/ip/{comp_name}.zip'

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

# Check if ALL_XIL_FAMILY is enabled
if int(os.getenv("ALL_XIL_FAMILY")) > 0:

    # Over the .ZIP file and decompress it
    ip_path = f'{workspace}/ip'
    os.system( f'rm -rf {ip_path}' )
    os.system( f'mkdir {ip_path}' )
    os.system( f'unzip {proj_zip} -d {ip_path}' )

    # Read and modify component.xml
    component_path = f'{ip_path}/component.xml'
    temp_path = f'{ip_path}/component.temp'
    with open(component_path, 'r') as infile, open(temp_path, 'w') as outfile:
        xil_family = """
<xilinx:family xilinx:lifeCycle="Production">artix7</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">kintex7</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">virtex7</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">zynq</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">kintexu</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">virtexu</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">kintexuplus</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">virtexuplus</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">virtexuplusHBM</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">zynquplus</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">zynquplusRFSOC</xilinx:family>
<xilinx:family xilinx:lifeCycle="Production">versal</xilinx:family>
"""
        for line in infile:
            if 'xilinx:family' in line:
                outfile.write(xil_family)
            else:
                outfile.write(line)

    # Replace the original component.xml with the modified one
    shutil.move(temp_path, component_path)

    # Compress the modify IP directory to the target's image directory
    os.system( f'bash -c "cd {ip_path}; zip -r {build_zip} *"' )

else:
    # Copy the .ZIP file to the local ip/ directory
    shutil.copy(proj_zip, build_zip)

print( f'\n\n\nHLS output file: {build_zip}' )
