FROM --platform=linux/386 i386/ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TARGET=ia16-elf
ENV PREFIX=/opt/gcc-ia16
ENV PATH=$PREFIX/bin:$PATH

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    bison \
    flex \
    libgmp3-dev \
    libmpc-dev \
    libmpfr-dev \
    texinfo \
    wget \
    curl \
    xz-utils \
    git \
    nasm \
    make \
    binutils \
    gdb \
    vim \
    && rm -rf /var/lib/apt/lists/*

# 构建 gcc-ia16
RUN git clone --recurse-submodules https://github.com/tkchia/gcc-ia16.git /tmp/gcc-ia16 && \
    cd /tmp/gcc-ia16 && \
    mkdir build && cd build && \
    ../configure \
      --build=i386-linux-gnu \
      --host=i386-linux-gnu \
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
WORKDIR /root/dev
VOLUME /root/dev

CMD ["/bin/bash"]
