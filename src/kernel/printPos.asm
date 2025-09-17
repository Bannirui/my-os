[BITS 16]
global printPos

; void printPos(char* msg, uint16_t len, uint16_t row, uint16_t col);
printPos:
    ; 此时栈里面 ip+col+row+len+msg
    pusha ; 保存 AX,BX,CX,DX,SI,DI,BP,SP 通用寄存器16字节
    ; 此时栈里面 ip+col+row+len+msg+通用寄存器
    mov si, sp
    add si, 16 + 2 ; 指向msg
    mov bp, [si] ; msg
    mov cx, [si + 2] ; len
    mov dh, [si + 4] ; row
    mov dl, [si + 6] ; col
    ; 设置ES=DS
    mov ax, ds
    mov es, ax
    mov ax, 0x1301 ; 功能号
    mov bh, 0x00 ; 页号
    mov bl, 0x07 ; 样式
    mov bp, bp
    int 0x10
    popa
    ret ; 弹出栈ip 跳到段内ip偏移上 也就是调用的地方