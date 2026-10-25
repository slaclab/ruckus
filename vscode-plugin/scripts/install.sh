#!/usr/bin/env bash
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
# Install the packaged extension into VS Code (builds it first if needed)
#   ./scripts/install.sh              -> build if needed, install the latest .vsix
#   ./scripts/install.sh --rebuild    -> always rebuild before installing
#   ./scripts/install.sh --uninstall  -> remove the extension
# Set CODE=/path/to/code to use another binary (code-insiders, codium, ...).
set -euo pipefail

cd "$(dirname "$0")/.."

find_code() {
   if [[ -n "${CODE:-}" ]]; then echo "$CODE"; return; fi
   for c in code code-insiders codium; do
      command -v "$c" >/dev/null && { command -v "$c"; return; }
   done
   for c in "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
            "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
            "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code-insiders"; do
      [[ -x "$c" ]] && { echo "$c"; return; }
   done
   return 1
}

CODE_BIN="$(find_code)" || { echo "error: VS Code 'code' CLI not found (set CODE=/path/to/code)"; exit 1; }
EXT_ID="$(node -p 'const p=require("./package.json"); p.publisher+"."+p.name' 2>/dev/null || echo slac.slac-ruckus-plugin)"

if [[ "${1:-}" == "--uninstall" ]]; then
   "$CODE_BIN" --uninstall-extension "$EXT_ID"
   exit 0
fi

VSIX="$(ls -t ./*.vsix 2>/dev/null | head -1 || true)"
if [[ "${1:-}" == "--rebuild" || -z "$VSIX" || -n "$(find src resources package.json -newer "$VSIX" 2>/dev/null | head -1)" ]]; then
   ./scripts/build.sh
   VSIX="$(ls -t ./*.vsix | head -1)"
fi

echo "==> Installing $VSIX with $CODE_BIN"
"$CODE_BIN" --install-extension "$VSIX" --force
echo "==> Installed $EXT_ID. Reload VS Code (Developer: Reload Window) to activate."
