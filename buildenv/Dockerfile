FROM ubuntu:22.04

# 安装构建工具和依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    nasm
RUN rm -rf /var/lib/apt/lists/*

# 创建工作目录
WORKDIR /root/env
VOLUME /root/env

# 默认命令进入bash
CMD ["/bin/bash"]
