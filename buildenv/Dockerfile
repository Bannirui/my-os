FROM randomdude/gcc-cross-x86_64-elf

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        # 汇编器
        nasm \
        # GRUB BIOS模块
        grub-pc-bin \
        # GRUB公共工具
        grub-common \
        # 生成ISO必须
        xorriso \
        # mformat/mcopy
        mtools \
        # QEMU模拟器
        qemu-system-x86 \
        # QEMU工具
        qemu-utils \
    && rm -rf /var/lib/apt/lists/*

VOLUME /root/env
WORKDIR /root/env
