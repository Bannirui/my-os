; 操作系统程序的加载分3批
; boot sector是第一批 由BIOS负责加载
; 第二批第三批由boot sector负责

; boot程序是放在软盘第一扇区的第一批程序
; 执行的时机是BIOS加载完该段程序后放到0x07c00地址上 并转移CPU执行权 即跳转到0x07c00这个地址进行执行
; 当前CPU是实模式 CPU中CS=0x0000 IP=0x7c00
; 因此该程序刚接收到CPU的执行权
; 告诉编译器程序的起始地址是0x07c00
org 0x7c00

BaseOfStack             equ 0x7c00                         ; boot sector程序运行时的段内偏移 也就是程序地址的offset

BaseOfLoader            equ 0x1000
OffsetOfLoader          equ 0x0000                         ; loader程序的起始地址=0x10000<<4+0x0000=0x10000

;                                                           偏移 长度[字节]                  内容
jmp short Label_Start                                      ; 0     2
nop                                                        ; 2     1        指令填充
%include "fat12.inc"                                       ; 3     59       FAT12文件系统构成
                                                           ; 62   448       引导代码\数据及其他信息

; @brief 软盘第1扇区中程序boot sector的实现
Label_Start:
    mov ax, cs                                             ;                代码段寄存器=0x0000
    mov ds, ax                                             ;                数据段寄存器=0x0000 数据从哪里来
    mov es, ax                                             ;                附加段寄存器=0x0000 数据到哪里去
    mov ss, ax                                             ;                堆栈段寄存器=0x0000
    mov sp, BaseOfStack                                    ;                栈基=0x7c00

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
Label_Clear:
    mov ax, 0x0600                                         ;                AH=0x06 AL=0x00 清屏
    mov bx, 0x0700                                         ;                BH=0 000 0 111 滚动之后屏幕显示的属性
    mov cx, 0x0000                                         ;                CH=0x00 CL=0x00 左上角坐标=[0,0]
    mov dx, 0x184f                                         ;                DH=0x18 DL=0x4f 右下角坐标=[79,24]
    int 0x10                                               ;                中断调用

; @brief 光标重置到[0,0]位置
;       设定光标位置
;       中断号int 0x10
;       功能号AH=0x02
; @param DH=游标的列号(从0计)
; @param DH=游标的行号(从0计)
; @param BH=页码
Label_Cursor:
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
Label_Print_Msg:
    mov ax, 0x1301                                         ;                AH=0x13 AL=0x01
    mov cx, 12                                             ;                字符串长度
    mov dx, 0
    mov bx, 0x000f                                         ;                黑色背景 白字高亮不闪烁

    push ax                                                ;                AX寄存器要临时使用 先把中断调用的参数缓存到堆栈 中断调用之前再把参数出栈放到寄存器
    mov ax, ds
    mov es, ax
    mov bp, StartBootMessage                               ;                字符串地址[DS:变量地址]
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
Label_Reset_Floppy:
    xor ah, ah
    xor dl, dl
    int 0x13

; 根目录扇区号范围为[19...32] 一共14个扇区
; 1 比如loader程序名叫loader.bin 磁盘文件格式是FAT12 那么该文件在FAT12中的文件名就是LOADER 扩展名是BIN
; 2 首先遍历根目录中的根目录项 从根目录项的前11B文件名LOADER和扩展名BIN找到loader程序
; 3 根目录项的bit[26, 27]是该文件的起始簇号
; 4 FAT1表中索引号就是簇号 表项值也是簇号 索引是当前簇号 表项值是下一个簇号 0xfff标识该文件簇号结束 FAT1表数组前2项弃用 数组脚标范围是[2...3071]
; 5 数据区的扇区范围是[33...2079]
; 6 簇号根扇区的映射就是 扇区=簇号+31
; 7 将3解析出来的文件簇号映射生成扇区
; 8 拿着扇区号利用中断读取内容放到到内存
; 9 以簇号为脚标的数组内容是下一个簇号 循环7和8直到簇号结束0xfff
    mov word[SectorNo], SectorNumOfRootDirStart

; @brief 根目录占14个扇区 轮询根目录中扇区
;       从19号扇区开始 每次读1个扇区 内容放到内存0x08000
Label_Search_In_Root_Dir_Begin:
    cmp word[RootDirSizeForLoop], 0
    jz Label_No_LoaderBin                                  ;                整个根目录中的14个扇区都遍历过了 没有找到loader程序 用于退出轮询
    dec word[RootDirSizeForLoop]
    
    mov ax, 0x0000
    mov es, ax
    mov bx, 0x8000                                         ;                ES:BX=0x08000 缓冲区地址

    mov ax, [SectorNo]
    mov cl, 1
    call Func_Read_Sector                                  ;                扇区[19...32]当前读Sector扇区

    mov si, LoaderFileName                                 ;                loader.bin文件名 相当于源地址 后面要使用lodsb将这个内存上的文件名读取到寄存器中跟目的地址内容去比较
    mov di, 0x8000                                         ;                内存缓冲区 存储着从根目录中读取出来的扇区内容 可以从中解析出文件名 相当于目的地址
    cld                                                    ;                让DF标志位=0 下面的lodsb指令依赖DF标志位 因此提前置位
    mov dx, 0x10                                           ;                每个扇区中有16个根目录项

; @brief 解析每个根目录项 是否存在loader.bin文件
;       1个扇区16个根目录 即1个扇区轮询检索16次
; @param SI=目标文件名 要在根目录项中找的文件名
; @param DI=根目录项 前11Byte是候选文件名
;       [0x08000...0x81ff]这512Byte放着根目录中某一扇区的内容 每32B就是一个根目录项
;        起始地址   根目录项   结束地址      DI指针 文件名地址区间前11B 实际肯定是前10B 否则当前根目录项就匹配上了
;       [0x08000] [根目录项0] [0x0801f]     [0x08000...0x08009]
;       [0x08020] [根目录项1] [0x0803f]     [0x08020...0x08029]
;       [0x08040] [根目录项2] [0x0805f]     [0x08040...0x08049]
;       [0x08060] [根目录项3] [0x0807f]     [0x08060...0x08069]
;       [0x08080] [根目录项4] [0x0809f]     [0x08080...0x08089]
;       [0x080a0] [根目录项5] [0x080bf]     [0x080a0...0x080a9]
;       [0x080c0] [根目录项6] [0x080df]     [0x080c0...0x080c9]
;       [0x080e0] [根目录项7] [0x080ff]     [0x080e0...0x080e9]
;       [0x08100] [根目录项8] [0x081ff]     [0x08100...0x08109]
;       [0x08120] [根目录项9] [0x0813f]     [0x08120...0x08129]
;       [0x08140] [根目录项10] [0x0815f]    [0x08140...0x08149]
;       [0x08160] [根目录项11] [0x0817f]    [0x08160...0x08169]
;       [0x08180] [根目录项12] [0x0819f]    [0x08180...0x08180]
;       [0x081a0] [根目录项13] [0x081bf]    [0x081a0...0x081a9]
;       [0x081c0] [根目录项14] [0x081df]    [0x081c0...0x081c9]
;       [0x081e0] [根目录项15] [0x081ff]    [0x081e0...0x081e9]
Label_Search_For_LoaderBin:
    cmp dx, 0                                              ;                轮询16个根目录项
    jz Label_Goto_Next_Sector_In_Root_Dir                  ;                在1个扇区之中有16个根目录项 轮询没有找到loader文件 继续检索根目录中的下一扇区
    dec dx
    mov cx, 11                                             ;                每个根目录项前11个Byte轮询出来跟文件名比较

; @brief 解析1个根目录项中的前11B 文件名占8B 扩展名占3B
;       考察解析出来的文件名是否是loader.bin程序文件
Label_Cmp_FileName:
    cmp cx, 0
    jz Label_fileName_Found                                ;                根目录项中前11个Byte的文件名就是要找的文件名 当前DI指向的根目录项就要要找的
    dec cx

    ; lodsb根据SI从DS:SI内存上将候选文件名的1个Byte读到AL寄存器上 读完了就会自增SI
    ; 手动根据DI从ES:DI内存上将目标文件名的1个Byte读出来根候选比较
    ; 当前字符相同就手动后移DI指针继续比较
    ; 当前字符不同就找到下一个根目录项中的候选文件名继续重复比较动作
    lodsb
    cmp al, byte[es:di]
    jz Label_Go_On
    jmp Label_Different

; @brief 目标文件名和候选文件名的某个字符相同 将二者字符指针后移 比较下一个字符
; @parm si 指向目标文件名的字符 lodsb指令会自增si 因此不需要手动后移指针
; @param di 指向候选文件名的字符 手动后移指针
Label_Go_On:
    inc di
    jmp Label_Cmp_FileName

; @brief 当前根目录项中的候选文件名跟目标文件名不匹配
;       FAT12文件系统的标准规定了文件名=8 扩展名=3
;       当前函数是比较出来候选文件名的某个字符跟目标文件名不一样了
;       也就是说一定是[0...10]这11个字符中某个字符开始不一样 因为si是lodsb负责自增的 那么si会比di靠后一个位置
;       要找到下一个根目录项中的候选文件名 继续跟目标文件名进行比较
; @param si [0...11]的某个偏移值
; @param di [0...10]的某个偏移值
; @return si重置到目标文件名的起始字符位置
;         di重置到下一个根目录项起始位置
;       1个扇区的根目录项在内存中的布局如下
;        起始地址   根目录项   结束地址           DI指针区间 [0...10]前11Byte是文件名
;       [0x8000] [根目录项0] [0x801f]     [0x8000...0x800a]
;       [0x8020] [根目录项1] [0x803f]     [0x8020...0x802a]
;       [0x8040] [根目录项2] [0x805f]     [0x8040...0x804a]
;       [0x8060] [根目录项3] [0x807f]     [0x8060...0x806a]
;       [0x8080] [根目录项4] [0x809f]     [0x8080...0x808a]
;       [0x80a0] [根目录项5] [0x80bf]     [0x80a0...0x80aa]
;       [0x80c0] [根目录项6] [0x80df]     [0x80c0...0x80ca]
;       [0x80e0] [根目录项7] [0x80ff]     [0x80e0...0x80ea]
;       [0x8100] [根目录项8] [0x81ff]     [0x8100...0x810a]
;       [0x8120] [根目录项9] [0x813f]     [0x8120...0x812a]
;       [0x8140] [根目录项10] [0x815f]    [0x8140...0x814a]
;       [0x8160] [根目录项11] [0x817f]    [0x8160...0x816a]
;       [0x8180] [根目录项12] [0x819f]    [0x8180...0x818a]
;       [0x81a0] [根目录项13] [0x81bf]    [0x81a0...0x81aa]
;       [0x81c0] [根目录项14] [0x81df]    [0x81c0...0x81ca]
;       [0x81e0] [根目录项15] [0x81ff]    [0x81e0...0x81ea]
;
;       假设每个根目录项的起始地址为x 则DI指针的活动范围为[x...x+a]
;       后4bit的表达范围是[0...15]
;       因此只要把di的后4bit置为0就回到了首地址
;       每个根目录项占32B 也就是每2个根目录项首地址间隔0x20
;       再将回到了当前根目录项的首地址+0x20就指向了下一个根目录项的首地址
Label_Different:
    and di, 0xfff0
    add di, 0x20                                           ;                重置DI=DI指向到当前根目录项头->DI指向下一个根目录项

    mov si, LoaderFileName                                 ;                重置SI
    jmp Label_Search_For_LoaderBin

; @brief 根目录当前扇区没找到目标文件名 继续SectorNo的下一个扇区读取 直至读完根目录中14个扇区
Label_Goto_Next_Sector_In_Root_Dir:
    add word[SectorNo], 1
    jmp Label_Search_In_Root_Dir_Begin

; @brief 没有检索到loader.bin程序文件时给出提示信息
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

; @brief 在根目录项中匹配到了文件名
;       从根目录项中读取出目标文件的起始簇号
;       解析出簇号映射的扇区号，然后顺着簇号找下一个簇号
;
;           bit位     [0...7] [8...10]   11   [12...21]    [22...23]      [24...25]    [26...27]  [28...31]
;       根目录项组成部分  文件名   扩展名  文件属性   保留位    最后一次写入时间  最后一次写入日期   起始簇号    文件大小
;           长度         8        3       1       10            2              2            2          4
Label_fileName_Found:
    and di, 0xfff0                                         ;                当前是根目录项中的文件名是匹配成功的 那么地址偏移是11 地址后4bit的表达区间是[0...15] 把后4位置0就是当前根目录项的首地址
    add di, 0x001a                                         ;                当前偏移0 重置到26偏移 [26...27]记录着起始簇号
    mov cx, word[es:di]                                    ;                文件对应的起始簇号读取出来

    push cx                                                ;                起始簇号 将簇号缓存在栈中 读取完当前簇号内容后 还要根据簇号找到下一个簇号

    add cx, ClusterMappingSector                              ;                扇区号=簇号+31

    mov ax, BaseOfLoader
    mov es, ax                                             
    mov bx, OffsetOfLoader                                 ;                读取出来的loader.bin程序从0x1000:0x0000=0x10000地址开始往后放

    mov ax, cx

; @brief 根据文件簇号映射到某个扇区 读取该扇区的数据到内存
;       在屏幕上显示.标识1个扇区 也就是说文件占用几个扇区 将来在屏幕上就会显示几个点
;       int 0x10 AH=0x0e 在屏幕上显示1个字符
;                        AL=待显示的字符
;                        BL=前景色
Label_DFS_Load_File:
    call Func_PrintChar

    mov cl, 1                                              ;                准备读1个扇区
    call Func_Read_Sector

    pop ax
    call Func_GetFATEntry                                  ;                AX中存储簇号 当前簇号的下一个簇号 一直递归读取到结束符
    cmp ax, 0x0fff                                         ;                12bit 0xfff标识结尾 也就意味着根据某个簇号找到的下一个簇号是0xfff就说明整个文件内容都读完了
    jz Label_File_Loaded

    push ax                                                ;                当前簇号的下一个簇号入栈 给递归函数的下一层是用 也就是下层递归的当前簇号
    add ax, ClusterMappingSector                              ;                扇区号=簇号+31
    add bx, [BPB_BytesPerSec]
    jmp Label_DFS_Load_File

; @brief loader程序加载到了内存 让CPU跳转执行loader程序
Label_File_Loaded:
    jmp BaseOfLoader:OffsetOfLoader                        ;                loader程序已经借助FAT12文件系统读到了内存 下面就是执行这段程序就行

; @brief LBA转换CHS
;       入参扇区号是LBA格式 依赖中断int 0x13读取扇区功能需要提供的参数是CHS格式 当前要做的就是格式转换
; @param AX=扇区号 LBA格式 从磁盘上哪个扇区开始读
; @param CL=扇区数 要读几个扇区
; @param ES:BX=缓冲区地址 磁盘上内容读出来放到内存什么位置
;       1 首先将LBA转换为CHS
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
;       2 然后借助中断调用读取软盘扇区
;         int 0x13 AH=0x02 读取磁盘扇区
;                          AL=读入的扇区数 必须非0
;                          CH=柱面号的低8位
;                          CL=扇区号
;                          DH=磁头号
;                          DL=驱动器号 如果操作的是硬盘驱动器则DL[7]必须被置位
;                          ES:BX=>数据缓冲区
Func_Read_Sector:
    push bp                                                ;                函数调用方BP指针
    mov bp, sp                                             ;                当前函数BP指针 相当于在栈中为当前函数开辟栈帧 这两步是为了函数调用结束能恢复调用方

    sub esp, 2                                             ;                ESP下移2个Byte 相当于在堆栈中开辟了2字节空间用于存放函数参数
    mov byte[bp-2], cl                                     ;                将扇区数这个参数入栈 下面调用中断前会出栈放到指定寄存器中

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

; @brief int 0x13中断读扇区
;       中断号int 0x13
;       功能号AH=0x02
; @param AH=0x02 功能号
; @param AL=扇区数 要读几个扇区
; @param CH=柱面
; @param CL=扇区 从哪个扇区开始读
; @param DH=磁头
; @param DL=驱动器
; @param ES:BX=缓冲区地址
; @return CF=0标识操作成功
Label_Do_Read_Sector:
    mov ah, 0x02
    mov al, byte[bp-2]                                     ;                栈中参数(扇区数)
    int 0x13
    jc Label_Do_Read_Sector                                ;                PSW标志位(CF标志位) 中断读扇区成功后会将CF为置0 如果没有被置0说明扇区读取失败 进行重试

    add esp, 2                                             ;                执行到这说明扇区中的数据已经被读到了内存 清理栈中缓存的参数(扇区数)
    pop bp                                                 ;                恢复中断调用前的BP基地址
    ret                                                    ;                退出函数

; @brief 根据当前FAT表项索引出下一个FAT表项
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

; @brief FAT表索引相对FAT1偏移量是整数
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
    call Func_Read_Sector                                  ;                FAT1扇区号为[1...9] 因此从扇区1开始读 读2个扇区 将读取出来的数据放到缓冲区ES:BX

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

; @brief 打印一个字符 用于调试
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
SectorNo           dw 0                                    ;                记录着当前开始读的扇区号 根目录区扇区范围为[19...32] 变量维护着当前读哪个扇区
Odd                db 0                                    ;                已知FAT表脚标时要读它的表项 标识FAT表相对FAT1的相对偏移是不是整数 Odd=1表示相对偏移是小数 Odd=0表示相对偏移是整数


    ;                                                                       扇区填充
    times 510-($-$$) db 0                                ;                BIOS加载第一扇区的512Byte内容
                                                           ;                最后2byte分别是 0xaa和0x55
                                                           ;                那么整个第一扇区bootsect程序就是510Byte
                                                           ;                [129...509]被填充0
    dw 0xaa55                                              ;                0xaa和0x55两个标识byte

