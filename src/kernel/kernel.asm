; 操作系统内核入口
BITS 16

[extern startUp] ; 在libc中的函数

global _start
_start:
    call startUp ; 调用libc里面的函数