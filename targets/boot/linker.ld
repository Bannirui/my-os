ENTRY(_start)

SECTIONS {
  . = 0x1000;        /* 内核加载到物理地址 0x1000 */

  .text : {
    *(.text)
  }

  .rodata : {
    *(.rodata)
  }

  .data : {
    *(.data)
  }

  .bss : {
    *(.bss)
    *(COMMON)
  }
}
