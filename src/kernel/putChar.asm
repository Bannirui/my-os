[BITS 16]

[global putChar]

; void putChar(char ch)
putChar:
    push bp ; 下面要用到bp 压栈保存 调用完后再恢复
    push ax ; ax暂存 这个时候一个6字节内容在栈里面 call压入的2字节ip+这4字节

    mov  bp, sp ; 栈顶往低地址方向增加了6字节
    mov al, [bp+6] ; 参数 要显示的字符
    mov ah, 0x0e
    mov bh, 0
    int 0x10

    pop ax ; ax出栈恢复
    pop bp ; bp出栈恢复
    ret ; ip出栈跳过去