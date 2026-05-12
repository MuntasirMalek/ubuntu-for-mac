# 🔍 Driver Coverage Audit — Intel Macs 2012–2020
# =================================================
# This documents every hardware component across all
# Intel Mac models and how our ISO handles it.

## WiFi — COVERED ✅
# All Intel Macs use Broadcom WiFi chips:
#   BCM4331  (2012 models)           → broadcom-sta-dkms / wl driver
#   BCM4360  (2013-2014 models)      → broadcom-sta-dkms / wl driver
#   BCM43602 (2015-2017 models)      → broadcom-sta-dkms / wl driver
#   BCM4350  (12" MacBook 2015-2017) → broadcom-sta-dkms / wl driver
#   BCM4364  (2018-2020 T2 models)   → broadcom-sta-dkms / wl driver
# Config: config/modprobe/broadcom-wl.conf (blacklists conflicting drivers)
# Package: broadcom-sta-dkms, bcmwl-kernel-source (base.list)

## Bluetooth — COVERED ✅
# Broadcom BT uses .hcd firmware files
# Package: bluez, bluez-tools (base.list)
# Firmware: Downloaded from winterheart/broadcom-bt-firmware in inject script
# T2 Macs: Handled by apple-bce-dkms

## Keyboard (2012-2015) — COVERED ✅
# Uses USB HID → works out of box with hid-apple kernel module
# Config: config/modprobe/hid-apple.conf (fnmode=2 for F-keys)

## Keyboard (2016-2017 non-T2) — COVERED ✅
# Uses Apple SPI → needs applespi driver (in kernel since 5.17)
# Config: config/modprobe/applespi.conf (softdep for SPI platform)
# Initramfs: inject script adds applespi + intel_lpss_pci + spi_pxa2xx_platform

## Keyboard (2018-2020 T2) — COVERED ✅
# Controlled by T2 chip → apple-bce-dkms from t2linux repo

## Trackpad (2012-2015) — COVERED ✅
# Uses bcm5974 USB driver → in kernel, works out of box
# Config: config/udev/99-apple-trackpad.rules (palm rejection, touch size)

## Trackpad (2016-2017) — COVERED ✅
# Uses Apple SPI → handled by applespi (same as keyboard)

## Trackpad (2018-2020 T2) — COVERED ✅
# Controlled by T2 chip → apple-bce-dkms

## Audio — COVERED ✅
# Intel HDA with Cirrus Logic codec
# Config: config/modprobe/apple-hda.conf (model=mbp101 hint)
# T2 Macs: apple-bce-dkms + apple-t2-audio-config

## GPU — Intel (all models) — COVERED ✅
# i915 driver → in kernel, works out of box

## GPU — AMD/NVIDIA discrete (dual-GPU MacBooks) — COVERED ✅
# Config: config/modprobe/apple-gmux.conf (force_igd=y for power saving)
# Package: mesa-utils

## Touch Bar (2016-2017 MacBook Pro) — COVERED ✅
# apple-ib-tb module → initramfs config in inject script

## Touch Bar (2018-2020 T2) — COVERED ✅
# apple-touchbar-dkms from t2linux repo

## Fan Control — COVERED ✅
# Package: mbpfan (base.list)
# Config: config/mbpfan.conf (tuned fan curves)
# Uses: applesmc + coretemp kernel modules (in kernel)

## Display Brightness — COVERED ✅
# apple_backlight module → in kernel
# GMUX controls backlight on dual-GPU models → apple-gmux in kernel

## Webcam / FaceTime HD — PARTIAL ⚠️
# 2012-2017: Uses USB → usually works out of box
# 2018-2020 T2: Handled by apple-bce-dkms
# Note: facetimehd DKMS driver exists but is optional/complex

## Thunderbolt — COVERED ✅
# In-kernel thunderbolt subsystem, works out of box since kernel 4.x

## NVMe SSD — COVERED ✅
# In-kernel NVMe driver, works out of box
# Config: config/modprobe/apple-nvme.conf (suspend fix)

## SD Card Reader — COVERED ✅
# Standard USB SD reader → in kernel

## Suspend/Resume — COVERED ✅
# NVMe quirk: config/modprobe/apple-nvme.conf
# Package: pm-utils (base.list)

## Power Management — COVERED ✅
# Packages: powertop, thermald (base.list)

## DKMS (kernel update resilience) — COVERED ✅
# Packages: dkms, build-essential, linux-headers-generic (base.list)
# All out-of-tree drivers use DKMS for automatic rebuild
