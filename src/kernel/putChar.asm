[BITS 16]

[global putChar]

; void putChar(char ch)
putChar:
    pusha
    mov bp, sp
    add bp, 16 + 2 ; 指向参数 要显示的字符
    mov al, [bp]
    mov bh, 0 ; 页码
    mov ah, 0x0e ; 中断功能号
    int 0x10
    popa
    ret