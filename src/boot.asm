; BIOS引导程序
org 0x7c00
BaseOfStack equ 0x7c00
L_Start:
; 标准设置寄存器
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
; 光标设置
    mov ax, 0x0200
    xor bx, bx
    xor dx, dx
    int 0x10
; 打印调试
    mov ax, 0x1301
    mov bx, 0x000f
    xor dx, dx
    mov cx, 0x10
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartBootMessage
    int 0x10
; 重置软驱
    xor ah, ah
    xor dl, dl
    int 0x13
    jmp $
StartBootMessage:
    db "START BOOT"
; 启动盘引导扇区
    times 510-($-$$) db 0
    dw 0xaa55