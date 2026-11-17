# Tcl HLS tool compatibility

Support downstream `make build` on installations with standalone `vitis_hls`
and newer installations exposing `vitis-run`, without a tool-version override in
each consuming target. Base revision: 8e93dd7.

The Tcl backend selects `vitis_hls -f` when available, falling back to
`vitis-run --mode hls --tcl`. `HLS_TCL_CMD` permits an explicit override.
Existing Tcl sources, solutions, directives, output paths and IP packaging stay
in use. Legacy GUI and interactive targets retain their existing launcher.

Changes: `system_vitis_hls.mk`, the HLS how-to and Makefile reference.
The consuming ldmx-firmware project also marks its nested HLS make recipe as
recursive so GNU make passes jobserver descriptors through `env`/`bash`.

Validation in progress: isolated downstream HLS builds with AMD 2024.2 and
2026.1, launcher selection/error propagation checks, and Sphinx documentation.
The already-running ESA26 clock-validation build uses the original source and
2024.2 HLS; it is not evidence for this compatibility change.

No staging, commits or publishing requested. No changes to personal remote
workspaces. Tool-generated RTL and IP may differ between tool versions; hardware
equivalence is outside the launcher compatibility check.
