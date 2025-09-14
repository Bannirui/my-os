FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
# 裸机编译器
ENV PREFIX=/opt/gcc-ia16
ENV TARGET=ia16-elf
ENV PATH=$PREFIX/bin:$PATH


# 安装构建依赖
RUN apt-get update && apt-get install -y \
    # 基础开发环境gcc g++ make
    build-essential \
    # GCC的编译器前端需要它来生成语法分析代码
    bison \
    # 配合bison把源码词法/语法规则编译成C代码
    flex \
    # GCC在编译优化时需要做大数运算
    libgmp3-dev \
    # GCC在处理浮点/复数计算时依赖它
    libmpc-dev \
    # 保证浮点运算的高精度
    libmpfr-dev \
    # 编译GCC时需要生成帮助文档
    texinfo \
    wget \
    curl \
    # 解压binutils gcc的源码包
    xz-utils \
    nasm \
    git \
    # hexdump命令
    bsdextrautils \
    && rm -rf /var/lib/apt/lists/*

# 构建gcc-ia16(包含binutils-ia16) 裸机内核编译工具 ia16-elf-gcc a16-elf-ld, ia16-elf-as, ia16-elf-objdump, ia16-elf-objcopy, ia16-elf-ar, ia16-elf-nm
# 下载源码
RUN git clone --recurse-submodules https://github.com/tkchia/gcc-ia16.git /tmp/gcc-ia16
WORKDIR /tmp/gcc-ia16
# 构建
RUN mkdir build && cd build && \
    ../configure \
      --target=$TARGET \
      --prefix=$PREFIX \
      --disable-nls \
      --enable-languages=c \
      --without-headers \
      --disable-libssp \
      --disable-libstdcxx \
    && make all-gcc -j$(nproc) \
    && make install-gcc

# 设置工作目录
WORKDIR /root/env
VOLUME /root/env

CMD ["/bin/bash"]