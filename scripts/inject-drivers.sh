#!/bin/bash
# ============================================================
# Phase 2: Inject Mac Drivers
# ============================================================
# Chroots into the extracted Ubuntu filesystem and installs
# ALL necessary Apple hardware drivers and configuration
# for Intel Macs 2012-2020.
#
# Usage: inject-drivers.sh <work-dir> <profile> <config-dir>
# ============================================================
set -euo pipefail

WORK_DIR="$1"
PROFILE="${2:-all}"
CONFIG_DIR="${3:-./config}"
SQUASH_DIR="${WORK_DIR}/squashfs-root"

log_info()  { echo -e "\033[0;34m[Inject]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[Inject]\033[0m $*"; }
log_warn()  { echo -e "\033[1;33m[Inject]\033[0m $*"; }

[[ ! -d "$SQUASH_DIR" ]] && echo "ERROR: $SQUASH_DIR not found" && exit 1

# ---- Mount system filesystems for chroot ----
log_info "Mounting system filesystems..."
mount --bind /dev "${SQUASH_DIR}/dev"
mount --bind /dev/pts "${SQUASH_DIR}/dev/pts"
mount -t proc proc "${SQUASH_DIR}/proc"
mount -t sysfs sysfs "${SQUASH_DIR}/sys"
mount -t tmpfs tmpfs "${SQUASH_DIR}/tmp"
cp /etc/resolv.conf "${SQUASH_DIR}/etc/resolv.conf" 2>/dev/null || true

cleanup_chroot() {
    log_info "Cleaning up chroot mounts..."
    umount -lf "${SQUASH_DIR}/tmp" "${SQUASH_DIR}/sys" "${SQUASH_DIR}/proc" \
               "${SQUASH_DIR}/dev/pts" "${SQUASH_DIR}/dev" 2>/dev/null || true
}
trap cleanup_chroot EXIT

# ---- Build package list from config files ----
PACKAGES=""
read_pkg_list() {
    [[ ! -f "$1" ]] && return
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        PACKAGES+="$line "
    done < "$1"
}

read_pkg_list "${CONFIG_DIR}/packages/base.list"
[[ "$PROFILE" == "all" || "$PROFILE" == "non-t2" ]] && read_pkg_list "${CONFIG_DIR}/packages/non-t2.list"
[[ "$PROFILE" == "all" || "$PROFILE" == "t2" ]] && read_pkg_list "${CONFIG_DIR}/packages/t2.list"

log_info "Package list: $PACKAGES"

# ---- Create the main chroot install script ----
cat > "${SQUASH_DIR}/tmp/install.sh" << SCRIPT
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive HOME=/root LC_ALL=C

echo "============================================"
echo "[chroot] Phase 2a: Fixing apt sources"
echo "============================================"

# Remove cdrom/offline sources that break apt in chroot
# Ubuntu 26.04 uses deb822 format (.sources files) not .list files
# The live ISO has 'cdrom.sources' pointing to file:///cdrom
rm -f /etc/apt/sources.list.d/cdrom.sources 2>/dev/null || true
rm -f /etc/apt/sources.list.d/cdrom*.sources 2>/dev/null || true
rm -f /etc/apt/sources.list.d/cdrom*.list 2>/dev/null || true
rm -f /etc/apt/sources.list.d/ubuntu-cdrom*.list 2>/dev/null || true
sed -i '/cdrom/d' /etc/apt/sources.list 2>/dev/null || true
sed -i '/^deb file:/d' /etc/apt/sources.list 2>/dev/null || true

# Also clean any remaining .list files with cdrom references
if [[ -d /etc/apt/sources.list.d ]]; then
    find /etc/apt/sources.list.d/ -name "*.list" -exec sed -i '/cdrom/d' {} \; 2>/dev/null || true
    find /etc/apt/sources.list.d/ -name "*.list" -exec sed -i '/^deb file:/d' {} \; 2>/dev/null || true
fi

# Ensure universe and multiverse are enabled in ubuntu.sources
if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
    sed -i 's/^Components:.*/Components: main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true
    echo "[chroot] ubuntu.sources updated with universe+multiverse"
fi

echo "[chroot] Remaining apt sources:"
ls /etc/apt/sources.list.d/ 2>/dev/null || true

# If sources.list exists and has entries, ensure universe/multiverse
if [[ -f /etc/apt/sources.list ]] && grep -q "^deb " /etc/apt/sources.list 2>/dev/null; then
    sed -i 's/main restricted$/main restricted universe multiverse/' /etc/apt/sources.list 2>/dev/null || true
fi

# Fallback: if no valid sources exist, create one
if ! grep -rq "archive.ubuntu.com\|ports.ubuntu.com\|security.ubuntu.com" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    echo "[chroot] No valid apt sources found, creating fallback..."
    CODENAME=\$(lsb_release -cs 2>/dev/null || echo "noble")
    cat > /etc/apt/sources.list << APTEOF
deb http://archive.ubuntu.com/ubuntu \${CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu \${CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu \${CODENAME}-security main restricted universe multiverse
APTEOF
fi

echo "[chroot] Apt sources configured"
cat /etc/apt/sources.list 2>/dev/null || true
ls /etc/apt/sources.list.d/ 2>/dev/null || true

echo "============================================"
echo "[chroot] Phase 2b: Installing packages"
echo "============================================"

apt-get update -y

# Install all packages from our lists
apt-get install -y --no-install-recommends $PACKAGES || {
    echo "[chroot] WARN: Some packages failed. Trying individually..."
    for pkg in $PACKAGES; do
        apt-get install -y --no-install-recommends \$pkg 2>/dev/null || \
            echo "[chroot] WARN: Could not install \$pkg — skipping"
    done
}

echo "============================================"
echo "[chroot] Phase 2b: Broadcom Bluetooth firmware"
echo "============================================"

# Download Broadcom BT firmware files for Mac hardware
# These .hcd files are needed for Bluetooth to work
mkdir -p /lib/firmware/brcm
BT_FIRMWARE_URL="https://raw.githubusercontent.com/winterheart/broadcom-bt-firmware/master/brcm"
BT_FILES=(
    "BCM20702A1-0a5c-6300.hcd"
    "BCM20702A1-0a5c-6410.hcd"
    "BCM20702A1-0a5c-216f.hcd"
    "BCM20702A1-0a5c-21e8.hcd"
    "BCM20702A1-0b05-17cb.hcd"
    "BCM43142A0-105b-e065.hcd"
    "BCM4350C5-0a5c-6414.hcd"
    "BCM4356A2-0a5c-6300.hcd"
)
for fw in "\${BT_FILES[@]}"; do
    curl -fsSL "\${BT_FIRMWARE_URL}/\${fw}" -o "/lib/firmware/brcm/\${fw}" 2>/dev/null || \
        echo "[chroot] WARN: Could not download BT firmware: \${fw}"
done
echo "[chroot] Bluetooth firmware installed"

SCRIPT

# ---- Add SPI keyboard setup for 2016-2017 MacBooks ----
if [[ "$PROFILE" == "all" || "$PROFILE" == "non-t2" ]]; then
    cat >> "${SQUASH_DIR}/tmp/install.sh" << 'SPIBLOCK'

echo "============================================"
echo "[chroot] Phase 2c: SPI keyboard/trackpad setup"
echo "============================================"

# Ensure SPI modules are loaded in initramfs
# This is critical for 2016-2017 MacBook Pro keyboard/trackpad
INITRAMFS_MODULES="/etc/initramfs-tools/modules"
if [[ -f "$INITRAMFS_MODULES" ]]; then
    # Add SPI modules if not already present
    for mod in applespi intel_lpss_pci spi_pxa2xx_platform apple_ib_tb apple_ib_als; do
        if ! grep -q "^${mod}$" "$INITRAMFS_MODULES" 2>/dev/null; then
            echo "$mod" >> "$INITRAMFS_MODULES"
            echo "[chroot] Added $mod to initramfs modules"
        fi
    done
    # Rebuild initramfs
    update-initramfs -u 2>/dev/null || echo "[chroot] WARN: Could not update initramfs"
fi

SPIBLOCK
fi

# ---- Add T2 repo and packages if needed ----
if [[ "$PROFILE" == "all" || "$PROFILE" == "t2" ]]; then
    cat >> "${SQUASH_DIR}/tmp/install.sh" << 'T2BLOCK'

echo "============================================"
echo "[chroot] Phase 2d: T2 Mac drivers"
echo "============================================"

apt-get install -y curl gnupg

# Add t2linux community repo
curl -fsSL https://adityagarg8.github.io/t2-ubuntu-repo/KEY.gpg \
    | gpg --dearmor -o /usr/share/keyrings/t2-ubuntu-repo.gpg 2>/dev/null || true

if [[ -f /usr/share/keyrings/t2-ubuntu-repo.gpg ]]; then
    CODENAME=$(lsb_release -cs 2>/dev/null || echo "noble")
    echo "deb [signed-by=/usr/share/keyrings/t2-ubuntu-repo.gpg] https://adityagarg8.github.io/t2-ubuntu-repo/ ${CODENAME} main" \
        > /etc/apt/sources.list.d/t2-linux.list

    # Try to update — if the repo doesn't support this Ubuntu version, skip
    if apt-get update -y 2>&1 | grep -q "404\|Release.*does not"; then
        echo "[chroot] WARN: T2 repo does not support Ubuntu ${CODENAME} yet"
        echo "[chroot] WARN: T2 Mac users may need to add drivers manually after install"
        rm -f /etc/apt/sources.list.d/t2-linux.list
        apt-get update -y 2>/dev/null || true
    else
        # Install T2 drivers — keyboard, trackpad, audio, Touch Bar
        apt-get install -y apple-bce-dkms 2>/dev/null || \
            echo "[chroot] WARN: apple-bce-dkms not available for this version"
        apt-get install -y apple-touchbar-dkms 2>/dev/null || \
            echo "[chroot] WARN: apple-touchbar-dkms not available"
        apt-get install -y apple-t2-audio-config 2>/dev/null || \
            echo "[chroot] WARN: apple-t2-audio-config not available"
    fi
else
    echo "[chroot] WARN: Could not add T2 repo. T2 drivers skipped."
fi

T2BLOCK
fi

# ---- Add cleanup to the chroot script ----
cat >> "${SQUASH_DIR}/tmp/install.sh" << 'CLEAN'

echo "============================================"
echo "[chroot] Phase 2e: Cleanup"
echo "============================================"
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/cache/apt/archives/*.deb
echo "[chroot] Driver injection complete!"

CLEAN

chmod +x "${SQUASH_DIR}/tmp/install.sh"

# ---- Run the install script inside chroot ----
log_info "Running package installation in chroot..."
chroot "$SQUASH_DIR" /bin/bash /tmp/install.sh

# ---- Copy ALL configuration files ----
log_info "Copying Mac hardware configuration files..."

# modprobe configs (WiFi blacklist, GPU, audio, keyboard, SPI, NVMe)
if [[ -d "${CONFIG_DIR}/modprobe" ]]; then
    mkdir -p "${SQUASH_DIR}/etc/modprobe.d"
    for conf in "${CONFIG_DIR}/modprobe/"*.conf; do
        [[ -f "$conf" ]] || continue
        cp "$conf" "${SQUASH_DIR}/etc/modprobe.d/"
        log_info "  → /etc/modprobe.d/$(basename "$conf")"
    done
fi

# udev rules (trackpad tuning)
if [[ -d "${CONFIG_DIR}/udev" ]]; then
    mkdir -p "${SQUASH_DIR}/etc/udev/rules.d"
    for rule in "${CONFIG_DIR}/udev/"*.rules; do
        [[ -f "$rule" ]] || continue
        cp "$rule" "${SQUASH_DIR}/etc/udev/rules.d/"
        log_info "  → /etc/udev/rules.d/$(basename "$rule")"
    done
fi

# mbpfan config (fan control)
if [[ -f "${CONFIG_DIR}/mbpfan.conf" ]]; then
    cp "${CONFIG_DIR}/mbpfan.conf" "${SQUASH_DIR}/etc/mbpfan.conf"
    log_info "  → /etc/mbpfan.conf"
    chroot "$SQUASH_DIR" systemctl enable mbpfan.service 2>/dev/null || true
fi

# Copy post-install helper script
if [[ -f "${CONFIG_DIR}/../scripts/post-install.sh" ]]; then
    mkdir -p "${SQUASH_DIR}/usr/local/bin"
    cp "${CONFIG_DIR}/../scripts/post-install.sh" "${SQUASH_DIR}/usr/local/bin/ubuntu-mac-setup"
    chmod +x "${SQUASH_DIR}/usr/local/bin/ubuntu-mac-setup"
    log_info "  → /usr/local/bin/ubuntu-mac-setup"
fi

# ---- Summary ----
log_success "Driver injection complete!"
log_info "Profile: ${PROFILE}"
log_info "Configs installed:"
log_info "  - broadcom-wl.conf     (WiFi driver blacklist)"
log_info "  - hid-apple.conf       (keyboard function keys)"
log_info "  - apple-gmux.conf      (GPU switching)"
log_info "  - apple-hda.conf       (audio fix)"
log_info "  - applespi.conf        (SPI keyboard/trackpad)"
log_info "  - apple-nvme.conf      (NVMe suspend fix)"
log_info "  - mbpfan.conf          (fan control)"
log_info "  - 99-apple-trackpad.rules (trackpad tuning)"
