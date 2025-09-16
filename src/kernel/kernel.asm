; 操作系统内核入口
BITS 16

[extern startUp] ; 在libc中的函数

global _start
_start:
    call dword startUp ; near call调用libc里面的函数
    hlt