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
#
# package.sh — wrap the Python-built AIE libadf.a + the Vivado-built XSA into
# a dynamic PDI via `v++ --package` (primary) or `bootgen` (fallback when
# USE_BOOTGEN_FALLBACK=1). Driven by the `package` target in
# system_vitis_unified_aie.mk; runs after `make build` produced the AIE component
# under $OUT_DIR/$PROJECT/.
#
# The Vitis Unified Python AIE component build only emits libadf.a — final
# PDI packaging still requires v++ --package (or bootgen), so this step
# remains bash.
#
# Required env vars (set by system_vitis_unified_aie.mk):
#   AIE_XSA_INPUT  AIE_PKG_DIR  AIE_IP_DIR  AIE_PDI  VPP_LOG
#   OUT_DIR  PROJECT  USE_BOOTGEN_FALLBACK

set -euo pipefail

if [ ! -f "${AIE_XSA_INPUT}" ]; then
  echo "ERROR: AIE_XSA_INPUT not found at ${AIE_XSA_INPUT}"
  echo "       Build the upstream Vivado target's XSA first."
  exit 1
fi

# Locate the AIE component's hw libadf.a. The Vitis Unified IDE places it
# under <workspace>/<comp>/build/hw/ but the exact subdir can vary across
# minor Vitis versions — find the first match under the component dir.
LIBADF=$(find "${OUT_DIR}/${PROJECT}" -path "*/build/hw/*" -name "libadf.a" 2>/dev/null | head -1)
if [ -z "${LIBADF}" ]; then
  echo "ERROR: libadf.a not found under ${OUT_DIR}/${PROJECT}/build/hw/"
  echo "       Did 'make build' complete? Inspect the Vitis build log."
  exit 1
fi
echo "Using AIE archive: ${LIBADF}"

mkdir -p "${AIE_PKG_DIR}" "${AIE_IP_DIR}"
echo "==== package (USE_BOOTGEN_FALLBACK=${USE_BOOTGEN_FALLBACK}) ===="

# bootgen path — assemble AIE CDO bins into a dynamic PDI directly. Used
# when (a) USE_BOOTGEN_FALLBACK=1 is set explicitly, or (b) v++ --package
# rejected AIE_XSA_INPUT as a non-accelerated platform. SLAC's standard
# Versal SoC firmware XSAs (axi-soc-versal-core) are non-accelerated, so
# the auto-fallback covers the SLAC default flow without the caller
# having to know about the bootgen escape hatch.
run_bootgen() {
  echo "---- bootgen fallback ----"
  local AIE_CDO_DIR
  AIE_CDO_DIR=$(find "${OUT_DIR}/${PROJECT}" -type d -path "*/ps/cdo" 2>/dev/null | head -1)
  if [ -z "${AIE_CDO_DIR}" ]; then
    echo "ERROR: AIE CDO directory (ps/cdo) not found under ${OUT_DIR}/${PROJECT}"
    exit 1
  fi
  cat > "${AIE_PKG_DIR}/aie_overlay.bif" <<EOF
all:
{
    image
    {
        name=aie_image, id=0x1c000000
        { type=cdo
          file = ${AIE_CDO_DIR}/aie_cdo_reset.bin
          file = ${AIE_CDO_DIR}/aie_cdo_clock_gating.bin
          file = ${AIE_CDO_DIR}/aie_cdo_error_handling.bin
          file = ${AIE_CDO_DIR}/aie_cdo_elfs.bin
          file = ${AIE_CDO_DIR}/aie_cdo_init.bin
          file = ${AIE_CDO_DIR}/aie_cdo_enable.bin
        }
    }
}
EOF
  bootgen -arch versal -image "${AIE_PKG_DIR}/aie_overlay.bif" -o "${AIE_PDI}" -w 2>&1 | tee -a "${VPP_LOG}"
}

if [ "${USE_BOOTGEN_FALLBACK}" = "1" ]; then
  run_bootgen
else
  echo "---- v++ --package primary ----"
  set +e
  v++ --package \
      --target hw \
      --platform "${AIE_XSA_INPUT}" \
      --package.out_dir "${AIE_PKG_DIR}" \
      --package.boot_mode sd \
      "${LIBADF}" \
      2>&1 | tee "${VPP_LOG}"
  VPP_RC=${PIPESTATUS[0]}
  set -e

  if [ "${VPP_RC}" -ne 0 ]; then
    # AMD policy: v++ --package rejects non-accelerated platforms (stock
    # SoC XSAs without PFM acceleration metadata). SLAC SoC XSAs are
    # always non-accelerated, so auto-fall back to bootgen on this exact
    # rejection. Any other failure stays a hard error.
    if grep -qE "non-accelerated platform|\[v\+\+ 60-1606\]" "${VPP_LOG}"; then
      echo "INFO: v++ --package rejected '${AIE_XSA_INPUT}' as a non-accelerated platform — falling back to bootgen automatically."
      run_bootgen
    else
      echo "ERROR: v++ --package failed (rc=${VPP_RC}). See ${VPP_LOG}."
      echo "       Force the bootgen path with: make USE_BOOTGEN_FALLBACK=1 package"
      exit "${VPP_RC}"
    fi
  else
    PDI=$(find "${AIE_PKG_DIR}" -name "pl.pdi" -o -name "*_pld.pdi" -o -name "*.pdi" 2>/dev/null | head -1)
    if [ -z "${PDI}" ]; then
      echo "ERROR: v++ --package succeeded but produced no PDI under ${AIE_PKG_DIR}"
      echo "       Inspect ${VPP_LOG}; engage USE_BOOTGEN_FALLBACK=1"
      echo "       Re-run with: make USE_BOOTGEN_FALLBACK=1 package"
      exit 1
    fi
    cp -f "${PDI}" "${AIE_PDI}"
  fi
fi

echo "AIE dynamic PDI staged: ${AIE_PDI}"
