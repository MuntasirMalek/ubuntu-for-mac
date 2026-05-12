#!/bin/bash
# ============================================================
# Ubuntu Mac Builder — Main Build Script
# ============================================================
# Builds a custom Ubuntu ISO with all Apple hardware drivers
# pre-installed. Runs the build inside Docker for
# cross-platform compatibility.
#
# Usage:
#   ./build.sh [OPTIONS] <ubuntu-iso-file>
#
# Options:
#   --profile <all|non-t2|t2>  Driver profile (default: all)
#   --no-docker                Run directly on Linux host
#   --output <filename>        Output ISO filename
#   --help                     Show this help
# ============================================================

set -euo pipefail

# ---- Colors for output ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ---- Default configuration ----
PROFILE="all"
USE_DOCKER=true
OUTPUT_ISO=""
INPUT_ISO=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Helper functions ----
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()    { echo -e "\n${CYAN}${BOLD}━━━ $* ━━━${NC}\n"; }

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
  _   _ _                 _            __  __            
 | | | | |               | |          |  \/  |           
 | | | | |__  _   _ _ __ | |_ _   _   | \  / | __ _  ___ 
 | | | | '_ \| | | | '_ \| __| | | |  | |\/| |/ _` |/ __|
 | |_| | |_) | |_| | | | | |_| |_| |  | |  | | (_| | (__ 
  \___/|_.__/ \__,_|_| |_|\__|\__,_|  |_|  |_|\__,_|\___|
                                                           
  B U I L D E R
EOF
    echo -e "${NC}"
    echo -e "  ${BOLD}Custom Ubuntu ISO with Apple hardware drivers${NC}"
    echo -e "  ${BLUE}https://github.com/MuntasirMalek/ubuntu-for-mac${NC}"
    echo ""
}

show_help() {
    echo "Usage: ./build.sh [OPTIONS] <ubuntu-iso-file>"
    echo ""
    echo "Options:"
    echo "  --profile <all|non-t2|t2>  Driver profile to include (default: all)"
    echo "    all    — Include drivers for ALL Mac models (2012-2020)"
    echo "    non-t2 — Only pre-2018 Mac drivers (smaller ISO)"
    echo "    t2     — Only T2 Mac drivers (2018-2020)"
    echo ""
    echo "  --no-docker    Run build directly (requires Linux host)"
    echo "  --output FILE  Custom output ISO filename"
    echo "  --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./build.sh ubuntu-26.04-desktop-amd64.iso"
    echo "  ./build.sh --profile non-t2 ubuntu-26.04-desktop-amd64.iso"
    echo "  ./build.sh --output my-custom.iso ubuntu-26.04-desktop-amd64.iso"
    echo ""
}

# ---- Parse arguments ----
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                PROFILE="$2"
                if [[ ! "$PROFILE" =~ ^(all|non-t2|t2)$ ]]; then
                    log_error "Invalid profile: $PROFILE (must be: all, non-t2, t2)"
                    exit 1
                fi
                shift 2
                ;;
            --no-docker)
                USE_DOCKER=false
                shift
                ;;
            --output)
                OUTPUT_ISO="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                INPUT_ISO="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$INPUT_ISO" ]]; then
        log_error "No input ISO specified!"
        echo ""
        show_help
        exit 1
    fi

    if [[ ! -f "$INPUT_ISO" ]]; then
        log_error "ISO file not found: $INPUT_ISO"
        echo "  Make sure the file exists and the path is correct."
        exit 1
    fi

    # Set default output name if not specified
    if [[ -z "$OUTPUT_ISO" ]]; then
        local basename
        basename="$(basename "$INPUT_ISO" .iso)"
        OUTPUT_ISO="${basename}-mac-edition.iso"
    fi
}

# ---- Pre-flight checks ----
preflight_checks() {
    log_step "Pre-flight Checks"

    # Check input ISO size
    local iso_size
    if [[ "$(uname)" == "Darwin" ]]; then
        iso_size=$(stat -f%z "$INPUT_ISO" 2>/dev/null || echo "0")
    else
        iso_size=$(stat -c%s "$INPUT_ISO" 2>/dev/null || echo "0")
    fi
    local iso_size_mb=$((iso_size / 1024 / 1024))
    log_info "Input ISO: $(basename "$INPUT_ISO") (${iso_size_mb} MB)"

    if [[ $iso_size_mb -lt 100 ]]; then
        log_error "ISO file seems too small (${iso_size_mb} MB). Is this a valid Ubuntu ISO?"
        exit 1
    fi

    # Check free disk space (need ~20 GB)
    local free_space_mb
    if [[ "$(uname)" == "Darwin" ]]; then
        free_space_mb=$(df -m "$SCRIPT_DIR" | tail -1 | awk '{print $4}')
    else
        free_space_mb=$(df -m "$SCRIPT_DIR" | tail -1 | awk '{print $4}')
    fi
    log_info "Free disk space: ${free_space_mb} MB"

    if [[ $free_space_mb -lt 15000 ]]; then
        log_warn "Less than 15 GB free! Build may fail. Recommended: 20+ GB free."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    log_info "Profile: ${BOLD}${PROFILE}${NC}"
    log_info "Output: ${BOLD}${OUTPUT_ISO}${NC}"
    log_success "Pre-flight checks passed!"
}

# ---- Docker build ----
build_with_docker() {
    log_step "Building with Docker"

    # Check Docker is available
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed!"
        echo ""
        echo "  Install Docker Desktop:"
        echo "    macOS: https://www.docker.com/products/docker-desktop/"
        echo "    Linux: curl -fsSL https://get.docker.com | sh"
        echo ""
        exit 1
    fi

    # Check Docker daemon is running
    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running!"
        echo "  Please start Docker Desktop and try again."
        exit 1
    fi

    log_info "Building Docker image..."
    docker build -t ubuntu-mac-builder:latest "$SCRIPT_DIR" 2>&1 | while read -r line; do
        echo -e "  ${BLUE}[Docker]${NC} $line"
    done

    log_info "Starting build container..."

    # Get the absolute path to the ISO
    local abs_iso_path
    abs_iso_path="$(cd "$(dirname "$INPUT_ISO")" && pwd)/$(basename "$INPUT_ISO")"
    local abs_output_dir
    abs_output_dir="$(cd "$(dirname "$OUTPUT_ISO")" 2>/dev/null && pwd)" || abs_output_dir="$SCRIPT_DIR"

    docker run --rm --privileged \
        -v "$abs_iso_path":/build/input.iso:ro \
        -v "$abs_output_dir":/build/output \
        -e PROFILE="$PROFILE" \
        -e OUTPUT_NAME="$(basename "$OUTPUT_ISO")" \
        ubuntu-mac-builder:latest

    if [[ -f "$abs_output_dir/$(basename "$OUTPUT_ISO")" ]]; then
        log_success "Build complete!"
        echo ""
        echo -e "  ${GREEN}${BOLD}✓ Custom ISO ready:${NC} ${OUTPUT_ISO}"
        echo ""
        echo "  Next steps:"
        echo "    1. Flash to USB:  sudo dd if=${OUTPUT_ISO} of=/dev/rdiskN bs=4m"
        echo "    2. Boot your Mac holding ⌥ Option"
        echo "    3. Select the USB drive and install!"
        echo ""
    else
        log_error "Build failed — output ISO not found."
        exit 1
    fi
}

# ---- Native Linux build ----
build_native() {
    log_step "Building Natively (Linux)"

    # Check we're on Linux
    if [[ "$(uname)" != "Linux" ]]; then
        log_error "--no-docker requires a Linux host!"
        echo "  On macOS, remove --no-docker to use Docker instead."
        exit 1
    fi

    # Check for root
    if [[ $EUID -ne 0 ]]; then
        log_error "Native build requires root. Run with: sudo ./build.sh --no-docker ..."
        exit 1
    fi

    # Check dependencies
    local deps=(xorriso unsquashfs mksquashfs chroot rsync)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_error "Missing dependency: $dep"
            echo "  Install with: sudo apt install xorriso squashfs-tools"
            exit 1
        fi
    done

    # Create temp working directory inside the project
    local work_dir="${SCRIPT_DIR}/.build-tmp"
    mkdir -p "$work_dir"
    trap 'log_info "Cleaning up..."; rm -rf "$work_dir"' EXIT

    # Run the build steps
    log_info "Extracting ISO..."
    bash "${SCRIPT_DIR}/scripts/extract-iso.sh" "$INPUT_ISO" "$work_dir"

    log_info "Injecting drivers..."
    bash "${SCRIPT_DIR}/scripts/inject-drivers.sh" "$work_dir" "$PROFILE" "${SCRIPT_DIR}/config"

    log_info "Rebuilding ISO..."
    bash "${SCRIPT_DIR}/scripts/rebuild-iso.sh" "$work_dir" "${SCRIPT_DIR}/${OUTPUT_ISO}"

    log_success "Build complete!"
    echo ""
    echo -e "  ${GREEN}${BOLD}✓ Custom ISO ready:${NC} ${OUTPUT_ISO}"
    echo ""
}

# ---- Main ----
main() {
    show_banner
    parse_args "$@"
    preflight_checks

    local start_time=$SECONDS

    if $USE_DOCKER; then
        build_with_docker
    else
        build_native
    fi

    local elapsed=$(( SECONDS - start_time ))
    local minutes=$(( elapsed / 60 ))
    local seconds=$(( elapsed % 60 ))
    echo -e "  ${BLUE}Build time: ${minutes}m ${seconds}s${NC}"
    echo ""
}

main "$@"
