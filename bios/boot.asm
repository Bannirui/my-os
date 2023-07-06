; 操作系统程序的加载分3批
; boot sector是第一批 由BIOS负责加载
; 第二批第三批由boot sector负责

    org 0x7c00 ; boot程序是放在软盘第一扇区的第一批程序
               ; 执行的时机是BIOS加载完该段程序后放到0x07c00地址上 并转移CPU执行权 即跳转到0x07c00这个地址进行执行
               ; 当前CPU是实模式 CPU中CS=0x0000 IP=0x7c00
               ; 因此该程序刚接收到CPU的执行权
               ; 告诉编译器程序的起始地址是0x07c00

BaseOfStack             equ 0x7c00                         ; boot sector程序运行时的段内偏移 也就是程序地址的offset

BaseOfLoader            equ 0x1000
OffsetOfLoader          equ 0x0000                         ; loader程序的起始地址=0x10000<<4+0x0000=0x10000

SectorNumOfRootDirStart equ 19                             ; 根目录的起始扇区号
RootDirSectors          equ 14                             ; 根目录占用扇区数 扇区[19...32]
SectorNumOfFAT1Start    equ 1                              ; FAT1起始扇区号 扇区[1...9]
SectorBalance           equ 17                             ; 
ClusMappingSector       equ 31                             ; FAT表中0跟1不可用 也就是说FAT表项从2开始 即簇号下标[2...]映射数据区扇区[33...] 已知簇号=x 则扇区=x-2+33=x+31

;                                                           偏移 长度[字节]                  内容

    jmp short Label_Start                                  ; 0     2
    nop                                                    ; 2     1        指令填充

; 1.44M的标准软盘 2880个分区 每个分区512B 大小=2880*512=1474560Byte=1440KB

; FAT12文件系统
; 为了加载loader程序和内核程序 需要一个文件系统
; 将软盘格式化成FAT12文件系统 FAT12文件系统会对软盘扇区进行结构化管理 将扇区划分为4个部分
; 1 引导扇区
; 2 FAT表    FAT12文件系统的FAT表中表项宽度是12bit
; 3 根目录区
; 4 数据区
;
; 组成部分 [Boot Sector] [ FAT tables ] [Root Directory] [Data Area]
;                         FAT1  FAT2
; 扇区号        0        1...9 10...18      19...32       33...2879
;
; FAT1表占9个扇区 总大小=4608Byte
; 每个簇占12bit 则FAT1表中共3072个簇 数据区共计2847个扇区 每个簇映射一个扇区 足可以保证访问所有的数据区
; 并且每个簇12个bit 数据范围=[0...4096] 可以保证簇能够访问到FAT表中每个簇
; 每12bit为1个簇 FAT1被划分为一个数组 共3072个数据项 数组脚标=[0...3071] 每个数组元素都是12bit 代表的是下一个指向的簇脚标
; 簇脚标0和簇脚标1不可用
; 簇值=0xfff标识结尾
;
; 根目录区占14个扇区 [19...32]
; 每个根目录项占32B
; 根目录区中每个扇区可容纳512/32=16个根目录项
; 
;     bit位     [0...7] [8...10]   11   [12...21]    [22...23]      [24...25]    [26...27]  [28...31]
; 根目录项组成部分  文件名   扩展名  文件属性   保留位    最后一次写入时间  最后一次写入日期   起始簇号    文件大小
;     长度         8        3       1       10            2              2            2          4

    ; 引导扇区 FAT12文件系统的引导扇区包含引导程序和FAT12文件系统的整个组成构成信息
    ; 内存中定义变量 描述FAT12文件系统的构成信息
    BS_OEMName      db 'MY-BOOT '                          ; 3     8        生产厂商名
    BPB_BytesPerSec dw 512                                 ; 11    2        每扇区字节数
    BPB_SecPerClus  db 1                                   ; 13    1        每簇扇区数 由于每个扇区的容量只有512B 过小的扇区容量可能会导致软盘读写次数过于频繁 从而引入簇的概念 簇将2的整数次方个扇区作为一个数据存储单元 也就是说簇是FAT类文件系统的最小数据存储单位
    BPB_RsvdSecCnt  dw 1                                   ; 14    2        保留扇区数 不能是0 保留扇区起始于FAT12文件系统的第一个扇区 对于FAT12而言此位必须为1 也就意味着引导扇区包含在保留扇区内 所以FAT表从软盘的第二个扇区开始
    BPB_NumFATs     db 2                                   ; 16    1        FAT表的份数 指定FAT12文件系统中FAT表的份数 任何FAT类文件系统都建议将该值置为2 FAT表2是FAT表1的备份 因此FAT1和FAT2的数据是一样的
    BPB_RootEntCnt  dw 224                                 ; 17    2        根目录可容纳的目录项数 对于FAT12文件系统而言 整个值*32必须是BPB_BytesPerSec的偶数倍 224*32=7168=512*14
    BPB_TotSec16    dw 2880                                ; 19    2        总扇区数 如果这个值是0 那么BPB_TotSec32就必须得是非0
    BPB_Media       db 0xf0                                ; 21    1        介质描述符 对于不可移动的存储介质而言标准值是0xf8 对于可移动存储介质常用值是0xf0
    BPB_FATSz16     dw 9                                   ; 22    2        每FAT扇区数 记录着每个FAT表占用多少个扇区 FAT表1和FAT表2拥有相同容量 
    BPB_SecPerTrk   dw 18                                  ; 24    2        每磁道扇区数
    BPB_NumHeadds   dw 2                                   ; 26    2        磁头数
    BPB_HiddSec     dd 0                                   ; 28    4        隐藏扇区数
    BPB_TotSec32    dd 0                                   ; 32    4        如果上面BPB_TotSec16为0就用这个值记录扇区数
    BS_DrvNum       db 0                                   ; 36    1        驱动器号 int 0x13系统调用读取磁盘扇区内容时要用到这个参数
    BS_Reserved1    db 0                                   ; 37    1        未使用
    BS_BootSig      db 0x29                                ; 38    1        扩展引导标记
    BS_VolID        dd 0                                   ; 39    4        卷序列号
    BS_VolLab       db 'boot loader'                       ; 43    11       卷标 在windows或者linux系统中显示的磁盘名
    BS_FileSysType  db 'FAT12   '                          ; 54    8        文件系统类型
                                                           ; 62   448       引导代码\数据及其他信息
; @bref 软盘第1扇区中程序boot sector的实现
Label_Start:
    mov ax, cs                                             ;                代码段寄存器=0x0000
    mov ds, ax                                             ;                数据段寄存器=0x0000 数据从哪里来
    mov es, ax                                             ;                附加段寄存器=0x0000 数据到哪里去
    mov ss, ax                                             ;                堆栈段寄存器=0x0000
    mov sp, BaseOfStack                                    ;                栈基=0x7c00

; @bref 中断调用实现清屏功能
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
Label_Clear:
    mov ax, 0x0600                                         ;                AH=0x06 AL=0x00 清屏
    mov bx, 0x0700                                         ;                BH=0 000 0 111 滚动之后屏幕显示的属性
    mov cx, 0                                             ;                CH=0x00 CL=0x00 左上角坐标=[0,0]
    mov dx, 0x184f                                         ;                DH=0x18 DL=0x4f 右下角坐标=[79,24]
    int 0x10                                               ;                中断调用

; @bref 中断调用实现重置光标位置功能
;       光标重置到[0,0]位置
;       int 0x10 AH=0x02 设定光标位置
;                        DH=游标的列号(从0计)
;                        DH=游标的行号(从0计)
;                        BH=页码
Label_Cursor:
    mov ax, 0x0200                                         ;                AH=0x02 中断的主功能号
    mov dx, 0                                             ;                DH=0x00 DL=0x00
    mov bx, 0                                             ;                BH=0x00
    int 0x10                                               ;                中断调用

; @bref 屏幕上显示字符串
;       屏幕上显示提示信息
;       int 0x10 AH=0x13 显示一行字符串
;                        AL=写入模式
;                           Al=0x00 字符串属性由BL寄存器控制 字符串长度由CX寄存器控制(以Byte为单位) 光标位置不变(即写入前光标在哪写入后还在哪)
;                           Al=0x01 字符串属性由BL寄存器控制 字符串长度由CX寄存器控制(以Byte为单位) 写入后光标在字符串尾端位置
;                           Al=0x02 字符串属性由每个字符后面紧跟的字节提供 字符串长度由CX寄存器控制(以Word为单位) 光标位置不变(即写入前光标在哪写入后还在哪)
;                           Al=0x03 字符串属性由每个字符后面紧跟的字节提供 字符串长度由CX寄存器控制(以Word为单位) 写入后光标在字符串尾端位置
;                        CX=字符串长度
;                        DH=游标的坐标行号(从0计)
;                        DL=游标的坐标列号(从0计)
;                        ES:BP=要显示字符串的内存地址
;                        BH=页码
;                        BL=字符串属性
;                           BL[7]     字体闪烁 0=不闪烁 1=闪烁
;                           BL[4...6] 背景颜色 0=黑色 1=蓝色 2=绿色 3=青色 4=红色 5=紫色 6=棕色 7=白色
;                           BL[3]     字体亮度 0=字体正常 1=字体高量
;                           BL[0...2] 字体颜色 0=黑色 1=蓝色 2=绿色 3=青色 4=红色 5=紫色 6=棕色 7=白色
Label_Print_Msg:
    mov ax, 0x1301                                         ;                AH=0x13 AL=0x01
    mov cx, 12                                             ;                要显示的字符串长度
    mov bx, 0x000f                                         ;                BH=0x00 BL=0 111 1 010
    mov dx, 0                                             ;                DH=0x00 DL=0x00
    push ax                                                ;                AX寄存器要临时使用 先把中断调用的参数缓存到堆栈
    mov ax, ds
    mov es, ax                                             ;                ES=数据段地址
    mov bp, StartBootMessage                               ;                BP=字符串内存地址偏移
    pop ax                                                 ;                恢复AX寄存器数据
    int 0x10                                               ;                中断调用

; @bref 复位软盘
;       重置磁盘驱动器 为下一次的读写软盘做准备
;       int 0x13 AH=0x00
;                        DL=驱动器号
;                           软盘=[0x00...0x7f]
;                             DL=0x00 代表第1个软盘驱动器(driverA:)
;                             DL=0x01 代表第2个软盘驱动器(driverB:)
;                           硬盘=[0x80...0xff]
;                             DL=0x80 代表第1个硬盘驱动器
;                             DL=0x81 代表第2个硬盘驱动器
Label_Reset_Floppy:
    xor ah, ah                                             ;                AH=0x00
    xor dl, dl                                             ;                DL=0x00
    int 0x13                                               ;                中断调用

    mov word[SectorNo], SectorNumOfRootDirStart            ;                从根目录起始扇区号19开始搜索loader.bin程序文件

; @bref 根目录占14个扇区 轮询根目录中扇区
;       从19号扇区开始 1次读1个扇区 读取指定扇区号内容放到内存0x08000
Lable_Search_In_Root_Dir_Begin:
    cmp word[RootDirSizeForLoop], 0
    jz Label_No_LoaderBin                                  ;                用于退出轮询 遍历14次
    dec word[RootDirSizeForLoop]
    
    mov ax, 0x0000
    mov es, ax
    mov bx, 0x8000                                         ;                ES:BX=>0x08000作为读取缓冲区
    mov ax, [SectorNo]                                     ;                根目录的起始扇区号19
    mov cl, 1                                              ;                读取的扇区数量
    call Func_ReadOneSector                                ;                读取扇区
    mov si, LoaderFileName                                 ;                loader.bin文件名 相当于源地址 后面要使用lodsb将这个内存上的文件名读取到寄存器中跟目的地址内容去比较
    mov di, 0x8000                                         ;                内存缓冲区 存储着从根目录中读取出来的扇区内容 可以从中解析出文件名 相当于目的地址
    cld                                                    ;                让DF标志位=0 下面的lodsb指令依赖DF标志位 因此提前置位
    mov dx, 0x10                                           ;                每个扇区中有16个根目录项

; @bref 解析每个根目录项 是否存在loader.bin文件
;       1个扇区16个根目录 即1个扇区轮询检索16次
Label_Search_For_LoaderBin:
    cmp dx, 0                                              ;                轮询16个根目录项
    jz Label_Goto_Next_Sector_In_Root_Dir                  ;                在1个扇区之中有16个根目录项 轮询没有找到loader文件 继续检索根目录中的下一扇区
    dec dx
    mov cx, 11                                             ;                根目录项前11个Byte轮询出来跟文件名比较

; @bref 解析1个根目录项中的前11B 文件名占8B 扩展名占3B
;       考察解析出来的文件名是否是loader.bin程序文件
Label_Cmp_FileName:
    cmp cx, 0
    jz Label_fileName_Found                                ;                根目录项中前11个byte完全匹配loader.bin程序的文件名
    dec cx
    lodsb                                                  ;                从DS:SI 将SI指向的内存数据读取到累加器AL中 读完1个byte后将SI自动加1
    cmp al, byte[es:di]                                    ;                逐个byte比较文件名源地址和目标地址上内容
    jz Label_Go_On
    jmp Label_Different                                    ;                1个根目录项没有匹配成功 准备解析下一个根目录项

; @bref 缓冲区目标地址上指针后移1个byte 准备比较下一个字符
Label_Go_On:
    inc di
    jmp Label_Cmp_FileName

; @bref 根目录项前11B解析出来没有匹配上loader.bin程序名
;       继续解析比较下一个根目录项
;       根目录区占14个扇区 扇区编号[19...32]
;       每个扇区占512B 每个根目录项占32B 也就是说1个扇区16个根目录项
;       从软盘读取数据的时候是从根目录中1个1个扇区读出来放在内存缓冲区的
;       DS=0x0000 offset=0x8000
;       那么1个扇区的根目录项在内存中的布局如下
;        起始地址   根目录项   结束地址      DI指针 文件名地址区间前11B 实际肯定是前10B 否则当前根目录项就匹配上了
;       [0x8000] [根目录项0] [0x801f]     [0x8000...0x8009]
;       [0x8020] [根目录项1] [0x803f]     [0x8020...0x8029]
;       [0x8040] [根目录项2] [0x805f]     [0x8040...0x8049]
;       [0x8060] [根目录项3] [0x807f]     [0x8060...0x8069]
;       [0x8080] [根目录项4] [0x809f]     [0x8080...0x8089]
;       [0x80a0] [根目录项5] [0x80bf]     [0x80a0...0x80a9]
;       [0x80c0] [根目录项6] [0x80df]     [0x80c0...0x80c9]
;       [0x80e0] [根目录项7] [0x80ff]     [0x80e0...0x80e9]
;       [0x8100] [根目录项8] [0x81ff]     [0x8100...0x8109]
;       [0x8120] [根目录项9] [0x813f]     [0x8120...0x8129]
;       [0x8140] [根目录项10] [0x815f]    [0x8140...0x8149]
;       [0x8160] [根目录项11] [0x817f]    [0x8160...0x8169]
;       [0x8180] [根目录项12] [0x819f]    [0x8180...0x8180]
;       [0x81a0] [根目录项13] [0x81bf]    [0x81a0...0x81a9]
;       [0x81c0] [根目录项14] [0x81df]    [0x81c0...0x81c9]
;       [0x81e0] [根目录项15] [0x81ff]    [0x81e0...0x81e9]
;
;       假设每个根目录项的起始地址为x 则DI指针的活动范围为[x...x+9] 只要把x的后4位置为0就回到了首地址
;       每个根目录项占32B 也就是每2个根目录项首地址间隔0x20
Label_Different:
    and di, 0xffe0                                         ;                抹掉缓冲期目的地址的后4位 指向当前根目录项首地址
    add di, 0x20                                         ;                指向缓冲区中下一个根目录项
    mov si, LoaderFileName                                 ;                上一轮字符比较过程中lodsb指令会一致自动增加SI 这个地方准备进行新的一个根目录项比较了 重置SI 让源地址指向期待的文件名
    jmp Label_Search_For_LoaderBin

; @bref 根目录扇区编号从19开始 [19...32] 逐个扇区读取搜索
Label_Goto_Next_Sector_In_Root_Dir:
    add word[SectorNo], 1
    jmp Lable_Search_In_Root_Dir_Begin

; @bref 没有检索到loader.bin程序文件时给出提示信息
;       搜索整个根目录的14个扇区都没有搜索到loader.bin再执行该函数
;       int 0x10 AH=0x13 显示一行字符串
;                        AL=写入模式
;                           Al=0x00 字符串属性由BL寄存器控制 字符串长度由CX寄存器控制(以Byte为单位) 光标位置不变(即写入前光标在哪写入后还在哪)
;                           Al=0x01 字符串属性由BL寄存器控制 字符串长度由CX寄存器控制(以Byte为单位) 写入后光标在字符串尾端位置
;                           Al=0x02 字符串属性由每个字符后面紧跟的字节提供 字符串长度由CX寄存器控制(以Word为单位) 光标位置不变(即写入前光标在哪写入后还在哪)
;                           Al=0x03 字符串属性由每个字符后面紧跟的字节提供 字符串长度由CX寄存器控制(以Word为单位) 写入后光标在字符串尾端位置
;                        CX=字符串长度
;                        DH=游标的坐标行号(从0计)
;                        DL=游标的坐标列号(从0计)
;                        ES:BP=要显示字符串的内存地址
;                        BH=页码
;                        BL=字符串属性
;                           BL[7]     字体闪烁 0=不闪烁 1=闪烁
;                           BL[4...6] 背景颜色 0=黑色 1=蓝色 2=绿色 3=青色 4=红色 5=紫色 6=棕色 7=白色
;                           BL[3]     字体亮度 0=字体正常 1=字体高量
;                           BL[0...2] 字体颜色 0=黑色 1=蓝色 2=绿色 3=青色 4=红色 5=紫色 6=棕色 7=白色
Label_No_LoaderBin:
    mov ax, 0x1301
    mov bx, 0x008c
    mov dx, 0x0100
    mov cx, 21
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, NoLoaderMessage
    int 0x10
    jmp $                                                  ;                让cpu陷在这 相当于阻塞线程

; @bref 在根目录项中匹配到了文件名
;       从根目录项中读取出目标文件的起始簇号
;       解析出簇号映射的扇区号，然后顺着簇号找下一个簇号
;
;           bit位     [0...7] [8...10]   11   [12...21]    [22...23]      [24...25]    [26...27]  [28...31]
;       根目录项组成部分  文件名   扩展名  文件属性   保留位    最后一次写入时间  最后一次写入日期   起始簇号    文件大小
;           长度         8        3       1       10            2              2            2          4
Label_fileName_Found:
    and di, 0xffe0                                         ;                当前是根目录项中的文件名是匹配成功的 那么地址偏移是11 地址后4bit的表达区间是[0...15] 把后4位置0就是当前根目录项的首地址
    add di, 0x001a                                         ;                当前偏移0 重置到26偏移 [26...27]记录着起始簇号
    mov cx, word[es:di]                                    ;                文件对应的起始簇号读取出来

    push cx                                                ;                起始簇号 将簇号缓存在栈中 读取完当前簇号内容后 还要根据簇号找到下一个簇号

    add cx, ClusMappingSector                              ;                扇区号=簇号+31

    mov ax, BaseOfLoader
    mov es, ax                                             
    mov bx, OffsetOfLoader                                 ;                读取出来的loader.bin程序从0x1000:0x0000=0x10000地址开始往后放

    mov ax, cx

; @bref 根据文件簇号映射到某个扇区 读取该扇区的数据到内存
;       在屏幕上显示.标识1个扇区 也就是说文件占用几个扇区 将来在屏幕上就会显示几个点
;       int 0x10 AH=0x0e 在屏幕上显示1个字符
;                        AL=待显示的字符
;                        BL=前景色
Label_Go_On_Loading_File:
    call Func_PrintChar

    mov cl, 1                                              ;                准备读1个扇区
    call Func_ReadOneSector

    pop ax                                                 ;                之前缓存在栈中的簇号 找到这个簇号的下一个簇号
    call Func_GetFATEntry

    cmp ax, 0x0fff
    jz Label_File_Loaded                                   ;                簇号12bit FAT表项值0xfff表示的是结尾 也就意味着根据某个簇号找到的下一个簇号是0xfff就说明整个文件内容都读完了

    push ax
    mov dx, RootDirSectors
    add ax, dx
    add ax, SectorBalance
    add bx, [BPB_BytesPerSec]
    jmp Label_Go_On_Loading_File

; @bref loader程序加载到了内存 让CPU跳转执行loader程序
Label_File_Loaded:
    jmp BaseOfLoader:OffsetOfLoader                        ;                loader程序已经借助FAT12文件系统读到了内存 下面就是执行这段程序就行

; @bref 指定读取软盘上某个扇区的内容到内存上 入参是逻辑块寻址LBA格式
; @param AX=待读取的磁盘起始扇区号
; @param CL=读入的扇区数量
; @param ES:BX=>目标缓冲区起始地址
;       首先将LBA转换为CHS
;         商Q=LBA扇区号/每磁道扇区数
;         余数R=LBA扇区号%每磁道扇区数
;         C 柱面号=Q>>1
;         H 磁头号=Q
;         S 扇区号=R+1
;         其中除法div 8位寄存器计算的规则是
;          被除数=AX
;          除数=BL
;          商->AL
;          余数->AH
;       然后借助中断调用读取软盘扇区
;         int 0x13 AH=0x02 读取磁盘扇区
;                          AL=读入的扇区数 必须非0
;                          CH=柱面号的低8位
;                          CL=扇区号
;                          DH=磁头号
;                          DL=驱动器号 如果操作的是硬盘驱动器则DL[7]必须被置位
;                          ES:BX=>数据缓冲区
Func_ReadOneSector:
    push bp                                                ;                BP是基址寄存器 相当于开辟栈帧之前缓存了调用方基址 等函数调用完用于恢复调用方
    mov bp, sp                                             ;                SP是栈顶指针 
    sub esp, 2                                             ;                ESP下移2个Byte 相当于在堆栈中开辟了2字节空间用于存放函数参数
    mov byte[bp-2], cl                                     ;                CL寄存器中存储的就是函数参数 要读取的扇区数量
    push bx                                                ;                要将BX作为ES的偏移地址作为缓冲区调用中断 但是在此期间还要使用BX寄存器进行除法运算 因此先将BX值缓存 计算过除法再出栈使用
    mov bl, [BPB_SecPerTrk]                                ;                变量指针解引用 BL=18 作为除数
    div bl                                                 ;                div除法计算 被除数=AX 除数=BL 商->AL 余数->AH
    
    inc ah
    mov cl, ah                                             ;                CL=扇区号

    mov dh, al                                             ;                DH=磁头号

    shr al, 1
    mov ch, al                                             ;                CH=柱面号
    mov dl, [BS_DrvNum]                                    ;                DL=驱动器号
    pop bx                                                 ;                除法计算之前缓存着的BX值 ES:BX=>缓冲区地址 磁盘上读取的数据放到内存上
Label_Go_On_Reading:
    mov ah, 2                                              ;                中断功能号
    mov al, byte[bp-2]                                     ;                AL=读入的扇区数
    int 0x13                                               ;                中断调用
    jc Label_Go_On_Reading                                 ;                PSW标志位(CF标志位)有进位就进行跳转 
                                                           ;                执行到这说明扇指定扇区中数据已经读到了内存中 数据读取成功 开始恢复调用现场
    add esp, 2                                             ;                清理栈中缓存的参数
    pop bp                                                 ;                恢复中断调用前的BP基地址
    ret                                                    ;                退出函数

; @bref 根据当前FAT表项索引出下一个FAT表项
; @param AX FAT表项号 即簇号
; @return AX 当前簇号的下一个簇号
;       乘法
;         AX*REG=DX:AX 当DX!=0时 进位标志CF=1
;       除法
;         被除数     除数     商  余数
;         DX:AX  reg/mem16  AX   DX
;       一个簇号占12bit
;       内存空间基本单位byte=8bit
;
;       只要知道簇号x就可以求出该簇号相对FAT1起始地址的偏移 即假设FAT1的地址为0
;       FAT表项下标  簇号开始 簇号结束
;           0         0      1.5
;           1        1.5      3
;           2         3      4.5
;           3        4.5      6
;           4         6      7.5
;           5        7.5      9
;           6         9      10.5
;           7        10.5     12
;           
;          3071     46065    46066.5
;
;        即已知簇号为x 则该FAT表项相对FAT1表的偏移offset=1.5x个Byte
;        很明显offset是小数的时候意味着连续3个byte 当前这个簇号被夹在中间
;        FAT1的扇区范围是[1...9]
;        每个扇区的大小=512B
;        知道了offset也就自然能知道簇号表项在哪个扇区上 其次就是在该扇区定位到准确位置
Func_GetFATEntry:
    push es
    push bx
    push ax                                                ;                缓存乘数 簇号

    mov ax, 0
    mov es, ax

    pop ax                                                 ;                乘数 簇号
    mov byte[Odd], 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx

    cmp dx, 0                                              ;                簇号*12/8的结果 AX=FAT表索引相对FAT1偏移量(向下取整) DX=0表示AX是整数结果 DX=1表示AX是小数取整结果
    jz Label_Even                                          ;                FAT表脚标相对FAT1的偏移是整数
    mov byte[Odd], 1                                       ;                FAT表脚标相对FAT1的偏移是小数

; @bref FAT表索引相对FAT1偏移量是整数
; @param AX=FAT表项索引相对偏移量
;       除法
;         被除数     除数     商  余数
;         DX:AX  reg/mem16  AX   DX
;       已知FAT表项索引相对FAT1表的相对偏移量是n个byte
;       FAT1表扇区范围[1...9]
;       每个扇区大小512B
;       那么FAT表项所在
;                      扇区=x/512+1
;                      相对扇区偏移=x%512
;       可能存在一个FAT表项跨扇区情况 比如簇号相对FAT1偏移为511B 那么这12bit就垮了扇区1和扇区2
;       在读盘的时候直接一次性读2个扇区
Label_Even:
    xor dx, dx                                             ;                DX=0
    mov bx, [BPB_BytesPerSec]
    div bx
    push dx                                                ;                AX=扇区相对扇区1的偏移扇区数 DX=所在扇区偏移量

    mov bx, 0x8000
    add ax, SectorNumOfFAT1Start                           ;                定位到扇区
    mov cl, 2
    call Func_ReadOneSector                                ;                FAT1扇区号为[1...9] 因此从扇区1开始读 读2个扇区 将读取出来的数据放到缓冲区ES:BX

    pop dx
    add bx, dx
    mov ax, [es:bx]                                        ;                DX=扇区相对偏移 缓冲区起始地址=0x08000 那么要找的FAT表项绝对地址=0x08000+扇区相对偏移 将表项读出来 寄存器是16位 实际表项内容是12位
    cmp byte[Odd], 1
    jnz Label_Even_2                                       ;                相对偏移量是整数
    shr ax, 4                                              ;                相对偏移量是小数 比如相对偏移是1.5Byte 现在定位到扇区号为1 

Label_Even_2:
    and ax, 0x0fff                                         ;                FAT表项中12bit的内容 就是当前簇的下一个簇
    pop bx
    pop es
    ret

; @bref 打印一个字符 用于调试
Func_PrintChar:
    push ax
    push bx
    mov ah, 0x0e
    mov al, '.'
    mov bl, 0x0f
    int 0x10
    pop bx
    pop ax
    ret

; 临时变量 
StartBootMessage:  db "BOOT running"                       ;                启动界面提示信息
NoLoaderMessage:   db "ERROR:No LOADER Found"              ;                加载loader.bin程序的提示信息
LoaderFileName:    db "LOADER  BIN",0                      ;                loader程序文件名LOADER 扩展名为BIN 在FAT12文件系统中文件名和目录项都是大写的 即使复制进来时小写的文件 文件系统也会为其创建大写的方式
RootDirSizeForLoop dw RootDirSectors                       ;                根目录占用14个扇区 轮询根目录中所有扇区进行查找文件
SectorNo           dw 0                                    ;                记录着当前访问的扇区号(从0计)
Odd                db 0                                    ;                已知FAT表脚标时要读它的表项 标识FAT表相对FAT1的相对偏移是不是整数 Odd=1表示相对偏移是小数 Odd=0表示相对偏移是整数


    ;                                                                       扇区填充
    times 510-($-$$) db 0                                ;                BIOS加载第一扇区的512Byte内容
                                                           ;                最后2byte分别是 0xaa和0x55
                                                           ;                那么整个第一扇区bootsect程序就是510Byte
                                                           ;                [129...509]被填充0
    dw 0xaa55                                              ;                0xaa和0x55两个标识byte

