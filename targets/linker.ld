ENTRY(_start)

SECTIONS {
    . = 0x8000;              /* 起始地址 */

    .text : {
        /* 先把 kernel.o 里的 _start 放在最前 */
        build/kernel/kernel.o(.text)
        /* 其他目标文件的代码 */
        *(.text*)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data*)
    }

    .bss : {
        *(.bss*)
        *(COMMON)
    }
}
