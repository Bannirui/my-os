RootDirSectors equ 14 ; 根目录扇区数
SectorNumOfRootDirStart equ 19 ; 根目录起始扇区号 0-based
SectorNumOfFAT1Start equ 1 ; fat1表起扇区号 0-based
SectorBalance equ 17

BS_OEMName db 'MINEBOOT'
BPB_BytesPerSec dw 512
BPB_SecPerClus db 1
BPB_RsvdSecCnt dw 1
BPB_NumFATs db 2
BPB_RootEntCnt dw 224
BPB_TotSec16 dw 2880
BPB_Media db 0xf0
BPB_FATSz16 dw 9
BPB_SecPerTrk dw 18
BPB_NumHeads dw 2
BPB_hiddSec dd 0
BPB_TotSec32 dd 0
BS_DrvNum db 0
BS_Reserved1 db 0
BS_BootSig db 0x29
BS_VolID dd 0
BS_VolLab db 'BOOT LOADER'
BS_FileSysType db 'FAT12   '