ENTRY(start)

SECTIONS
{
    . = 0x7C00;          /* 设置起始地址 */
    
    .text : {
        *(.text)         /* 把所有 .text 段放到这里 */
    }

    .data : {
        *(.data)         /* 全部数据段 */
    }

    .bss : {
        *(.bss)          /* 全部未初始化段 */
        *(COMMON)
    }
}
