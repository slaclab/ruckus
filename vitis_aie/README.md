# vitis_aie/

Helper TCL scripts for `system_vitis_aie.mk`.

Reserved (empty placeholder in v1) for future AIE TCL helpers — aiesim
drivers, multi-partition geometry, Vitis Analyzer report capture. The v1
AIE flow invokes `aiecompiler` / `v++` / `bootgen` directly from Make
recipes in `system_vitis_aie.mk`; no TCL glue layer is needed yet.
