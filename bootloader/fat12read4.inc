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
func_read_sector:
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
    and dh, 1
    pop bx                                                 ;                除法计算之前缓存着的BX值 ES:BX=>缓冲区地址 磁盘上读取的数据放到内存上
    mov dl, [BS_DrvNum]                                    ;                DL=驱动器号

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
.do_read_sector:
    mov ah, 0x02
    mov al, byte[bp-2]                                     ;                栈中参数(扇区数)
    int 0x13
    jc .do_read_sector                                     ;                PSW标志位(CF标志位) 中断读扇区成功后会将CF为置0 如果没有被置0说明扇区读取失败 进行重试

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
func_next_entry:
    push es
    push bx
    push ax                                                ;                缓存乘数 簇号

    mov ax, 0
    mov es, ax

    pop ax                                                 ;                乘数 簇号
    mov byte[odd], 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx

    cmp dx, 0                                              ;                簇号*12/8的结果 AX=FAT表索引相对FAT1偏移量(向下取整) DX=0表示AX是整数结果 DX=1表示AX是小数取整结果
    jz .even                                          ;                FAT表脚标相对FAT1的偏移是整数
    mov byte[odd], 1                                       ;                FAT表脚标相对FAT1的偏移是小数

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
.even:
    xor dx, dx                                             ;                DX=0
    mov bx, [BPB_BytesPerSec]
    div bx
    push dx                                                ;                AX=扇区相对扇区1的偏移扇区数 DX=所在扇区偏移量

    mov bx, 0x8000
    add ax, fat1_sector_begin                              ;                定位到扇区
    mov cl, 2
    call func_read_sector                                  ;                FAT1扇区号为[1...9] 因此从扇区1开始读 读2个扇区 将读取出来的数据放到缓冲区ES:BX

    pop dx
    add bx, dx
    mov ax, [es:bx]                                        ;                DX=扇区相对偏移 缓冲区起始地址=0x08000 那么要找的FAT表项绝对地址=0x08000+扇区相对偏移 将表项读出来 寄存器是16位 实际表项内容是12位
    cmp byte[odd], 1
    jnz .even_2                                       ;                相对偏移量是整数
    shr ax, 4                                              ;                相对偏移量是小数 比如相对偏移是1.5Byte 现在定位到扇区号为1

.even_2:
    and ax, 0x0fff                                         ;                FAT表项中12bit的内容 就是当前簇的下一个簇
    pop bx
    pop es
    ret