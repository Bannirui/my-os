#!/bin/bash

set -e

# 必要的工具
command -v nasm >/dev/null 2>&1 || { echo "ERROR: nasm not found. Install: sudo apt install nasm"; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "ERROR: cmake not found. Install: sudo apt install cmake"; exit 1; }
command -v qemu-system-x86_64 --version >/dev/null 2>&1 || { echo "ERROR: qemu not found. Install: sudo apt install qemu-system-x86_64"; exit 1; }

CUR_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${CUR_DIR}/build"

# build
echo "Configuring build..."
mkdir -p "${BUILD_DIR}"
cmake -B "${BUILD_DIR}" -S .

echo "Building..."
cmake --build "${BUILD_DIR}" -j$(nproc)

# 创建磁盘镜像
dd if=/dev/zero \
   of=${BUILD_DIR}/os.img \
   bs=512 \
   count=10

# 写入boot sector
dd if=${BUILD_DIR}/boot.bin \
   of=${BUILD_DIR}/os.img \
   bs=512 \
   count=1 \
   conv=notrunc

# 启动qemu
qemu-system-x86_64 \
    -drive format=raw,file=${BUILD_DIR}/os.img