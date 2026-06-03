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
#   VIVADO_XSA_DIR  AIE_PKG_DIR  AIE_IP_DIR  AIE_PDI  VPP_LOG
#   OUT_DIR  PROJECT  USE_BOOTGEN_FALLBACK

set -euo pipefail

if [ ! -d "${VIVADO_XSA_DIR}" ]; then
  echo "ERROR: VIVADO_XSA_DIR '${VIVADO_XSA_DIR}' is not a directory"
  echo "       Point it at the upstream Vivado target's images/ directory."
  exit 1
fi
# Resolve VIVADO_XSA_DIR to an absolute path BEFORE the `cd "${AIE_PKG_DIR}"`
# below. Callers commonly define it as a relative path (e.g.
# VIVADO_XSA_DIR=../../targets/.../images from the AIE project dir) and
# v++ resolves --platform against its own cwd.
VIVADO_XSA_DIR=$(realpath "${VIVADO_XSA_DIR}")

# Select the newest .xsa by the BUILD_TIME timestamp encoded in the
# IMAGENAME (<project>-<version>-<YYYYMMDDhhmmss>-<user>-<githash>.xsa).
# Files without a 14-digit timestamp sort as oldest (ts=0).
XSA_INPUT=$(
  for f in "${VIVADO_XSA_DIR}"/*.xsa; do
    [ -e "${f}" ] || continue
    ts=$(basename "${f}" | grep -oE '[0-9]{14}' | head -1)
    echo "${ts:-0} ${f}"
  done | sort -n -k1,1 | tail -1 | cut -d' ' -f2-
)
if [ -z "${XSA_INPUT}" ]; then
  echo "ERROR: no .xsa found in ${VIVADO_XSA_DIR}"
  echo "       Build the upstream Vivado target's XSA first."
  exit 1
fi
echo "Using XSA: ${XSA_INPUT}"

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

# Localize stray outputs. v++ and bootgen drop _x/, v++.package_summary,
# v++_package.log, xcd.log, and .Xil/ in the invocation cwd. Run them from
# AIE_PKG_DIR so all of that lands under build/aie_package/ instead of
# polluting PROJ_DIR.
cd "${AIE_PKG_DIR}"

# bootgen path — assemble AIE CDO bins into a dynamic PDI directly. Used
# when (a) USE_BOOTGEN_FALLBACK=1 is set explicitly, or (b) v++ --package
# rejected XSA_INPUT as a non-accelerated platform. SLAC's standard
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

  # Derive id_code/extended_id_code from the Vivado XSA's dynamic (_pld) PDI.
  # Without an explicit id_code, bootgen stamps a generic Versal IDCODE
  # (0x04ca8093) into the partial PDI's image header table and the PLM
  # rejects the runtime load with "IDCODE Checks failed" (PLM Error Status
  # 0x03260014). The XSA always carries the device-correct values in its
  # *_pld.pdi image header table; bootgen -read exposes them.
  local PLD_MEMBER ID_CODE EXT_ID_CODE BG_READ
  PLD_MEMBER=$(unzip -Z1 "${XSA_INPUT}" 2>/dev/null | grep -E '_pld\.pdi$' | head -1)
  if [ -z "${PLD_MEMBER}" ]; then
    echo "ERROR: no *_pld.pdi found inside ${XSA_INPUT} — cannot derive id_code"
    echo "       for the AIE partial PDI (required to pass the PLM IDCODE check)."
    exit 1
  fi
  unzip -p "${XSA_INPUT}" "${PLD_MEMBER}" > "${AIE_PKG_DIR}/_pld_idcode_probe.pdi"
  BG_READ=$(bootgen -arch versal -read "${AIE_PKG_DIR}/_pld_idcode_probe.pdi" 2>/dev/null)
  rm -f "${AIE_PKG_DIR}/_pld_idcode_probe.pdi"
  ID_CODE=$(echo "${BG_READ}" | grep -oE 'id_code \(0x18\) : 0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+$' | head -1)
  EXT_ID_CODE=$(echo "${BG_READ}" | grep -oE 'extended_id_code \(0x44\) : 0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+$' | head -1)
  if [ -z "${ID_CODE}" ] || [ -z "${EXT_ID_CODE}" ]; then
    echo "ERROR: failed to parse id_code/extended_id_code from ${PLD_MEMBER} (bootgen -read)"
    exit 1
  fi
  echo "Derived id_code=${ID_CODE} extended_id_code=${EXT_ID_CODE} from ${PLD_MEMBER}"

  cat > "${AIE_PKG_DIR}/aie_overlay.bif" <<EOF
all:
{
    id_code = ${ID_CODE}
    extended_id_code = ${EXT_ID_CODE}
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
      --platform "${XSA_INPUT}" \
      --package.out_dir "${AIE_PKG_DIR}" \
      --package.boot_mode sd \
      --temp_dir "${AIE_PKG_DIR}/_x" \
      --log_dir "${AIE_PKG_DIR}/_x/logs" \
      --report_dir "${AIE_PKG_DIR}/_x/reports" \
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
      echo "INFO: v++ --package rejected '${XSA_INPUT}' as a non-accelerated platform — falling back to bootgen automatically."
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
