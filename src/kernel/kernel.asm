; 操作系统内核入口
BITS 16

; 在libc中的函数
[extern startUp]
[extern shell]

global _start
_start:
    call dword startUp ; near call调用libc里面的函数

; 等键盘输入回车进到shell
KeyBoard:
    mov ah, 0
    int 0x16
    cmp al, 0x0d
    jne KeyBoard ; 不是回车就一直等
    call dword shell
    jmp KeyBoard