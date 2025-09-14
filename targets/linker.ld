ENTRY(_start)

SECTIONS {
    . = 0x8000;              /* 起始加载地址 */

    .text : ALIGN(4) {
        /* 确保内核入口最前 */
        build/kernel/kernel.o(.text)
        build/kernel/liba.o(.text)
        build/kernel/libc.o(.text)
        /* 其他所有目标文件的代码段 */
        build/kernel/*.o(.text)
        *(.text*)
    }

    .rodata : ALIGN(4) {
        build/kernel/*.o(.rodata*)
        *(.rodata*)
    }

    .data : ALIGN(4) {
        build/kernel/*.o(.data*)
        *(.data*)
    }

    .bss : ALIGN(4) {
        build/kernel/*.o(.bss*)
        *(.bss*)
        *(COMMON)
    }
}
