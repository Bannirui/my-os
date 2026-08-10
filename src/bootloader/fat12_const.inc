; fat12文件系统的常量定义 equ only 不产生数据字节

; (a+b-1)/b是经典的a/b向上取整方法
; 根目录区每个目录项32字节 224个目录项
; 每个扇区512字节 需要的扇区数量=(32*224)/512=(32*224+512-1)/512=14
RootDirSectors equ 14

; 根目录起始扇区号 0-based
; FAT12规定1个保留扇区+2个fat表每个表占9个扇区=19个扇区
; 也就是说根目录前面有19个扇区 那么根目录的扇区编号就是从19开始
SectorNumOfRootDirStart equ 19

; fat1表起扇区号 0-based FAT12规定有1个保留扇区 也就是说是在FAT表1前面有1个扇区 那么它就从1开始编号
SectorNumOfFAT1Start equ 1

; 用来辅助计算数据区的扇区号
; 在FAT表中的数组标号就是簇号 0-based 规定0号脚标上的值是0x0FF0表示坏簇的标记 1号脚标上的值是0x0FFF是结尾标记
; 所以数据区(根目录区和数据区都算数据区)的簇号是从2号开始的
; 根目录前面的扇区有 FAT12的1个保留扇区+FAT1的9个扇区+FAT2的9个扇区 根目录的扇区号是从19号开始的
; 所以已知簇号=x 那么扇区号=x+17
SectorBalance equ 17

; BPB字段值
; 每个扇区多少个字节
BPB_BytesPerSec equ 512
; 1个簇包含多少个扇区
BPB_SecPerClus equ 1
; 保留扇区数量 也就是FAT12文件系统保留不用的扇区
BPB_RsvdSecCnt equ 1
; 几个FAT表
BPB_NumFATs equ 2
; 根目录区有多少个目录项
BPB_RootEntCnt equ 224
; 整个文件系统有多少个扇区 这个字段和BPB_TotSec32属于是二选一 这边填了那边就填0 这边0那边就得填正确的扇区总数
BPB_TotSec16 equ 2880
; 存储介质类型 不可移动的存储介质类型标准值是0xF8 可移动的存储介质标准值是0xF0
BPB_Media equ 0xf0
; FAT表占几个扇区
BPB_FATSz16 equ 9
; 每个磁道有几个扇区
BPB_SecPerTrk equ 18
; 磁头数量
BPB_NumHeads equ 2
; 隐藏磁头数 非分区启动时是0
BPB_hiddSec equ 0
; 跟上面的BPB_TotSec16二选一填就行
BPB_TotSec32 equ 0
; 逻辑驱动器号 0表示软盘 0x80表示硬盘
BS_DrvNum equ 0
; 保留字段 必须填0
BS_Reserved1 equ 0
; 扩展引导 0x29表示以下字段存在
BS_BootSig equ 0x29
; 卷序列号 一般用随机数或者时间戳生成
BS_VolID equ 0