; BIOS Parameter Block参数块
; 是FAT12/FAT16/FAT32磁盘引导扇区里的一个结构 描述了磁盘的基本几何参数和文件系统信息
; BIOS把第一个扇区读到0x7c00后 如果BPB格式正确 操作系统就能识别这是一个FAT格式磁盘
; 位置要求
; 在偏移0x03~0x3D之间 紧跟在jmp和nop后面
; 长度固定

; 编译期常量替换
RootDirSectors equ 14 ; 根目录有多少个扇区
; 根目录起始扇区号 0-based 2个fat表每个表占9个扇区+保留1个扇区不用=19个扇区 也就是[0...18] 那么根目录的第一个扇区是19#
SectorNumOfRootDirStart equ 19
SectorNumOfFAT1Start equ 1 ; fat1表起扇区号 0-based
SectorBalance equ 17

; BPB 必须从引导扇区的0x03偏移开始
BS_OEMName db 'MINEBOOT' ; 占8字节 OEM名称字符串不足补空格
BPB_BytesPerSec dw 512 ; 占2字节 每个扇区字节数 一般是512
BPB_SecPerClus db 1 ; 占1字节 每簇包含的扇区数
BPB_RsvdSecCnt dw 1 ; 占2字节 保留不用的扇区数 通常是1表示引导扇区这个扇区本身
BPB_NumFATs db 2 ; 占1字节 fat表有几个
BPB_RootEntCnt dw 224 ; 占2字节 根目录区目录项最多有多少个 1.44M的软盘是224个
BPB_TotSec16 dw 2880 ; 占2字节 扇区数总共有多少个
BPB_Media db 0xf0 ; 占1字节 介质描述符 0xf0表示1.44M软盘
BPB_FATSz16 dw 9 ; 占2字节 fat表占用多少个扇区 1.44M软盘的fat表占用9个扇区
BPB_SecPerTrk dw 18 ; 占2字节 每个磁道有多少个扇区
BPB_NumHeads dw 2 ; 占2字节 磁头数
BPB_hiddSec dd 0 ; 占4字节 隐藏磁头数 非分区启动时是0
BPB_TotSec32 dd 0 ; 占4字节 如果BPB_TotSec16=0这个字段就用来存放总扇区数
BS_DrvNum db 0 ; 占1字节 逻辑驱动器号 0表示软盘 0x80表示硬盘
BS_Reserved1 db 0 ; 占1字节 保留字段 必须是0
BS_BootSig db 0x29 ; 占1字节 扩展引导标识符 0x29表示以下字段存在
BS_VolID dd 0 ; 占4字节 卷序列号 一般用随机数/时间戳生成
BS_VolLab db 'BOOT LOADER' ; 占11字节 卷标 11字节字符串不足补空格
BS_FileSysType db 'FAT12   ' ; 占8字节 文件系统类型 固定值