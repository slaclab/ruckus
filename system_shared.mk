##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

ifndef PRJ_VERSION
export PRJ_VERSION = 0xFFFFFFFF
endif

ifndef RECONFIG_CHECKPOINT
export RECONFIG_CHECKPOINT = 0
export RECONFIG_STATIC_HASH = 0
endif

# Check for /u1 drive
BUILD_EXIST=$(shell [ -e  $(TOP_DIR)/build/ ] && echo 1 || echo 0 )
U1_EXIST=$(shell [ -e /u1/ ] && echo 1 || echo 0 )
ifeq ($(U1_EXIST), 1)
   $(shell mkdir -p /u1/$(USER) )
   $(shell mkdir -p /u1/$(USER)/build )
   ifeq ($(BUILD_EXIST), 0)
      $(shell ln -s /u1/$(USER)/build $(TOP_DIR)/build )
   endif
else
   $(shell mkdir -p $(TOP_DIR)/build )
endif
U1_EXIST=$(shell [ -e /u1/$(USER)/build ] && echo 1 || echo 0 )
ifeq ($(U1_EXIST), 1)
   export TMP_DIR=/u1/$(USER)/build
else
   export TMP_DIR=$(TOP_DIR)/build
endif

# Generate build string
export BUILD_SYS_NAME = $(shell uname -n)
export BUILD_USER = $(shell id -u -n)
BUILD_SVR_TYPE := $(shell grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d \")
BUILD_DATE := $(shell date)
BUILD_TIME := $(shell date +%Y%m%d%H%M%S)
export BUILD_STRING = $(PROJECT): Vivado v${VIVADO_VERSION}, ${BUILD_SYS_NAME} (${BUILD_SVR_TYPE}), Built ${BUILD_DATE} by ${BUILD_USER}

# Check the GIT status
export GIT_STATUS = $(shell git update-index --refresh | sed -e 's/: needs update//g')

# Check for non-dirty git clone
ifeq ($(GIT_STATUS),)
   export GIT_HASH_LONG  = $(shell git rev-parse HEAD)
   export GIT_HASH_SHORT = $(shell git rev-parse --short HEAD)
   export GIT_HASH_MSG   = $(GIT_HASH_LONG)
   ifeq ($(RECONFIG_STATIC_HASH), 0)
      export IMAGENAME = $(PROJECT)-$(PRJ_VERSION)-$(BUILD_TIME)-$(USER)-$(GIT_HASH_SHORT)
   else
      export IMAGENAME = $(PROJECT)-$(PRJ_VERSION)-$(BUILD_TIME)-$(USER)-$(GIT_HASH_SHORT)_$(RECONFIG_STATIC_HASH)
   endif
else
   export GIT_HASH_MSG   = dirty (uncommitted code)
   # Check if we are using GIT tagging
   ifeq ($(GIT_BYPASS), 0)
      export GIT_HASH_LONG  =
      export GIT_HASH_SHORT =
   else
      export GIT_HASH_LONG  = 0
      export GIT_HASH_SHORT = 0
   endif
   ifeq ($(RECONFIG_STATIC_HASH), 0)
      export IMAGENAME = $(PROJECT)-$(PRJ_VERSION)-$(BUILD_TIME)-$(USER)-dirty
   else
      export IMAGENAME = $(PROJECT)-$(PRJ_VERSION)-$(BUILD_TIME)-$(USER)-dirty_$(RECONFIG_STATIC_HASH)
   endif
endif

# Build System Header
define ACTION_HEADER
@echo
@echo    "============================================================================="
@echo    $(1)
@echo    "   Project      = $(PROJECT)"
@echo    "   Out Dir      = $(OUT_DIR)"
@echo    "   Version      = $(PRJ_VERSION)"
@echo    "   Build String = $(BUILD_STRING)"
@echo    "   GIT Hash     = $(GIT_HASH_MSG)"
@echo    "============================================================================="
@echo
endef

