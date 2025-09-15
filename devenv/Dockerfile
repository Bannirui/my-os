FROM i386/ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TARGET=ia16-elf
ENV PREFIX=/opt/gcc-ia16
ENV PATH=$PREFIX/bin:$PATH

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    bison \
    flex \
    texinfo \
    git \
    wget \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# 拉取 binutils + gcc-ia16 源码
RUN git clone --depth=1 https://github.com/tkchia/binutils-gdb.git
RUN git clone --depth=1 https://github.com/tkchia/gcc-ia16.git

# 构建 binutils
RUN mkdir build-binutils && cd build-binutils && \
    ../binutils-gdb/configure \
      --target=$TARGET \
      --prefix=$PREFIX \
      --disable-nls \
      --disable-werror && \
    make -j$(nproc) && \
    make install

# 构建 gcc (只构建 C 编译器)
RUN mkdir build-gcc && cd build-gcc && \
    ../gcc-ia16/configure \
      --target=$TARGET \
      --prefix=$PREFIX \
      --disable-nls \
      --enable-languages=c \
      --without-headers && \
    make all-gcc -j$(nproc) && \
    make install-gcc

# 构建 libgcc（必须单独搞）
RUN cd build-gcc && \
    make all-target-libgcc -j$(nproc) && \
    make install-target-libgcc

# 清理无用文件，减小镜像
RUN rm -rf /tmp/*

CMD ["/bin/bash"]
