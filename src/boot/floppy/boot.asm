; BIOS引导程序 放在磁盘引导扇区被加载
org 0x7c00

BaseOfStack equ 0x7c00

; loader程序物理地址 0x1000:0
BaseOfLoader equ 0x1000
OffsetOfLoader equ 0

; 在FAT12引导扇区开头 必须是EB xx 90 EB是jmp指令保证跳过fat12的BPB直接执行代码 90中nop负责占位保证3字节固定格式
jmp L_Start
nop

%include "fat12.inc" ; 这里面是fat12的BPB 必须在引导扇区的偏移3上紧跟着jmp和nop

L_Start:
; 标准设置寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, BaseOfStack
; 清屏
    mov ax, 0x0600
    mov bx, 0x0700
    mov cx, 0
    mov dx, 0x184f
    int 0x10
; 光标设置
    mov ax, 0x0200
    xor bx, bx
    xor dx, dx
    int 0x10
; 打印调试
    mov ax, 0x1301
    mov bx, 0x000f
    xor dx, dx
    mov cx, 0x10
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartBootMessage
    int 0x10
; 重置软驱
    xor ah, ah
    xor dl, dl
    int 0x13
; 通过文件系统读软盘里面的loader程序
    mov word [SectorNo], SectorNumOfRootDirStart
Lable_Search_In_Root_Dir_Begin:
    cmp word [RootDirSizeForLoop], 0
    jz Label_No_LoaderBin
    dec word [RootDirSizeForLoop]
    xor ax, ax
    mov es, ax
    mov bx, 0x8000
    mov ax, [SectorNo]
    mov cl, 1
    call Func_ReadOneSector ; near call
    mov si, LoaderFileName
    mov di, 0x8000
    cld
    mov dx, 0x10
Label_Search_For_LoaderBin:
    cmp dx, 0
    jz Label_Goto_Next_Sector_In_Root_Dir
    dec dx
    mov cx, 11
Label_Cmp_FileName:
    cmp cx, 0
    jz Label_FileName_Found
    dec cx
    lodsb
    cmp al, byte [es:di]
    jz Label_Go_On
    jmp Label_Different
Label_Go_On:
    inc di
    jmp Label_Cmp_FileName
Label_Different:
    and di, 0xffe0
    add di, 0x20
    mov si, LoaderFileName
    jmp Label_Search_For_LoaderBin
Label_Goto_Next_Sector_In_Root_Dir:
    add word [SectorNo], 1
    jmp Lable_Search_In_Root_Dir_Begin

; 找不到loader程序
Label_No_LoaderBin:
    mov ax, 0x1301
    mov bx, 0x008c
    mov dx, 0x0100
    mov cx, 21
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, NoLoaderMessage
    int 0x10
    jmp $
Label_FileName_Found:
    mov ax, RootDirSectors
    and di, 0xffe0
    add di, 0x001a
    mov cx, word [es:di]
    push cx
    add cx, ax
    add cx, SectorBalance
    mov ax, BaseOfLoader
    mov es, ax
    mov bx, OffsetOfLoader
    mov ax, cx
Label_Go_On_Loading_File:
    push ax
    push bx
    mov ah, 0x0e
    mov al, '.'
    mov bl, 0x0f
    int 0x10
    pop bx
    pop ax
    mov cl, 1
    call Func_ReadOneSector
    pop ax
    call Func_GetFATEntry
    cmp ax, 0x0fff
    jz Label_File_Loaded
    push ax
    mov dx, RootDirSectors
    add ax, dx
    add ax, SectorBalance
    add bx, [BPB_BytesPerSec]
    jmp Label_Go_On_Loading_File

Label_File_Loaded:
    jmp BaseOfLoader:OffsetOfLoader

Func_ReadOneSector:
    push bp
    mov bp, sp
    sub esp, 2
    mov byte [bp - 2], cl
    push bx
    mov bl, [BPB_SecPerTrk]
    div bl
    inc ah
    mov cl, ah
    mov dh, al
    shr al, 1
    mov ch, al
    and dh, 1
    pop bx
    mov dl, [BS_DrvNum]
Label_Go_On_Reading:
    mov ah, 2
    mov al, byte [bp - 2]
    int 0x13
    jc Label_Go_On_Reading
    add esp, 2
    pop bp
    ret

; fat表项占12bit 每3个字节存储2个fat表项 fat表项具有奇偶性 根据当前fat表项索引出下一个fat表项
Func_GetFATEntry:
    push es
    push bx
    push ax
    xor ax, ax
    mov es, ax
    pop ax
    mov byte [Odd], 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    cmp dx, 0
    jz Label_Even
    mov byte [Odd], 1
Label_Even:
    xor dx, dx
    mov bx, [BPB_BytesPerSec]
    div bx
    push dx
    mov bx, 0x8000
    add ax, SectorNumOfFAT1Start
    mov cl, 2
    call Func_ReadOneSector ; near call
    pop dx
    add bx, dx
    mov ax, [es:bx]
    cmp byte [Odd], 1
    jnz Label_Even_2
    shr ax, 4
Label_Even_2:
    and ax, 0x0fff
    pop bx
    pop es
    ret

; 临时变量
RootDirSizeForLoop dw RootDirSectors
SectorNo dw 0
Odd db 0

; 字符串
StartBootMessage:
    db "START BOOT"
NoLoaderMessage:
    db "ERROR:No LOADER Found"
LoaderFileName:
    db "LOADER  BIN", 0

; 启动盘引导扇区
    times 510-($-$$) db 0
    dw 0xaa55