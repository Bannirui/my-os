[BITS 16]

[global getChar]

; char geChar()
getChar:
    pusha
    mov ah, 0 ; 功能号
    int 0x16
    xor ah, ah ; 读到的字符串在al上 把ax的高8位置0
    popa
    ret ; ip出栈跳过去