; 基于BIOS的中断实现函数导出给C直接调用
BITS 16

[global getch]
[global putchar]
[global printInPos]

; char getch();
; 通过BIOS的16号中断从键盘读取字符 调用方就可以拿到键盘输入
getch:
    mov ah, 0 ; 功能号
    int 0x16
    mov ah, 0 ; 读取字符 al存的是读到的字符 同时设置ah为0 为返回作准备
    retf

; void putchar(char c);
; 通过BIOS的10号中断 在光标处打印一个字符到屏幕
putchar:
    pusha ; 所有参数全部压栈占16字节
    mov bp, sp
    add bp, 16+4 ; 返回地址被压栈(cs占2字节 ip占2字节) 后面才是参数(编译汇编指定位宽32 每个4字节)
    mov al, [bp] ; al=要打印的字符
    mov bh, 0 ; bh=页码
    mov ah, 0x0e ; 中断功能号
    int 0x10
    popa
    retf

; 在指定的位置显示字符串
; void printInPos(char* str, int len, int row, int col);
printInPos:
    pusha ; 会往栈里面压入16字节 AX, CX, DX, BX, SP, BP, SI, DI 然后才是返回地址(返回地址是cs占2字节 ip占2字节)和参数(编译汇编时候会指定位宽32 每个参数占2字节 字符串地址 长度 行号 列号)
    mov si, sp            	;use SI
    add si, 16 + 4        	;First parameter address
    mov ax, cs
    mov ds, ax
    mov bp, [si]          	;BP = offset
    mov ax, ds            	;
    mov es, ax            	;ES = DS
    mov cx, [si + 4]      	;CX = String length
    mov ax, 0x1301         	;functon number AH = 13 AL = 01H,Indicates that the cursor displays the end of the string
    mov bx, 0x0007         	;BH = page number BL = 07 black and white
    mov dh, [si + 8]      	;Line number= 0
    mov dl, [si + 12]     	;Column number = 0
    int 0x10               	;BIOS 10H interrupt call
    popa
    retf ; 返回到地址cs:ip上去