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

# import_dtbo.sh — populate ip/<PROJECT>.dtbo so ip/ carries the full
# /boot/aie/ runtime triple (pdi + partition.conf + dtbo). Invoked by the
# `dtbo` target in system_vitis_unified_aie.mk.
#
# Required env vars (inherited from system_vitis_unified_aie.mk via Make):
#   AIE_DTBO_SRC         — source overlay: either a loose .dtbo file or a
#                          *.linux.tar.gz/.tgz PetaLinux image archive. May be
#                          a glob (the newest match by mtime is used) — the
#                          archive name typically embeds a build timestamp.
#   AIE_IP_DTBO          — output path (e.g. firmware/shared/<name>/ip/<name>.dtbo)
#
# Optional env vars:
#   AIE_DTBO_TAR_MEMBER  — member extracted when AIE_DTBO_SRC is an archive
#                          (default: linux/pl.dtbo, the axi-soc-versal-core layout)
#   AIE_IP_DIR           — ip/ staging dir (defaults to $(dirname AIE_IP_DTBO))
#
# Hard-fails (exit 1) if AIE_DTBO_SRC is unset, no readable source matches, the
# archive member is absent, the extension is unrecognized, or the result is
# empty — the overlay is required for the boot loop to load the AIE PDI.

set -euo pipefail

: "${AIE_DTBO_SRC:?AIE_DTBO_SRC not set — point it at a *.linux.tar.gz image archive or a loose .dtbo file (e.g. make AIE_DTBO_SRC=<target>/images/<name>.linux.tar.gz dtbo)}"
: "${AIE_IP_DTBO:?AIE_IP_DTBO not set — expected from system_vitis_unified_aie.mk}"

TAR_MEMBER="${AIE_DTBO_TAR_MEMBER:-linux/pl.dtbo}"
IP_DIR="${AIE_IP_DIR:-$(dirname "${AIE_IP_DTBO}")}"

mkdir -p "${IP_DIR}"

# Resolve AIE_DTBO_SRC (may be a glob); pick the newest match by mtime.
# Unquoted on purpose so the shell expands any wildcard.
# shellcheck disable=SC2086
SRC=$(ls -t ${AIE_DTBO_SRC} 2>/dev/null | head -n1 || true)
if [ -z "${SRC}" ] || [ ! -r "${SRC}" ]; then
    echo "ERROR: no readable source matches AIE_DTBO_SRC='${AIE_DTBO_SRC}'"
    echo "       (build the Vivado target image first, or fix the path)"
    exit 1
fi

case "${SRC}" in
    *.tar.gz|*.tgz)
        echo "Extracting ${TAR_MEMBER} from $(basename "${SRC}")"
        if ! tar -xzf "${SRC}" -O "${TAR_MEMBER}" > "${AIE_IP_DTBO}"; then
            echo "ERROR: failed to extract '${TAR_MEMBER}' from ${SRC}"
            rm -f "${AIE_IP_DTBO}"
            exit 1
        fi
        ;;
    *.dtbo)
        echo "Copying $(basename "${SRC}")"
        cp -f "${SRC}" "${AIE_IP_DTBO}"
        ;;
    *)
        echo "ERROR: source '${SRC}' has unrecognized extension"
        echo "       (expected *.dtbo, *.tar.gz, or *.tgz)"
        exit 1
        ;;
esac

if [ ! -s "${AIE_IP_DTBO}" ]; then
    echo "ERROR: imported overlay '${AIE_IP_DTBO}' is empty"
    rm -f "${AIE_IP_DTBO}"
    exit 1
fi

echo "[PASS] dtbo imported: ${AIE_IP_DTBO} ($(stat -c%s "${AIE_IP_DTBO}") bytes)"
