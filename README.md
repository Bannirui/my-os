## MY-OS

### 1 Bochs虚拟机

#### 1.1 安装

bochs图形化依赖需要，安装包中已经依赖了sdl2，下文的配置文件中直接指定sdl2即可，不需要再次安装sdl。

```shell
> brew info bochs
==> bochs: stable 2.7 (bottled)
Open source IA-32 (x86) PC emulator written in C++
https://bochs.sourceforge.io/
/usr/local/Cellar/bochs/2.7 (172 files, 8MB) *
  Poured from bottle using the formulae.brew.sh API on 2023-07-03 at 10:29:03
From: https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/bochs.rb
License: LGPL-2.0-or-later
==> Dependencies
Build: pkg-config ✔
Required: libtool ✔, sdl2 ✔
==> Analytics
install: 0 (30 days), 0 (90 days), 0 (365 days)
install-on-request: 0 (30 days), 0 (90 days), 0 (365 days)
build-error: 0 (30 days)
```



```shell
brew install bochs
```

安装路径为/usr/local/Cellar/bochs/2.7

#### 1.2 创建虚拟软盘

```shell
> bximage
========================================================================
                                bximage
  Disk Image Creation / Conversion / Resize and Commit Tool for Bochs
         $Id: bximage.cc 14091 2021-01-30 17:37:42Z sshwarts $
========================================================================

1. Create new floppy or hard disk image
2. Convert hard disk image to other format (mode)
3. Resize hard disk image
4. Commit 'undoable' redolog to base image
5. Disk image info

0. Quit

Please choose one [0]
```

此处创建的软盘，指定的名称在下文配置文件中将要使用，只要保证前后一致即可，比如创建一个名为boot.img的虚拟软盘

##### 1.2.1 镜像

```shell
> bximage
========================================================================
                                bximage
  Disk Image Creation / Conversion / Resize and Commit Tool for Bochs
         $Id: bximage.cc 14091 2021-01-30 17:37:42Z sshwarts $
========================================================================

1. Create new floppy or hard disk image
2. Convert hard disk image to other format (mode)
3. Resize hard disk image
4. Commit 'undoable' redolog to base image
5. Disk image info

0. Quit

Please choose one [0] 1
```

##### 1.2.2 软盘

```shell
========================================================================
                                bximage
  Disk Image Creation / Conversion / Resize and Commit Tool for Bochs
         $Id: bximage.cc 14091 2021-01-30 17:37:42Z sshwarts $
========================================================================

1. Create new floppy or hard disk image
2. Convert hard disk image to other format (mode)
3. Resize hard disk image
4. Commit 'undoable' redolog to base image
5. Disk image info

0. Quit

Please choose one [0] 1

Create image

Do you want to create a floppy disk image or a hard disk image?
Please type hd or fd. [hd] fd
```

##### 1.2.3 规格

```shell
========================================================================
                                bximage
  Disk Image Creation / Conversion / Resize and Commit Tool for Bochs
         $Id: bximage.cc 14091 2021-01-30 17:37:42Z sshwarts $
========================================================================

1. Create new floppy or hard disk image
2. Convert hard disk image to other format (mode)
3. Resize hard disk image
4. Commit 'undoable' redolog to base image
5. Disk image info

0. Quit

Please choose one [0] 1

Create image

Do you want to create a floppy disk image or a hard disk image?
Please type hd or fd. [hd] fd

Choose the size of floppy disk image to create.
Please type 160k, 180k, 320k, 360k, 720k, 1.2M, 1.44M, 1.68M, 1.72M, or 2.88M.
 [1.44M]
```

##### 1.2.4 名称

```shell
========================================================================
                                bximage
  Disk Image Creation / Conversion / Resize and Commit Tool for Bochs
         $Id: bximage.cc 14091 2021-01-30 17:37:42Z sshwarts $
========================================================================

1. Create new floppy or hard disk image
2. Convert hard disk image to other format (mode)
3. Resize hard disk image
4. Commit 'undoable' redolog to base image
5. Disk image info

0. Quit

Please choose one [0] 1

Create image

Do you want to create a floppy disk image or a hard disk image?
Please type hd or fd. [hd] fd

Choose the size of floppy disk image to create.
Please type 160k, 180k, 320k, 360k, 720k, 1.2M, 1.44M, 1.68M, 1.72M, or 2.88M.
 [1.44M]

What should be the name of the image?
[a.img] boot.img
```

#### 1.3 查看软盘

```shell
> bximage
========================================================================
                                bximage
  Disk Image Creation / Conversion / Resize and Commit Tool for Bochs
         $Id: bximage.cc 14091 2021-01-30 17:37:42Z sshwarts $
========================================================================

1. Create new floppy or hard disk image
2. Convert hard disk image to other format (mode)
3. Resize hard disk image
4. Commit 'undoable' redolog to base image
5. Disk image info

0. Quit

Please choose one [0] 5
```



```shell
========================================================================
                                bximage
  Disk Image Creation / Conversion / Resize and Commit Tool for Bochs
         $Id: bximage.cc 14091 2021-01-30 17:37:42Z sshwarts $
========================================================================

1. Create new floppy or hard disk image
2. Convert hard disk image to other format (mode)
3. Resize hard disk image
4. Commit 'undoable' redolog to base image
5. Disk image info

0. Quit

Please choose one [0] 5

Disk image info

What is the name of the image?
[c.img] boot.img
```



```shell
disk image mode = 'flat'
hd_size: 1474560
geometry = 2/16/63 (1 MB)
```

#### 1.4 写入软盘镜像

##### 1.4.1 bootsect程序

软盘第一扇区程序编写

##### 1.4.2 编译

nasm boot.asm -o boot.bin

##### 1.4.3 程序写入引导扇区

引导扇区需要放在bochs安装路径下

```shell
cp /Users/dingrui/Dev/code/mine/c/os/bios/boot.bin ./usr/local/Cellar/bochs/2.7/

dd if=boot.bin of=boot.img bs=512 count=1 conv=notrunc
```

#### 1.5 配置文件

/usr/local/Cellar/bochs/2.7/boshsrc

```shell
boot: floppy
floppya: 1_44="boot.img", status=inserted
floppy_bootsig_check: disabled=0

ata0: enabled=1, ioaddr1=0x1f0, ioaddr2=0x3f0, irq=14
ata0-master: type=none
ata0-slave: type=none
ata1: enabled=1, ioaddr1=0x170, ioaddr2=0x370, irq=15
ata1-master: type=none
ata1-slave: type=none
ata2: enabled=0
ata3: enabled=0


log: bochsout.txt

panic: action=ask
error: action=report
info: action=report
debug: action=ignore, pci=report # report BX_DEBUG from module 'pci'

debugger_log: -

parport1: enabled=1, file="parport.out"

#sound: driver=default, waveout=/dev/dsp. wavein=, midiout=
speaker: enabled=1, mode=sound, volume=15

display_library: sdl2
```

#### 1.6 启动

```shell
cd /usr/local/Cellar/bochs/2.7

bochs -f ./boshsrc
```

### 2 程序加载

操作系统程序也是源码，分为3批加载到计算机，加载的语义是，程序都在软盘上，要加载到计算机内存上，供CPU寻址。

| 程序   | 软盘位置 | 加载方     | 内存位置 | 功能职责              |
| ------ | -------- | ---------- | -------- | --------------------- |
| 第一批 | 扇区0    | BIOS程序   |          | 加载第二批\第三批程序 |
| 第二批 |          | 第一批程序 |          |                       |
| 第三批 |          | 第一批程序 |          |                       |

### 3 FAT12文件系统

[为1.44M软盘设计文件系统](./docs/FD.md)
