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
# Compile the extension and package it as a .vsix
#   ./scripts/build.sh            -> compile + package (slac-ruckus-plugin-<version>.vsix)
#   ./scripts/build.sh --compile  -> compile only (out/)
set -euo pipefail

cd "$(dirname "$0")/.."

# Homebrew node is not on the PATH of non-login shells on macOS
for d in /opt/homebrew/bin /usr/local/bin; do
   [[ -x "$d/node" && ":$PATH:" != *":$d:"* ]] && PATH="$d:$PATH"
done

command -v node >/dev/null || { echo "error: node not found (install Node.js >= 18)"; exit 1; }
command -v npm  >/dev/null || { echo "error: npm not found"; exit 1; }

if [[ ! -d node_modules || package.json -nt node_modules ]]; then
   echo "==> Installing dependencies"
   npm install --no-audit --no-fund
   touch node_modules
fi

echo "==> Compiling TypeScript"
rm -rf out
npx tsc -p ./

if ! command -v tclsh >/dev/null; then
   echo "warning: tclsh not found; the extension needs it at runtime (setting ruckus.tclsh)"
fi

if [[ "${1:-}" == "--compile" ]]; then
   echo "==> Done (out/)"
   exit 0
fi

echo "==> Packaging .vsix"
# The license is the one of the ruckus repository this extension lives in
cp ../LICENSE.txt LICENSE.txt
npx vsce package --no-dependencies -o "slac-ruckus-plugin-$(node -p 'require("./package.json").version').vsix"
ls -1 ./*.vsix
