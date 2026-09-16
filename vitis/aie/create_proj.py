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
#                        entry has the form `path[:dest_subdir]`:
#                          - a FILE path → imports just that file
#                          - a DIRECTORY path → imports every source file
#                            in that directory (non-recursive)
#                        Source extensions: .cpp .cc .h .hpp
#                        Without `:dest_subdir`, files land flat at the
#                        component root. With `:dest_subdir`, they are
#                        imported into <component>/<dest_subdir>/ — needed
#                        for the AMD canonical layout where graph.h does
#                        `adf::source(loop) = "kernels/loopback.cc";`.
#                        Example:
#                          AIE_SOURCES = $(CURDIR)/aie \
#                                        $(CURDIR)/aie/kernels:kernels
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

workspace = os.getenv("OUT_DIR")
comp_name = os.getenv("PROJECT")
aie_platform = os.getenv("AIE_PLATFORM")
aie_part = os.getenv("AIE_PART")
aie_sources = os.getenv("AIE_SOURCES", "").split()
aie_top_level_file = os.getenv("AIE_TOP_LEVEL_FILE")

# PROJ_DIR is the parent of OUT_DIR (the script runs with cwd=OUT_DIR per
# system_vitis_unified_aie.mk). User cfg lives at PROJ_DIR/aie_config.cfg
# by convention, mirroring HLS's hls_config.cfg.
proj_dir = os.path.abspath(os.path.join(workspace, '..'))
aie_config_user = os.path.join(proj_dir, 'aie_config.cfg')

# Generated cfg actually attached to the component. We synthesize this so
# that include= directives derived from AIE_SOURCES dest_subdirs are
# always present alongside the user's [aie] settings — without it, the
# aiecompiler can't resolve `adf::source("kernels/loopback.cc")` paths.
# Lives under OUT_DIR (build/), keeping PROJ_DIR clean — the file is a
# regenerable build artifact, not user-managed. include= paths are
# relative to v++'s working directory (<comp>/build/<target>/), so
# `../..` is the component root and `../../<subdir>` is <comp>/<subdir>/.
aie_config_generated = os.path.join(workspace, 'aie_config.generated.cfg')
aie_config_generated_rel = '../aie_config.generated.cfg'

if not aie_sources:
    raise SystemExit("create_proj: AIE_SOURCES is empty — list the files "
                     "and/or directories in the consuming Makefile, e.g. "
                     "AIE_SOURCES = $(CURDIR)/aie $(CURDIR)/aie/kernels")

# Idempotent — skip if the component is already realized in the workspace.
if os.path.isdir(f'{workspace}/{comp_name}'):
    print(
        f'AIE component "{comp_name}" already exists at {workspace}/{comp_name} — skipping create_proj.')
    raise SystemExit(0)

# Expand each AIE_SOURCES entry. Each entry is `path[:dest_subdir]` —
# files are taken as-is; directories are globbed non-recursively for
# SRC_EXTENSIONS. Missing entries error loudly. `dest_subdir` (optional)
# selects an in-component destination directory; default is component
# root (flat). Each expanded item is recorded as (abs_file_path, dest_subdir).
expanded = []
for raw_entry in aie_sources:
    if ':' in raw_entry:
        entry, dest_subdir = raw_entry.rsplit(':', 1)
    else:
        entry, dest_subdir = raw_entry, ''
    abspath = os.path.abspath(entry)
    if os.path.isfile(abspath):
        expanded.append((abspath, dest_subdir))
    elif os.path.isdir(abspath):
        for name in sorted(os.listdir(abspath)):
            full = os.path.join(abspath, name)
            if os.path.isfile(full) and name.endswith(SRC_EXTENSIONS):
                expanded.append((full, dest_subdir))
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
        name=comp_name,
        platform=aie_platform,
        template="empty",
    )
else:
    aie_comp = client.create_aie_component(
        name=comp_name,
        part=aie_part,
        template="empty",
    )

# Group expanded paths by (parent dir, dest_subdir) so we issue one
# import_files() call per (source dir, destination) pair. Files with no
# dest_subdir land flat at the component root.
groups = defaultdict(list)
for path, dest_subdir in expanded:
    groups[(os.path.dirname(path), dest_subdir)].append(os.path.basename(path))

for (from_loc, dest_subdir), basenames in groups.items():
    if dest_subdir:
        aie_comp.import_files(from_loc=from_loc, files=basenames,
                              dest_dir_in_cmp=dest_subdir)
    else:
        aie_comp.import_files(from_loc=from_loc, files=basenames)

aie_comp.update_top_level_file(top_level_file=aie_top_level_file)

# Synthesize PROJ_DIR/aie_config.generated.cfg from auto-derived
# include= directives + the user's aie_config.cfg. Include paths are
# relative to v++'s working directory (<comp>/build/<target>/), so
# `../..` is the component root and `../../<subdir>` reaches each
# AIE_SOURCES dest_subdir. The component root is always added so that
# graph.h / kernels.h are discoverable.
unique_dests = sorted({d for _, d in expanded if d})
include_lines = ['include=../..']
include_lines += [f'include=../../{d}' for d in unique_dests]
header = '\n'.join(include_lines) + '\n\n'
if os.path.isfile(aie_config_user):
    with open(aie_config_user, 'r') as f:
        user_body = f.read()
else:
    user_body = ''
with open(aie_config_generated, 'w') as f:
    f.write('# Auto-generated by ruckus vitis/aie/create_proj.py — DO NOT EDIT.\n')
    f.write('# Edits to aie_config.cfg are merged on every `make proj`.\n')
    f.write('# include= paths are derived from AIE_SOURCES dest_subdirs.\n\n')
    f.write(header)
    f.write(user_body)

# Vitis 2025.2 attaches a default cfg file at component creation; AIE
# components reject a second cfg file. Strip whatever is already attached
# so add_cfg_file() below installs the generated cfg cleanly.
existing_cfg = aie_comp.report().get('cfg_files', []) or []
for cfg in existing_cfg:
    aie_comp.remove_cfg_file(cfg)

aie_comp.add_cfg_file(aie_config_generated_rel)

aie_comp.report()

vitis.dispose()
