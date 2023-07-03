org 0x7c00 ;程序的起始地址

BaseOfStack equ 0x7c00

Label_Start:
    mov ax, cs ;代码段寄存器=0x0000
    mov ds, ax ;数据段寄存器
    mov es, ax ;附加段寄存器
    mov ss, ax ;堆栈段寄存器
    mov sp, BaseOfStack ;栈基

;指定范围滚动窗口实现清屏 滚动80行 25列
    mov ax, 0x0600 ;AH=0x06 中断的主功能号 上卷指定范围的窗口
    mov bx, 0x0700 ;BH=00000111 滚动后空出来的位置放入的属性
                   ;bit7 0:字体不闪烁
                   ;bit4-6 0:背景黑色;
                   ;bit3 0:字体亮度正常
                   ;bit0-2 7:字体白色
    mov cx, 0 ;CH=0x00 要滚动的左上角 列号
              ;CL=0x00 要滚动的左上角 行号
              ;左上[0,0]
    mov dx, 0x184f ;DH=0x18 要滚动的右下角 列号
                   ;DL=0x4f 要滚动的右下角 行号
                   ;右下[79,24]
    int 0x10 ;0x10中断

;重置游标在屏幕左上角
    mov ax, 0x0200 ;AH=0x02 中断的主功能号 设置屏幕光标位置
    mov bx, 0 ;BH=页码
    mov dx, 0 ;DH=游标的列
              ;DL=游标的行
    int 0x10 ;0x10中断

;屏幕上显示信息
    mov ax, 0x1301 ;AH=0x13 中断的主功能号 显式字符串
                   ;AL=0x01 光标移动至字符串尾位置
                   ;        BL寄存器提供字符串属性
    mov bx, 0x000f ;BH=0x00
                   ;BL=0x0f 字符属性\颜色属性 0000 1111
                   ;                       bit0-2 字体颜色 3=青色
                   ;                       bit3 字体亮度 1=字体高亮度
                   ;                       bit4-6 背景颜色 0=黑色
                   ;                       bit7 字体闪烁 0=字体闪烁
    mov dx, 0 ; DH=0x00 游标的行号
              ; DL=0x00 游标的列号
    mov cx, 16 ;要显示的字符串长度
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartBootMessage ;ES:BP 字符串的内存地址
    int 0x10 ;0x10中断

;reset floppy 复位软盘
    xor ah, ah ;AH=0 0x13中断 AH=0x00 重置软盘驱动器 为下一次读写软盘做准备
    xor dl, dl ;DL=0 驱动器号 DL=0x00代表第一个软盘驱动器 driverA:
               ;             0x00-0x7f 软盘
               ;             0x80-0xff 硬盘
    int 0x13 ;0x13中断

    jmp $ ;loop

StartBootMessage: db "Hello Dingrui..." ;定义字符串

;fill 0 til whole sector
    times 512-2-($-$$) db 0 ;BIOS加载第一扇区的512Byte内容
                          ;最后2byte分别是 0xaa和0x55
                          ;那么整个第一扇区bootsect程序就是510Byte
    dw 0xaa55 ;0xaa和0x55两个标识byte

