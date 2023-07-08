## MAC平台

### 1 Bochs

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

到bochs的安装路径下执行/usr/local/Cellar/bochs/2.7

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

#### 1.4 boot写入软盘镜像

##### 1.4.1 bootsect程序

软盘第一扇区程序编写

##### 1.4.2 编译

```shell
nasm boot.asm -o boot.bin
```

##### 1.4.3 程序写入引导扇区

引导扇区需要放在bochs安装路径下

```shell
cp /Users/dingrui/Dev/code/mine/c/my-os/boot/boot.bin /usr/local/Cellar/bochs/2.7/

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

### 2 loader程序写入软盘

此时在boot程序中为软盘创建了FAT12文件系统，目的就是用来加载boot之后的程序，即在此之后的程序文件可以依赖系统的目录挂载到虚拟软盘，然后直接将文件复制到挂载点即可。

#### 2.1 loader程序编写

```asm
; loader程序
; boot sector程序读取到该程序 将内容放在了内存0x1000:0x0000上
; 因此这段程序的起始地址就是0x10000

org 0x10000

    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, 0x00
    mov ss, ax
    mov sp, 0x7c00

; 临时变量
StartLoaderMessage: db "loader running"

; @bref 利用BIOS中断打印字符串
;       屏幕上显示提示信息
;       int 0x10 AH=0x13 显示一行字符串
;                        AL=写入模式
;                           Al=0x00 字符串属性由BL寄存器控制 字符串长度由CX寄存器控制(以Byte为单位) 光标位置不变(即写入前光标在哪写入后还在哪)
;                           Al=0x01 字符串属性由BL寄存器控制 字符串长度由CX寄存器控制(以Byte为单位) 写入后光标在字符串尾端位置
;                           Al=0x02 字符串属性由每个字符后面紧跟的字节提供 字符串长度由CX寄存器控制(以Word为单位) 光标位置不变(即写入前光标在哪写入后还在哪)
;                           Al=0x03 字符串属性由每个字符后面紧跟的字节提供 字符串长度由CX寄存器控制(以Word为单位) 写入后光标在字符串尾端位置
;                        CX=字符串长度
;                        DH=游标的坐标行号(从0计)
;                        DL=游标的坐标列号(从0计)
;                        ES:BP=要显示字符串的内存地址
;                        BH=页码
;                        BL=字符串属性
;                           BL[7]     字体闪烁 0=不闪烁 1=闪烁
;                           BL[4...6] 背景颜色 0=黑色 1=蓝色 2=绿色 3=青色 4=红色 5=紫色 6=棕色 7=白色
;                           BL[3]     字体亮度 0=字体正常 1=字体高量
;                           BL[0...2] 字体颜色 0=黑色 1=蓝色 2=绿色 3=青色 4=红色 5=紫色 6=棕色 7=白色
Label_Start:
    mov ax, 0x1301
    mov cx, 14
    mov dx, 0x0200
    mov bx, 0x0000
    push ax

    mov ax, ds
    mov es, ax
    mov bp, StartLoaderMessage

    pop ax
    int 0x10
    jmp $
```

代码很简单，就是打印字符串验证boot中FAT12文件系统工作正常，并且CPU执行程序切换正常。

#### 2.2 编译loader

```shell
nasm loader.asm -o loader.bin
```

#### 2.3 挂载目录

指定一个挂载点挂载到虚拟软盘

```shell
cd /usr/local/Cellar/bochs/2.7

mkdir -p mnt/floppy

> mount -t vfat -o loop boot.img mnt/floppy
mount: exec /Library/Filesystems/vfat.fs/Contents/Resources/mount_vfat for /usr/local/Cellar/bochs/2.7/mnt/floppy: No such file or directory
mount: /usr/local/Cellar/bochs/2.7/mnt/floppy failed with 72
```

执行挂载命令的时候报错，很明显挂载点/mnt/floppy是存在的，因此推断报错的原因是`exec /Library/Filesystems/vfat.fs/Contents/Resources/mount_vfat`，这个命令应该是通过mount指定的-t参数，推断具体执行程序，但是我当前平台不存在这个可执行程序，也就是说我的mac上不存在对fat文件系统类型的支持

至此，可以得到的信息可能是

* 我的MAC平台上缺少mount工具链的完整支持
* MAC系统对FAT12缺少支持或者不支持

那么应对的方案也就是

* 完善当前MAC平台对mount工具链的支持
* 寻找mount命令的替代方案
* 更换到别的系统平台，能够直接支持mount指令的