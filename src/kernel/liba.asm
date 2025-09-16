; 基于BIOS的中断实现函数导出给C直接调用
BITS 16

[global printCh]
[global clearScreen]

printCh:
    mov ax, 0xb800
    mov es, ax
    mov byte [es: 0x00], 'Y'
    retf

; 清屏
clearScreen:
    push ax
    mov ax, 0x0003
    int 0x10
    pop ax
    retf