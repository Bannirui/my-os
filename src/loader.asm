; loader负责 硬件检测 cpu模式切换 向内核传递数据
org 10000h
jmp Label_Start

%include "fat12.inc"

BaseOfKernelFile equ 0x00
OffsetOfKernelFile equ 0x100000

BaseTmpOfKernelAddr equ 0x9000
OffsetTmpOfKernelFile equ 0x0000

MemoryStructBufferAddr equ 0x7E00

[SECTION gdt]
LABEL_GDT:
    dd 0,0
LABEL_DESC_CODE32:
    dd 0x0000FFFF,0x00CF9A00
LABEL_DESC_DATA32:
    dd 0x0000FFFF,0x00CF9200
GdtLen equ $-LABEL_GDT
GdtPtr dw GdtLen-1
dd LABEL_GDT
SelectorCode32 equ LABEL_DESC_CODE32-LABEL_GDT
SelectorData32 equ LABEL_DESC_DATA32-LABEL_GDT

[SECTION .s16]
[BITS 16] ; 代码跑在16位实模式下
Label_Start:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax ; 10000:0000
    xor sp, sp

	mov ax, 0xB800 ; 用显存打印字符串
	mov gs, ax

; 打印字符串调试
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0200
    mov cx, 12
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartLoaderMessage
    int 0x10

; 打开a20地址线 寻址空间从1M突破到4G
    push ax
    in al, 0x92
    or al, 0x02
    out 0x92, al
    pop ax
    cli
    db 0x66
    lgdt [GdtPtr]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    mov ax, SelectorData32
    mov fs, ax
    mov eax, cr0
    and al, 0xfe
    mov cr0, eax

    sti

; 重置软驱
    xor ah, ah
    xor dl, dl
    int 0x13

; 软盘加载kernel程序到内存
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
    call Func_ReadOneSector
    mov si, KernelFileName
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
    and di, 0xFFE0
    add di, 0x20
    mov si, KernelFileName
    jmp Label_Search_For_LoaderBin
Label_Goto_Next_Sector_In_Root_Dir:
    add word [SectorNo], 1
    jmp Lable_Search_In_Root_Dir_Begin
Label_No_LoaderBin:
    mov ax, 0x1301
    mov bx, 0x008C
    mov dx, 0x0300 ; 第3行
    mov cx, 21
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, NoLoaderMessage
    int 0x10
    jmp $
Label_FileName_Found:
    jmp $

[SECTION .s16lib]
[BITS 16] ; 跑在cpu 16位模式下
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
    mov al, byte [bp-2]
    int 0x13
    jc Label_Go_On_Reading
    add esp, 2
    pop bp
    ret
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
    call Func_ReadOneSector
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
StartLoaderMessage:
    db "START LOADER"
NoLoaderMessage:
    db "ERROR:No KERNEL Found"
KernelFileName:
    db "KERNEL  BIN",0