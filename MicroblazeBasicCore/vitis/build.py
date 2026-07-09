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

## \file vitis/build.py
# \brief Builds the MicroBlaze .ELF using the Vitis Unified Python API.
#        This is the Vitis 2026.1+ replacement for the XSCT-based prj.tcl/elf.tcl
#        flow (XSCT was removed in Vitis 2026.1).

import vitis
import os
import glob
import shutil

# Get build system variables (exported by system_vivado.mk).
# Resolve symlinks: the generated CMakeLists.txt collects sources from BOTH
# aux_source_directory() (which CMake stores as the real path) and
# USER_COMPILE_SOURCES (which expands $ENV{VITIS_PRJ}). If $::env(OUT_DIR)/build
# is a symlink, those two spellings differ and every source compiles twice
# ("multiple definition" at link). Canonicalizing here (and re-exporting
# VITIS_PRJ so the CMake-time expansion matches) keeps both spellings identical.
vitis_prj = os.path.realpath(os.environ['VITIS_PRJ'])
vitis_elf = os.environ['VITIS_ELF']
vitis_src = os.environ['VITIS_SRC_PATH']
out_dir   = os.path.realpath(os.environ['OUT_DIR'])
project   = os.environ['PROJECT']
embed_proc = os.environ['EMBED_PROC']
os.environ['VITIS_PRJ'] = vitis_prj

# VITIS_LIB is a space-separated list of library source directories
vitis_lib = os.environ.get('VITIS_LIB', '').split()

xsa_path      = os.path.join(out_dir, f'{project}.xsa')
platform_name = f'{project}_platform'
app_name      = 'app_0'
domain_name   = 'microblaze'

# Remove any stale Vitis workspace
if os.path.isdir(vitis_prj):
    shutil.rmtree(vitis_prj, ignore_errors=True)

# Create a client object and set the workspace
client = vitis.create_client()
client.set_workspace(vitis_prj)

# Create the platform from the Vivado-exported .xsa, add a standalone
# MicroBlaze domain, and build the platform
platform = client.create_platform_component(name=platform_name, hw_design=xsa_path)
platform.add_domain(name=domain_name, cpu=embed_proc, os='standalone')
platform.build()

# Create an empty application component on the generated platform
platform_xpfm = client.find_platform_in_repos(platform_name)
app = client.create_app_component(name=app_name, platform=platform_xpfm, domain=domain_name)

# Import the user sources into the application's src/ directory
app.import_files(from_loc=vitis_src, dest_dir_in_cmp='src')

# Import the library sources (e.g. surf/.../sdk/common: ssi_printf.c, printf.c) so the
# .c files get compiled, and add each library directory as an include path so headers
# resolve. Mirrors the legacy prj.tcl include-path + source-link behavior.
for lib in vitis_lib:
    app.import_files(from_loc=lib, dest_dir_in_cmp='src')
    app.append_app_config(key='USER_INCLUDE_DIRECTORIES', values=lib)

# Optimize for size (legacy used "Optimize for size (-Os)")
app.set_app_config(key='USER_COMPILE_OPTIMIZATION_LEVEL', values='-Os')

# Build the application -> produces the .ELF
app.build()

# Locate the built .ELF and copy it to the standardized location ($VITIS_ELF)
elf_list = glob.glob(os.path.join(app.component_location, '**', f'{app_name}.elf'), recursive=True)
if not elf_list:
    elf_list = glob.glob(os.path.join(app.component_location, '**', '*.elf'), recursive=True)
if not elf_list:
    vitis.dispose()
    raise RuntimeError(f'build.py: no .elf produced under {app.component_location}')

shutil.copyfile(elf_list[0], vitis_elf)
os.chmod(vitis_elf, 0o664)
print(f'build.py: copied {elf_list[0]} -> {vitis_elf}')

# Close the client connection and terminate the vitis server
vitis.dispose()
