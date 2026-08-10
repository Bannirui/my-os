#!/bin/bash

set -e

# 必要的工具
command -v nasm >/dev/null 2>&1 || { echo "ERROR: nasm not found. Install: sudo apt install nasm"; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "ERROR: cmake not found. Install: sudo apt install cmake"; exit 1; }
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "ERROR: qemu not found. Install: sudo apt install qemu-system-x86_64"; exit 1; }
command -v mformat >/dev/null 2>&1 || { echo "ERROR: mformat not found. Install: sudo apt install mtools"; exit 1; }

IMAGE_PATH="${PWD}/build/os.img"

# build
echo "Configuring build..."
mkdir -p "${PWD}/build"
cmake -B "${PWD}/build" -S .

echo "Building..."
cmake --build "${PWD}/build" -j$(nproc)

# 创建磁盘镜像并格式化为FAT12，同时将boot.bin作为引导扇区
# mformat -B 将boot.bin写入0#扇区，并基于其中的BPB创建FAT表和根目录
mformat -f 1440 -B "${PWD}/build/boot.bin" -i "${IMAGE_PATH}" ::

# 把loader.bin和kernel.bin拷贝到fat12文件系统中
mcopy -i "${IMAGE_PATH}" "${PWD}/build/loader.bin" ::/
mcopy -i "${IMAGE_PATH}" "${PWD}/build/kernel/kernel.bin" ::/

echo "os.img ready: ${IMAGE_PATH}"

# 启动
qemu-system-x86_64 \
    -fda "${IMAGE_PATH}" \
    -boot a \
    -monitor stdio
