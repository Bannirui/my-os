; loader程序
; boot sector程序读取到该程序 将内容放在了内存0x1000:0x0000上
; 因此这段程序的起始地址就是0x10000(=0x1000<<4+0x0000)
org 0x10000

jmp Label_start

%include "fat12.inc"

; 临时变量
BaseOfKernelFile equ 0x0000
OffsetOfKernelFile equ 0x100000

BaseOfTmpKernelFile equ 0x0000
OffsetOfTmpKernelFile equ 0x7e00

MemoryStructBufferAddr equ 0x7e00

[SECTION GDT_32]
Label_gdt_32:
    dd 0,0

Label_desc_code_32:
    dd 0x0000ffff, 0x00cf9a00

Label_desc_data_32:
    dd 0x0000ffff, 0x00cf9200

GDT_32_Len equ $ - Label_gdt_32
GDT_32_Ptr dw GDT_32_Len - 1
dd Label_gdt_32

SELECTOR_CODE_32 equ Label_desc_code_32 - Label_gdt_32
SELECTOR_DATA_32 equ Label_desc_data_32 - Label_gdt_32

[SECTION GDT_64]
Label_gdt_64:
    dq 0x0000000000000000

Label_desc_code_64:
    dq 0x0020980000000000

Label_desc_data_64:
    dq 0x0000920000000000

GDT_LEN_64 equ $ - Label_gdt_64
GDT_Ptr_64 dw GDT_LEN_64-1
dd Label_gdt_64

SELECTOR_CODE_64 equ Label_desc_code_64 - Label_gdt_64
SELECTOR_DATA_64 equ Label_desc_data_64 - Label_gdt_64

[SECTION .s16]
[BITS 16]

; @brief 段寄存器设置
Label_start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, 0x00
    mov ss, ax
    mov sp, 0x7c00

; 临时变量
;StartLoaderMessage:
;    db "LOADER running"

; @brief 利用BIOS中断打印字符串
;        屏幕上显示提示信息
;        int 0x10 AH=0x13 显示一行字符串
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
    mov ax, 0x1301
    mov cx, 14
    mov dx, 0x0200
    mov bx, 0x000f
    push ax

    mov ax, ds
    mov es, ax
    pop ax
    mov bp, start_loader_message

    int 0x10

; @brief 打开A20地址线
Label_open_a20:
    push ax
    in al, 0x92
    or al, 0x02
    out 0x92, al
    pop ax

    cli

    db 0x66
    lgdt [GDT_32_Ptr]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    mov ax, SELECTOR_DATA_32
    mov fs, ax
    mov eax, cr0
    and al, 0xfe
    mov cr0, eax

    sti

; @brief 重置软盘 为读取做准备
Label_floppy_reset:
    xor ah, ah
    xor dl, dl
    int 0x13

; @brief 从FAT12文件系统中加载kernel程序



; 定义变量
section .data
sector_no dw 0 ;FAT12文件系统中检索的扇区 初始化为0 轮询根目录扇区[19...32]
start_loader_message db 'LOADER running' ; loader程序启动的欢迎界面
root_dir_size_for_loop dw RootDirSectors
kernel_file_name db "KERNEL BIN"
