OUTPUT_FORMAT("elf64-x86-64","elf64-x86-64","elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start) # 入口在内核头程序的_start
SECTIONS
{

 	# 内核代码被loader放在了物理地址0x100_000上了
	# 在设计地址的时候把0xffff800000000000这个高半区地址作为内核程序的线性地址 映射成物理地址0 这个虚拟地址就是内核程序的起始地址
	# 在加载磁盘的内核程序时把它放在了物理地址1M上了 所以为对应 就把内核程序起始线性地址偏移1M 就是0xffff800000000000 + 0x100000
	. = 0xffff800000000000 + 0x100000;
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