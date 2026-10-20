#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GOPEED_DIR="${ROOT_DIR}/third_party/gopeed"

if [[ ! -d "${GOPEED_DIR}" ]]; then
  echo "Error: ${GOPEED_DIR} not found. Please ensure third_party/gopeed is cloned."
  exit 1
fi

echo "==> Building libgopeed FFI shared library..."

TARGET_OS="${1:-$(uname -s | tr '[:upper:]' '[:lower:]')}"

case "${TARGET_OS}" in
  darwin|macos)
    mkdir -p "${ROOT_DIR}/macos/Frameworks"
    cd "${GOPEED_DIR}"
    go build -tags nosqlite -ldflags="-w -s" -buildmode=c-shared \
      -o "${ROOT_DIR}/macos/Frameworks/libgopeed.dylib" \
      github.com/GopeedLab/gopeed/bind/desktop
    echo "✓ Built macos/Frameworks/libgopeed.dylib successfully."
    ;;
  windows)
    mkdir -p "${ROOT_DIR}/windows"
    cd "${GOPEED_DIR}"
    go build -tags nosqlite -ldflags="-w -s" -buildmode=c-shared \
      -o "${ROOT_DIR}/windows/libgopeed.dll" \
      github.com/GopeedLab/gopeed/bind/desktop
    echo "✓ Built windows/libgopeed.dll successfully."
    ;;
  linux)
    mkdir -p "${ROOT_DIR}/linux"
    cd "${GOPEED_DIR}"
    go build -tags nosqlite -ldflags="-w -s" -buildmode=c-shared \
      -o "${ROOT_DIR}/linux/libgopeed.so" \
      github.com/GopeedLab/gopeed/bind/desktop
    echo "✓ Built linux/libgopeed.so successfully."
    ;;
  *)
    echo "Unsupported OS: ${TARGET_OS}"
    exit 1
    ;;
esac
