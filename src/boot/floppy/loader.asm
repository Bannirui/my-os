; loader负责 硬件检测 cpu模式切换 向内核传递数据
org 0x10000
jmp Label_Start

%include "fat12.inc"

BaseOfKernelFile equ 0
OffsetOfKernelFile equ 0x100000 ; 内核代码放在物理地址0x100_000上

BaseTmpOfKernelAddr equ 0x9000
OffsetTmpOfKernelFile equ 0

MemoryStructBufferAddr equ 0x7e00

[SECTION gdt]
LABEL_GDT:
    dd 0, 0
LABEL_DESC_CODE32:
    dd 0x0000ffff, 0x00cf9a00
LABEL_DESC_DATA32:
    dd 0x0000ffff, 0x00cf9200
GdtLen equ $-LABEL_GDT
GdtPtr dw GdtLen-1
       dd LABEL_GDT
SelectorCode32 equ LABEL_DESC_CODE32-LABEL_GDT
SelectorData32 equ LABEL_DESC_DATA32-LABEL_GDT

[SECTION gdt64]
LABEL_GDT64:
    dq 0
LABEL_DESC_CODE64:
    dq 0x0020980000000000
LABEL_DESC_DATA64:
    dq 0x0000920000000000
GdtLen64 equ $-LABEL_GDT64
GdtPtr64 dw GdtLen64-1
         dd LABEL_GDT64
SelectorCode64 equ LABEL_DESC_CODE64-LABEL_GDT64
SelectorData64 equ LABEL_DESC_DATA64-LABEL_GDT64


[SECTION .s16]
[BITS 16] ; 代码跑在16位实模式下
Label_Start:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax ; 10000:0000
    xor sp, sp

	mov ax, 0xb800 ; 用显存打印字符串
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

; kernel代码读到物理内存上
Label_FileName_Found:
    mov ax, RootDirSectors
    and di, 0xffe0
    add di, 0x001a
    mov cx, word [es:di]
    push cx
    add cx, ax
    add cx, SectorBalance
    mov eax, BaseTmpOfKernelAddr
    mov es, eax
    mov bx, OffsetTmpOfKernelFile
    mov ax, cx
Label_Go_On_Loading_File:
    push ax
    push bx
    mov	ah, 0x0e
    mov al, '.'
    mov bl, 0x0f
    int 10h
    pop bx
    pop ax

    mov cl, 1
    call Func_ReadOneSector
    pop ax

    push cx
    push eax
    push fs
    push edi
    push ds
    push esi

    mov cx, 0x200
    mov ax, BaseOfKernelFile
    mov fs, ax
    mov edi, dword [OffsetOfKernelFileCount]

    mov ax, BaseTmpOfKernelAddr
    mov ds, ax
    mov esi, OffsetTmpOfKernelFile
Label_Mov_Kernel:
    mov al, byte [ds:esi]
    mov byte [fs:edi], al

    inc esi
    inc edi

    loop Label_Mov_Kernel

    mov eax, 0x1000
    mov ds,	eax

    mov dword [OffsetOfKernelFileCount], edi

    pop esi
    pop ds
    pop edi
    pop fs
    pop eax
    pop cx

    call Func_GetFATEntry
    cmp ax, 0x0fff
    jz Label_File_Loaded
    push ax
    mov dx, RootDirSectors
    add ax, dx
    add ax, SectorBalance

    jmp Label_Go_On_Loading_File

; 打印调试
Label_File_Loaded:
    mov ax, 0xb800
    mov gs, ax
    mov ah, 0x0f ; 0000黑底 1111白字
    mov al, 'G'
    mov [gs:((80*0+39)*2)], ax ; 屏幕第0行 第39列。

; kernel程序被加载到了内存 软驱的使命完成了 后面不需要使用软驱了 可以关闭软驱
KillMotor:
    push dx
    mov dx, 0x03f2
    mov al, 0
    out dx, al
    pop dx

; 内核程序不需要再借助内存临时转存了 这块临时转存空间用来记录物理地址空间信息
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0400 ;row 4
    mov cx, 24
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartGetMemStructMessage
    int 0x10

    xor ebx, ebx
    xor ax, ax
    mov es, ax
    mov di, MemoryStructBufferAddr
Label_Get_Mem_Struct:
    mov eax, 0x0e820
    mov ecx, 20
    mov edx, 0x534d4150
    int 0x15
    jc Label_Get_Mem_Fail
    add di, 20

    cmp ebx, 0
    jne Label_Get_Mem_Struct
    jmp Label_Get_Mem_OK
Label_Get_Mem_Fail:
    mov ax, 0x1301
    mov bx, 0x008c
    mov dx, 0x0500 ;row 5
    mov cx, 23
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, GetMemStructErrMessage
    int 0x10
    jmp $
Label_Get_Mem_OK:
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0600 ;row 6
    mov cx, 29
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, GetMemStructOKMessage
    int 0x10

; SVGA信息
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0800 ; row 8
    mov cx, 23
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartGetSVGAVBEInfoMessage
    int 0x10

    xor ax, ax
    mov es, ax
    mov di, 0x8000
    mov ax, 0x4f00
    int 0x10
    cmp ax, 0x004f
    jz .KO

; 获取SVGA失败
    mov ax, 0x1301
    mov bx, 0x008c
    mov dx, 0x0900 ; row 9
    mov cx, 23
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, GetSVGAVBEInfoErrMessage
    int 0x10
    jmp $

.KO:
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0a00 ; row 10
    mov cx, 29
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, GetSVGAVBEInfoOKMessage
    int 0x10

; SVGA模式
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0c00 ;row 12
    mov cx, 24
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartGetSVGAModeInfoMessage
    int 0x10

    xor ax, ax
    mov es, ax
    mov si, 0x800e

    mov esi, dword [es:si]
    mov edi, 0x8200
Label_SVGA_Mode_Info_Get:
    mov cx, word [es:esi]

; 打印SVGA模式
    push ax
    xor ax, ax
    mov al, ch
    call Label_DispAL

    xor ax, ax
    mov al, cl
    call Label_DispAL
    pop ax

    cmp cx, 0xffff
    jz Label_SVGA_Mode_Info_Finish

    mov ax, 0x4f01
    int 0x10

    cmp ax, 0x004f

    jnz Label_SVGA_Mode_Info_FAIL

    add esi, 2
    add edi, 0x100

    jmp Label_SVGA_Mode_Info_Get
Label_SVGA_Mode_Info_FAIL:
    mov ax, 0x1301
    mov bx, 0x008c
    mov dx, 0x0d00 ; row 13
    mov cx, 24
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, GetSVGAModeInfoErrMessage
    int 0x10
Label_SET_SVGA_Mode_VESA_VBE_FAIL:
    jmp $
Label_SVGA_Mode_Info_Finish:
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0e00 ; row 14
    mov cx, 30
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, GetSVGAModeInfoOKMessage
    int 0x10

; 设置SVGA模式
    mov ax, 0x4f02
    mov bx, 0x4180
    int 0x10

    cmp ax, 0x004f
    jnz	Label_SET_SVGA_Mode_VESA_VBE_FAIL

; 初始化IDT GDT进入保护模式
    cli ; 先关闭BIOS的中断
    db 0x66
    lgdt [GdtPtr]
    ; db 0x66
    ; lidt [LIDT_POINTER]
    mov eax, cr0
    or eax, 1
    mov	cr0, eax
    jmp dword SelectorCode32:GO_TO_TMP_Protect

[SECTION .s32]
[BITS 32] ; 代码跑在32位保护模式下
; 切换到IA-32e模式
GO_TO_TMP_Protect:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov esp, 0x7e00
    call support_long_mode
    test eax, eax
    jz no_support

; 配置页目录和页表
    mov dword [0x90000], 0x91007
    mov dword [0x90800], 0x91007
    mov dword [0x91000], 0x92007
    mov dword [0x92000], 0x000083
    mov dword [0x92008], 0x200083
    mov dword [0x92010], 0x400083
    mov dword [0x92018], 0x600083
    mov dword [0x92020], 0x800083
    mov dword [0x92028], 0xa00083
; 加载GDT
    db 0x66
    lgdt [GdtPtr64]
; 初始化段寄存器
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, 0x7e00
; 打开地址扩展
    mov eax, cr4
    bts eax, 5
    mov cr4, eax
; 页目录首地址设置到crc3寄存器
    mov eax, 0x90000
    mov cr3, eax
; 激活IA-32e长模式
    mov ecx, 0x0c0000080
    rdmsr
    bts eax, 8
    wrmsr
; 使能分页
    mov eax, cr0
    bts eax, 0
    bts eax, 31
    mov cr0, eax
; 从loader程序跳到kernel内核去
    jmp SelectorCode64:OffsetOfKernelFile

; 检测cpu支不支持ia-32e长模式
support_long_mode:
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    setnb al
    jb support_long_mode_done
    mov eax, 0x80000001
    cpuid
    bt edx, 29
    setc al
support_long_mode_done:
    movzx eax, al
    ret
; cpu不支持ia-32e长模式
no_support:
    jmp	$

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

; 打印调试
Label_DispAL:
    push ecx
    push edx
    push edi
    mov edi, [DisplayPosition]
    mov ah, 0x0f
    mov dl, al
    shr al, 4
    mov ecx, 2
.begin:
    and al, 0x0f
    cmp al, 9
    ja .1
    add al, '0'
    jmp .2
.1:
    sub al, 0x0a
    add al, 'A'
.2:
    mov [gs:edi], ax
    add edi, 2
    mov al, dl
    loop .begin
    mov [DisplayPosition], edi
    pop edi
    pop edx
    pop ecx
    ret

; IDT表
IDT:
    times 0x50 dq 0
IDT_END:

IDT_POINTER:
    dw IDT_END-IDT-1
    dd IDT

; 临时变量
RootDirSizeForLoop dw RootDirSectors
SectorNo dw 0
Odd db 0
OffsetOfKernelFileCount dd OffsetOfKernelFile
DisplayPosition dd 0

; 字符串
StartLoaderMessage:
    db "START LOADER"
NoLoaderMessage:
    db "ERROR:No KERNEL Found"
KernelFileName:
    db "KERNEL  BIN",0
StartGetMemStructMessage:
    db "Start Get Memory Struct."
GetMemStructErrMessage:
    db "Get Memory Struct ERROR"
GetMemStructOKMessage:
    db "Get Memory Struct SUCCESSFUL!"

StartGetSVGAVBEInfoMessage:
    db "Start Get SVGA VBE Info"
GetSVGAVBEInfoErrMessage:
    db "Get SVGA VBE Info ERROR"
GetSVGAVBEInfoOKMessage:
    db "Get SVGA VBE Info SUCCESSFUL!"

StartGetSVGAModeInfoMessage:
    db "Start Get SVGA Mode Info"
GetSVGAModeInfoErrMessage:
    db "Get SVGA Mode Info ERROR"
GetSVGAModeInfoOKMessage:
    db "Get SVGA Mode Info SUCCESSFUL!"