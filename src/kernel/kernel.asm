; 操作系统内核入口
BITS 16
[extern startUp] ; 在libc中的函数
[extern shell] ; 在libc中的函数

global _start
_start:
    mov ax, 0xb800
    mov es, ax
    mov byte [es:0x00], 'X'
    mov byte [es:0x01], 0x07

    call dword startUp ; 调用C写的函数

; 等键盘输入命令
KeyBoard:
    mov ah, 0
    int 0x16
    cmp al, 0x0d ; enter键
    jne KeyBoard
    call dword shell ; 系统启动后按enter键调用libc中的shell函数
    jmp KeyBoard