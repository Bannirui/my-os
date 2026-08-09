; 起始地址
org 0x7c00

; 不用分配空间 下面给栈指针寄存器SP提供栈基址
BaseOfStack equ 0x7c00

Label_Start:
    ; 初始化寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, BaseOfStack

    ; 清屏
    mov ax, 0x0600
    mov bx, 0x0700
    mov cx, 0
    mov dx, 0x184f
    int 0x10

    ; 光标
    mov ax, 0x0200
    mov bx, 0
    mov dx, 0
    int 0x10

    ; 打印字符串
    mov ax, 0x1301
    mov bx, 0x0f
    mov dx, 0
    mov cx, 0x0a
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartBootMessage
    int 0x10

    ; 软盘光驱复位
    xor ah, ah
    xor dl, dl
    int 0x13

    jmp $

; 字符串
StartBootMessage: db "Start Boot"

; 填充到510字节
times 510-($-$$) db 0

; 引导扇区结束标识
dw 0xaa55