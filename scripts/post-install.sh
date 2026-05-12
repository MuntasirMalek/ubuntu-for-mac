#!/bin/bash
# ============================================================
# Ubuntu Mac Setup — Post-Install Verification & Configuration
# ============================================================
# Run this after installing Ubuntu to verify all Mac hardware
# is working correctly and apply any final fixes.
#
# Usage: sudo ubuntu-mac-setup
# ============================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
log() { echo -e "${CYAN}[Mac Setup]${NC} $*"; }
ok()  { echo -e "${GREEN}  ✓${NC} $*"; }
warn(){ echo -e "${YELLOW}  ⚠${NC} $*"; }
fail(){ echo -e "${RED}  ✗${NC} $*"; }

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ubuntu-mac-setup"
    exit 1
fi

echo ""
echo -e "${CYAN}${BOLD}  Ubuntu Mac Setup — Post-Install Check${NC}"
echo -e "${CYAN}  ─────────────────────────────────────${NC}"
echo ""

# Detect Mac model
MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "Unknown")
YEAR=$(cat /sys/class/dmi/id/board_version 2>/dev/null || echo "")
log "Mac model: ${BOLD}${MODEL}${NC} ${YEAR}"

# Detect T2 chip
IS_T2=false
if lspci 2>/dev/null | grep -qi "Apple.*T2"; then
    IS_T2=true
    log "T2 chip: Detected"
else
    log "T2 chip: Not present (pre-2018 Mac)"
fi
echo ""

# ---- 1. WiFi ----
echo -e "${BOLD}1. WiFi${NC}"
if ip link show | grep -q "wl"; then
    WIFI_IFACE=$(ip link show | grep "wl" | head -1 | awk -F: '{print $2}' | tr -d ' ')
    if lsmod | grep -q "^wl "; then
        ok "WiFi driver (wl/broadcom-sta) loaded — interface: $WIFI_IFACE"
    elif lsmod | grep -q "brcmfmac"; then
        ok "WiFi driver (brcmfmac) loaded — interface: $WIFI_IFACE"
    else
        ok "WiFi interface found: $WIFI_IFACE"
    fi
else
    fail "No WiFi interface detected"
    warn "Trying to load wl driver..."
    modprobe -r b43 ssb bcma brcmsmac brcmfmac 2>/dev/null || true
    if modprobe wl 2>/dev/null; then
        ok "wl driver loaded successfully — try connecting now"
    else
        fail "Could not load wl driver. Run: sudo dkms autoinstall && sudo modprobe wl"
    fi
fi

# ---- 2. Bluetooth ----
echo -e "\n${BOLD}2. Bluetooth${NC}"
if systemctl is-active --quiet bluetooth; then
    ok "Bluetooth service running"
    if hciconfig 2>/dev/null | grep -q "UP"; then
        ok "Bluetooth adapter is UP"
    else
        warn "Bluetooth adapter not UP — may need firmware"
        warn "Check: dmesg | grep -i bluetooth"
    fi
else
    warn "Bluetooth service not running"
    systemctl enable bluetooth 2>/dev/null && systemctl start bluetooth 2>/dev/null && ok "Started bluetooth service" || true
fi

# ---- 3. Keyboard ----
echo -e "\n${BOLD}3. Keyboard${NC}"
if lsmod | grep -q "hid_apple"; then
    ok "Apple keyboard driver (hid-apple) loaded"
    FNMODE=$(cat /sys/module/hid_apple/parameters/fnmode 2>/dev/null || echo "?")
    ok "Function key mode: ${FNMODE} (2=F-keys default)"
elif lsmod | grep -q "applespi"; then
    ok "SPI keyboard driver (applespi) loaded"
else
    if [[ "$MODEL" == *"MacBookPro13"* ]] || [[ "$MODEL" == *"MacBookPro14"* ]] || [[ "$MODEL" == *"MacBook9"* ]] || [[ "$MODEL" == *"MacBook10"* ]]; then
        warn "SPI keyboard model detected but applespi not loaded"
        warn "Try: sudo modprobe applespi intel_lpss_pci spi_pxa2xx_platform"
    else
        ok "Standard keyboard (no special driver needed)"
    fi
fi

# ---- 4. Trackpad ----
echo -e "\n${BOLD}4. Trackpad${NC}"
if xinput list 2>/dev/null | grep -qi "trackpad\|bcm5974\|apple"; then
    ok "Trackpad detected by X11/Wayland"
elif libinput list-devices 2>/dev/null | grep -qi "trackpad\|apple"; then
    ok "Trackpad detected by libinput"
else
    warn "Trackpad not explicitly detected (may still work)"
fi

# ---- 5. Audio ----
echo -e "\n${BOLD}5. Audio${NC}"
if lsmod | grep -q "snd_hda_intel"; then
    ok "Intel HDA audio driver loaded"
    if aplay -l 2>/dev/null | grep -q "card"; then
        ok "Audio output device found"
    else
        warn "No audio output detected — try: sudo alsactl init"
    fi
elif $IS_T2 && lsmod | grep -q "apple_bce"; then
    ok "T2 audio via apple-bce loaded"
else
    warn "Audio driver not detected"
fi

# ---- 6. Fan Control ----
echo -e "\n${BOLD}6. Fan Control${NC}"
if systemctl is-active --quiet mbpfan; then
    ok "mbpfan is running"
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    TEMP_C=$((TEMP / 1000))
    ok "CPU temperature: ${TEMP_C}°C"
else
    warn "mbpfan not running"
    systemctl enable mbpfan 2>/dev/null && systemctl start mbpfan 2>/dev/null && ok "Started mbpfan" || true
fi

# ---- 7. Display ----
echo -e "\n${BOLD}7. Display / GPU${NC}"
if lsmod | grep -q "i915"; then
    ok "Intel GPU driver (i915) loaded"
fi
if lsmod | grep -q "amdgpu\|radeon"; then
    ok "AMD GPU driver loaded"
    if lsmod | grep -q "apple_gmux"; then
        ok "GPU switching (apple-gmux) active"
    fi
fi
if xrandr 2>/dev/null | grep -q " connected"; then
    RES=$(xrandr 2>/dev/null | grep " connected" | head -1 | grep -oP '\d+x\d+')
    ok "Display connected: $RES"
fi

# ---- 8. DKMS Modules ----
echo -e "\n${BOLD}8. DKMS Modules${NC}"
if command -v dkms &>/dev/null; then
    DKMS_STATUS=$(dkms status 2>/dev/null)
    if [[ -n "$DKMS_STATUS" ]]; then
        while IFS= read -r line; do
            ok "$line"
        done <<< "$DKMS_STATUS"
    else
        warn "No DKMS modules registered"
    fi
fi

# ---- 9. Power ----
echo -e "\n${BOLD}9. Power Management${NC}"
if command -v powertop &>/dev/null; then
    ok "powertop available — run: sudo powertop --auto-tune"
fi
if systemctl is-active --quiet thermald 2>/dev/null; then
    ok "thermald running"
fi

# ---- Summary ----
echo ""
echo -e "${CYAN}${BOLD}  ─────────────────────────────────────${NC}"
echo -e "${GREEN}${BOLD}  Setup check complete!${NC}"
echo ""
echo "  Useful commands:"
echo "    sensors              — Check temperatures"
echo "    sudo powertop        — Optimize battery"
echo "    dkms status          — Check driver modules"
echo "    sudo ubuntu-mac-setup — Run this check again"
echo ""
