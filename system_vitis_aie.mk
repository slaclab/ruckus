##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Detect project name
ifndef PROJECT
export PROJECT = $(notdir $(PWD))
endif

# Detect project path
ifndef PROJ_DIR
export PROJ_DIR = $(abspath $(PWD))
endif

# Project Build Directory
ifndef OUT_DIR
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))
endif

# Synthesis Variables
export VIVADO_VERSION  := $(shell vivado -version | grep -Po "v(\d+\.)+\d+" | cut -c2-)
export RUCKUS_DIR       = $(TOP_DIR)/submodules/ruckus

##############################################################################
## Hard-fail early if the environment was not sourced
##############################################################################
ifndef XILINX_VITIS
$(error XILINX_VITIS not set — source firmware/setup_env_slac.sh first)
endif

include $(TOP_DIR)/submodules/ruckus/system_shared.mk

##############################################################################
## AIE-specific paths (env-overridable so consuming targets can rebind)
##############################################################################
ifndef AIE_SRC_DIR
export AIE_SRC_DIR = $(PROJ_DIR)/aie
endif

ifndef AIE_WORK_DIR
export AIE_WORK_DIR = $(OUT_DIR)/aie_work
endif

ifndef AIE_ARCHIVE
export AIE_ARCHIVE = $(OUT_DIR)/libadf.a
endif

ifndef AIE_LOG
export AIE_LOG = $(OUT_DIR)/aiecompiler.log
endif

ifndef AIE_PKG_DIR
export AIE_PKG_DIR = $(OUT_DIR)/aie_package
endif

ifndef AIE_PLATFORM
export AIE_PLATFORM = $(XILINX_VITIS)/base_platforms/xilinx_vek280_base_202520_1/xilinx_vek280_base_202520_1.xpfm
endif

ifndef VPP_LOG
export VPP_LOG = $(OUT_DIR)/vpp_package.log
endif

ifndef NO_REGRESSION_SHA
export NO_REGRESSION_SHA = $(OUT_DIR)/no_regression.sha256
endif

# AIE_XSA_INPUT uses DEFERRED expansion (`=` not `:=`) so that IMAGENAME
# (set by system_shared.mk above) resolves at use time, not at include time.
ifndef AIE_XSA_INPUT
export AIE_XSA_INPUT = $(IMAGES_DIR)/$(IMAGENAME).xsa
endif

ifndef AIE_PDI
export AIE_PDI = $(IMAGES_DIR)/$(IMAGENAME)_aie_dynamic.pdi
endif

ifndef USE_BOOTGEN_FALLBACK
export USE_BOOTGEN_FALLBACK = 0
endif

# All graph sources (used as Make prereqs so source edits trigger rebuild)
AIE_SOURCES = $(shell find $(AIE_SRC_DIR) -name "*.cpp" -o -name "*.cc" -o -name "*.h" 2>/dev/null)

.PHONY : all
all: aie_package

###############################################################
#### aie_compile — produces $(AIE_ARCHIVE) ####################
###############################################################
.PHONY : aie_compile aie
aie aie_compile: $(AIE_ARCHIVE)

$(AIE_ARCHIVE): $(AIE_SOURCES)
	@mkdir -p $(AIE_WORK_DIR) $(dir $(AIE_ARCHIVE))
	@echo "==== aie_compile ===="
	@(echo "==== aiecompiler --version ===="; \
	  aiecompiler --version 2>&1; \
	  echo "==== aiecompiler --target=hw ====") > $(AIE_LOG)
	aiecompiler \
	    --target=hw \
	    --platform=$(AIE_PLATFORM) \
	    -include="$(XILINX_VITIS)/aietools/include" \
	    -include="$(XILINX_HLS)/include" \
	    -include="$(AIE_SRC_DIR)" \
	    -include="$(AIE_SRC_DIR)/kernels" \
	    --pl-freq=250 \
	    --workdir=$(AIE_WORK_DIR) \
	    --output-archive=$(AIE_ARCHIVE) \
	    $(AIE_SRC_DIR)/graph.cpp \
	    2>&1 | tee -a $(AIE_LOG)

###############################################################
#### aie_package — produces $(AIE_PDI) ########################
###############################################################
.PHONY : aie_package package
package aie_package: $(AIE_PDI)

$(AIE_PDI): $(AIE_ARCHIVE) $(AIE_XSA_INPUT)
	@if [ ! -f "$(AIE_XSA_INPUT)" ]; then \
	  echo "ERROR: AIE_XSA_INPUT not found at $(AIE_XSA_INPUT)"; \
	  echo "       Run 'make pdi' first to produce the Vivado XSA."; \
	  exit 1; \
	fi
	@mkdir -p $(AIE_PKG_DIR) $(IMAGES_DIR)
	@echo "==== aie_package (USE_BOOTGEN_FALLBACK=$(USE_BOOTGEN_FALLBACK)) ===="
	@# BUILD-05 sha256 capture BEFORE — provenance + static/dynamic fingerprints
	@(echo "# BUILD-05 sha256 capture for $(IMAGENAME)"; \
	  echo "# Captured: $$(date -Iseconds)"; \
	  echo "# Phase: 06-aie-standalone-build-refactor"; \
	  echo "# HEAD: $$(git -C $(TOP_DIR) rev-parse --short HEAD 2>/dev/null || echo unknown)"; \
	  echo "# USE_BOOTGEN_FALLBACK: $(USE_BOOTGEN_FALLBACK)"; \
	  echo "before_static_pdi  $$(sha256sum $(IMAGES_DIR)/$(IMAGENAME)_static.pdi  2>/dev/null | awk '{print $$1}')"; \
	  echo "before_dynamic_pdi $$(sha256sum $(IMAGES_DIR)/$(IMAGENAME)_dynamic.pdi 2>/dev/null | awk '{print $$1}')") \
	  > $(NO_REGRESSION_SHA)
	@# Branch on packaging mode
	@if [ "$(USE_BOOTGEN_FALLBACK)" = "1" ]; then \
	  echo "---- bootgen fallback ----"; \
	  printf 'all:\n{\n    image\n    {\n        { type=bootimage, file=%s }\n    }\n    image\n    {\n        name=aie_image, id=0x1c000000\n        { type=cdo\n          file = %s/ps/cdo/aie_cdo_reset.bin\n          file = %s/ps/cdo/aie_cdo_clock_gating.bin\n          file = %s/ps/cdo/aie_cdo_error_handling.bin\n          file = %s/ps/cdo/aie_cdo_elfs.bin\n          file = %s/ps/cdo/aie_cdo_init.bin\n          file = %s/ps/cdo/aie_cdo_enable.bin\n        }\n    }\n}\n' \
	    '$(IMAGES_DIR)/$(IMAGENAME)_dynamic.pdi' \
	    '$(AIE_WORK_DIR)' '$(AIE_WORK_DIR)' '$(AIE_WORK_DIR)' '$(AIE_WORK_DIR)' '$(AIE_WORK_DIR)' '$(AIE_WORK_DIR)' \
	    > $(AIE_PKG_DIR)/aie_overlay.bif; \
	  bootgen -arch versal -image $(AIE_PKG_DIR)/aie_overlay.bif -o $(AIE_PDI) -w 2>&1 | tee $(VPP_LOG); \
	else \
	  echo "---- v++ --package primary ----"; \
	  v++ --package \
	      --target hw \
	      --platform $(AIE_XSA_INPUT) \
	      --package.out_dir $(AIE_PKG_DIR) \
	      --package.boot_mode sd \
	      $(AIE_ARCHIVE) \
	      2>&1 | tee $(VPP_LOG); \
	  PDI=$$(find $(AIE_PKG_DIR) -name "pl.pdi" -o -name "*_pld.pdi" -o -name "*.pdi" 2>/dev/null | head -1); \
	  if [ -z "$$PDI" ]; then \
	    echo "ERROR: v++ --package produced no PDI under $(AIE_PKG_DIR)"; \
	    echo "       Inspect $(VPP_LOG); engage USE_BOOTGEN_FALLBACK=1"; \
	    echo "       Re-run with: make USE_AIE=1 USE_BOOTGEN_FALLBACK=1 aie_package"; \
	    exit 1; \
	  fi; \
	  cp -f "$$PDI" $(AIE_PDI); \
	  echo "AIE dynamic PDI staged: $(AIE_PDI) (from $$PDI)"; \
	fi
	@# BUILD-05 sha256 capture AFTER + invariance assertion
	@AFTER_STATIC=$$(sha256sum $(IMAGES_DIR)/$(IMAGENAME)_static.pdi  2>/dev/null | awk '{print $$1}'); \
	  AFTER_DYNAMIC=$$(sha256sum $(IMAGES_DIR)/$(IMAGENAME)_dynamic.pdi 2>/dev/null | awk '{print $$1}'); \
	  echo "after_static_pdi   $$AFTER_STATIC"  >> $(NO_REGRESSION_SHA); \
	  echo "after_dynamic_pdi  $$AFTER_DYNAMIC" >> $(NO_REGRESSION_SHA); \
	  if grep -q "before_static_pdi  $$AFTER_STATIC" $(NO_REGRESSION_SHA) && \
	     grep -q "before_dynamic_pdi $$AFTER_DYNAMIC" $(NO_REGRESSION_SHA); then \
	    echo "BUILD-05 invariance VERIFIED: $(NO_REGRESSION_SHA)"; \
	  else \
	    echo "ERROR: BUILD-05 invariance FAILED — aie_package mutated existing PDIs"; \
	    cat $(NO_REGRESSION_SHA); \
	    exit 1; \
	  fi
	@echo "BUILD-05 invariance VERIFIED" >> $(NO_REGRESSION_SHA)

###############################################################
#### aie_clean — removes workdir, archive, AND log ###########
###############################################################
.PHONY : aie_clean
aie_clean:
	rm -rf $(AIE_WORK_DIR) $(AIE_ARCHIVE) $(AIE_LOG) $(AIE_PKG_DIR) $(AIE_PDI) $(VPP_LOG) $(NO_REGRESSION_SHA)
