; loader程序
; boot sector程序读取到该程序 将内容放在了内存0x1000:0x0000上
; 因此这段程序的起始地址就是0x10000(=0x1000<<4+0x0000)
; 逻辑地址=0x100000
; 当前还是在实模式下 物理地址=0x100000
org 0x10000

jmp start

%include "fat12.inc"

base_of_dest        equ 0x0000
offset_of_dest      equ 0x7e00                             ;                地址=0<<4+0x7e00=0x07e00 加载kernel程序到该地址 临时存放在这

base_of_kernel      equ 0x00
offset_of_kernel    equ 0x100000                           ;                kernel程序会从上面地址再复制到这个地址上 跳转到该地址 将CPU执行权转移到kernel程序上

mem_struct_buf_addr equ 0x7e00

[section gdt_32]
gdt_32:
    dd 0,0

desc_code_32:
    dd 0x0000ffff, 0x00cf9a00

desc_data_32:
    dd 0x0000ffff, 0x00cf9200

gdt_32_sz equ $ - gdt_32
gdt_32_ptr dw gdt_32_sz - 1
dd gdt_32

selector_code_32 equ desc_code_32 - gdt_32
selector_data_32 equ desc_data_32 - gdt_32

[section gdt_64]
gdt_64:
    dq 0x0000000000000000

desc_code_64:
    dq 0x0020980000000000

desc_data_64:
    dq 0x0000920000000000

gdt_64_sz equ $ - gdt_64
gdt_64_ptr dw gdt_64_sz-1
dd gdt_64

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
    in al, 0x92
    or al, 0x02
    out 0x92, al
    pop ax
    cli                                                    ;                关闭外部中断

    db 0x66
    lgdt [gdt_32_ptr]                                      ;                加载保护模式结构数据信息

    mov eax, cr0
    or eax, 1
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

; 相当于重写fat12read2.inc中逻辑
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
    mov gs, ax
    mov ah, 0x0f
    mov al, 'G'
    mov [gs:((80*0+39)*2)], ax

; @brief 关闭软驱马达
;        kernel程序已经从软盘中被加载出来 后续软盘将不再使用
.kill_floppy:
    push dx
    mov dx, 0x03f2
    mov al, 0
    out dx, al
    pop dx

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
    mov di, mem_struct_buf_addr

.get_mem_struct:
    mov eax, 0x0e820
    mov ecx, 20
    mov edx, 0x534d4150
    int 0x15
    jc .get_mem_fail
    add di, 20

    cmp ebx, 0
    jne .get_mem_struct
    jmp .get_mem_succ

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

.set_vesa_vbe:
    mov ax, 0x4f02
    mov bx, 0x4180
    int 0x10
    cmp ax, 0x004f
    jnz .over

.switch_protect_mode:
    cli
    db 0x66
    lgdt [gdt_32_ptr]
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp dword selector_code_32:.tmp_proj

[section .s32]
[bits 32]

.tmp_proj:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov esp, 0x7e00

    call .support_long_mode
    test eax, eax
    jz .no_support

.init_tmp_page_table:
    mov dword[0x90000], 0x91007
    mov dword[0x90800], 0x91007
    mov dword[0x91000], 0x92007
    mov dword[0x92000], 0x000083
    mov dword[0x92008], 0x200083
    mov dword[0x92010], 0x400083
    mov dword[0x92018], 0x600083
    mov dword[0x92020], 0x800083
    mov dword[0x92028], 0xa00083

.load_gdtr:
    db 0x66
    lgdt [gdt_64_ptr]
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x7e00

.open_pae:
    mov eax, cr4
    bts eax, 5
    mov cr4, eax

.load_cr3:
    mov eax, 0x90000
    mov cr3, eax

.enable_long_mode:
    mov ecx, 0x0c0000080
    rdmsr
    bts eax, 8
    wrmsr

.open_pe_and_page:
    mov eax, cr0
    bts eax, 0
    bts eax, 31
    mov cr0, eax
    ; 调试
    jmp $
    jmp selector_code_64:offset_of_kernel

.support_long_mode:
    mov eax, 0x80000000
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

.no_support:
    jmp $

[section .s16lib]
[bits 16]

%include "fat12read3.inc"

show_hex:
    push ecx
    push edx
    push edi
    mov edi, [show_pos]
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
    mov [show_pos], edi
    pop edi
    pop edx
    pop ecx
    ret

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