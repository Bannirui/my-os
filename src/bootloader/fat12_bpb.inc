; FAT12文件系统的引导扇区不仅包含引导程序 还包含FAT12文件系统的整个组成结构信息
; 什么是BPB(BIOS Parameter Bloc参数块)
; FAT12 FAT16 FAT32磁盘引导扇区里面的一个结构 描述了磁盘的基本几何参数和文件系统信息
; BIOS把一个扇区读到0x7c00后 如果BPB格式正确 操作系统就能识别出来这是一个FAT文件系统
; 第一个字段BS_jmpBoot是一个占3字节的跳转指令 在BS_jmpBoot字段后面的数据不是可执行程序 而是FAT12文件系统的组成结构 所以要跳过这个部分
; 跳转指令一定占3字节 jmp short label跳转指令编译后只占3字节 那么就插入一个nop占位1个字节

; fat12文件系统的扇区分配
;扇区号0-based            用途                       说明
;----------------------------------------------------------------
;0                    Boot Sector (BPB)           引导扇区 + BIOS 参数区
;1 .. 9               FAT #1 (9 sectors)          FAT表副本1
;10 .. 18             FAT #2 (9 sectors)          FAT表副本2
;19 .. 32             Root Directory (14 sectors) 根目录区（固定条目数）
;33 .. 2879           Data Area (clusters)        数据区：簇从 2 开始

; 把用到的常量单独放在一个文件了
%include "fat12_const.inc"

; 下面是FAT12文件系统引导扇区结构 除了第1个字段之外的所有字段
; 占8字节
; 制造商的名字 随便命名
BS_OEMName db 'MINEBOOT'
; 占2字节
; 每个扇区的字节数
BPB_BytesPerSec_SLOT dw BPB_BytesPerSec
; 占1字节
; 每个簇包含多少个扇区
; 由于每个扇区只有512字节大小 过小的扇区容量可能会导致软盘读写次数过于频繁 从而引入了簇 将2的整数次方个扇区作为一个簇 簇是FAT类文件系统的最小存储单位
BPB_SecPerClus_SLOT db BPB_SecPerClus
; 占2字节
; 保留扇区数 这个字段的值不能是0 保留扇区起始于FAT12文件系统的第1个扇区 对于FAT12系统而言必须是1 也就是说引导扇区包含在保留扇区里面 所以FAT表是从软盘的第2个扇区开始的
BPB_RsvdSecCnt_SLOT dw BPB_RsvdSecCnt
; 占1字节
; FAT表的份数
; 任何FAT类文件系统都建议这个字段设置为2 主是要给FAT表准备了一个备份表 因此FAT1表和FAT2表内的数据是一样的 FAT表2是表1的数据备份
BPB_NumFATs_SLOT db BPB_NumFATs
; 占2字节
; 根目录可容纳的目录项数 对于FAT12文件系统而言 这个值乘以32必须是BPB_BytesPerSec的偶数倍
BPB_RootEntCnt_SLOT dw BPB_RootEntCnt
; 占2字节
; 总扇区数 这里的总扇区数包括保留扇区也就是引导山区+FAT表+目录区+数据区 如果这个字段是0 那就用BPB_TotSec32字段记录总共多少个扇区
BPB_TotSec16_SLOT dw BPB_TotSec16
; 占1字节
; 介质描述符 不可移动介质标准值是0xF8 可移动介质标准值是0xF0
BPB_Media_SLOT db BPB_Media
; 占2字节
; 每个FAT表的扇区数
BPB_FATSz16_SLOT dw BPB_FATSz16
; 占2字节
; 每个磁道扇区数
BPB_SecPerTrk_SLOT dw BPB_SecPerTrk
; 占2字节
; 磁头数
BPB_NumHeads_SLOT dw BPB_NumHeads
; 占4字节
; 隐藏扇区数
BPB_hiddSec_SLOT dd BPB_hiddSec
; 占4字节
; 如果BPB_TotSec16值是0 就用这个字段记录总共有多少个扇区
BPB_TotSec32_SLOT dd BPB_TotSec32
; 占1字节
; int 0x13的驱动器号
BS_DrvNum_SLOT db BS_DrvNum
; 占1字节
; 未使用
BS_Reserved1_SLOT db BS_Reserved1
; 占1字节
; 扩展引导标记 0x29表示下面的字段启用了
BS_BootSig_SLOT db BS_BootSig
; 占4字节
; 卷序列号
BS_VolID_SLOT dd BS_VolID
; 占11字节
; 卷标
BS_VolLab db 'BOOT LOADER'
; 占8字节
; 文件系统类型 必须满8个字节 不足的自己用空格
BS_FileSysType db 'FAT12   '
