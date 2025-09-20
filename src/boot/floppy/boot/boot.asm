; BIOS引导程序 放在磁盘引导扇区被加载 这个程序负责把loader程序从磁盘读到内存0x8000上然后跳过去
[SECTION mbr] ; 打上节标识 程序写完最后用$-$$就能知道从这到被编译后的地址有多大 用0凑够510字节 再补上2字节占位标识就完成了扇区引导区
org 0x7c00 ; 处理器跳过来到引导程序的时候还在实模式 它会在0x7c00上寻址执行 cs=0 ip=7c00 所以告诉编译器指定程序的起始地址 如果不指定的话编译器会抒把0作为程序的起始地址

BaseOfStack equ 0x7c00

; loader程序物理地址 0x1000:0 现在引导程序跑在16位实模式下 把loader程序从磁盘读到内存0x10000后还得依赖jmp跳转顺便重置cs=0x1000 ip=0
BaseOfLoader equ 0x1000
OffsetOfLoader equ 0

; 在FAT12引导扇区开头 必须是EB xx 90 EB是jmp指令保证跳过fat12的BPB直接执行代码 90中nop负责占位保证3字节固定格式
jmp L_Start
nop

%include "fat12.inc" ; 这里面是fat12的BPB 必须在引导扇区的偏移3上紧跟着jmp和nop

L_Start:
; 标准寄存器初始化
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, BaseOfStack ; BIOS不强制要求设置栈基址 因为引导程序中涉及栈操作不多 所以让栈倒扣在这向下生长没有问题
; 清屏
    mov ax, 0x0600
    mov bx, 0x0700
    mov cx, 0
    mov dx, 0x184f ; 文本模式 80行*25列
    int 0x10
; 光标设置
    mov ax, 0x0200
    xor bx, bx
    xor dx, dx
    int 0x10
; 打印调试
    mov ax, 0x1301 ; 功能号
    mov bx, 0x000f
    mov dh, StartBootMessageRow ; 打印在第几行
    xor dl, dl
    mov cx, StartBootMessageLen
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartBootMessage
    int 0x10
; 重置软驱
    xor ah, ah ;0号功能号
    xor dl, dl ; 驱动器号 软盘[0...7f] 硬盘[80...ff] 00表示第1个软盘驱动器driveA:
    int 0x13
; 通过文件系统读软盘里面的loader程序 下面封装BIOS中断开始读盘 fat12根目录的扇区是19#
    mov word [SectorNo], SectorNumOfRootDirStart

; fat12根目录共14个扇区 轮询查找
L_Search_In_Root_Dir_Begin:
    cmp word [RootDirSizeForLoop], 0 ; 根目录的14个扇区都读完还没找到LOADER.BIN文件就打印出来
    jz L_No_LoaderBin
    dec word [RootDirSizeForLoop] ; 在根目录中每找1次就减减
    ; 准备读扇区数据到内存上的参数 从19扇区开始找 把根目录里面文件名读到缓存0x8000上
    xor ax, ax
    mov es, ax ; es=0
    mov bx, 0x8000 ; bx=0x8000 把磁盘数据读到内存es:bx上
    mov ax, [SectorNo] ; 要读的扇区号
    mov cl, 1 ; 读1个扇区
    call Func_ReadOneSector ; ret把下一条要执行的指令地址入栈 然后跳过去执行函数 函数执行完ret会跳到刚才压入的待执行地址上
    mov si, LoaderFileName
    mov di, 0x8000
    cld ; 下面要在循环里面比较字符串 此时在0x8000上放着的是从根目录读到的文件名 要保证比较字符串方向是从0x8000低地址空间到高地址空间
    ; 1个扇区512字节 1个目录项32字节 那么1个扇区容纳512/32=16个目录项
    ; 16=0x10 表示的是1个根目录扇区有16个根目录项目 
    ; 也就是说这边会套2层循环 外层是16个目录项 内层是每个文件名称11字节 对比每个目录项的文件名去找LOADER.BIN
    mov dx, 0x10
L_Search_For_LoaderBin:
    cmp dx, 0
    jz L_Goto_Next_Sector_In_Root_Dir ; 1个扇区的16个目录项都找完了就继续下一个扇区直到14个根目录扇区全部找一遍
    dec dx
    mov cx, 11 ; 11表示是的文件名+扩展名长度是11
L_Cmp_FileName:
    cmp cx, 0 ; LOADER.BIN文件名完全匹配就算找到了对应的目录项
    jz L_FileName_Found
    dec cx
    lodsb ; 拿到ds:si的字符放到al里面 就是目标文件名的字符 然后跟扇区根目录的文件名比较
    cmp al, byte [es:di] ; 文件名逐个字符比较
    jz L_Go_On
    jmp L_Different ; 文件名不一样 说明目录项不是要找的
L_Go_On:
    inc di ; 指向内存上的指针后移 准备比较扇区中根目录里面拿到的文件名的下一个字符
    jmp L_Cmp_FileName
L_Different:
    ; 现在出现了根目录项文件名不匹配情况 1个根目录14个扇区 1个扇区512字节 1个目录项32字节 1个根目录的1个扇区16个目录项
    ; 现在1个文件名不匹配 也就是当前目录项不是要找的 那就去下一个目录项目
    ; 先and与抹掉抵5位 就是跳到当前目录项的起始地址 然后add跳32个字节到下一个目录项的起始地址
    and di, 0xffe0
    add di, 0x20
    mov si, LoaderFileName
    jmp L_Search_For_LoaderBin
L_Goto_Next_Sector_In_Root_Dir:
    add word [SectorNo], 1
    jmp L_Search_In_Root_Dir_Begin

; 找不到loader程序 打印提示信息然后夯在这
L_No_LoaderBin:
    mov ax, 0x1301
    mov bx, 0x008c
    mov dx, NoLoaderMessageRow ; 打印在第几行
    xor dl, dl
    mov cx, NoLoaderMessageLen
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, NoLoaderMessage
    int 0x10
    jmp $
L_FileName_Found:
    mov ax, RootDirSectors
    and di, 0xffe0
    add di, 0x001a
    mov cx, word [es:di]
    push cx
    add cx, ax
    add cx, SectorBalance
    mov ax, BaseOfLoader
    mov es, ax
    mov bx, OffsetOfLoader
    mov ax, cx
L_Go_On_Loading_File:
    push ax
    push bx
    mov ah, 0x0e
    mov al, '.'
    mov bl, 0x0f
    int 0x10
    pop bx
    pop ax
    mov cl, 1
    call Func_ReadOneSector
    pop ax
    call Func_GetFATEntry
    cmp ax, 0x0fff
    jz L_File_Loaded
    push ax
    mov dx, RootDirSectors
    add ax, dx
    add ax, SectorBalance
    add bx, [BPB_BytesPerSec]
    jmp L_Go_On_Loading_File
L_File_Loaded:
    jmp BaseOfLoader:OffsetOfLoader ; loader程序放在0x10000上 跳过去

; 把1个扇区读到内存上
; 入参 ax-扇区编号 读哪个扇区
;     cl-读几个扇区
;     es:bx-磁盘数据读到内存的位置
; BIOS中断受理的是CHS格式的扇区 而现在方法传进来的扇区参数是LBA的 所以这个方法在调用BIOS中断服务前要进行LBA转换CHS
; 用LBA扇区号/每磁道扇区数得到商和余数
; 那么CHS 柱面号=商右移1 磁头号=商 起始扇区号=余数+1
Func_ReadOneSector:
    push bp ; 保存调用者的bp帧指针 此时栈里面内容在自己上面还有调用方call指令压入的返回地址 等自己函数内容处理完 出栈bp恢复调用方的bp 再ret出栈返回地址跳过去
    mov bp, sp ; 建立当前函数自己的栈帧
    sub esp, 2 ; 在栈里面开2字节的局部变量空间
    mov byte [bp - 2], cl ; 局部变量入栈 读几个扇区
    push bx ; 局部变量入栈 每个磁道的扇区数量
    mov bl, [BPB_SecPerTrk] ; 每个磁道的扇区数量
    div bl ; 汇编除法规则 ax/bl 商在al 余数在ah
    inc ah ; ah=余数+1
    mov cl, ah ; cl=CHS起始扇区号=余数+1
    mov dh, al ; dh=商=磁头号
    shr al, 1
    mov ch, al ; ch=CHS柱面号=商>>1
    and dh, 1 ; 软盘只有2个磁头 与1求出 dh=磁头号
    pop bx ; 此时bx出栈 栈里面的局部变量只有1个 表示读几个扇区
    mov dl, [BS_DrvNum] ; dl=驱动器号
; BIOS中断读盘
; 入参
; ah=中断功能号2
; al=读入的扇区数
; ch=柱面号 cl=扇区号
; dh=磁头号 dl=驱动器号
; 出参
; es:bx=数据缓冲区
L_Go_On_Reading:
    mov ah, 2 ; 中断功能号2
    mov al, byte [bp - 2] ; 栈里面有1个局部变量表示读几个扇区
    int 0x13
    jc L_Go_On_Reading
    add esp, 2 ; 销毁栈帧中局部变量空间
    pop bp ; 栈里面还有刚进被调用函数时存着的老bp 出栈恢复调用方的bp
    ret ; 此时自己函数的栈帧已经没有了 还有调用方call指令放进来的返回地址 ret将这个地址出栈跳过去回到调用方

; fat表项占12bit 每3个字节存储2个fat表项 fat表项具有奇偶性 根据当前fat表项索引出下一个fat表项
Func_GetFATEntry:
    push es
    push bx
    push ax
    xor ax, ax
    mov es, ax
    pop ax
    mov byte [Odd], 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    cmp dx, 0
    jz L_Even
    mov byte [Odd], 1
L_Even:
    xor dx, dx
    mov bx, [BPB_BytesPerSec]
    div bx
    push dx
    mov bx, 0x8000
    add ax, SectorNumOfFAT1Start
    mov cl, 2
    call Func_ReadOneSector ; near call
    pop dx
    add bx, dx
    mov ax, [es:bx]
    cmp byte [Odd], 1
    jnz L_Even_2
    shr ax, 4
L_Even_2:
    and ax, 0x0fff
    pop bx
    pop es
    ret

; 临时变量
RootDirSizeForLoop dw RootDirSectors ; fat12根目录占14个扇区
SectorNo dw 0 ; 读盘的时候要知道读哪个扇区 0-based
Odd db 0

LoaderFileName: db "LOADER  BIN", 0 ; 定义字符串 这个是用来跟fat12根目录区里面读到的文件名比较的 0是字符串结束符 在根目录中文件名的规则是8+3 前8字节是文件名 后3字节是扩展名
; 要显示的字符串 长度 显示在第几行
StartBootMessage: db "START BOOT"
StartBootMessageLen equ $-StartBootMessage
StartBootMessageRow equ 0

NoLoaderMessage: db "ERROR: No LOADER Found"
NoLoaderMessageLen equ $-NoLoaderMessage
NoLoaderMessageRow equ 1

; 启动盘引导扇区
    times 510-($-$$) db 0 ; 这行被编译后的地址到这节的地址也就是0x7c00的大小 用0补齐510个字节 再填充2字节占位标识保证引导扇区大小是512字节
    ; 第1扇区用55 aa结尾标识这个扇区是引导扇区 intel处理器是小端序 写成1个word是0xaa55
    db 0x55
    db 0xaa