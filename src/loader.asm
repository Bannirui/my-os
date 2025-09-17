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


; 字符串
StartLoaderMessage:
    db "START LOADER"