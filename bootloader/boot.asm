; 操作系统程序的加载分3批
; boot sector是第一批 由BIOS负责加载
; 第二批第三批由boot sector负责

; boot程序是放在软盘第一扇区的第一批程序
; 执行的时机是BIOS加载完该段程序后放到0x07c00地址上 并转移CPU执行权 即跳转到0x07c00这个地址进行执行
; 当前CPU是实模式 CPU中CS=0x0000 IP=0x7c00
; 因此该程序刚接收到CPU的执行权
; 告诉编译器程序的起始地址是0x07c00
org 0x7c00

base_of_stack             equ 0x7c00                       ;                boot sector程序运行时的段内偏移 也就是程序地址的offset

base_of_dest            equ 0x1000
offset_of_dest          equ 0x0000                         ;                地址=0x10000<<4+0x0000=0x10000

;                                                           偏移 长度[字节]                  内容
jmp short label_start                                      ; 0     2
nop                                                        ; 2     1        指令填充
%include "fat12.inc"                                       ; 3     59       FAT12文件系统构成
                                                           ; 62   448       引导代码\数据及其他信息

; @brief 软盘第1扇区中程序boot sect的实现
label_start:
    label_init:
        mov ax, cs                                         ;                代码段寄存器=0x0000
        mov ds, ax                                         ;                数据段寄存器=0x0000 数据从哪里来
        mov es, ax                                         ;                附加段寄存器=0x0000 数据到哪里去
        mov ss, ax                                         ;                堆栈段寄存器=0x0000
        mov sp, base_of_stack                              ;                栈基=0x7c00

    ; @brief 中断调用实现清屏功能
    ;       屏幕[(0,0)...(79,24)]这80行25列范围清屏
    ;       int 0x10 AH=0x60 指定范围的窗口滚动
    ;                        AL=滚动的列数 为0则实现清空屏幕功能
    ;                        BH=滚动后空出位置放入的属性
    ;                           BH[7]     字体闪烁 0=不闪烁 1=闪烁
    ;                           BH[4...6] 背景颜色 0=黑色 1=蓝色 2=绿色 3=青色 4=红色 5=紫色 6=棕色 7=白色
    ;                           BH[3]     字体亮度 0=字体正常 1=字体高亮
    ;                           BH[0...2] 字体颜色 0=黑色 1=蓝色 2=绿色 3=青色 4=红色 5=紫色 6=棕色 7=白色
    ;                        CH=滚动范围左上角坐标 列号
    ;                        CL=滚动范围左上角坐标 行号
    ;                        DH=滚动范围右下角坐标 列号
    ;                        DL=滚动范围右下角坐标 行号
    label_clear:
        mov ax, 0x0600                                     ;                AH=0x06 AL=0x00 清屏
        mov bx, 0x0700                                     ;                BH=0 000 0 111 滚动之后屏幕显示的属性
        mov cx, 0x0000                                     ;                CH=0x00 CL=0x00 左上角坐标=[0,0]
        mov dx, 0x184f                                     ;                DH=0x18 DL=0x4f 右下角坐标=[79,24]
        int 0x10                                           ;                中断调用

    ; @brief 光标重置到[0,0]位置
    ;       设定光标位置
    ;       中断号int 0x10
    ;       功能号AH=0x02
    ; @param DH=游标的列号(从0计)
    ; @param DH=游标的行号(从0计)
    ; @param BH=页码
    label_cursor:
        mov ax, 0x0200
        mov dx, 0x0000
        mov bx, 0x0000
        int 0x10

    ; @brief 屏幕上显示字符串 作为提示boot程序运行提示
    ;       显示一行字符串
    ;       中断号int 0x10
    ;       功能号AH=0x13
    ; @param AL=写入模式
    ;          Al=0x00 字符串属性由BL寄存器控制 字符串长度由CX寄存器控制(以Byte为单位) 光标位置不变(即写入前光标在哪写入后还在哪)
    ;          Al=0x01 字符串属性由BL寄存器控制 字符串长度由CX寄存器控制(以Byte为单位) 写入后光标在字符串尾端位置
    ;          Al=0x02 字符串属性由每个字符后面紧跟的字节提供 字符串长度由CX寄存器控制(以Word为单位) 光标位置不变(即写入前光标在哪写入后还在哪)
    ;          Al=0x03 字符串属性由每个字符后面紧跟的字节提供 字符串长度由CX寄存器控制(以Word为单位) 写入后光标在字符串尾端位置
    ; @param CX=字符串长度
    ; @param DH=游标的坐标行号(从0计)
    ; @param DL=游标的坐标列号(从0计)
    ; @param ES:BP=要显示字符串的内存地址
    ; @param BH=页码
    ; @param BL=字符串属性
    ;          BL[7]     字体闪烁 0=不闪烁 1=闪烁
    ;          BL[4...6] 背景颜色 0=黑色 1=蓝色 2=绿色 3=青色 4=红色 5=紫色 6=棕色 7=白色
    ;          BL[3]     字体亮度 0=字体正常 1=字体高亮
    ;          BL[0...2] 字体颜色 0=黑色 1=蓝色 2=绿色 3=青色 4=红色 5=紫色 6=棕色 7=白色
    label_print_msg:
        mov ax, 0x1301                                     ;                AH=0x13 AL=0x01
        mov cx, 12                                         ;                字符串长度
        mov dx, 0
        mov bx, 0x000f                                     ;                黑色背景 白字高亮不闪烁

        push ax                                            ;                AX寄存器要临时使用 先把中断调用的参数缓存到堆栈 中断调用之前再把参数出栈放到寄存器
        mov ax, ds
        mov es, ax
        mov bp, running_msg                                ;                字符串地址[DS:变量地址]
        pop ax

        int 0x10

    ; @brief 复位第一个软盘
    ;       重置磁盘驱动器 为下一次的读写软盘做准备
    ;       中断号int 0x13
    ;       功能号AH=0x00
    ; @param DL=驱动器号
    ;             软盘=[0x00...0x7f]
    ;               DL=0x00 代表第1个软盘驱动器(driverA:)
    ;               DL=0x01 代表第2个软盘驱动器(driverB:)
    ;               依次类推
    ;             硬盘=[0x80...0xff]
    ;               DL=0x80 代表第1个硬盘驱动器
    ;               DL=0x81 代表第2个硬盘驱动器
    ;               依次类推
    label_reset_floppy:
        xor ah, ah
        xor dl, dl
        int 0x13

    ; 通过FAT12文件系统加载指定文件
    %include "fat12read.inc"

    ; @brief loader程序加载完成的回调
    search_file_name_callback:
        jmp base_of_dest:offset_of_dest                   ;                跳转到loader程序

    ; 当前程序启动提示信息
    running_msg:      db "BOOT running",0
    ; FAT12加载文件需要的变量
    search_file_name: db "LOADER  BIN",0
    odd               db 0
    sector_no         dw 0
    root_dir_loop_sz  dw RootDirSectors

    times 512-2-($-$$) db 0                                ;                BIOS加载第一扇区的512Byte内容
                                                           ;                最后2byte分别是 0xaa和0x55
                                                           ;                那么整个第一扇区bootsect程序就是510Byte
                                                           ;                [129...509]被填充0
    dw 0xaa55                                              ;                0xaa和0x55两个byte标识该扇区是启动扇区