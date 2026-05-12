# Supported Mac Models

Comprehensive list of Apple Mac models and their Linux hardware compatibility.

## Legend

- ✅ **Works out of the box** — No extra drivers needed
- 🔧 **Fixed by this ISO** — Our custom ISO includes the needed drivers
- ⚠️ **Partial** — Mostly works, may need minor manual tweaks
- ❌ **Not supported** — Hardware not compatible

---

## MacBook Pro

### 15-inch Models

| Year | Model ID | WiFi | Keyboard | Trackpad | Audio | GPU | Webcam | Tier |
|------|----------|------|----------|----------|-------|-----|--------|------|
| 2012 | MacBookPro10,1 | 🔧 BCM4331 | ✅ | ✅ | 🔧 | ✅/🔧 dGPU | ✅ | Tier 1 |
| 2013 Early | MacBookPro10,1 | 🔧 BCM4360 | ✅ | ✅ | 🔧 | ✅/🔧 dGPU | ✅ | Tier 1 |
| 2013 Late | MacBookPro11,3 | 🔧 BCM4360 | ✅ | ✅ | 🔧 | ✅/🔧 dGPU | ✅ | Tier 1 |
| 2014 | MacBookPro11,3 | 🔧 BCM4360 | ✅ | ✅ | 🔧 | ✅/🔧 dGPU | ✅ | Tier 1 |
| **2015** | **MacBookPro11,5** | **🔧 BCM43602** | **✅** | **✅** | **🔧** | **✅/🔧** | **✅** | **Tier 1** |
| 2016 | MacBookPro13,3 | 🔧 BCM43602 | ✅ | ✅ | 🔧 | ✅/🔧 dGPU | ✅ | Tier 1 |
| 2017 | MacBookPro14,3 | 🔧 BCM43602 | ✅ | ✅ | 🔧 | ✅/🔧 dGPU | ✅ | Tier 1 |
| 2018 | MacBookPro15,1 | 🔧 BCM4364 | 🔧 T2 | 🔧 T2 | 🔧 T2 | ✅ | 🔧 T2 | Tier 2 |
| 2019 | MacBookPro15,1/3 | 🔧 BCM4364 | 🔧 T2 | 🔧 T2 | 🔧 T2 | ✅ | 🔧 T2 | Tier 2 |

### 13-inch Models

| Year | Model ID | WiFi | Keyboard | Trackpad | Audio | GPU | Webcam | Tier |
|------|----------|------|----------|----------|-------|-----|--------|------|
| 2012 | MacBookPro9,2 | 🔧 BCM4331 | ✅ | ✅ | 🔧 | ✅ Intel | ✅ | Tier 1 |
| 2013-2014 | MacBookPro11,1 | 🔧 BCM4360 | ✅ | ✅ | 🔧 | ✅ Intel | ✅ | Tier 1 |
| 2015 | MacBookPro12,1 | 🔧 BCM43602 | ✅ | ✅ | 🔧 | ✅ Intel | ✅ | Tier 1 |
| 2016-2017 | MacBookPro13,1/14,1 | 🔧 BCM43602 | ✅ | ✅ | 🔧 | ✅ Intel | ✅ | Tier 1 |
| 2018-2019 | MacBookPro15,2/4 | 🔧 BCM4364 | 🔧 T2 | 🔧 T2 | 🔧 T2 | ✅ Intel | 🔧 T2 | Tier 2 |
| 2020 Intel | MacBookPro16,2/3 | 🔧 BCM4364 | 🔧 T2 | 🔧 T2 | 🔧 T2 | ✅ Intel | 🔧 T2 | Tier 2 |

## MacBook Air

| Year | Model ID | WiFi | Keyboard | Trackpad | Audio | GPU | Tier |
|------|----------|------|----------|----------|-------|-----|------|
| 2012 | MacBookAir5,x | 🔧 BCM4360 | ✅ | ✅ | 🔧 | ✅ Intel | Tier 1 |
| 2013-2014 | MacBookAir6,x | 🔧 BCM4360 | ✅ | ✅ | 🔧 | ✅ Intel | Tier 1 |
| 2015-2017 | MacBookAir7,x | 🔧 BCM4360 | ✅ | ✅ | 🔧 | ✅ Intel | Tier 1 |
| 2018-2019 | MacBookAir8,1/2 | 🔧 BCM4364 | 🔧 T2 | 🔧 T2 | 🔧 T2 | ✅ Intel | Tier 2 |
| 2020 Intel | MacBookAir9,1 | 🔧 BCM4364 | 🔧 T2 | 🔧 T2 | 🔧 T2 | ✅ Intel | Tier 2 |

## MacBook (12-inch)

| Year | Model ID | WiFi | Keyboard | Trackpad | Audio | Notes | Tier |
|------|----------|------|----------|----------|-------|-------|------|
| 2015-2017 | MacBook8,1/9,1/10,1 | 🔧 BCM4350 | ✅ | ✅ | 🔧 | Single USB-C, may need hub | Tier 2 |

## iMac & Mac Mini

These generally work well with this ISO. WiFi is the main fix needed.
Desktop Macs don't need fan tuning as urgently, but mbpfan is still included.

## NOT Supported

| Model | Reason | Alternative |
|-------|--------|-------------|
| Any Apple Silicon Mac (M1/M2/M3/M4) | Completely different architecture | [Asahi Linux](https://asahilinux.org/) |
| Pre-2012 Macs | Very old hardware, kernel support varies | Try Lubuntu or Puppy Linux |

## How to Find Your Model

```bash
# On macOS:
system_profiler SPHardwareDataType | grep "Model Identifier"

# On Linux (if already installed):
cat /sys/class/dmi/id/product_name
sudo dmidecode -s system-product-name
```
