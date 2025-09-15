; 操作系统内核入口
BITS 16
[extern startUp] ; 在libc中的函数
[extern shell] ; 在libc中的函数

global _start
_start:
    call dword startUp ; 调用libc里面的函数

; 等键盘输入
KeyBoard:
    mov ah, 0
    int 0x16
    cmp al, 0x0d ; 看看是不是回车键被按下
    jne KeyBoard
    call dword shell ; 按下了回车键就跳到shell入口 调用libc里面的函数
    jmp KeyBoard