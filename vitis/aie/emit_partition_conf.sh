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

# emit_partition_conf.sh — extract AIE partition geometry from Vitis-emitted
# aie_partition.json and write ip/<PROJECT>.partition.conf for aie-partition-init.
#
# Required env vars (inherited from system_vitis_unified_aie.mk via Make):
#   OUT_DIR     — build output root (e.g. firmware/shared/AieLoopback/build)
#   PROJECT     — project name     (e.g. AieLoopback)
#   AIE_IP_DIR  — ip/ staging dir  (e.g. firmware/shared/AieLoopback/ip)
#
# Output: ${AIE_IP_DIR}/${PROJECT}.partition.conf with two lines:
#   PARTITION_ID=<hex>   (consumed by aie-partition-init ioctl; strtoul base-0)
#   UID=<hex>            (used to verify the correct PDI is loaded)
#
# Schema note — three-schema fallback chain:
#   Schema 3 (PRIMARY): the only schema emitted by Vitis 2025.2.
#     Path: .AIE.ai_engine_0.partitions[0]
#     UID  = .aie_pl_intf_id  (present as a hex string)
#     PARTITION_ID is COMPUTED from geometry: (numColumns << 8) | startColumn
#     It is NOT a JSON field in the Schema-3 output; do not attempt to read it.
#   Schema 1 (FALLBACK, never observed in Vitis 2025.x output — kept for
#     forward/backward compatibility):
#     Path: .AIEMLPartition.AIEMLPartitionInst
#     UID  = .AIEPLIntfID   (present as a field)
#     PARTITION_ID = .PartitionID  (present as a field; read directly)
#   Schema 2 (FALLBACK, flat keys, never observed in Vitis 2025.x — same):
#     UID  = .aie_pl_intf_id   (top-level flat key)
#     PARTITION_ID = .partition_id  (top-level flat key; read directly)
#
# Pitfall 2 guard: do NOT read from aie_partition_id.json (Work/config/).
#   Its Unique_ID (e.g. 0x11e05e92) is a different value and would cause
#   AIE_REQUEST_PART_IOCTL to fail on-board. The source is always
#   aie_partition.json at Work/arch/.

set -euo pipefail

JSON="${OUT_DIR}/${PROJECT}/build/hw/Work/arch/aie_partition.json"

# Graceful skip: non-AIE projects have no aiecompiler run, so no JSON.
if [ ! -f "${JSON}" ]; then
    echo "INFO: ${JSON} not found — skipping partition.conf emission (non-AIE project)"
    exit 0
fi

# Defensive mkdir even though package already creates AIE_IP_DIR (Pitfall 4).
mkdir -p "${AIE_IP_DIR}"

UID_VAL=""
PART_ID=""

# ── Schema 3 (PRIMARY — Vitis 2025.2 actual output) ─────────────────────────
uid_s3=$(jq -re '.AIE.ai_engine_0.partitions[0].aie_pl_intf_id // empty' "${JSON}" 2>/dev/null || true)
if [ -n "${uid_s3}" ]; then
    nc_s3=$(jq -e '.AIE.ai_engine_0.partitions[0].numColumns // empty' "${JSON}" 2>/dev/null || true)
    sc_s3=$(jq -e '.AIE.ai_engine_0.partitions[0].startColumn // empty' "${JSON}" 2>/dev/null || true)
    if [ -n "${nc_s3}" ] && [ -n "${sc_s3}" ]; then
        # PARTITION_ID is computed from geometry in Schema 3 — NOT a JSON field.
        # Formula: (numColumns << 8) | startColumn
        # Example: numColumns=38 (0x26), startColumn=0 → 0x2600
        PART_ID=$(printf '0x%04x' $(( (nc_s3 << 8) | sc_s3 )))
        UID_VAL="${uid_s3}"
    fi
fi

# ── Schema 1 (FALLBACK — AIEMLPartition path; dead code against Vitis 2025.x) ─
if [ -z "${UID_VAL}" ]; then
    uid_s1=$(jq -re '.AIEMLPartition.AIEMLPartitionInst.AIEPLIntfID // empty' "${JSON}" 2>/dev/null || true)
    pid_s1=$(jq -re '.AIEMLPartition.AIEMLPartitionInst.PartitionID // empty'  "${JSON}" 2>/dev/null || true)
    if [ -n "${uid_s1}" ] && [ -n "${pid_s1}" ]; then
        # In Schema 1 the PartitionID field exists explicitly — read it directly.
        UID_VAL="${uid_s1}"
        # Normalize to canonical 0x hex form (may already be hex or decimal).
        PART_ID=$(printf '0x%04x' "${pid_s1}")
    fi
fi

# ── Schema 2 (FALLBACK — flat keys; dead code against Vitis 2025.x) ──────────
if [ -z "${UID_VAL}" ]; then
    uid_s2=$(jq -re '.aie_pl_intf_id // empty'  "${JSON}" 2>/dev/null || true)
    pid_s2=$(jq -re '.partition_id // empty'     "${JSON}" 2>/dev/null || true)
    if [ -n "${uid_s2}" ] && [ -n "${pid_s2}" ]; then
        # In Schema 2 the partition_id field exists explicitly — read it directly.
        UID_VAL="${uid_s2}"
        PART_ID=$(printf '0x%04x' "${pid_s2}")
    fi
fi

# ── Fail-loud if no schema matched ──────────────────────────────────────────
if [ -z "${UID_VAL}" ] || [ -z "${PART_ID}" ]; then
    echo "ERROR: could not extract UID or PARTITION_ID from ${JSON} (no schema matched)"
    echo "ERROR: tried Schema 3 (.AIE.ai_engine_0.partitions[0]), Schema 1 (.AIEMLPartition.*), Schema 2 (flat keys)"
    exit 1
fi

CONF="${AIE_IP_DIR}/${PROJECT}.partition.conf"
printf 'PARTITION_ID=%s\nUID=%s\n' "${PART_ID}" "${UID_VAL}" > "${CONF}"
echo "[PASS] partition.conf written: ${CONF}"
