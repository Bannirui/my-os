## MY-OS

在[TUTORIAL](https://github.com/Bannirui/tutorial.git)中有记录当时学习的操作系统相关的知识

[TODO list](./TODO.md)

### 1 PRE-REQUIRED

- 虚拟机用的是qemu 安装`brew install qemu`
- 编译没有在宿主机上直接进行 安装docker
- 启动方式前期学习的是软盘 后来学习了硬盘 两相比较硬盘方式的读盘因为LBA更简单 因此切换到硬盘方式
- make中写了对软盘启动方式的构建命令 只停留在loader的加载
- 打包docker镜像`docker build ./buildenv -t myos-buildenv`
- 宿主机执行启动盘方式
  - 软盘启动`qemu-system-x86_64 -fda dist/floppy.img -boot a`
  - 硬盘启动`qemu-system-x86_64 -hda dist/disk.img`

### 2 QUICK START

以下命令全在项目根路径下执行

- 启动docker容器`docker run --rm -it --name my-os-env -v $PWD:/root/env myos-buildenv`
- docker中执行编译`make`
- 宿主机上执行`make run`