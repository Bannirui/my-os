; 端口操作硬盘驱动
; mbr程序是启动盘0#扇区内容 负责1#扇区的loader程序加载到内存
; loader程序负责加载内核代码到内存
; loader布局在0x900上

LOADER_BASE_ADDR    equ 0x900
LOADER_START_SECTOR equ 0x1 ; 磁盘1#扇区 扇区编号是0-based

SECTION MBR vstart=0x7c00
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00
    mov ax, 0xb800
    mov gs, ax ; 指向显存

; 10号中断0x06的功能清屏
; AH=0x06 功能号
; AL=0 全部清除
; BH=上卷行的属性
; CL, CH 左上角
; DL, DH 右下角
    mov ax, 0x0600
    mov bx, 0x0700
    mov cx, 0
    mov dx, 0x184f ; 文本模式下80行25列
    int 0x10

; 打印调试信息
    mov byte [gs:0x00], 'I'
    mov byte [gs:0x01], 0xa4
    mov byte [gs:0x02], ' '
    mov byte [gs:0x03], 0xa4
    mov byte [gs:0x04], 'M'
    mov byte [gs:0x05], 0xa4
    mov byte [gs:0x06], 'B'
    mov byte [gs:0x07], 0xa4
    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xa4

    mov eax, LOADER_START_SECTOR ; LBA读入的扇区
    mov bx, LOADER_BASE_ADDR ; 扇区里面内容读到哪个地址上
    mov cx,1 ; 等待读入的扇区数量
    call rd_disk
    jmp LOADER_BASE_ADDR ; 跳到实际的物理内存

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

    times 510 - ($-$$) db 0
    dw 0xaa55