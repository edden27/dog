#!/usr/bin/env bash
#
# Cross-platform build & test runner for dog.
# Runs swift build + swift test on both macOS (native) and Linux (Docker).
#
# Usage:
#   ./scripts/generate/linux.sh                 # Run both macOS and Linux
#   ./scripts/generate/linux.sh linux           # Run Linux tests only
#   ./scripts/generate/linux.sh macos           # Run macOS tests only
#   ./scripts/generate/linux.sh shell           # Open interactive shell in Linux container
#   ./scripts/generate/linux.sh binary          # Build release binaries (both arches) → ./dog-linux-{x86_64,arm64}
#   ./scripts/generate/linux.sh binary x86_64   # Build only x86_64
#   ./scripts/generate/linux.sh binary arm64    # Build only arm64
#
# Requirements:
#   - Docker Desktop or OrbStack (preferred) for Linux tests
#   - Swift 6.3+ toolchain for macOS tests

set -euo pipefail

SWIFT_IMAGE="swift:6.3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="${1:-all}"
# Separate build directory inside the container to avoid permission conflicts
# with the host's .build directory (different Swift versions, different UIDs).
LINUX_BUILD_PATH="/tmp/dog-build"

# UtilityDark palette
RED='\033[38;2;204;67;61m'
GREEN='\033[38;2;136;169;141m'
YELLOW='\033[38;2;222;169;99m'
BOLD='\033[1m'
RESET='\033[0m'

header() {
    echo ""
    echo -e "${BOLD}━━━ $1 ━━━${RESET}"
    echo ""
}

success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

fail() {
    echo -e "${RED}✗ $1${RESET}"
}

check_docker() {
    if ! docker info &>/dev/null; then
        echo -e "${RED}Error: Docker/OrbStack is not running.${RESET}"
        echo "Start Docker Desktop or OrbStack and try again."
        exit 1
    fi
}

run_macos() {
    header "macOS: swift build + swift test"
    if (cd "$PROJECT_DIR" && swift build && swift test) 2>&1; then
        success "macOS build + tests passed"
    else
        fail "macOS build or tests failed"
        exit 1
    fi

    header "macOS: scaffold integration tests"
    if bash "$SCRIPT_DIR/scaffold/run-all.sh" 2>&1; then
        success "macOS scaffold tests passed"
    else
        fail "macOS scaffold tests failed"
        exit 1
    fi
}

run_linux() {
    check_docker

    header "Linux ($SWIFT_IMAGE): swift build + swift test + scaffold"
    if docker run --rm \
        -v "$PROJECT_DIR:/workspace:ro" \
        -w /tmp/src \
        "$SWIFT_IMAGE" \
        bash -c "cp -a /workspace/. . && swift build --build-path $LINUX_BUILD_PATH && swift test --build-path $LINUX_BUILD_PATH && DOG_BIN=$LINUX_BUILD_PATH/debug/dog bash scripts/scaffold/run-all.sh" 2>&1; then
        success "Linux build + tests + scaffold passed"
    else
        fail "Linux build or tests failed"
        exit 1
    fi
}

build_linux_arch() {
    # $1 = docker platform (linux/amd64|linux/arm64), $2 = output suffix (x86_64|arm64)
    local PLATFORM="$1"
    local SUFFIX="$2"
    local OUTPUT="$PROJECT_DIR/dog-linux-$SUFFIX"
    header "Linux $SUFFIX ($SWIFT_IMAGE, $PLATFORM): building release binary"
    if docker run --rm \
        --platform "$PLATFORM" \
        -v "$PROJECT_DIR:/workspace" \
        -w /tmp/src \
        "$SWIFT_IMAGE" \
        bash -c "cp -a /workspace/. . && swift build -c release --build-path $LINUX_BUILD_PATH -Xcc -flto=thin -Xswiftc -use-ld=lld --static-swift-stdlib && strip $LINUX_BUILD_PATH/release/dog && cp $LINUX_BUILD_PATH/release/dog /workspace/dog-linux-$SUFFIX"; then
        chmod +x "$OUTPUT"
        success "Binary built: $OUTPUT"
    else
        fail "Release build failed ($SUFFIX)"
        exit 1
    fi
}

run_binary() {
    check_docker
    local ARCH="${2:-all}"
    case "$ARCH" in
        x86_64|amd64) build_linux_arch linux/amd64 x86_64 ;;
        arm64|aarch64) build_linux_arch linux/arm64 arm64 ;;
        all|*)
            build_linux_arch linux/amd64 x86_64
            build_linux_arch linux/arm64 arm64
            ;;
    esac
    echo ""
    echo -e "${YELLOW}Send to Linux users. They run:${RESET}"
    echo "  chmod +x dog-linux-<arch>"
    echo "  mv dog-linux-<arch> /usr/local/bin/dog"
}

run_shell() {
    check_docker
    header "Opening interactive shell in $SWIFT_IMAGE"
    echo -e "${YELLOW}Building dog and installing to /usr/local/bin...${RESET}"
    echo -e "${YELLOW}Type 'exit' to leave the container${RESET}"
    echo ""
    docker run --rm -it \
        -e LANG=C.UTF-8 \
        -v "$PROJECT_DIR:/workspace:ro" \
        -w /tmp/src \
        "$SWIFT_IMAGE" \
        bash -c "cp -a /workspace/. . && swift build --build-path $LINUX_BUILD_PATH && cp $LINUX_BUILD_PATH/debug/dog /usr/local/bin/ && echo -e '${GREEN}dog installed — ready to use${RESET}' && exec /bin/bash"
}

case "$TARGET" in
    macos)
        run_macos
        ;;
    linux)
        run_linux
        ;;
    binary)
        run_binary "$@"
        ;;
    shell)
        run_shell
        ;;
    all)
        run_macos
        run_linux
        ;;
    *)
        echo "Usage: $0 [all|macos|linux|shell|binary]"
        exit 1
        ;;
esac

header "Done"
success "All checks passed!"
