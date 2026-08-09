bits 16
org 0x7c00

start:
    mov ah, 0x0e
    mov al, 'H'
    int 0x10

    mov al, 'i'
    int 0x10


hang:
    jmp hang


; 填充到510字节
times 510-($-$$) db 0

; boot signature
dw 0xaa55