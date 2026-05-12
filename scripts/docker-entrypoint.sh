#!/bin/bash
# ============================================================
# Docker Entrypoint — Orchestrates the full ISO build
# ============================================================
# This script runs INSIDE the Docker container. It calls
# the three build phases in order:
#   1. extract-iso.sh  — Mount and copy ISO contents
#   2. inject-drivers.sh — Chroot and install packages
#   3. rebuild-iso.sh  — Repack into bootable ISO
# ============================================================

set -euo pipefail

PROFILE="${PROFILE:-all}"
OUTPUT_NAME="${OUTPUT_NAME:-ubuntu-mac-edition.iso}"
WORK_DIR="/build/work"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_step()    { echo -e "\n${CYAN}${BOLD}━━━ $* ━━━${NC}\n"; }

# Verify input ISO exists
if [[ ! -f /build/input.iso ]]; then
    echo -e "${RED}[ERROR]${NC} Input ISO not found at /build/input.iso"
    exit 1
fi

mkdir -p "$WORK_DIR"

log_step "Phase 1/3: Extracting ISO"
bash /build/scripts/extract-iso.sh /build/input.iso "$WORK_DIR"

log_step "Phase 2/3: Injecting Mac Drivers (profile: ${PROFILE})"
bash /build/scripts/inject-drivers.sh "$WORK_DIR" "$PROFILE" /build/config

log_step "Phase 3/3: Rebuilding ISO"
bash /build/scripts/rebuild-iso.sh "$WORK_DIR" "/build/output/${OUTPUT_NAME}"

log_success "All done! ISO written to: /build/output/${OUTPUT_NAME}"

