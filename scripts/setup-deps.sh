#!/usr/bin/env bash
set -euo pipefail

readonly project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly sdk_dir="${PICO_SDK_PATH:-$project_root/.deps/pico-sdk}"
readonly sdk_ref="${PICO_SDK_REF:-2.3.0}"

if command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install --yes --no-install-recommends \
        build-essential cmake git ninja-build \
        gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf \
        picolibc-riscv64-unknown-elf \
        libstdc++-riscv64-unknown-elf-picolibc \
        picotool
fi

if [[ ! -d "$sdk_dir/.git" ]]; then
    mkdir -p "$(dirname "$sdk_dir")"
    git clone --branch "$sdk_ref" --depth 1 \
        https://github.com/raspberrypi/pico-sdk.git "$sdk_dir"
fi

git -C "$sdk_dir" submodule update --init --depth 1
printf 'PICO_SDK_PATH=%q\n' "$sdk_dir"
printf 'Configure with: cmake --preset pico2-riscv\n'
