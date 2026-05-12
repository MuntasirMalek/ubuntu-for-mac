#!/bin/bash
# ============================================================
# Download Ubuntu for Mac ISO
# ============================================================
# This script downloads all split parts of the ISO from
# GitHub Releases and automatically combines them into
# a single bootable ISO file.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/MuntasirMalek/ubuntu-for-mac/main/download.sh | bash
#   OR
#   ./download.sh
# ============================================================

set -euo pipefail

# ---- Configuration ----
REPO="MuntasirMalek/ubuntu-for-mac"
ISO_NAME="ubuntu-26.04-desktop-amd64-mac-edition.iso"
EXPECTED_PARTS=4  # Will be updated based on actual split

# ---- Colors ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║      Ubuntu for Mac — ISO Download       ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}This will download and assemble the custom"
echo -e "  Ubuntu ISO with all Mac drivers included.${NC}"
echo ""

# ---- Check available disk space ----
check_disk_space() {
    local required_gb=14  # Need ~14 GB (parts + final ISO)
    local available_kb
    available_kb=$(df -k . | tail -1 | awk '{print $4}')
    local available_gb=$((available_kb / 1024 / 1024))

    if [[ $available_gb -lt $required_gb ]]; then
        echo -e "${RED}ERROR: Not enough disk space!${NC}"
        echo "  Required: ~${required_gb} GB"
        echo "  Available: ${available_gb} GB"
        echo "  Please free some space and try again."
        exit 1
    fi
    echo -e "${GREEN}  ✓${NC} Disk space OK (${available_gb} GB available)"
}

# ---- Get latest release info ----
get_release_info() {
    echo -e "${BLUE}  ↓${NC} Finding latest release..."

    # Get the latest release tag
    RELEASE_URL="https://api.github.com/repos/${REPO}/releases/latest"
    RELEASE_JSON=$(curl -fsSL "$RELEASE_URL" 2>/dev/null) || {
        echo -e "${RED}ERROR: Could not fetch release info.${NC}"
        echo "  Check your internet connection and try again."
        echo "  URL: ${RELEASE_URL}"
        exit 1
    }

    # Extract download URLs for .part. files
    PART_URLS=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*\.part\.[^"]*"' | grep -o 'https://[^"]*' | sort)

    if [[ -z "$PART_URLS" ]]; then
        # Try looking for a single ISO file (not split)
        SINGLE_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*\.iso"' | grep -o 'https://[^"]*' | head -1)
        if [[ -n "$SINGLE_URL" ]]; then
            echo -e "${GREEN}  ✓${NC} Found single ISO (not split)"
            echo -e "${BLUE}  ↓${NC} Downloading ISO..."
            curl -L --progress-bar -o "$ISO_NAME" "$SINGLE_URL"
            echo ""
            echo -e "${GREEN}${BOLD}  ✓ Download complete!${NC}"
            echo -e "  File: ${BOLD}${ISO_NAME}${NC}"
            echo -e "  Size: $(du -h "$ISO_NAME" | cut -f1)"
            exit 0
        fi

        echo -e "${RED}ERROR: No ISO parts found in the latest release.${NC}"
        echo "  Visit: https://github.com/${REPO}/releases"
        exit 1
    fi

    PART_COUNT=$(echo "$PART_URLS" | wc -l | tr -d ' ')
    echo -e "${GREEN}  ✓${NC} Found ${PART_COUNT} parts to download"
}

# ---- Download all parts ----
download_parts() {
    local i=1
    local total=$PART_COUNT

    echo ""
    echo -e "${BOLD}  Downloading ${total} parts...${NC}"
    echo ""

    for url in $PART_URLS; do
        local filename=$(basename "$url")
        echo -e "${BLUE}  [${i}/${total}]${NC} Downloading ${filename}..."

        if [[ -f "$filename" ]]; then
            echo -e "${YELLOW}    ⟳${NC} Already exists, skipping (delete to re-download)"
        else
            curl -L --progress-bar -o "${filename}" "$url" || {
                echo -e "${RED}    ✗ Failed to download: ${filename}${NC}"
                echo "    Retrying..."
                curl -L --progress-bar -o "${filename}" "$url" || {
                    echo -e "${RED}ERROR: Could not download ${filename}${NC}"
                    echo "  Try running this script again."
                    exit 1
                }
            }
        fi

        i=$((i + 1))
    done

    echo ""
    echo -e "${GREEN}  ✓ All parts downloaded${NC}"
}

# ---- Combine parts into final ISO ----
combine_parts() {
    echo ""
    echo -e "${BOLD}  Combining parts into ${ISO_NAME}...${NC}"

    # Find all part files and sort them
    local parts=$(ls -1 *.part.* 2>/dev/null | sort)

    if [[ -z "$parts" ]]; then
        echo -e "${RED}ERROR: No part files found in current directory${NC}"
        exit 1
    fi

    # Combine using cat
    cat $parts > "$ISO_NAME" || {
        echo -e "${RED}ERROR: Failed to combine parts${NC}"
        exit 1
    }

    echo -e "${GREEN}  ✓ ISO assembled successfully${NC}"

    # Verify size
    local size=$(du -h "$ISO_NAME" | cut -f1)
    echo -e "  File: ${BOLD}${ISO_NAME}${NC}"
    echo -e "  Size: ${size}"
}

# ---- Verify checksum if available ----
verify_checksum() {
    # Check if SHA256 is in the release
    local checksum_url=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*sha256[^"]*"' | grep -o 'https://[^"]*' | head -1)

    if [[ -n "$checksum_url" ]]; then
        echo ""
        echo -e "${BLUE}  ↓${NC} Verifying checksum..."
        local expected=$(curl -fsSL "$checksum_url" | awk '{print $1}')
        local actual=$(shasum -a 256 "$ISO_NAME" | awk '{print $1}')

        if [[ "$expected" == "$actual" ]]; then
            echo -e "${GREEN}  ✓ Checksum verified — file is intact${NC}"
        else
            echo -e "${YELLOW}  ⚠ Checksum mismatch! File may be corrupted.${NC}"
            echo "    Expected: ${expected}"
            echo "    Got:      ${actual}"
            echo "    Try downloading again."
        fi
    fi
}

# ---- Cleanup parts ----
cleanup_parts() {
    echo ""
    read -p "  Delete downloaded parts to save space? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f *.part.*
        echo -e "${GREEN}  ✓ Parts cleaned up${NC}"
    else
        echo -e "  Parts kept in current directory"
    fi
}

# ---- Main ----
echo -e "${BOLD}  Step 1: Checking disk space${NC}"
check_disk_space

echo ""
echo -e "${BOLD}  Step 2: Finding latest release${NC}"
get_release_info

echo ""
echo -e "${BOLD}  Step 3: Downloading${NC}"
download_parts

echo ""
echo -e "${BOLD}  Step 4: Assembling ISO${NC}"
combine_parts
verify_checksum
cleanup_parts

echo ""
echo -e "${CYAN}${BOLD}  ══════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✓ Done! Your ISO is ready.${NC}"
echo ""
echo -e "  ${BOLD}File:${NC} ${ISO_NAME}"
echo -e "  ${BOLD}Size:${NC} $(du -h "$ISO_NAME" | cut -f1)"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo "  1. Flash to USB:  balenaEtcher (easiest) or:"
echo "     sudo dd if=${ISO_NAME} of=/dev/rdiskN bs=4m status=progress"
echo "  2. Boot your Mac holding Option (⌥) key"
echo "  3. Select the USB drive and install!"
echo ""
echo -e "  ${BOLD}Full guide:${NC} https://github.com/${REPO}#-quick-start-install-ubuntu-on-your-mac"
echo ""
