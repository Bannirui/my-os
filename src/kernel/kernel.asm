; 操作系统内核入口
BITS 16
[extern startUp] ; 在libc中的函数

global _start
_start:
    mov ax, 0xb800
    mov es, ax
    mov byte [es: 0x00], 'X'
    call dword startUp ; 调用libc里面的函数
    hlt