#!/bin/bash
# ============================================================
# Phase 1: Extract ISO
# ============================================================
# Extracts the Ubuntu ISO contents and the squashfs filesystem
# so we can modify it in the next phase.
#
# Usage: extract-iso.sh <input.iso> <work-dir>
# ============================================================

set -euo pipefail

INPUT_ISO="$1"
WORK_DIR="$2"

ISO_DIR="${WORK_DIR}/iso-contents"
SQUASH_DIR="${WORK_DIR}/squashfs-root"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[Extract]${NC} $*"; }
log_success() { echo -e "${GREEN}[Extract]${NC} $*"; }

# ---- Step 1: Extract ISO contents ----
log_info "Extracting ISO contents..."
mkdir -p "$ISO_DIR"

# Use xorriso to extract while preserving boot records
xorriso -osirrox on \
    -indev "$INPUT_ISO" \
    -extract / "$ISO_DIR" \
    2>/dev/null

# Make extracted contents writable
chmod -R u+w "$ISO_DIR"

log_success "ISO contents extracted to: $ISO_DIR"

# ---- Step 2: Find and extract squashfs ----
log_info "Looking for squashfs filesystem..."

# Ubuntu ISOs store the filesystem in different locations depending on version
SQUASHFS_FILE=""
POSSIBLE_PATHS=(
    "${ISO_DIR}/casper/filesystem.squashfs"
    "${ISO_DIR}/casper/minimal.squashfs"
    "${ISO_DIR}/install/filesystem.squashfs"
    "${ISO_DIR}/live/filesystem.squashfs"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        SQUASHFS_FILE="$path"
        break
    fi
done

if [[ -z "$SQUASHFS_FILE" ]]; then
    # Try to find it anywhere
    SQUASHFS_FILE=$(find "$ISO_DIR" -name "*.squashfs" -type f | head -1)
fi

if [[ -z "$SQUASHFS_FILE" || ! -f "$SQUASHFS_FILE" ]]; then
    echo -e "\033[0;31m[Extract] ERROR: Could not find squashfs filesystem in ISO!\033[0m"
    echo "  Searched: ${POSSIBLE_PATHS[*]}"
    echo "  ISO contents:"
    find "$ISO_DIR" -maxdepth 3 -type f | head -20
    exit 1
fi

log_info "Found squashfs: $SQUASHFS_FILE"

# Save the squashfs path relative to ISO for rebuild phase
SQUASHFS_REL_PATH="${SQUASHFS_FILE#$ISO_DIR/}"
echo "$SQUASHFS_REL_PATH" > "${WORK_DIR}/squashfs-path.txt"

# Extract squashfs
log_info "Extracting squashfs filesystem (this may take a few minutes)..."
unsquashfs -d "$SQUASH_DIR" -f "$SQUASHFS_FILE"

log_success "Squashfs extracted to: $SQUASH_DIR"

# ---- Stats ----
local_size=$(du -sh "$SQUASH_DIR" 2>/dev/null | cut -f1)
log_info "Extracted filesystem size: $local_size"

