#!/bin/bash
# Phase 3: Rebuild ISO from modified filesystem
set -euo pipefail

WORK_DIR="$1"
OUTPUT_ISO="$2"
ISO_DIR="${WORK_DIR}/iso-contents"
SQUASH_DIR="${WORK_DIR}/squashfs-root"

log_info()  { echo -e "\033[0;34m[Rebuild]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[Rebuild]\033[0m $*"; }

# Read squashfs path from extract phase
SQUASHFS_REL_PATH=$(cat "${WORK_DIR}/squashfs-path.txt")
SQUASHFS_TARGET="${ISO_DIR}/${SQUASHFS_REL_PATH}"

# Step 1: Rebuild squashfs (slowest step)
log_info "Rebuilding squashfs (this is the slowest step, ~10-20 min)..."
rm -f "$SQUASHFS_TARGET"
mksquashfs "$SQUASH_DIR" "$SQUASHFS_TARGET" \
    -comp xz -b 1M -Xdict-size 100% \
    -noappend

log_info "New squashfs size: $(du -sh "$SQUASHFS_TARGET" | cut -f1)"

# Step 2: Update filesystem.size
CASPER_DIR="$(dirname "$SQUASHFS_TARGET")"
printf "$(du -sx --block-size=1 "$SQUASH_DIR" | cut -f1)" \
    > "${CASPER_DIR}/filesystem.size" 2>/dev/null || true

# Step 3: Update MD5 checksums
log_info "Updating checksums..."
cd "$ISO_DIR"
find . -type f -not -name "md5sum.txt" -not -path "./boot/*" \
    -not -path "./EFI/*" -not -path "./.disk/*" \
    -exec md5sum {} \; > md5sum.txt 2>/dev/null || true

# Step 4: Rebuild the ISO with proper EFI boot support
log_info "Rebuilding ISO with EFI boot support..."

# Find the EFI boot image
EFI_IMG=""
for candidate in boot/grub/efi.img EFI/BOOT/efi.img; do
    if [[ -f "${ISO_DIR}/${candidate}" ]]; then
        EFI_IMG="$candidate"
        break
    fi
done

# Find BIOS boot catalog
BOOT_CAT=""
BOOT_IMG=""
for candidate in boot/grub/bios.img isolinux/isolinux.bin boot.catalog; do
    if [[ -f "${ISO_DIR}/${candidate}" ]]; then
        if [[ "$candidate" == *".bin" || "$candidate" == *"bios.img" ]]; then
            BOOT_IMG="$candidate"
        fi
    fi
done

mkdir -p "$(dirname "$OUTPUT_ISO")"

if [[ -n "$EFI_IMG" ]]; then
    log_info "Building hybrid ISO (BIOS + UEFI) with EFI image: $EFI_IMG"
    xorriso -as mkisofs \
        -r -V "Ubuntu Mac Edition" \
        -J -joliet-long \
        -iso-level 3 \
        -partition_offset 16 \
        --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img 2>/dev/null || true \
        -append_partition 2 0xef "${ISO_DIR}/${EFI_IMG}" \
        -appended_part_as_gpt \
        -eltorito-alt-boot \
        -e "$EFI_IMG" \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -o "$OUTPUT_ISO" \
        "$ISO_DIR" 2>&1 || {
            # Fallback: simpler xorriso invocation
            log_info "Trying simplified ISO build..."
            xorriso -as mkisofs \
                -r -V "Ubuntu Mac Edition" \
                -J -joliet-long \
                -iso-level 3 \
                -eltorito-alt-boot \
                -e "$EFI_IMG" \
                -no-emul-boot \
                -o "$OUTPUT_ISO" \
                "$ISO_DIR"
        }
else
    log_info "Building ISO (UEFI only)..."
    xorriso -as mkisofs \
        -r -V "Ubuntu Mac Edition" \
        -J -joliet-long \
        -iso-level 3 \
        -o "$OUTPUT_ISO" \
        "$ISO_DIR"
fi

# Verify output
if [[ -f "$OUTPUT_ISO" ]]; then
    local_size=$(du -sh "$OUTPUT_ISO" | cut -f1)
    log_success "ISO built successfully: $OUTPUT_ISO ($local_size)"
else
    echo -e "\033[0;31m[Rebuild] ERROR: Output ISO was not created!\033[0m"
    exit 1
fi
