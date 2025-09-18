OUTPUT_FORMAT("elf64-x86-64","elf64-x86-64","elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start) # 入口在内核头程序的_start
SECTIONS
{

	. = 0xffff800000000000 + 0x100000; # 内核代码被loader放在了物理地址0x100_000上了 链接的时候把内核程序入口定在虚拟地址的高区 为了映射方便再把物理空间的偏移也加进来
	.text :
	{
		_text = .;
		*(.text)

		_etext = .;
	}
	. = ALIGN(8);
	.data :
	{
		_data = .;
		*(.data)
		
		_edata = .;
	}
	.bss :
	{
		_bss = .;
		*(.bss)
		_ebss = .;
	}

	_end = .;
}