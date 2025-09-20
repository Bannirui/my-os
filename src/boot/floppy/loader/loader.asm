; loader负责 硬件检测 cpu模式切换 向内核传递数据
; 硬件检测 检测硬件信息依赖的是BIOS中断服务 大部分只能在16位实模式下运行 所以在趁切换模式之前进行检测 最重要的是检测出物理地址空间信息 将这些信息交给内存管理单元进行管理
; 处理器模式切换 16位实模式->32位保护模式->64位IA-32e长模式
; 向内核传递数据 向内核传递2类数据 控制信息和硬件数据信息
org 0x10000 ; 在boot引导程序中最后一跳是0x1000:0 所以loader程序起手告诉编译器把自己放在物理地址0x10000上
    jmp L_Start

%include "fat12.inc" ; 还要用到fat12加载kernel代码 但是已经不是引导扇区 所以fat的BPB信息不需要一定放在偏移3字节的地方 不需要nop占位

; 16位实模式下寻址方式 段寄存器<<4+偏移 0<<4+0x100000 把kernel程序要放到1M地址空间上去 将来内核程序的运行肯定是在平台模型线性地址空间的
BaseOfKernelFile equ 0
OffsetOfKernelFile equ 0x100000 ; 内核代码放在物理地址0x100_000上 放在1M地址的原因是减少心智负担 BIOS是跑在16位实模式下能访问的都是1M内空间 直接把内核程序放到1M空间 保证BIOS访问不到 不用担心切换模式的过程中规划内存空间把BIOS的内存空间冲掉
; 16位实模式下还不能突破1M空间限制 从磁盘把内核程序加载到内存上不是一步到位放到1M地址空间 先在1M内空间暂存然后再复制过去
BaseTmpOfKernelAddr equ 0

; loader程序执行的时候还是在16位实模式下 因此能访问的空间还是受限1M
; 就先把磁盘中加载到的kernel程序放在这个地方上 起到缓存作用 之后通过big-real-mode模式把kernel程序般到1M位置上
; 读磁盘搬代码的单位是扇区 就是每个扇区操作一遍 所以0x7e00这个地址只会用[0x7e00...]这512字节作为缓存 循环使用 每读完1个扇区的kernel程序就放在这 然后搬到高地址空间 然后继续读下一个扇区继续缓存到这个地方
OffsetTmpOfKernelFile equ 0x7e00

MemoryStructBufferAddr equ OffsetTmpOfKernelFile ; 放在这个地址上的内核程序被挪到1M地址上后 这块临时转存空间就没有用了 就用来记录物理地址空间信息 所谓的物理地址空间 就是这台机器有哪些ROM哪些RAM

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
L_GDT: dd 0, 0 ; intel规范规定GDT表的第1个表项必须是0
L_DESC_CODE32: dd 0x0000ffff, 0x00cf9a00 ; 代码段 基址0 界限4G
L_DESC_DATA32: dd 0x0000ffff, 0x00cf9200 ; 数据段 基址0 界限4G
GdtLen equ $-L_GDT ; GDT表的大小是多少个字节
; 要把GDT表的信息告诉寄存器 一个GDT表的元信息就两个 共6字节
; 2字节=GDT表的表长-1
; 4字节=GDT表的基地址
GdtPtr dw GdtLen-1
       dd L_GDT
; 段选择子 高13位放GDT表的数组脚标 TI(0是GDT 1是LDT) RPL(ring0内核态 ring3用户态)
; ((((L_DESC_CODE32-L_GDT)/8) <<3) | (0<<2) | 0) ; 代码段的段选择子
SelectorCode32 equ L_DESC_CODE32 - L_GDT
; ((((L_DESC_DATA32-L_GDT)/8)<<3) | (0<<2) | 0) ; 数据段的段选择子
SelectorData32 equ L_DESC_DATA32 - L_GDT

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
L_GDT64: dq 0 ; 跟32位GDT一样 第1个表项是0
L_DESC_CODE64: dq 0x0020980000000000 ; 内核代码段
L_DESC_DATA64: dq 0x0000920000000000 ; 内核数据段
GdtLen64 equ $-L_GDT64
GdtPtr64 dw GdtLen64-1
         dd L_GDT64
; 这种写法比上面的简洁太多 正确性的原因是 跑在内核态ring0低2位是0 GDT所以第3位是0 也就是说GDT描述符选择子的低3位是0 那么GDT表项目偏移/8就等于>>3得到的就是GDT表的索引 再左移3位拼上低3位的0就等同于偏移量
SelectorCode64 equ L_DESC_CODE64-L_GDT64
SelectorData64 equ L_DESC_DATA64-L_GDT64

[SECTION .s16]
[BITS 16] ; 代码跑在16位实模式下
L_Start:
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
; 早期处理器只有20根地址线 现在需要突破访问空间的限制 机器上电默认A20地址线是禁用的 开启A20功能很多
; 1 操作键盘控制器
; 2 A20快速门 使用I/O端口0x92控制 但是如果这个端口已经被占用了就不能用这样的方式
; 3 BIOS提供了中断服务0x15 功能号ax=2401可以开启A20地址线 功能号ax=2400可以禁用A20地址线 功能号ax=2403可以查询A20地址线的当前状态
; 4 通过读0xee端口开启A20信号线 写0xee端口禁止A20信号线
    push ax
    ; 通过0x92端口开启A20地址线的方式就是置位0x92端口第1位值1 先把0x92端口值读出来然后把第1位写成1再写回0x92端口
    in al, 0x92 ; 把0x92值读到al寄存器
    or al, 0x02 ; 或运算保证第1位值是1
	out 0x92, al ; 再把al里面新的值写回到0x92端口 就开启了A20地址线了
    pop ax
    cli ; 关闭BIOS的中断 准备切换处理器模式进入到32位保护模式了 保证在切换模式过程中不会发生外部中断和异常
    lgdt [GdtPtr] ; 3字节描述了GDT表的元信息 自此从寄存器gdtr就可以拿到GDT表的信息
    ; 切换到保护模式很简单 就是把cr0寄存器的第0位置1就行
    mov eax, cr0 ; 把cr0寄存器的值读到eax中
    or eax, 1 ; 或运算保证值的第0值是1
    mov cr0, eax ; 再把新的值写回到cr0寄存器 这个时候处理器的模式就进入到32位保护模式了

    mov ax, SelectorData32
    mov fs, ax ; fs指向数据段选择子
    ; 下面要再关闭保护模式 重新退回到实模式 步骤就是跟开启保护模式相反 把cr0寄存器的第0位置0就行
    mov eax, cr0 ; 把cr0寄存器的值读到eax寄存器
    and al, 0xfe ; 与运算保证第0位的值是0
    mov cr0, eax ; 再把新值写回到cr0寄存器
    ; 上面这一对操作步骤 先打开保护模式再关闭保护模式的目的是什么 唯一的目的就是让fs段寄存器的寻址能力在实模式下能突破1M 也就是big real mode模式
    ; 为什么这么麻烦 又回到实模式呢 因为读盘的函数是基于BIOS的中断服务0x10实现的 现在kernel的程序还在磁盘中需要依赖BIOS的中断函数读到内存 并且根据内存规划 将来这个kernel程序是要放到1M地址上的 这件事情又是实模式下不具备的 所以需要折腾一下 既要fs段寄存器有突破1M寻址的能力 又要继续在实模式下使用中断读盘
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
    jz L_No_LoaderBin
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
L_Search_For_LoaderBin:
    cmp dx, 0
    jz L_Goto_Next_Sector_In_Root_Dir
    dec dx
    mov cx, 11 ; 11表示是的文件名+扩展名长度是11
L_Cmp_FileName:
    cmp cx, 0
    jz L_FileName_Found
    dec cx
    lodsb ; 拿到ds:si的字符放到al里面 就是目标文件名的字符 然后跟扇区根目录的文件名比较
    cmp al, byte [es:di]
    jz L_Go_On
    jmp L_Different
L_Go_On:
    inc di ; 指向内存上的指针后移 准备比较扇区中根目录里面拿到的文件名的下一个字符
    jmp L_Cmp_FileName
L_Different:
    and di, 0xffe0
    add di, 0x20
    mov si, KernelFileName
    jmp L_Search_For_LoaderBin
L_Goto_Next_Sector_In_Root_Dir:
    add word [SectorNo], 1
    jmp Lable_Search_In_Root_Dir_Begin

; 找不到loader程序 打印提示信息然后夯在这
L_No_LoaderBin:
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
L_FileName_Found:
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
L_Go_On_Loading_File:
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
; 至此 已经借助BIOS中断把kernel程序读到了0:0x7e00上了 读磁盘是1个扇区1个扇区读的 所以搬代码也是1个扇区1个扇区搬的 并一是一口气读完再一口气去搬的
; 下面就准备把这1个扇区的内核程序搬到1M地址上
; 这个时候还是在16位实模式下 理论上现在还是只能访问1M内空间 前面开保护模式->设置fs段寄存器段选择子->关闭保护模式的操作开始发力了
; 严格来说现在是big-real-mode模式 是有能力访问1M以上能力的
    ; 把这一坨寄存器 搬完kernel代码后再恢复
    push cx
    push eax
    push fs ; 尤其是这个段寄存器 现在指向的是数据段寄存器
    push edi
    push ds
    push esi

    mov cx, 0x0200 ; 10进制的512 loop指令在16位模式下是跟cx搭配使用的 所以cx=512就是循环512次 每次循环搬1字节内容 可以明确512的原因是磁盘扇区的大小就是512字节 这也是读完1个扇区立马搬代码的好处
    ; 设置fs:edi=0:OffsetOfKernelFileCount 复制搬代码的dest 搬到什么地方是随着读的扇区变多跟着变的 初始化值肯定是0x100000 所以每读完1个扇区搬完1个扇区后要同步更新这个临时变量 指向下一次要搬到的地方
    mov ax, BaseOfKernelFile
    mov fs, ax
    mov edi, dword [OffsetOfKernelFileCount]
    ; 设置ds:esi=0:0x7e00 复制搬代码的src
    mov ax, BaseTmpOfKernelAddr
    mov ds, ax
    mov esi, OffsetTmpOfKernelFile
    ; 必要的准备工作好了 现在就是要从ds:esi->fs:edi 循环512次 每次循环搬1字节 循环1次就自增esi和edi
L_Mov_Kernel:
    ; 搬1字节的数据 ds:esi->fs:edi
    mov al, byte [ds:esi]
    mov byte [fs:edi], al
    ; 搬完1次就++ 保证顺序搬完kernel程序
    inc esi
    inc edi
    ; 16位模式下loop指令会跟cx搭配使用直到cx为0 意思是会顺序搬512字节
    loop L_Mov_Kernel
    ; 到这 上面刚从磁盘里面读出来的1扇区kernel程序已经全部搬到了1M以上的地址了
    ; todo 下面2条指令设置ds寄存器值我没看懂干嘛用的 但是尝试注释掉后会导致异常
    mov eax, 0x1000
    mov ds, eax

    mov dword [OffsetOfKernelFileCount], edi ; OffsetOfKernelFileCount是个临时变量初始是0x100000 edi在每次loop循环都会++ 等1个扇区搬完此时它就会+512 所以也就实现了临时变量每搬完1个扇区代码就+512 指向了下一个扇区代码要搬到什么地方
    ; 1个扇区的kernel程序已经搬到了1M以上地址空间 恢复搬之前的段寄存器现场 继续读盘
    pop esi
    pop ds
    pop edi
    pop fs
    pop eax
    pop cx

; 继续读盘函数
    call Func_GetFATEntry
    cmp ax, 0x0fff
    jz L_File_Loaded
    push ax
    mov dx, RootDirSectors
    add ax, dx
    add ax, SectorBalance
    jmp L_Go_On_Loading_File
; 所有的kernel程序都从磁盘读出来并且搬到了1M以上地址空间了
L_File_Loaded:
    ; b800显示方法 跟BIOS比起来更高效
    ; 内存地址从b800开始是一段专门用来显示字符的内存空间 每个字符占用2个字节的内存空间 低字节保存要显示的字符 高字节保存字符的颜色属性
    ; 字符到内存b800地址偏移offset = (row * 80 + col) * 2 乘以2的原因是每个字符要占2字节
    mov ax, 0xb800
    mov gs, ax
    mov ah, 0x0f ; 0000黑底 1111白字
    mov al, 'H'
    mov [gs:((80 * 0 + 39) * 2)], ax ; 屏幕第0行 第39列
    mov al, 'E'
    mov [gs:((80 * 1 + 39) * 2)], ax ; 屏幕第1行 第39列
    mov al, 'L'
    mov [gs:((80 * 2 + 39) * 2)], ax ; 屏幕第2行 第39列
    mov al, 'L'
    mov [gs:((80 * 3 + 39) * 2)], ax ; 屏幕第3行 第39列
    mov al, 'O'
    mov [gs:((80 * 4 + 39) * 2)], ax ; 屏幕第4行 第39列

; kernel程序被加载到了内存 软驱的使命完成了 后面不需要使用软驱了 可以关闭软驱
; 通过向3f2端口写命令控制关闭软驱马达
KillMotor:
    push ax
    mov ah, 0
    in al, 0x03f2 ; 端口3f2现在的值读出来
    and al, 0 ; 与运算改值
    out 0x03f2, al ; 新的值再写回到端口
    pop ax

; 打印
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

; 上面[7e00...]512字节的空间在搬运内核代码时是缓存空间 内核程序不需要再借助内存临时转存了 这块临时转存空间用来记录物理地址空间信息
    ; es:di=0:0x7e00
    xor ebx, ebx
    xor ax, ax
    mov es, ax
    mov di, MemoryStructBufferAddr

; 0x15获取内存布局中断调用
; 入参
; ebx-在BIOS 0x15中断调用中会刷新这个值 0表示不继续发起调用了 1表示还要继续中断调用继续获取更多的内存结构信息 所以在第1次调用前就初始化0值
; es:di-中断服务会把拿到的内存结构体信息放到这
; 出参
; cf=0-表示成功
; ES:DI-指向写入的内存表
; EBX-被BIOS更新 用于下一次调用
L_Get_Mem_Struct:
    mov eax, 0xe820 ; 系统调用功能号 获取内存布局
    mov ecx, 20 ; 系统调用返回的结构体大小是20字节 这也是标准的E820结构体大小
    mov edx, 0x534d4150 ; SMAP的ASCII值 表示需要的是SMAP格式的内存表
    int 0x15 ; 发起BIOS系统调用
    jc L_Get_Mem_Fail ; cf=1表示调用失败
    add di, 20 ; 在调用中断之前已经约定了每个结构体大小是20字节 现在成功拿到了1个内存结构体 说明BIOS中断已经在es:di上放了20字节内容了 所以要后移di指针 为下一个结构体的放入布局
    inc dword [MemStructNumber] ; 记录拿到了多少个结构体
    cmp ebx, 0 ; 是继续标识 不是0表示还有更多的内存条目可以继续获取 0表示已经是最后一个内存条目了没有更多了
    jne L_Get_Mem_Struct
    jmp L_Get_Mem_OK
L_Get_Mem_Fail:
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
L_Get_Mem_OK:
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
L_SVGA_Mode_Info_Get:
    mov cx, word [es:esi]

; 打印SVGA模式
    push ax
    xor ax, ax
    ; 调用函数显示16进制的数 al是参数-要显示的数
    mov al, ch
    call L_DispAL

    xor ax, ax
    mov al, cl
    call L_DispAL
    pop ax

    cmp cx, 0xffff
    jz L_SVGA_Mode_Info_Finish

    mov ax, 0x4f01
    int 0x10

    cmp ax, 0x004f

    jnz L_SVGA_Mode_Info_FAIL

    inc dword [SVGAModeCounter]
    add esi, 2
    add edi, 0x100

    jmp L_SVGA_Mode_Info_Get
L_SVGA_Mode_Info_FAIL:
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
L_SET_SVGA_Mode_VESA_VBE_FAIL:
    jmp $
L_SVGA_Mode_Info_Finish:
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
    jnz L_SET_SVGA_Mode_VESA_VBE_FAIL

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

[SECTION .s16lib]
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
L_Go_On_Reading:
    mov ah, 2
    mov al, byte [bp - 2]
    int 0x13
    jc L_Go_On_Reading
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
    jz L_Even
    mov byte [Odd], 1
L_Even:
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
    jnz L_Even_2
    shr ax, 4
L_Even_2:
    and ax, 0x0fff
    pop bx
    pop es
    ret

; 打印显示16进制数值
; 参数
; al-要显示的16进制数
L_DispAL:
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
OffsetOfKernelFileCount dd OffsetOfKernelFile ; 临时变量初始0x100000 等把kernel代码从0x7e00搬到0x100000后会被赋值512
MemStructNumber dd 0 ; BIOS中断0x15获取内存布局信息时拿到了多少个内存结构体 这些结构体放在0x7e00上 1个就是20字节 n个就是20n个字节
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