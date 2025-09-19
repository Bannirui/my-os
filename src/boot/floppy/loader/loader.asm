; loader负责 硬件检测 cpu模式切换 向内核传递数据
org 0x10000
    jmp Label_Start

%include "fat12.inc"

; 16位实模式下寻址方式 段寄存器<<4+偏移 0<<4+0x100000 把kernel程序要放到1M地址空间上去 将来内核程序的运行肯定是在平台模型线性地址空间的
BaseOfKernelFile equ 0
OffsetOfKernelFile equ 0x100000 ; 内核代码放在物理地址0x100_000上
; 16位实模式下还不能突破1M空间限制 从磁盘把内核程序加载到内存上不是一步到位放到1M地址空间 先在1M内空间暂存然后再复制过去
BaseTmpOfKernelAddr equ 0
OffsetTmpOfKernelFile equ 0x7e00

MemoryStructBufferAddr equ OffsetTmpOfKernelFile ; 放在这个地址上的内核程序被挪到1M地址上后 这块临时转存空间就没有用了 就用来记录物理地址空间信息

; 规划GDT表 这个表里面每一项是一个描述符 用来描述内存空间段的段描述符 每个描述符8字节 也就是GDT表每个表项8字节
; 剩下问题就是这个表可以规划放多少个表项 表是用来检索用的 将来靠着段选择子来检索表项 现在的cs寄存器就是将来的段选择子 CS的16位中高13位放index 那么index最大能表达的数组脚标就是(1<<13)-1=8191 也就说GDT表最多也就8192个表项
; 一般情况GDT表就定义代码段跟数据段就足够了 把它们定义成基址是0 界限是4G的 拉满整个平坦模型 后面用分页真正进行内存的隔离保护
; 32位下的GDT表段描述符
; 63                        56 55   52 51   48 47        40 39        32
;+----------------------------+-------+------+------------+------------+
;|       Base 31:24           | G AVL | D/B  | Limit19:16 | AccessByte |
;+----------------------------+-------+------+------------+------------+
;|        Base 23:16          |               Base 15:0                |
;+----------------------------+----------------------------------------+
;|                          Limit 15:0                                |
;+---------------------------------------------------------------------+
; 15                           8 7                                     0

[SECTION gdt]
LABEL_GDT: dd 0, 0 ; intel规范规定GDT表的第1个表项必须是0
LABEL_DESC_CODE32: dd 0x0000ffff, 0x00cf9a00 ; 代码段 基址0 界限4G
LABEL_DESC_DATA32: dd 0x0000ffff, 0x00cf9200 ; 数据段 基址0 界限4G
GdtLen equ $-LABEL_GDT ; GDT表的大小是多少个字节
; 要把GDT表的信息告诉寄存器 一个GDT表的元信息就两个 共6字节
; 2字节=GDT表的表长-1
; 4字节=GDT表的基地址
GdtPtr dw GdtLen-1
       dd LABEL_GDT
; 段选择子 高13位放GDT表的数组脚标 TI(0是GDT 1是LDT) RPL(ring0内核态 ring3用户态)
; ((((LABEL_DESC_CODE32-LABEL_GDT)/8) <<3) | (0<<2) | 0) ; 代码段的段选择子
SelectorCode32 equ LABEL_DESC_CODE32 - LABEL_GDT
; ((((LABEL_DESC_DATA32-LABEL_GDT)/8)<<3) | (0<<2) | 0) ; 数据段的段选择子
SelectorData32 equ LABEL_DESC_DATA32 - LABEL_GDT

; 64位下的GDT表段描述符
; 63                      56 55  52 51  48 47    40 39      32
;+-------------------------+------+------+--------+----------+
;|     Base 31:24          | GAVL | L  D | Limit |  Access  |
;+-------------------------+------+------+--------+----------+
;|           Base 23:16    |           Base 15:0             |
;+-------------------------+---------------------------------+
;|                      Limit 15:0                          |
;+----------------------------------------------------------+
; 15                       8 7                               0
; 64位已经没有了内存段的概念了 GDT表的段描述符退化成了权限/模式管理的门票
[SECTION gdt64]
LABEL_GDT64: dq 0 ; 跟32位GDT一样 第1个表项是0
LABEL_DESC_CODE64: dq 0x0020980000000000 ; 内核代码段
LABEL_DESC_DATA64: dq 0x0000920000000000 ; 内核数据段
GdtLen64 equ $-LABEL_GDT64
GdtPtr64 dw GdtLen64-1
         dd LABEL_GDT64
; 这种写法比上面的简洁太多 正确性的原因是 跑在内核态ring0低2位是0 GDT所以第3位是0 也就是说GDT描述符选择子的低3位是0 那么GDT表项目偏移/8就等于>>3得到的就是GDT表的索引 再左移3位拼上低3位的0就等同于偏移量
SelectorCode64 equ LABEL_DESC_CODE64-LABEL_GDT64
SelectorData64 equ LABEL_DESC_DATA64-LABEL_GDT64

[SECTION .s16]
[BITS 16] ; 代码跑在16位实模式下
Label_Start:
	mov ax, cs
	mov ds, ax
	mov es, ax
    xor ax, ax
    mov ss, ax
    mov sp, 0x7c00

; 打印字符串调试
    mov ax, 0x1301
    mov bx, 0x000f
    mov dh, StartLoaderMessageRow
    mov dl, 0
    mov cx, StartLoaderMessageLen
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartLoaderMessage
    int 0x10

; 打开a20地址线 寻址空间从1M突破到4G
    push ax
    in al, 0x92
    or al, 00000010b
	out 0x92, al
    pop ax
    cli ; 关闭BIOS的中断
    lgdt [GdtPtr] ; 3字节描述了GDT表的元信息 自此从寄存器gdtr就可以拿到GDT表的信息

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    mov ax, SelectorData32
    mov fs, ax ; fs指向数据段选择子
    mov eax, cr0
    and al, 11111110b
    mov cr0, eax
    sti ; 跟上面的cli成对使用 打开BIOS的中断

; 重置软驱
    xor ah, ah
    xor dl, dl
    int 0x13

; 软盘加载kernel程序到内存
    mov word [SectorNo], SectorNumOfRootDirStart

; fat12根目录共14个扇区 轮询查找
Lable_Search_In_Root_Dir_Begin:
    cmp word [RootDirSizeForLoop], 0
    jz Label_No_LoaderBin
    dec word [RootDirSizeForLoop]
    ; 准备读扇区数据到内存上的参数 从19扇区开始找读到0x8000上
    xor ax, ax
    mov es, ax ; es=0
    mov bx, 0x8000 ; bx=0x8000 把磁盘数据读到内存es:bx上
    mov ax, [SectorNo]
    mov cl, 1 ; 读1个扇区
    call Func_ReadOneSector ; near call
    mov si, KernelFileName
    mov di, 0x8000
    cld ; 下面要在循环里面比较字符串 此时在0x8000上放着的是从根目录读到的文件名 要保证比较字符串方向是从0x8000低地址空间到高地址空间
    mov dx, 0x10 ; 16表示的是1个根目录扇区有16个根目录项目 也就是说这边会套2层循环 外层是16个目录项 内层是每个文件名称11字节 跟LOADER BIN比较找到loader程序
Label_Search_For_LoaderBin:
    cmp dx, 0
    jz Label_Goto_Next_Sector_In_Root_Dir
    dec dx
    mov cx, 11 ; 11表示是的文件名+扩展名长度是11
Label_Cmp_FileName:
    cmp cx, 0
    jz Label_FileName_Found
    dec cx
    lodsb ; 拿到ds:si的字符放到al里面 就是目标文件名的字符 然后跟扇区根目录的文件名比较
    cmp al, byte [es:di]
    jz Label_Go_On
    jmp Label_Different
Label_Go_On:
    inc di ; 指向内存上的指针后移 准备比较扇区中根目录里面拿到的文件名的下一个字符
    jmp Label_Cmp_FileName
Label_Different:
    and di, 0xffe0
    add di, 0x20
    mov si, KernelFileName
    jmp Label_Search_For_LoaderBin
Label_Goto_Next_Sector_In_Root_Dir:
    add word [SectorNo], 1
    jmp Lable_Search_In_Root_Dir_Begin

; 找不到loader程序 打印提示信息然后夯在这
Label_No_LoaderBin:
    mov ax, 0x1301
    mov bx, 0x008c
    mov dh, NoLoaderMessageRow
    xor dl, dl
    mov cx, NoLoaderMessageLen
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
    mov eax, BaseTmpOfKernelAddr
    mov es, eax
    mov bx, OffsetTmpOfKernelFile
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

    push cx
    push eax
    push fs
    push edi
    push ds
    push esi

    mov cx, 0x0200
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
    mov ds, eax

    mov dword [OffsetOfKernelFileCount], edi

    pop esi
    pop ds
    pop edi
    pop fs
    pop eax
    pop cx

; 继续读盘函数
    call Func_GetFATEntry
    cmp ax, 0x0fff
    jz Label_File_Loaded
    push ax
    mov dx, RootDirSectors
    add ax, dx
    add ax, SectorBalance
    jmp Label_Go_On_Loading_File
Label_File_Loaded:
    mov ax, 0xb800
    mov gs, ax
    mov ah, 0x0f ; 0000黑底 1111白字
    mov al, 'G'
    mov [gs:((80 * 0 + 39) * 2)], ax ; 屏幕第0行 第39列

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
    mov dh, StartGetMemStructMessageRow
    mov dl, 0
    mov cx, StartGetMemStructMessageLen
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
    mov eax, 0xe820
    mov ecx, 20
    mov edx, 0x534d4150
    int 0x15
    jc Label_Get_Mem_Fail
    add di, 20
    inc dword [MemStructNumber]
    cmp ebx, 0
    jne Label_Get_Mem_Struct
    jmp Label_Get_Mem_OK
Label_Get_Mem_Fail:
    mov dword [MemStructNumber], 0
    mov ax, 0x1301
    mov bx, 0x008c
    mov dh, GetMemStructErrMessageRow
    mov dl, 0
    mov cx, GetMemStructErrMessageLen
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, GetMemStructErrMessage
    int 0x10
Label_Get_Mem_OK:
    mov ax, 0x1301
    mov bx, 0x000f
    mov dh, GetMemStructOKMessageRow
    mov dl, 0
    mov cx, GetMemStructOKMessageLen
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, GetMemStructOKMessage
    int 0x10

; SVGA信息
    mov ax, 0x1301
    mov bx, 0x000f
    mov dh, StartGetSVGAVBEInfoMessageRow
    mov dl, 0
    mov cx, StartGetSVGAVBEInfoMessageLen
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
    mov dh, GetSVGAVBEInfoErrMessageRow
    mov dl, 0
    mov cx, GetSVGAVBEInfoErrMessageLen
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
    mov dh, GetSVGAVBEInfoOKMessageRow
    mov dl, 0
    mov cx, GetSVGAVBEInfoOKMessageLen
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, GetSVGAVBEInfoOKMessage
    int 0x10

; SVGA模式
    mov ax, 0x1301
    mov bx, 0x000f
    mov dh, StartGetSVGAModeInfoMessageRow
    mov dl, 0
    mov cx, StartGetSVGAModeInfoMessageLen
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

    inc dword [SVGAModeCounter]
    add esi, 2
    add edi, 0x100

    jmp Label_SVGA_Mode_Info_Get
Label_SVGA_Mode_Info_FAIL:
    mov ax, 0x1301
    mov bx, 0x008c
    mov dh, GetSVGAModeInfoErrMessageRow
    mov dl, 0
    mov cx, GetSVGAModeInfoErrMessageLen
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
    mov dh, GetSVGAModeInfoOKMessageRow
    mov dl, 0
    mov cx, GetSVGAModeInfoOKMessageLen
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
    jnz Label_SET_SVGA_Mode_VESA_VBE_FAIL

; 初始化IDT GDT进入保护模式
    cli ; 先关闭BIOS的中断
    lgdt [GdtPtr]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
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

[SECTION .s116]
[BITS 16]
; 把1个扇区读到内存上
; 入参 ax-扇区编号 读哪个扇区
;     cl-读几个扇区
;     es:bx-磁盘数据读到内存的位置
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
IDT: times 0x50 dq 0
IDT_END:

IDT_POINTER:
    dw IDT_END-IDT-1
    dd IDT

; 临时变量
RootDirSizeForLoop dw RootDirSectors ; fat12根目录占14个扇区
SectorNo dw 0 ; 读盘的时候要知道读哪个扇区 0-based
Odd db 0
OffsetOfKernelFileCount dd OffsetOfKernelFile
MemStructNumber dd 0
SVGAModeCounter dd 0
DisplayPosition dd 0

KernelFileName: db "KERNEL  BIN", 0 ; 磁盘中烧录的内核程序名字 字符串长度11 文件名 扩展名 结束符\0

; 打印字符串 长度 显示在第几行
StartLoaderMessage: db "START LOADER..."
StartLoaderMessageLen equ $-StartLoaderMessage
StartLoaderMessageRow equ 2

NoLoaderMessage: db "ERROR: No KERNEL Found"
NoLoaderMessageLen equ $-NoLoaderMessage
NoLoaderMessageRow equ 3

StartGetMemStructMessage: db "Start Get Memory Struct(address, size, type)"
StartGetMemStructMessageLen equ $-StartGetMemStructMessage
StartGetMemStructMessageRow equ 4

GetMemStructErrMessage: db "Get Memory Struct ERR"
GetMemStructErrMessageLen equ $-GetMemStructErrMessage
GetMemStructErrMessageRow equ 5

GetMemStructOKMessage: db "Get Memory Struct SUCC"
GetMemStructOKMessageLen equ $-GetMemStructOKMessage
GetMemStructOKMessageRow equ 6

StartGetSVGAVBEInfoMessage: db "Start Get SVGA VBE Info"
StartGetSVGAVBEInfoMessageLen equ $-StartGetSVGAVBEInfoMessage
StartGetSVGAVBEInfoMessageRow equ 8

GetSVGAVBEInfoErrMessage: db "Get SVGA VBE Info ERR"
GetSVGAVBEInfoErrMessageLen equ $-GetSVGAVBEInfoErrMessage
GetSVGAVBEInfoErrMessageRow equ 9

GetSVGAVBEInfoOKMessage: db "Get SVGA VBE Info SUCC"
GetSVGAVBEInfoOKMessageLen equ $-GetSVGAVBEInfoOKMessage
GetSVGAVBEInfoOKMessageRow equ 0x0a

StartGetSVGAModeInfoMessage: db "Start Get SVGA Mode Info"
StartGetSVGAModeInfoMessageLen equ $-StartGetSVGAModeInfoMessage
StartGetSVGAModeInfoMessageRow equ 0x0c

GetSVGAModeInfoErrMessage: db "Get SVGA Mode Info ERR"
GetSVGAModeInfoErrMessageLen equ $-GetSVGAModeInfoErrMessage
GetSVGAModeInfoErrMessageRow equ 0x0d

GetSVGAModeInfoOKMessage: db "Get SVGA Mode Info SUCC"
GetSVGAModeInfoOKMessageLen equ $-GetSVGAModeInfoOKMessage
GetSVGAModeInfoOKMessageRow equ 0x0e