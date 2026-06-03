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
# program.sh — generic AIE PDI deploy helper invoked by the `program` target
# in system_vitis_unified_aie.mk. Uploads the dynamic PDI + matching DTBO
# (and optional partition.conf sidecar) to /boot/aie/<name>.{pdi,dtbo,
# partition.conf} on the target board, optionally reboots, and verifies that
# the Phase-2 startup-app-init boot loop loaded the AIE and the
# aie-partition-init@<name>.service instance is active.
#
# The <name> is the -p PDI basename minus .pdi, with any legacy dynamic-PDI
# suffix stripped: AieLoopback.pdi -> AieLoopback (legacy
# AieLoopback_aie_dynamic.pdi -> AieLoopback still works). The dtbo is renamed
# to <name>.dtbo at the destination so all three triple members share the
# normalized basename (required for the Phase-2 boot loop to find them).
#
# Required flags:
#   -p <path>        runtime PDI to upload
#   -d <path>        matching device-tree overlay
#   -i <user@host>   board target (no default — required)
#
# Optional flags:
#   -c <path>        partition.conf sidecar (default: derived from PDI dir as
#                    $(dirname PDI)/<name>.partition.conf); warn-not-fail if
#                    absent — pdi+dtbo still upload, aie-partition-init will
#                    not start for this image
#   -r               stage-only: upload triple to /boot/aie/ without rebooting
#                    or verifying (useful when scheduling a maintenance window)
#   -h               show this help
#
# Exit codes:
#   0  success: triple deployed and AIE loaded (journalctl confirms) with
#      aie-partition-init@<name>.service active and /sys/class/aie present
#   1  local pre-flight failed (missing/invalid -p/-d/-i, or static-PDI guard)
#   2  scp/ssh failure during upload
#   3  post-reboot verification failed (board didn't come up, or AIE load line
#      never appeared within PL_LOAD_TIMEOUT, or systemd/sysfs check failed)

set -euo pipefail

BOARD_IP=""
PDI_LOCAL=""
DTBO_LOCAL=""
CONF_LOCAL=""
DO_REBOOT=1
BOARD_UP_TIMEOUT=90
PL_LOAD_TIMEOUT=30

show_help() {
    cat <<'EOF'
Usage: program.sh -p <pdi> -d <dtbo> -i <user@host> [-c <conf>] [-r] [-h]

AIE PDI deploy helper. Uploads PDI + DTBO (+ optional partition.conf sidecar)
to /boot/aie/<name>/ on the target board, optionally reboots, and verifies
that the AIE design loaded via the startup-app-init boot loop.

The <name> is the PDI basename minus .pdi, with any legacy _aie_dynamic or
_dynamic suffix stripped: AieLoopback.pdi -> AieLoopback.

Flags:
  -p <path>        runtime PDI to upload (required; must not be *_static*)
  -d <path>        matching device-tree overlay (required)
  -i <user@host>   board target (required, e.g. root@192.168.1.10)
  -c <path>        partition.conf sidecar; if omitted, derived from PDI dir
                   as <pdi-dir>/<name>.partition.conf (warn-not-fail if absent)
  -r               stage-only: upload triple, skip reboot and verification
  -h               show this help
EOF
    exit 0
}

while getopts "i:p:d:c:rh" flag; do
    case "$flag" in
        i) BOARD_IP="$OPTARG" ;;
        p) PDI_LOCAL="$OPTARG" ;;
        d) DTBO_LOCAL="$OPTARG" ;;
        c) CONF_LOCAL="$OPTARG" ;;
        r) DO_REBOOT=0 ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# Derive the normalized <name> from the PDI basename (D-01):
#   AieLoopback.pdi -> AieLoopback  (legacy AieLoopback_aie_dynamic.pdi ->
#   AieLoopback_aie_dynamic -> AieLoopback also collapses via the strips below)
# This round-trips through the Phase-2 boot loop's own derivation:
#   base="${pdi%.pdi}"; name="$(basename "$base")"
# so the uploaded /boot/aie/<name>.pdi filename matches what the boot loop
# expects for the dtbo, conf, and aie-partition-init@<name>.service lookups.
derive_name() {
    local name
    name="$(basename "$PDI_LOCAL" .pdi)"
    name="${name%_aie_dynamic}"
    name="${name%_dynamic}"
    echo "$name"
}

preflight() {
    local fail=0
    if [[ -z "$BOARD_IP" ]]; then
        echo "[FAIL] -i <user@host> not provided"
        fail=$(( fail + 1 ))
    fi
    # Defend against uploading the static (boot-image) PDI as the runtime
    # overlay. The pair is <name>_static.pdi (BOOT.BIN half) vs the dynamic
    # overlay (<name>.pdi, or legacy <name>_dynamic.pdi / <name>_aie_dynamic.pdi).
    if [[ -n "$PDI_LOCAL" ]] && [[ "$PDI_LOCAL" == *_static* ]]; then
        echo "[FAIL] -p filename '$PDI_LOCAL' contains '_static'."
        echo "       Refusing to upload static PDI as runtime overlay;"
        echo "       pass the dynamic overlay PDI (<name>.pdi) instead."
        fail=$(( fail + 1 ))
    fi
    if [[ -z "$PDI_LOCAL" ]] || [[ ! -s "$PDI_LOCAL" ]]; then
        echo "[FAIL] -p missing or empty (PDI='$PDI_LOCAL')"
        fail=$(( fail + 1 ))
    else
        echo "[PASS] PDI present at $PDI_LOCAL ($(stat -c%s "$PDI_LOCAL") bytes)"
    fi
    if [[ -z "$DTBO_LOCAL" ]] || [[ ! -s "$DTBO_LOCAL" ]]; then
        echo "[FAIL] -d missing or empty (DTBO='$DTBO_LOCAL')"
        fail=$(( fail + 1 ))
    else
        echo "[PASS] DTBO present at $DTBO_LOCAL ($(stat -c%s "$DTBO_LOCAL") bytes)"
    fi
    if [[ -n "$BOARD_IP" ]]; then
        if ssh -o ConnectTimeout=5 -o BatchMode=yes -o ForwardX11=no \
               "$BOARD_IP" 'true' >/dev/null 2>&1; then
            echo "[PASS] $BOARD_IP reachable via ssh"
        else
            echo "[FAIL] $BOARD_IP unreachable via ssh (ssh-key auth required;"
            echo "       no password prompt under BatchMode=yes)"
            fail=$(( fail + 1 ))
        fi
    fi
    [[ $fail -eq 0 ]] || return 1
    return 0
}

upload() {
    local name="$1"
    # Resolve partition.conf: use -c override if given, else auto-derive from PDI dir.
    local conf_src
    if [[ -n "$CONF_LOCAL" ]]; then
        conf_src="$CONF_LOCAL"
    else
        conf_src="$(dirname "$PDI_LOCAL")/${name}.partition.conf"
    fi

    # Ensure the destination directory exists on the board before scp.
    ssh -o BatchMode=yes -o ConnectTimeout=5 -o ForwardX11=no \
        "$BOARD_IP" 'mkdir -p /boot/aie'

    echo "---- scp $(basename "$PDI_LOCAL") -> $BOARD_IP:/boot/aie/${name}.pdi ----"
    scp -o BatchMode=yes -o ConnectTimeout=5 -o ForwardX11=no \
        "$PDI_LOCAL" "$BOARD_IP:/boot/aie/${name}.pdi"
    echo "[PASS] ${name}.pdi uploaded"

    echo "---- scp $(basename "$DTBO_LOCAL") -> $BOARD_IP:/boot/aie/${name}.dtbo ----"
    scp -o BatchMode=yes -o ConnectTimeout=5 -o ForwardX11=no \
        "$DTBO_LOCAL" "$BOARD_IP:/boot/aie/${name}.dtbo"
    echo "[PASS] ${name}.dtbo uploaded"

    # Upload partition.conf sidecar if present (D-02b): warn-not-fail if absent.
    if [[ -s "$conf_src" ]]; then
        echo "---- scp $(basename "$conf_src") -> $BOARD_IP:/boot/aie/${name}.partition.conf ----"
        scp -o BatchMode=yes -o ConnectTimeout=5 -o ForwardX11=no \
            "$conf_src" "$BOARD_IP:/boot/aie/${name}.partition.conf"
        echo "[PASS] ${name}.partition.conf uploaded"
        CONF_UPLOADED="$conf_src"
    else
        echo "WARNING: no ${name}.partition.conf found — aie-partition-init will not start for ${name}"
        CONF_UPLOADED=""
    fi
}

reboot_board() {
    echo "---- rebooting $BOARD_IP (sync; reboot) ----"
    # Disconnection from the reboot itself is expected; suppress rc with || true.
    ssh -o BatchMode=yes -o ConnectTimeout=5 \
        -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
        -o ForwardX11=no \
        "$BOARD_IP" '/bin/sync; /sbin/reboot' || true
}

wait_for_board_up() {
    local elapsed=0
    echo "---- polling $BOARD_IP for ssh liveness (deadline ${BOARD_UP_TIMEOUT}s) ----"
    while [[ $elapsed -lt $BOARD_UP_TIMEOUT ]]; do
        if ssh -o ConnectTimeout=3 -o BatchMode=yes -o ForwardX11=no \
               "$BOARD_IP" 'true' >/dev/null 2>&1; then
            echo "[PASS] board up after ${elapsed}s"
            return 0
        fi
        sleep 5
        elapsed=$(( elapsed + 5 ))
    done
    return 1
}

# Poll journalctl for the Phase-2 startup-app-init AIE load log line.
# The boot loop emits: AIE load: $pdi + $dtbo
# We match the leading substring: AIE load: /boot/aie/<name>.pdi
# journalctl -b restricts to the current boot so a line from a prior boot
# cannot produce a false success (D-03b).
wait_for_aie_load_complete() {
    local name="$1"
    local elapsed=0
    echo "---- polling $BOARD_IP for AIE load log line (deadline ${PL_LOAD_TIMEOUT}s) ----"
    while [[ $elapsed -lt $PL_LOAD_TIMEOUT ]]; do
        if ssh -o ConnectTimeout=3 -o BatchMode=yes -o ForwardX11=no \
               "$BOARD_IP" "journalctl -b 2>/dev/null | grep -q 'AIE load: /boot/aie/${name}.pdi'" \
               >/dev/null 2>&1; then
            echo "[PASS] AIE load complete after ${elapsed}s"
            return 0
        fi
        sleep 3
        elapsed=$(( elapsed + 3 ))
    done
    return 1
}

# Final one-shot check: aie-partition-init@<name>.service must be active AND
# /sys/class/aie must exist (confirms the xilinx-ai-engine driver enumerated
# the partition). No dependence on fpga_manager/fpga0/state (D-03).
check_aie_active() {
    local name="$1"
    local svc_state
    svc_state=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o ForwardX11=no \
        "$BOARD_IP" "systemctl is-active aie-partition-init@${name}.service" 2>&1) || true
    svc_state="${svc_state%$'\n'}"
    if [[ "$svc_state" != "active" ]]; then
        echo "[FAIL] aie-partition-init@${name}.service is '$svc_state' (expected 'active')"
        return 1
    fi
    echo "[PASS] aie-partition-init@${name}.service is active"
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o ForwardX11=no \
             "$BOARD_IP" '[ -d /sys/class/aie ]' >/dev/null 2>&1; then
        echo "[FAIL] /sys/class/aie not present on board"
        return 1
    fi
    echo "[PASS] /sys/class/aie present"
    return 0
}

print_summary() {
    local overall="$1"
    local name="$2"
    local verdict
    if [[ $DO_REBOOT -eq 0 ]]; then
        verdict="Staged to /boot/aie/ — reboot required to load AIE (verification skipped)"
    elif [[ $overall -eq 0 ]]; then
        verdict="AIE PROGRAMMED"
    else
        verdict="FAILED"
    fi
    echo "=============================================================="
    echo " AIE PROGRAM SUMMARY"
    echo "--------------------------------------------------------------"
    echo "  Board IP:           $BOARD_IP"
    echo "  PDI uploaded:       $PDI_LOCAL"
    echo "  DTBO uploaded:      $DTBO_LOCAL"
    echo "  Conf uploaded:      ${CONF_UPLOADED:-<none — aie-partition-init will not start>}"
    echo "  Dest dir:           /boot/aie/${name}"
    echo "  Reboot performed:   $([[ $DO_REBOOT -eq 1 ]] && echo yes || echo no)"
    echo "--------------------------------------------------------------"
    echo " Overall: $verdict"
    echo "=============================================================="
}

CONF_UPLOADED=""

NAME=$(derive_name)

printf '[%s] program.sh start: BOARD_IP=%s PDI=%s DTBO=%s DO_REBOOT=%s\n' \
    "$(date -Iseconds)" "$BOARD_IP" "$PDI_LOCAL" "$DTBO_LOCAL" "$DO_REBOOT"

preflight                  || exit 1
upload "$NAME"             || exit 2

if [[ $DO_REBOOT -eq 0 ]]; then
    print_summary 0 "$NAME"
    exit 0
fi

reboot_board
wait_for_board_up          || { echo "FAIL: board did not come back up in ${BOARD_UP_TIMEOUT}s"; exit 3; }
wait_for_aie_load_complete "$NAME" || { echo "FAIL: AIE load line not seen in ${PL_LOAD_TIMEOUT}s post-up"; exit 3; }
check_aie_active           "$NAME" || exit 3
print_summary 0 "$NAME"
exit 0
