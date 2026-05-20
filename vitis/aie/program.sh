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
# to /boot/{pl.pdi,pl.dtbo} on the target board (PetaLinux convention),
# optionally reboots, and verifies the fpga_manager comes up in the
# 'operating' state.
#
# Required flags:
#   -p <path>        runtime PDI to upload
#   -d <path>        matching device-tree overlay
#   -i <user@host>   board target (no default — required)
#
# Optional flags:
#   -r               dry-run: skip the reboot (uploads only)
#   -h               show this help
#
# Exit codes:
#   0  success: PDI deployed and fpga_manager in 'operating' state
#   1  local pre-flight failed (missing/invalid -p/-d/-i, or static-PDI guard)
#   2  scp/ssh failure during upload
#   3  post-reboot verification failed (board didn't come up, or fpga0/state
#      not 'operating')

set -euo pipefail

BOARD_IP=""
PDI_LOCAL=""
DTBO_LOCAL=""
DO_REBOOT=1
BOARD_UP_TIMEOUT=90
PL_LOAD_TIMEOUT=30

show_help() {
    cat <<'EOF'
Usage: program.sh -p <pdi> -d <dtbo> -i <user@host> [-r] [-h]

Generic AIE PDI deploy helper. Uploads PDI + DTBO to /boot/, optionally
reboots, verifies fpga_manager state.

Flags:
  -p <path>        runtime PDI to upload (required)
  -d <path>        matching device-tree overlay (required)
  -i <user@host>   board target (required, e.g. root@192.168.1.10)
  -r               dry-run: skip the reboot
  -h               show this help
EOF
    exit 0
}

while getopts "i:p:d:rh" flag; do
    case "$flag" in
        i) BOARD_IP="$OPTARG" ;;
        p) PDI_LOCAL="$OPTARG" ;;
        d) DTBO_LOCAL="$OPTARG" ;;
        r) DO_REBOOT=0 ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

preflight() {
    local fail=0
    if [[ -z "$BOARD_IP" ]]; then
        echo "[FAIL] -i <user@host> not provided"
        fail=$(( fail + 1 ))
    fi
    # Defend against uploading the static (boot-image) PDI as the runtime
    # overlay. The pair is <name>_static.pdi (BOOT.BIN half) vs
    # <name>_dynamic.pdi / <name>_aie_dynamic.pdi (the overlay).
    if [[ -n "$PDI_LOCAL" ]] && [[ "$PDI_LOCAL" == *_static* ]]; then
        echo "[FAIL] -p filename '$PDI_LOCAL' contains '_static'."
        echo "       Refusing to upload static PDI as runtime overlay;"
        echo "       pass the *_aie_dynamic.pdi (or *_dynamic.pdi) instead."
        fail=$(( fail + 1 ))
    fi
    if [[ -z "$PDI_LOCAL" ]] || [[ ! -s "$PDI_LOCAL" ]]; then
        echo "[FAIL] -p missing or empty (PDI='$PDI_LOCAL')"
        fail=$(( fail + 1 ))
    else
        echo "[PASS] pl.pdi present at $PDI_LOCAL ($(stat -c%s "$PDI_LOCAL") bytes)"
    fi
    if [[ -z "$DTBO_LOCAL" ]] || [[ ! -s "$DTBO_LOCAL" ]]; then
        echo "[FAIL] -d missing or empty (DTBO='$DTBO_LOCAL')"
        fail=$(( fail + 1 ))
    else
        echo "[PASS] pl.dtbo present at $DTBO_LOCAL ($(stat -c%s "$DTBO_LOCAL") bytes)"
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
    echo "---- scp pl.pdi  -> $BOARD_IP:/boot/pl.pdi ----"
    scp -o BatchMode=yes -o ConnectTimeout=5 -o ForwardX11=no \
        "$PDI_LOCAL" "$BOARD_IP:/boot/pl.pdi"
    echo "[PASS] pl.pdi uploaded"
    echo "---- scp pl.dtbo -> $BOARD_IP:/boot/pl.dtbo ----"
    scp -o BatchMode=yes -o ConnectTimeout=5 -o ForwardX11=no \
        "$DTBO_LOCAL" "$BOARD_IP:/boot/pl.dtbo"
    echo "[PASS] pl.dtbo uploaded"
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

wait_for_pl_load_complete() {
    local elapsed=0
    echo "---- polling $BOARD_IP for fpga_manager 'operating' (deadline ${PL_LOAD_TIMEOUT}s) ----"
    while [[ $elapsed -lt $PL_LOAD_TIMEOUT ]]; do
        if ssh -o ConnectTimeout=3 -o BatchMode=yes -o ForwardX11=no \
               "$BOARD_IP" "journalctl -b 2>/dev/null | grep -q 'fpga_manager/fpga0/state: operating'" \
               >/dev/null 2>&1; then
            echo "[PASS] PL load complete after ${elapsed}s"
            return 0
        fi
        sleep 3
        elapsed=$(( elapsed + 3 ))
    done
    return 1
}

check_fpga_state() {
    local out
    out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o ForwardX11=no \
              "$BOARD_IP" 'cat /sys/class/fpga_manager/fpga0/state' 2>&1) || true
    out="${out%$'\n'}"
    if [[ "$out" == "operating" ]]; then
        echo "[PASS] fpga0/state == operating"
        return 0
    else
        echo "[FAIL] fpga0/state == '$out' (expected 'operating')"
        return 1
    fi
}

print_summary() {
    local overall="$1"
    local verdict
    if [[ $overall -eq 0 ]]; then
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
    echo "  Reboot performed:   $([[ $DO_REBOOT -eq 1 ]] && echo yes || echo no)"
    echo "--------------------------------------------------------------"
    echo " Overall: $verdict"
    echo "=============================================================="
}

printf '[%s] program.sh start: BOARD_IP=%s PDI=%s DTBO=%s DO_REBOOT=%s\n' \
    "$(date -Iseconds)" "$BOARD_IP" "$PDI_LOCAL" "$DTBO_LOCAL" "$DO_REBOOT"

preflight                  || exit 1
upload                     || exit 2
[[ $DO_REBOOT -eq 1 ]] && reboot_board
wait_for_board_up          || { echo "FAIL: board did not come back up in ${BOARD_UP_TIMEOUT}s"; exit 3; }
wait_for_pl_load_complete  || { echo "FAIL: PL load did not complete in ${PL_LOAD_TIMEOUT}s post-up"; exit 3; }
check_fpga_state           || exit 3
print_summary 0
exit 0
