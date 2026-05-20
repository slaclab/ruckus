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
#
# create_proj.py — idempotent Vitis Unified IDE workspace + AIE component
# bootstrap. Driven by system_vitis_unified_aie.mk. Skipped silently if the
# component already exists (so `make build` / `make gui` can call `make proj`
# as a cheap no-op prereq).
#
# Required env vars (set by system_vitis_unified_aie.mk):
#   OUT_DIR              workspace root
#   PROJECT              AIE component name
#   AIE_PLATFORM (xor)   absolute path to .xpfm (dev boards with a shipped
#   AIE_PART     (xor)   xpfm); OR Versal device ID (custom AIE boards
#                        without an xpfm — e.g. xcve2802-vsvh1760-2MP-e-S).
#                        Exactly one must be set; the Makefile asserts this.
#   AIE_SOURCES          whitespace-separated list of source paths. Each
#                        entry is either:
#                          - a FILE path → imports just that file
#                          - a DIRECTORY path → imports every source file
#                            in that directory (non-recursive)
#                        Source extensions: .cpp .cc .h .hpp
#                        All files land flat at the component root.
#   AIE_TOP_LEVEL_FILE   top-level graph file basename (e.g. graph.cpp)
#
# Convention (not configurable, mirrors the HLS flow):
#   aie_config.cfg lives at $(PROJ_DIR)/aie_config.cfg — i.e. the same
#   directory as the consuming Makefile. Referenced below as a relative
#   path that Vitis resolves against the component directory.

import vitis
import os
from collections import defaultdict

SRC_EXTENSIONS = ('.cpp', '.cc', '.h', '.hpp')

workspace          = os.getenv("OUT_DIR")
comp_name          = os.getenv("PROJECT")
aie_platform       = os.getenv("AIE_PLATFORM")
aie_part           = os.getenv("AIE_PART")
aie_sources        = os.getenv("AIE_SOURCES", "").split()
aie_top_level_file = os.getenv("AIE_TOP_LEVEL_FILE")

# Hardcoded — same convention as HLS's `cfg_file = '../../hls_config.cfg'`.
# Resolves to $(PROJ_DIR)/aie_config.cfg (component dir is OUT_DIR/PROJECT,
# OUT_DIR is PROJ_DIR/build, so ../../ lands in PROJ_DIR).
aie_config         = '../../aie_config.cfg'

if not aie_sources:
    raise SystemExit("create_proj: AIE_SOURCES is empty — list the files "
                     "and/or directories in the consuming Makefile, e.g. "
                     "AIE_SOURCES = $(CURDIR)/aie $(CURDIR)/aie/kernels")

# Idempotent — skip if the component is already realized in the workspace.
if os.path.isdir(f'{workspace}/{comp_name}'):
    print(f'AIE component "{comp_name}" already exists at {workspace}/{comp_name} — skipping create_proj.')
    raise SystemExit(0)

# Expand each AIE_SOURCES entry. Files are taken as-is; directories are
# globbed non-recursively for SRC_EXTENSIONS. Missing entries error loudly.
expanded = []
for entry in aie_sources:
    abspath = os.path.abspath(entry)
    if os.path.isfile(abspath):
        expanded.append(abspath)
    elif os.path.isdir(abspath):
        for name in sorted(os.listdir(abspath)):
            full = os.path.join(abspath, name)
            if os.path.isfile(full) and name.endswith(SRC_EXTENSIONS):
                expanded.append(full)
    else:
        raise SystemExit(f"create_proj: AIE_SOURCES entry not found: {entry}")

if not expanded:
    raise SystemExit(f"create_proj: AIE_SOURCES expanded to zero files "
                     f"(looked for extensions {SRC_EXTENSIONS}).")

client = vitis.create_client()
client.set_workspace(workspace)

# create_aie_component accepts either platform=<xpfm> or part=<device-id>
# (the Makefile guarantees exactly one is set).
if aie_platform:
    aie_comp = client.create_aie_component(
        name     = comp_name,
        platform = aie_platform,
        template = "empty",
    )
else:
    aie_comp = client.create_aie_component(
        name     = comp_name,
        part     = aie_part,
        template = "empty",
    )

# Group expanded paths by parent directory so we issue one import_files()
# call per directory. All files land flat at the component root.
groups = defaultdict(list)
for path in expanded:
    groups[os.path.dirname(path)].append(os.path.basename(path))

for from_loc, basenames in groups.items():
    aie_comp.import_files(from_loc=from_loc, files=basenames)

aie_comp.update_top_level_file(top_level_file=aie_top_level_file)
aie_comp.add_cfg_file(aie_config)

aie_comp.report()

vitis.dispose()
