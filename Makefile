# ==============================================================================
#
# Project:      CoreaLoader
# Name:         Three-Stage Bootloader Build System
# File:         Makefile
# Author:       @lorick_la_brique
# Date:         22 February 2026 - Revision 2
# Description:  Manages assembly of boot stages and creates a 1.44MB floppy.
#
# ==============================================================================

# Configuration Variables
BUILD_DIR = build
SRC_DIR   = src
IMAGE_NAME = $(BUILD_DIR)/corealoader.img

# Binaries
BOOTLOADER_BIN   = $(BUILD_DIR)/bootloader.bin
SECOND_STAGE_BIN = $(BUILD_DIR)/second_stage.bin

.PHONY: all
all: $(IMAGE_NAME)

# --- Compilation Rules ---

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BOOTLOADER_BIN): $(SRC_DIR)/bootloader.asm | $(BUILD_DIR)
	@echo "[NASM] Assembling MBR (Stage 1)..."
	@nasm -f bin $< -o $@

$(SECOND_STAGE_BIN): $(SRC_DIR)/second_stage.asm | $(BUILD_DIR)
	@echo "[NASM] Assembling Long Mode Transition (Stage 2)..."
	@nasm -f bin $< -o $@

# --- Disk Image Creation ---

$(IMAGE_NAME): $(BOOTLOADER_BIN) $(SECOND_STAGE_BIN)
	@echo "[DD] Creating 1.44MB Bootable Image..."
	@dd if=/dev/zero of=$(IMAGE_NAME) bs=1024 count=1440 2>/dev/null
	@dd if=$(BOOTLOADER_BIN) of=$(IMAGE_NAME) conv=notrunc 2>/dev/null
	@dd if=$(SECOND_STAGE_BIN) of=$(IMAGE_NAME) seek=1 conv=notrunc 2>/dev/null
	@echo "------------------------------------------------"
	@echo "Done! Image created at $(IMAGE_NAME)"

# --- Utilities ---

.PHONY: run
run: $(IMAGE_NAME)
	@echo "[QEMU] Starting CoreaLoader..."
	@qemu-system-x86_64 -drive format=raw,file=$(IMAGE_NAME) -monitor stdio

.PHONY: clean
clean:
	@echo "[CLEAN] Removing build directory..."
	@rm -rf $(BUILD_DIR)