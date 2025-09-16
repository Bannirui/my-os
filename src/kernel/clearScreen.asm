[BITS 16]
global clearScreen

; void clearScreen();
clearScreen:
    push ax ; 下面要用到ax寄存器 先保存
    mov ax, 0x0003
    int 0x10
    pop ax ; 恢复
    ret