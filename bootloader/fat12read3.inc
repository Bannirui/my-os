; @brief 根据文件簇号映射到某个扇区 读取该扇区的数据到内存
;       在屏幕上显示.标识1个扇区 也就是说文件占用几个扇区 将来在屏幕上就会显示几个点
;       int 0x10 AH=0x0e 在屏幕上显示1个字符
;                        AL=待显示的字符
;                        BL=前景色
.dfs_load_for_file:
    push ax
    push bx
    mov ah, 0x0e
    mov al, '-'
    mov bl, 0x0f
    int 0x10
    pop bx
    pop ax

    mov cl, 1                                              ;                准备读1个扇区
    call func_read_sector

    pop ax
    call func_next_entry                                   ;                AX中存储簇号 当前簇号的下一个簇号 一直递归读取到结束符
    cmp ax, 0x0fff                                         ;                12bit 0xfff标识结尾 也就意味着根据某个簇号找到的下一个簇号是0xfff就说明整个文件内容都读完了
    jz .load_succ

    push ax                                                ;                当前簇号的下一个簇号入栈 给递归函数的下一层是用 也就是下层递归的当前簇号
    add ax, cluster_map_sector                             ;                扇区号=簇号+31
    add bx, [BPB_BytesPerSec]
    jmp .dfs_load_for_file

; @brief loader程序加载到了内存 让CPU跳转执行loader程序
.load_succ:
    jmp search_file_name_callback                          ;                让调用方决定加载完成之后的动作