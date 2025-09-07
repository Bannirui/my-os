## MY-OS

[TODO list](./TODO.md)

### QUICK START

- 打包docker镜像
`docker build ./buildenv -t myos-buildenv`
- 启动docker容器
`docker run --rm -it -v $PWD:/root/env myos-buildenv`
- docker执行编译
`make`
- 宿主机执行
`qemu-system-x86_64 -fda dist/floppy.img -boot a`

### 1 调试平台

一开始用的是MAC系统来调试引导程序，BIOS切换CPU执行权，执行boot程序是没有问题的。

之后在boot程序中构建了FAT12文件系统，用其加载loader程序，这个时候在挂载目录文件这个地方遇到了坎(macos do not support `mount`)，因此放弃了MAC平台的调试方案，转而到Linux系统。

* [MAC平台](./docs/MAC.md)
* [Centos平台](./docs/CENTOS.md)
* [Ubuntu](./docs/UBUNTU.md)
* [ArchLinux](./docs/ArchLinux.md)

### 2 程序文件

操作系统程序也是源码，分为3批加载到计算机，加载的语义是，程序都在软盘上，要加载到计算机内存上，供CPU寻址。

| 程序   | 名称     | 持久化位置 | 加载方(谁加载到内存)   | 内存位置                                                     | 主要功能职责                                                 |
| ------ | -------- | ---------- | ---------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| BIOS   | BIOS     | 主板ROM    | BIOS ROM存储器内存映射 | [0xffe0 0000...0xffff ffff] High BIOS<br />[0x0xf 0000...0x10 0000]System BIOS<br />[0xe 0000....0xf 0000]Extended System BIOS | 1.构建BIOS中断向量表<br />2.加载bootsect程序<br />3.跳转执行bootsect程序 |
| 第一批 | bootsect | 软盘扇区0  | BIOS程序               | [0x7c00...0x7e00]                                            | 1.构建软盘文件系统<br />2.加载loader程序<br />3.跳转执行loader程序 |
| 第二批 | loader   | 软盘       | bootsect               | [0x1 0000...]视具体的开发大小                                | 1.构建软盘文件系统<br />2.加载kernel程序<br />3.16位实模式切换32位保护模式<br />4.32位保护模式切换IA-32e模式<br />5.跳转执行kernel程序 |
| 第三批 | kernel   | 软盘       | loader                 | [0x10 0000...]视具体的开发大小                               |                                                              |

kernel程序中比较核心的是内核执行头程序和链接脚本，二者将CPU模式跳转和内存规划布局的工作完成好，后面的事情就是C语言编程。

* 内核执行头程序，负责将CPU真正切换到IA-32e模式
  * loader程序最终所处的模式仅仅是混合模式，即虽然切换到了64位保护模式，但是运行的依然是32位保护模式下的代码，即使手工给段寄存器赋值了，但是不能手工给CS段寄存器赋值
  * 因此需要依赖一个长跳\长调用来变相改变CS的寄存器值
  * 并且，loader程序在进行16位实模式->32位保护模式->64保护模式切换过程中所构建的GDT表和IDT都是临时的，相当于内存占位，并没有真正构建出需要的GDT表和IDT
  * CPU跳到内核执行头程序后，首先处理器的工作模式真正编程了IA-32e模式，其次该程序负责布局内存，构建GDT表和IDT及页表
* 链接脚本，脚本中对物理地址和逻辑地址进行了映射，布局了内存空间，保证编译过程中手工链接之后，内核执行头程序能被先执行

### 3 FAT12文件系统

[为1.44M软盘设计文件系统](./docs/FD.md)

### 4 内存布局

[内存布局和规划](./docs/MEM.md)

### 5 Bochs执行

#### 5.1 [通过Bochs虚拟机调试模式查看处理器运行模式](./docs/CPU-MODE.md)

#### 5.2 [内核程序运行](./docs/SNAPSHOT.md)
