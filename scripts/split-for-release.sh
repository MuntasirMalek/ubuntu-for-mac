#!/bin/bash
# ============================================================
# Split ISO for GitHub Release upload
# ============================================================
# Splits the built ISO into parts small enough for GitHub
# Releases (max 2 GB per file) and generates checksums.
#
# Usage: ./scripts/split-for-release.sh <iso-file>
# ============================================================

set -euo pipefail

ISO_FILE="${1:?Usage: $0 <iso-file>}"
PART_SIZE="1900m"  # 1.9 GB chunks (GitHub allows 2 GB max)

if [[ ! -f "$ISO_FILE" ]]; then
    echo "ERROR: File not found: $ISO_FILE"
    exit 1
fi

BASENAME=$(basename "$ISO_FILE" .iso)
echo "============================================"
echo "Splitting: $ISO_FILE"
echo "Part size: $PART_SIZE"
echo "============================================"

# Split the file
echo "Splitting..."
split -b "$PART_SIZE" "$ISO_FILE" "${BASENAME}.part."

# List the parts
echo ""
echo "Parts created:"
ls -lh "${BASENAME}.part."* | awk '{print "  " $NF " (" $5 ")"}'

PART_COUNT=$(ls -1 "${BASENAME}.part."* | wc -l | tr -d ' ')
echo ""
echo "Total parts: $PART_COUNT"

# Generate SHA256 checksum of the original ISO
echo ""
echo "Generating checksum..."
shasum -a 256 "$ISO_FILE" > "${BASENAME}.sha256"
echo "Checksum: $(cat "${BASENAME}.sha256")"

echo ""
echo "============================================"
echo "Ready to upload to GitHub Releases!"
echo ""
echo "Upload these files:"
for f in "${BASENAME}.part."* "${BASENAME}.sha256"; do
    echo "  - $f"
done
echo ""
echo "Users can download with:"
echo "  curl -fsSL https://raw.githubusercontent.com/MuntasirMalek/ubuntu-for-mac/main/download.sh | bash"
echo "============================================"
