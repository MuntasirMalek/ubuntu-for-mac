# ============================================================
# Ubuntu Mac Builder — Docker Build Environment
# ============================================================
# This Dockerfile creates a Linux environment capable of
# remastering Ubuntu ISOs on any host OS (macOS, Windows, Linux).
# ============================================================

FROM ubuntu:24.04

LABEL maintainer="Ubuntu Mac Builder"
LABEL description="Build environment for creating Mac-compatible Ubuntu ISOs"

ENV DEBIAN_FRONTEND=noninteractive

# Install all tools needed for ISO remastering
RUN apt-get update && apt-get install -y \
    xorriso \
    squashfs-tools \
    genisoimage \
    syslinux-utils \
    isolinux \
    rsync \
    wget \
    curl \
    gnupg \
    dosfstools \
    mtools \
    grub-efi-amd64-bin \
    grub-pc-bin \
    grub2-common \
    fdisk \
    e2fsprogs \
    && rm -rf /var/lib/apt/lists/*

# Create working directories
RUN mkdir -p /build/iso-extract /build/squashfs-root /build/output

WORKDIR /build

# Copy build scripts
COPY scripts/ /build/scripts/
COPY config/ /build/config/
RUN chmod +x /build/scripts/*.sh

ENTRYPOINT ["/build/scripts/docker-entrypoint.sh"]

