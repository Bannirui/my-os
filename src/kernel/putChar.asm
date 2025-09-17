[BITS 16]

[global putChar]

; void putChar(char ch)
putChar:
    ; 高地址到低地址空间 栈底到栈顶 ip+要显示的字符
    pusha ; 通用寄存器16字节
    ; 此时 栈里面 ip+要显示的字符+通用寄存器
    mov bp, sp
    mov al, [bp+16+2] ; 参数 要显示的字符
    mov ah, 0x0e
    mov bh, 0
    int 0x10
    popa
    ret ; ip出栈跳过去