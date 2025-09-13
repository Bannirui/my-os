BITS 16

[global printInPos]
[global putchar] ; 输出一个字符
[global getch] ; 获得键盘的输入

getch:
    mov ah, 0 ; 功能号
    int 0x16
    mov ah, 0 ; 读取字符 al存的是读到的字符 同时设置为0 为返回作准备
    retf

putchar: ; 在光标处打印一个字符到屏幕
    pusha
    mov bp, sp
    add bp, 16+4 ; 参数地址
    mov al, [bp] ; al=要打印的字符
    mov bh, 0 ; bh=页码
    mov ah, 0x0e ; 中断功能号
    int 0x10
    popa
    retf

printInPos: ; 在指定的位置显示字符串
    pusha
    mov si, sp ; si为参数寻址
    add si, 16+4 ; 首个参数地址
    mov ax, cs
    mov ds, ax
    mov bp, [si] ; bp指向当前串的偏移地址
    mov ax, ds ; ES:BP=串地址
    mov es, ax
    mov cx, [si+4] ; cx=串长
    mov ax, 0x1301 ; ah=13功能号 al=01表示字符串显示完毕后光标应该置于字符串尾
    mov bx, 0x0007 ; bh=0表示0号页 bl=07表示黑底白字
    mov dh, [si+8] ; 行号=0
    mov dl, [si+12] ; 列号=0
    int 0x10 ; 调用BIOS中断
    popa
    retf