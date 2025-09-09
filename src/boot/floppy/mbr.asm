; 软盘版本 
LOADER_SEG       equ 0x9000
LOADER_OFFSET    equ 0x0000
LOADER_SECTOR    equ 2 ; 软盘CHS的分区号是1-based

section .text
org 0x7c00

start:
    ; 初始化段寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00

    ; 屏显段用GS
    mov ax, 0xb800
    mov gs, ax

    ; 屏幕左上角打印 "MBR"
    mov byte [gs:0x00], 'I'
    mov byte [gs:0x01], 0x07
    mov byte [gs:0x02], ' '
    mov byte [gs:0x03], 0x07
    mov byte [gs:0x04], 'M'
    mov byte [gs:0x05], 0x07
    mov byte [gs:0x06], 'B'
    mov byte [gs:0x07], 0x07
    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0x07

    ; BIOS int0x13读软盘第2扇区到0x9000:0000
    ; 中断会把读出来的数据复制到ES:BX上
    mov ax, LOADER_SEG
    mov es, ax                 ; ES = 0x9000
    mov bx, LOADER_OFFSET      ; BX = 0x0000

    mov ah, 0x02               ; 功能号2表示读扇区
    mov al, 1                  ; 读1个扇区
    mov ch, 0                  ; 柱面号=0
    mov cl, LOADER_SECTOR      ; 扇区号=2
    mov dh, 0                  ; 磁头号=0

    int 0x13
    jc disk_error              ; 如果出错跳错误处理

    ; 跳转到loader程序入口
    jmp LOADER_SEG:LOADER_OFFSET

disk_error:
    ; 中断函数读盘失败显示ERR
    mov byte [gs:0x0A], 'E'
    mov byte [gs:0x0B], 0x4F
    mov byte [gs:0x0C], 'R'
    mov byte [gs:0x0D], 0x4F
    mov byte [gs:0x0E], 'R'
    mov byte [gs:0x0F], 0x4F
    hlt

times 510-($-$$) db 0
dw 0xaa55