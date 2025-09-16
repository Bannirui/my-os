; 基于BIOS的中断实现函数导出给C直接调用
BITS 16

[global printCh]

printCh:
    mov ax, 0xb800
    mov es, ax
    mov byte [es: 0x00], 'Y'
    ret