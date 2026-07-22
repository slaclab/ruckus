#!/usr/bin/env python3
##############################################################################
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
# https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
##############################################################################
#
# build.py — drives the AIE component build via the Vitis Unified Python API.
# Defaults to target='hw' (production libadf.a); pass --x86sim for the
# simulator build (analog of HLS csim).
#
# Required env vars (set by system_vitis_aie.mk):
#   OUT_DIR   workspace root (must be the cwd; system_vitis_aie.mk does cd)
#   PROJECT   AIE component name

import vitis
import os
import argparse

parser = argparse.ArgumentParser(prog="Vitis AIE build script")
parser.add_argument("--x86sim", default=False, action="store_true",
                    help="Build for x86 simulator instead of hardware.")
args = parser.parse_args()

target = "x86sim" if args.x86sim else "hw"
workspace = os.getenv("OUT_DIR")
comp_name = os.getenv("PROJECT")

client = vitis.create_client()
client.set_workspace(workspace)

aie_comp = client.get_component(comp_name)
aie_comp.build(target=target)

vitis.dispose()
