org 0x7c00 ; 实模式 20根总线 20位 程序的起始地址 段地址=CS<<4+IP
           ;             CS=0x0000
           ;             IP=0x7c00
           ;             段地址=0x07c00

BaseOfStack             equ 0x7c00 ;栈基
BaseOfLoader            equ 0x1000 ;段基地址
OffsetOfLoader          equ 0      ;BaseOfLoader<<4+OffsetOfLoader=0x10000 Loader程序的起始地址

RootDirSectors          equ 14     ;根目录占用扇区数
                                   ;=(BPB_RootEntCnt*32+BPB_BytesPerSec-1)/BPB_BytesPerSec
                                   ;=(224*32+512-1)/512=14
SectorNumOfRootDirStart equ 19     ;根目录的起始扇区号
                                   ;=BPB_RsvdSecCnt+BPB_FATSz16*BPB_NumFATAs
                                   ;=1+9*2=19
SectorNumOfFat1Start    equ 1      ;FAT1起始扇区号 在此之前扇区0已经加载好了
SectorBalance           equ 17     ;=起始扇区号-2

; 为虚拟软盘创建FAT12文件系统引导扇区数据
;                                         偏移 字节长度                  内容
    jmp short Label_Start                ; 0     2     偏移=Label_Start的偏移地址-cpu读完jmp之后的IP
    nop                                  ; 2     1     指令填充
    BS_OEMName      db 'MINEboot'        ; 3     8     生产厂商名
    BPB_BytesPerSec dw 512               ; 11    2     每扇区字节数
    BPB_SecPerClus  db 1                 ; 13    1     每簇扇区数
    BPB_RsvdSecCnt  dw 1                 ; 14    2     保留扇区数
    BPB_NumFATs     db 2                 ; 16    1     FAT表的份数
    BPB_RootEntCnt  dw 224               ; 17    2     根目录可容纳的目录项数
    BPB_TotSec16    dw 2880              ; 19    2     总扇区数
    BPB_Media       db 0xf0              ; 21    1     介质描述符
    BPB_FATSz16     dw 9                 ; 22    2     每FAT扇区数
    BPB_SecPerTrk   dw 18                ; 24    2     每磁道扇区数
    BPB_NumHeadds   dw 2                 ; 26    2     磁头数
    BPB_HiddSec     dd 0                 ; 28    4     隐藏扇区数
    BPB_TotSec32    dd 0                 ; 32    4     如果上面BPB_TotSec16为0就用这个值记录扇区数
    BS_DrvNum       db 0                 ; 36    1     int 0x13的驱动器号
    BS_Reserved1    db 0                 ; 37    1     未使用
    BS_BootSig      db 0x29              ; 38    1     扩展引导标记
    BS_VolID        dd 0                 ; 39    4     卷序列号
    BS_VolLab       db 'boot loader'     ; 43    11    卷标
    BS_FileSysType  db 'FAT12   '        ; 54    8     文件系统类型
                                         ; 62   448    引导代码\数据及其他信息
                                         ; 510   2     引导盘标识符

;                                        ; 偏移  长度[字节]         内容
;                                                         bootsect程序 软盘第1扇区
Label_Start:
    mov ax, cs                           ; 62      2      代码段寄存器=0x0000
    mov ds, ax                           ; 64      2      数据段寄存器=0x0000
    mov es, ax                           ; 66      2      附加段寄存器=0x0000
    mov ss, ax                           ; 68      2      堆栈段寄存器=0x0000
    mov sp, BaseOfStack                  ; 70      3      栈基=0x7c00

    ;                                                     指定范围滚动窗口实现清屏 滚动80行 25列
    mov ax, 0x0600                       ; 73      3      AH=0x06 中断的主功能号 上卷指定范围的窗口
    mov bx, 0x0700                       ; 76      3      BH=00000111 滚动后空出来的位置放入的属性
                                         ;                            bit7 0=字体不闪烁
                                         ;                            bit4-6 0=背景黑色
                                         ;                            bit3 0=字体亮度正常
                                         ;                            bit0-2 7=字体白色
    mov cx, 0                            ; 79      3      CH=0x00 要滚动的左上角 列号
                                         ;                CL=0x00 要滚动的左上角 行号
                                         ;                左上[0,0]
    mov dx, 0x184f                       ; 82      3      DH=0x18 要滚动的右下角 列号
                                         ;                DL=0x4f 要滚动的右下角 行号
                                         ;                右下[79,24]
    int 0x10                             ; 85      2      0x10中断

    ;                                                     重置游标在屏幕左上角
    mov ax, 0x0200                       ; 88      3      AH=0x02 中断的主功能号 设置屏幕光标位置
    mov bx, 0                            ; 91      3      BH=页码
    mov dx, 0                            ; 94      3      DH=游标的列 DL=游标的行 游标坐标[0,0]
    int 0x10                             ; 97      2      0x10中断

    ;                                                     屏幕上显示信息
    mov ax, 0x1301                       ; 99      3      AH=0x13 中断的主功能号 显式字符串
                                         ;                AL=0x01 光标移动至字符串尾位置
    mov bx, 0x000f                       ; 102     3      BH=0x00
                                         ;                BL=0x0f 字符属性\颜色属性 0000 1111
                                         ;                                                  bit0-2 字体颜色 3=青色
                                         ;                                                  bit3 字体亮度 1=字体高亮度
                                         ;                                                  bit4-6 背景颜色 0=黑色
                                         ;                                                  bit7 字体闪烁 0=字体闪烁
    mov dx, 0                            ; 105     3      DH=0x00 游标的行号 DL=0x00 游标的列号 游标坐标[0,0]
    mov cx, 16                           ; 108     3      要显示的字符串长度
    push ax                              ; 111     1
    mov ax, ds                           ; 112     2
    mov es, ax                           ; 113     2
    pop ax                               ; 115     1
    mov bp, StartBootMessage             ; 116     3      ES:BP 字符串的内存地址
    int 0x10                             ; 119     2      0x10中断

    ;                                                     复位软盘
    xor ah, ah                           ; 121     2      AH=0 0x13中断 AH=0x00 重置软盘驱动器 为下一次读写软盘做准备
    xor dl, dl                           ; 123     2      DL=0 驱动器号 DL=0x00代表第一个软盘驱动器 driverA:
                                         ;                0x00-0x7f 软盘
                                         ;                0x80-0xff 硬盘
    int 0x13                             ; 125     2      0x13中断

    jmp $                                ; 127     2      loop

StartBootMessage: db "Hello Dingrui..."  ;                定义字符串

    ;                                                     扇区填充
    times 512-2-($-$$) db 0              ; 129     4      BIOS加载第一扇区的512Byte内容
                                         ;                最后2byte分别是 0xaa和0x55
                                         ;                那么整个第一扇区bootsect程序就是510Byte
                                         ;                [129...509]被填充0
    dw 0xaa55                            ; 510     2      0xaa和0x55两个标识byte

