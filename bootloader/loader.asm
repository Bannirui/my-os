; loader程序
; boot sector程序读取到该程序 将内容放在了内存0x1000:0x0000上
; 因此这段程序的起始地址就是0x10000(=0x1000<<4+0x0000)
; 逻辑地址=0x100000
; 当前还是在实模式下 物理地址=0x100000
org 0x10000

jmp start

%include "fat12.inc"

base_of_dest        equ 0x0000
offset_of_dest      equ 0x0500                             ;                地址=0<<4+0x0500=0x00500 加载kernel程序到该地址 临时存放在这

base_of_kernel      equ 0x00
offset_of_kernel    equ 0x100000                           ;                kernel程序会从上面地址再复制到这个地址上 跳转到该地址 将CPU执行权转移到kernel程序上

mem_struct_buf_addr equ 0x7e00                             ;                保存物理地址空间信息

; CPU模式切换前的数据结构准备 GDT表 32位保护模式下的GDT表
[section gdt_32]
gdt_32:
    dd 0,0

desc_code_32:
    dd 0x0000ffff, 0x00cf9a00

desc_data_32:
    dd 0x0000ffff, 0x00cf9200

gdt_32_sz equ $ - gdt_32
gdt_32_ptr dw gdt_32_sz - 1
           dd gdt_32                                       ;                GDT表的基地址和长度必须借助LGDT汇编指令才能加载到GDTR寄存器中 GDTR寄存器是6B的结构 低2B保存GDT表的长度 高4B保存GDT表的基地址 用指针gdt_ptr指向该结构的起始地址

selector_code_32 equ desc_code_32 - gdt_32
selector_data_32 equ desc_data_32 - gdt_32

; CPU模式切换前的数据结构准备 GDT表 64位保护模式(IA-32e模式)下的GDT表
[section gdt_64]
gdt_64:
    dq 0x0000000000000000

desc_code_64:
    dq 0x0020980000000000

desc_data_64:
    dq 0x0000920000000000

gdt_64_sz equ $ - gdt_64
gdt_64_ptr dw gdt_64_sz-1
           dd gdt_64                                       ;                GDT表的基地址和长度必须借助LGDT汇编指令才能加载到GDTR寄存器中 GDTR寄存器是6B的结构 低2B保存GDT表的长度 高4B保存GDT表的基地址 用指针gdt_ptr指向该结构的起始地址

selector_code_64 equ desc_code_64 - gdt_64
selector_data_64 equ desc_data_64 - gdt_64

; .s16的段
[section .s16]
; 告知nasm编译器生成的代码执行在16位宽处理器上
[bits 16]

start:
; @brief 段寄存器设置
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, 0x00
    mov ss, ax
    mov sp, 0x7c00

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
print_running_msg:
    mov ax, 0x1301
    mov cx, 14
    mov dx, 0x0200
    mov bx, 0x000f
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, running_msg
    int 0x10

; @brief 打开A20地址线
;        在机器上电时 默认情况下A20地址线是禁用的 开启方法如下
;        1 开启A20功能的常用方法是操作键盘控制器 由于键盘控制器是低速设备 以至于功能开启速度相对较慢
;        2 A20快速门(Fast Gate A20) 它使用I/O端口0x92来处理A20信号线 即置位0x92端口的第1位 对于不含键盘控制器的操作系统 就只能使用0x92端口来控制 但是该端口有可能被其他设备使用
;        3 使用BIOS中断服务程序int 0x15的主功能号AX=2401可开启A20地址线 功能号AX=2400可禁用A20地址线 功能号AX=2403可查询A20地址线的当前状态
;        4 通过读0xee端口来开启A20信号线 写该端口则会禁止A20信号线
;
;        当前处理器还运行在16位实模式下 CPU的寻址空间上限为1M
;        开启实模式下对4G空间的寻址能力
;        关中断-加载保护模式结构数据-开启保护模式-FS段寄存器加载新数据段值-退出保护模式-开启中断
;        目的就是为了让FS段寄存器在实模式下寻址能力超过1M 即Big Real Mode模式
;        经此之后 FS段寄存器的特殊寻址能力就可以将内核程序移动到1M以上的内存地址空间
.open_a20:
    push ax
    in al, 0x92                                            ;                南桥芯片内的端口
    or al, 0x02
    out 0x92, al
    pop ax
    cli                                                    ;                关闭外部中断
    db 0x66
    lgdt [gdt_32_ptr]                                      ;                加载保护模式结构数据信息

    mov eax, cr0
    or eax, 0x01
    mov cr0, eax                                           ;                置位CR0寄存器的第0位开启保护模式
    mov ax, selector_data_32
    mov fs, ax                                             ;                给FS段寄存器加载新的数据段值
    mov eax, cr0
    and al, 0xfe
    mov cr0, eax                                           ;                退出保护模式
    sti                                                    ;                开启外部中断

; @brief 重置软盘 为读取做准备
.floppy_reset:
    xor ah, ah
    xor dl, dl
    int 0x13

%include "fat12read1.inc"

.file_found:
    and di, 0xfff0                                         ;                当前是根目录项中的文件名是匹配成功的 那么地址偏移是11 地址后4bit的表达区间是[0...15] 把后4位置0就是当前根目录项的首地址
    add di, 0x001a                                         ;                当前偏移0 重置到26偏移 [26...27]记录着起始簇号
    mov cx, word[es:di]                                    ;                文件对应的起始簇号读取出来
    push cx                                                ;                起始簇号 将簇号缓存在栈中 读取完当前簇号内容后 还要根据簇号找到下一个簇号
    add cx, cluster_map_sector                             ;                扇区号=簇号+31
    mov eax, base_of_dest
    mov es, eax
    mov bx, offset_of_dest                                 ;                读取出来的loader.bin程序从base_of_dest:offset_of_dest地址开始往后放
    mov ax, cx

.dfs_load_for_file:
    call func_print_char
    mov cl, 1                                              ;                准备读1个扇区
    call func_read_sector
    pop ax
    ; --- 读完一个扇区就复制一个扇区 ----
    push cx
    push eax
    push fs
    push edi
    push ds
    push esi

    mov cx, 0x200
    mov ax, base_of_kernel
    mov fs, ax
    mov edi, dword[offset_of_kernel_file_cnt]
    mov ax, base_of_dest
    mov ds, ax
    mov esi, offset_of_dest

.move_kernel:
    mov al, byte[ds:esi]
    mov byte[fs:edi], al
    inc esi
    inc edi
    loop .move_kernel
    mov eax, 0x1000
    mov ds, eax
    mov dword[offset_of_kernel_file_cnt], edi
    pop esi
    pop ds
    pop edi
    pop fs
    pop eax
    pop cx
    ; --- 读完一个扇区就复制一个扇区 ----

    call func_next_entry                                   ;                AX中存储簇号 当前簇号的下一个簇号 一直递归读取到结束符
    cmp ax, 0x0fff                                         ;                12bit 0xfff标识结尾 也就意味着根据某个簇号找到的下一个簇号是0xfff就说明整个文件内容都读完了
    jz .load_succ

    push ax                                                ;                当前簇号的下一个簇号入栈 给递归函数的下一层是用 也就是下层递归的当前簇号
    add ax, cluster_map_sector                             ;                扇区号=簇号+31
    add bx, [BPB_BytesPerSec]
    jmp .dfs_load_for_file

; @brief 将kernel成加载完成 打印调试信息
.load_succ:
    mov ax, 0x0b800
    mov gs, ax                                             ;                GS段寄存器的基地址设置在0x0b800处
    mov ah, 0x0f                                           ;                AH控制字体属性
                                                           ;                位[0...3]控制背景颜色 0000=黑色
                                                           ;                位[4...7]控制字体颜色 1111=白色
    mov al, 'G'                                            ;                要显示的字符
    mov [gs:((80*0+39)*2)], ax                             ;                AX寄存器的值填充到0x0b800偏移指定的位置上

; @brief 关闭软驱马达
;        kernel程序已经从软盘中被加载出来 后续软盘将不再使用
;        通过向IO端口0x03f2写控制命令的方式控制软盘驱动功能
;        位[7] 控制软驱D马达 1=启动 0=关闭
;        位[6] 控制软驱C马达 1=启动 0=关闭
;        位[5] 控制软驱B马达 1=启动 0=关闭
;        位[4] 控制软驱A马达 1=启动 0=关闭
;        位[3] 1=允许DMA和中断请求 0=禁止DMA和中断请求
;        位[2] 1=允许软盘控制器发送控制信息 0=复位软盘驱动器
;        位[1]
;        位[0]
;        低位2个组合用于选择哪个驱动器 即[A...D]中哪个软驱马达
.kill_floppy:
    push dx
    mov dx, 0x03f2
    mov al, 0
    out dx, al                                             ;                控制命令写端口0x03f2
    pop dx

; @brief 准备通过BIOS中断int 15h获取物理地址空间信息
.print_mem_msg:
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0400
    mov cx, 13
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, mem_struct_start_msg
    int 0x10

    mov ebx, 0
    mov ax, 0x00
    mov es, ax
    mov di, mem_struct_buf_addr                            ;                0x07e00放物理地址空间信息

; @brief 实模式下BIOS中断 获取物理地址空间信息
; @param EAX    Function Code   E820h
; @param EBX    Continuation
; @param ES:DI  Buffer Pointer  Pointer to an Address Range Description structure which the BIOS is to fill in
; @param ECX    Buffer Size
; @param EDX    Signature
;
; @return CF    Carry Flag      Non-Carry - indicates no error
; @return EAX   Signature
; @return ES:DI Buffer Pointer
; @return ECX   Buffer Size
; @return EBX   Continuation    A return value of zero means that this is the last descriptor.
.get_mem_struct:
    mov eax, 0x0e820                                       ;                中断功能号
    mov ecx, 20
    mov edx, 0x534d4150
    int 0x15
    jc .get_mem_fail                                       ;                CF=1 CF标志位有进位 即int 0x15中断调用有异常发生
    add di, 20                                             ;                每次中断调用结果用的内存buffer是20B 还有结果可以获取就要后移填充的指针

    cmp ebx, 0
    jne .get_mem_struct                                    ;                EBX不是0说明继续获取信息填充到内存
    jmp .get_mem_succ                                      ;                EBX是0说明物理地址空间信息已经获取完

; @brief 通过BIOS中断获取物理地址空间信息失败 打印提示信息
.get_mem_fail:
    mov ax, 0x1301
    mov bx, 0x008c
    mov dx, 0x0500
    mov cx, 15
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, mem_struct_err_msg
    int 0x10
    jmp $

; @brief 通过BIOS中断获取物理地址空间信息成功 打印提示信息
.get_mem_succ:
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0600
    mov cx, 16
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, mem_struct_succ_msg
    int 0x10

.svga_vbe:
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0800
    mov cx, 11
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, svga_vbe_start_msg
    int 0x10

    mov ax, 0x00
    mov es, ax
    mov di, 0x8000
    mov ax, 0x4f00
    int 0x10

    cmp ax, 0x004f
    jz .svga_vbe_succ

.svga_vbe_fail:
    mov ax, 0x1301
    mov bx, 0x008c
    mov dx, 0x0900
    mov cx, 13
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, svga_vbe_err_msg
    int 0x10
    jmp $

.svga_vbe_succ:
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0a00
    mov cx, 14
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, svga_vbe_succ_msg
    int 0x10

.svga_mode:
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0c00
    mov cx, 12
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, svga_mode_start_msg
    int 0x10

    mov ax, 0x00
    mov es, ax
    mov si, 0x800e
    mov esi, dword[es:si]
    mov edi, 0x8200

.svga_mode_start:
    mov cx, word[es:esi]
    push ax

    mov ax, 0x00
    mov al, ch
    call show_hex

    mov ax, 0x00
    mov al, cl
    call show_hex

    pop ax

    cmp cx, 0x0ffff
    jz .svga_mode_succ

    mov ax, 0x4f01
    int 0x10

    cmp ax, 0x004f
    jnz .svga_mode_err

    add esi, 2
    add edi, 0x100
    jmp .svga_mode_start

.svga_mode_err:
    mov ax, 0x1301
    mov bx, 0x008c
    mov dx, 0x0d00
    mov cx, 14
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, svga_mode_err_msg
    int 0x10

.over:
    jmp $

.svga_mode_succ:
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0e00
    mov cx, 15
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, svga_mode_succ_msg
    int 0x10

; @brief 设置SVGA芯片的显示模式
;        从Bochs虚拟平台的SVGA芯片中获取显示配置信息 包括屏幕分辨率\每个像素点的数据位宽\颜色格式
;        通过配置不同的显示模式就可以配置出不同的屏幕分辨率\每个像素点的数据位宽\颜色格式
;          模式        列        行         物理地址         像素点位宽
;         0x180      1440      900        e0000000h         32bit
;         0x143       800      600        e0000000h         32bit
.set_vesa_vbe:
    mov ax, 0x4f02
    mov bx, 0x4180
    int 0x10
    cmp ax, 0x004f
    jnz .over

; CPU模式切换 由16位实模式切换到32位保护模式
.switch_to_protect_mode_32:
    cli                                                    ;                CLI汇编指令禁止可屏蔽硬件中断 模式切换程序必须保证在切换过程中不能产生异常和中断
    db 0x66                                                ;                0x66是LGDT指令和LIDT指令的前缀 用于修饰当前指令的操作数是32位宽
    lgdt [gdt_32_ptr]                                      ;                通过LGDT指令加载6B的数据到GDTR寄存器中 低2B保存GDT表的长度 高4B保存GDT表的基地址
    mov eax, cr0
    or eax, 1
    mov cr0, eax                                           ;                置位CR0寄存器第0位为1
    jmp dword selector_code_32:protected_code_32           ;                典型的保护模式切换方式 在CR0寄存器设置之后紧随远跳到保护模式的代码去执行

[section .s32]
[bits 32]

; @brief 32位保护模式下的代码 供给16位实模式切换32位保护模式远跳
protected_code_32:
    ; 进入保护模式首先要做的就是初始化各个段寄存器和栈指针
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov esp, 0x7e00

    call .check_if_support_long_mode                       ;                检测CPU处理器是否支持IA-32e长模式 处理器支持IA-32e模式就从32位保护模式切换到IA-32e模式 处理器不支持IA-32e模式就进入待机状态不做任何操作
    test eax, eax
    jz .non_support_ia32e                                  ;                处理器不支持64位长模式

; @brief 处理器支持IA-32e模式 开始为IA-32e模式配置临时页目录和页表项
.init_tmp_page_table:
    mov dword[0x90000], 0x91007                            ;                IA-32e模式下页目录首地址在0x90000上
    mov dword[0x90800], 0x91007
    mov dword[0x91000], 0x92007
    mov dword[0x92000], 0x000083
    mov dword[0x92008], 0x200083
    mov dword[0x92010], 0x400083
    mov dword[0x92018], 0x600083
    mov dword[0x92020], 0x800083
    mov dword[0x92028], 0xa00083

; @brief 从32位保护模式切换到IA-32e模式的前置准备工作 重新加载全局描述符表GDT 初始化大部分寄存器
.switch_to_protect_mode_64:
    db 0x66                                                ;                LGDT指令和LIDT指令前缀 修饰位宽是32位
    lgdt [gdt_64_ptr]                                      ;                通过LGDT指令加载6B的数据到GDTR寄存器中 低2B保存GDT表的长度 高4B保存GDT表的基地址
    ; 进入保护模式首先要做的就是初始化各个段寄存器和栈指针 CS代码段寄存器值不能通过直接赋值方式来改变 只能通过跨段跳转(far jmp)或者跨段调用(far call)指令来改变
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x7e00

; @brief 开启PAE CR4寄存器的第5位是PAE的功能位
.open_pae:
    mov eax, cr4
    bts eax, 5                                             ;                EAX位5置1
    mov cr4, eax

; @brief 临时页目录的首地址设置到CR3寄存器中
.load_cr3:
    mov eax, 0x90000
    mov cr3, eax

; @brief 通过置位IA32_EFER寄存器的LME标志位(第8位)来激活IA-32e模式
.enable_long_mode:
    mov ecx, 0x0c0000080                                   ;                IA32_EFER寄存器
    rdmsr
    bts eax, 8                                             ;                将IA32_EFER寄存器第8位置1 但是IA32_EFER寄存器是位于MSR寄存器组内 为了操作IA32_EFER寄存器必须借助特殊汇编指令RDMSR/WRMSR
    wrmsr

; @brief 再次使能保护模式 真正进入64位长模式
.open_pe_and_page:
    mov eax, cr0
    bts eax, 0                                             ;                使能CR0寄存器的0位 PE=1 使处理器运行于保护模式
    bts eax, 31                                            ;                使能CR0寄存器的31位 PG=1 启用分页管理机制
    mov cr0, eax
    jmp selector_code_64:offset_of_kernel                  ;                此时处理器处于的是兼容模式 也就是处理器虽然进入了IA-32e模式 但是运行的的代码还是保护模式的程序 通过一段跨段跳\跨段调用将CS段寄存器的值更新为IA-32e模式的代码段描述符 CPU就真正进入了64位长模式IA-32e

; @brief 检测CPU处理器是否支持IA-32e长模式 处理器支持IA-32e模式就从32位保护模式切换到IA-32e模式 处理器不支持IA-32e模式就进入待机状态不做任何操作
.check_if_support_long_mode:
    mov eax, 0x80000000
    ; @brief CPUID指令会根据EAX寄存器传入的基础功能号查询处理器的坚定信息和机能信息 其返回结果存储在EAX\EBX\ECX和EDX寄存器中
    ;        CPUID指令的扩展功能项0x80000001的第29位指示处理器是否支持IA-32e模式 只有当CPUID扩展功能号>=0x80000001才有可能支持64位的长模式
    cpuid
    cmp eax, 0x80000001
    setnb al
    jb .support_long_mode_done
    mov eax, 0x80000001
    cpuid
    bt edx, 29
    setc al

.support_long_mode_done:
    movzx eax, al
    ret

; @brief 处理器不支持IA-32e的64位长模式 使其待机在这
.non_support_ia32e:
    jmp $

[section .s16lib]
[bits 16]

%include "fat12read4.inc"

; @brief 打印16进制数值
; @param AL 要显示的16进制数
show_hex:
    push ecx
    push edx
    push edi
    mov edi, [show_pos]
    mov ah, 0x0f                                           ;                AH寄存器存储字体颜色属性 位[7...4]标识背景颜色 0000=黑色 位[3...0]标识字体颜色 1111=白色
    mov dl, al                                             ;                要先处理AL的高4位 因此先把AL的值缓存到DL寄存器中
    shr al, 4                                              ;                AL的高4位
    mov ecx, 2

.begin:
    and al, 0x0f
    cmp al, 9
    ja .1                                                  ;                AL高4位大于9则减去0Ah并与字符A相加 否则直接将其与字符0相加
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
    mov [show_pos], edi
    pop edi
    pop edx
    pop ecx
    ret

; 为IDT开辟内存空间
idt:
    times 0x50 dq 0
idt_end:

idt_ptr:
    dw idt_end - idt - 1
    dd idt

; 定义变量
running_msg db "LOADER running",0 ; loader程序启动的欢迎界面
; 加载kernel程序
search_file_name: db "KERNEL  BIN",0
odd               db 0
sector_no         dw 0
root_dir_loop_sz  dw root_dir_sector_cnt
; 复制kernel程序
offset_of_kernel_file_cnt dd offset_of_kernel

; mem
mem_struct_start_msg: db "mem struct...",0
mem_struct_succ_msg: db "mem struct, succ",0
mem_struct_err_msg: db "mem struct, err",0

; svga_vbe
svga_vbe_start_msg: db "svga vbe...",0
svga_vbe_succ_msg: db "svga vbe, succ",0
svga_vbe_err_msg: db "svga vbe, err",0

; svga_mode
svga_mode_start_msg: db "svga mode...",0
svga_mode_succ_msg: db "svga mode, succ",0
svga_mode_err_msg: db "svga mode, err",0

show_pos dd 0