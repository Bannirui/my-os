LOADER_BASE_ADDR equ 0x900
section loader vstart=LOADER_BASE_ADDR
; kernel程序放在物理地址
KERNEL_BASE_ADDR equ 0x8000
; kernel程序从硬盘8#扇区开始
KERNEL_START_SECTOR equ 0x08


mov ax, 0xb800
mov es, ax
mov byte [es:0x00], 'O'
mov byte [es:0x01], 0x07
mov byte [es:0x02], 'K'
mov byte [es:0x03], 0x06

mov eax, KERNEL_START_SECTOR ; LBA读入的扇区
mov bx, KERNEL_BASE_ADDR ; 扇区里面内容读到哪个地址上
mov cx,1 ; 等待读入的扇区数量
call rd_disk
; 跳到kernel程序
jmp KERNEL_BASE_ADDR


; LBA读硬盘
rd_disk:
    ; eax LBA的扇区号
    ; bx 数据写入的内存地址
    ; 读入的扇区数
    mov esi, eax ; 备份eax
    mov di, cx ; 备份cx
; 读写硬盘
    mov dx, 0x1f2
    mov al, cl
    out dx, al
    mov eax, esi
; 将LBA的地址存入0x1f3 0x1f6
    ; 7到0位写入0x1f3
    mov dx, 0x1f3
    out dx, al
    ; 15到8位写入0x1f4
    mov cl, 8
    shr eax, cl
    mov dx, 0x1f4
    out dx, al
    ; 23到16位写入0x1f5
    shr eax, cl
    mov dx, 0x1f5
    out dx, al

    shr eax, cl
    and al, 0x0f
    or al, 0xe0 ; 设置7到4位为1110 此时才是LBA模式
    mov dx, 0x1f6
    out dx, al

    ; 向0x1f7写入读命
    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

    ; 检测硬盘状态
    .not_ready:
    nop
    in al, dx
    and al, 0x88 ; 4位为1表示可以传输 7位为1表示硬盘busy
    cmp al, 0x08
    jnz .not_ready

    ; 读数据
    mov ax, di
    mov dx, 256
    mul dx
    mov cx, ax
    mov dx, 0x1f0

    .go_on:
        in ax, dx
        mov [bx], ax
        add bx, 2
        loop .go_on
        ret
