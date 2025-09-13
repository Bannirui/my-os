; 操作系统内核入口
BITS 16
[extern startUp] ; 在lib.c中的函数
[extern shell] ; 在lib.c中的函数

global _start
_start:
    call dword startUp ; 调用C写的函数

; 等键盘输入命令
KeyBoard:
    mov ah,0
    int 0x16
    cmp al,0x0d ; enter键
    jne KeyBoard
    call dword shell ; 系统启动后按enter键进入shell
    jmp KeyBoard