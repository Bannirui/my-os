org 0x7c00

    mov ax, cs
    mov ds, ax
    mov es, ax

    call Disp
    hlt

Disp:
    mov ax, BootMsg     ; 字符串偏移
    mov bp, ax
    mov ax, cs
    mov es, ax          ; ES = CS, ES:BP 指向字符串

    mov cx, BootMsgLen  ; CX = 字符串长度
    mov ax, 0x1301      ; 功能号: 显示字符串
    mov bx, 0x0007      ; 页号=0, 属性=灰底白字
    mov dl, 0           ; 光标列 (0)
    int 0x10
    ret

BootMsg: db "hello world"
BootMsgLen equ $ - BootMsg

times 510-($-$$) db 0
dw 0xaa55
