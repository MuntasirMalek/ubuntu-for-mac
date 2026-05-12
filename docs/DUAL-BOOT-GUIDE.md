# Dual Boot Guide: Ubuntu + macOS (with OpenCore)

This guide walks you through installing Ubuntu alongside macOS on your Mac's internal SSD, with macOS remaining the default boot OS.

## Overview

```
INTERNAL SSD (after setup):
├── macOS partition (APFS)     ← Default boot via OpenCore
├── Ubuntu partition (ext4)    ← ~50-100 GB
└── Ubuntu swap (optional)     ← ~4-8 GB
```

## Prerequisites

- ✅ macOS working (with or without OpenCore)
- ✅ Custom Ubuntu ISO (built with `./build.sh`)
- ✅ USB drive (8 GB+) or external drive partition to boot from
- ✅ **Backup your data** — always before partitioning!

## Step 1: Prepare the Internal SSD

### On macOS:

1. Open **Disk Utility** (Applications → Utilities)
2. Click **View → Show All Devices**
3. Select your internal SSD (not a partition, the physical drive)
4. Click **Partition**
5. Click the **+** button to add a partition
6. Set:
   - **Name**: `UBUNTU` (or anything you want)
   - **Format**: MS-DOS (FAT) — Ubuntu will reformat this
   - **Size**: 50–100 GB (more is better)
7. Click **Apply**

> ⚠️ If Disk Utility says it can't add a partition, you may need to resize your APFS container first. This can happen if Time Machine snapshots are using space.

## Step 2: Flash the Custom ISO

### Find your USB drive:

```bash
diskutil list
```

Look for your USB drive (e.g., `/dev/disk3`). **Make absolutely sure** you have the right disk!

### Flash:

```bash
# Unmount the USB
diskutil unmountDisk /dev/diskN

# Flash the ISO (use 'rdisk' for faster writes)
sudo dd if=ubuntu-26.04-mac-edition.iso of=/dev/rdiskN bs=4m status=progress

# Eject
diskutil eject /dev/diskN
```

## Step 3: Boot the Installer

1. Restart your Mac
2. **Hold ⌥ Option** immediately at startup
3. You'll see boot options — select the orange **EFI Boot** (your USB)
4. Ubuntu live environment will load
5. **Test your hardware** before installing:
   - Does WiFi work? (Should work with our custom ISO!)
   - Does the trackpad work?
   - Does audio work?

## Step 4: Install Ubuntu

1. Double-click **Install Ubuntu** on the desktop
2. Follow the wizard until you reach **Installation type**
3. Choose **"Something Else"** (manual partitioning)

### Partition Setup:

You'll see a list of ALL drives and partitions. **BE CAREFUL.**

Find the FAT partition you created in Step 1 (look for the one matching the size you set, e.g., ~50 GB, type FAT32).

| Action | Partition | Size | Mount | Format |
|--------|-----------|------|-------|--------|
| Delete | The FAT partition you created | — | — | — |
| Create | New ext4 | ~46 GB (or more) | `/` | ✅ Yes |
| Create | New swap | ~4-8 GB | swap | ✅ Yes |

### CRITICAL: Bootloader Location

- **If using OpenCore**: Install the bootloader to the **Ubuntu ext4 partition** (e.g., `/dev/sda4`), NOT to the main drive
- **If NOT using OpenCore**: Default is fine (it'll install GRUB to the EFI partition)

Click **Install Now**.

## Step 5: After Installation

### Default Boot Behavior:

| Setup | What Happens |
|-------|-------------|
| **OpenCore Mac** | Boots to OpenCore → macOS by default. Hold **⌥ Option** at startup to pick Ubuntu |
| **Standard Mac** | GRUB appears → pick macOS or Ubuntu. Edit `/etc/default/grub` to change default |

### To Make macOS the Default in GRUB:

```bash
# After booting into Ubuntu:
sudo nano /etc/default/grub

# Find GRUB_DEFAULT and change to:
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true

# Update GRUB
sudo update-grub
```

Then boot into macOS once — GRUB will remember your choice.

### Post-Install Verification:

```bash
# Run the included Mac setup helper
sudo ubuntu-mac-setup

# Or manually check:
lspci -nnk | grep -iA3 network  # WiFi
lsmod | grep wl                   # WiFi driver
sensors                            # Temperatures
systemctl status mbpfan            # Fan control
```

## Troubleshooting

### Can't see Ubuntu in boot menu?
- Hold **⌥ Option** at startup — it should appear as "EFI Boot"
- If using OpenCore, you may need to add Ubuntu's EFI entry to your `config.plist`

### macOS won't boot after Ubuntu install?
- This usually means GRUB overwrote the EFI boot entry
- Boot to Ubuntu, then: `sudo efibootmgr -o XXXX,YYYY` (reorder boot entries)
- Or boot macOS Recovery (⌘+R) and reinstall the boot loader

### Ubuntu partition not showing?
- In macOS Disk Utility, the ext4 partition won't be visible (macOS can't read ext4)
- This is normal — Ubuntu will see it fine

### OpenCore doesn't show Ubuntu?
- Add a `BlessOverride` entry in your OpenCore `config.plist`
- Or just use ⌥ Option key at boot (simpler)
