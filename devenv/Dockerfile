FROM --platform=linux/386 i386/ubuntu:16.04

RUN apt-get update && apt-get install -y \
    gcc \
    make \
    nasm \
    binutils \
    gdb \
    && rm -rf /var/lib/apt/lists/*
# 设置默认工作目录
WORKDIR /root/dev
VOLUME /root/dev
# 进入容器后默认执行bash
CMD ["/bin/bash"]