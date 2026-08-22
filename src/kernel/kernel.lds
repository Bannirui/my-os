# 怎么把内核头程序编译生成到整个内核程序文件的起始处
# 这个链接脚本的作用就是手动编写内核程序的链接 在内核程序的链接过程中 链接器会按照链接脚本描述的空间布局 把编译好的程序片段填充到内核程序中

OUTPUT_FORMAT("elf64-x86-64","elf64-x86-64","elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start) # 入口在内核头程序的_start
SECTIONS
{
    # 代码段的起始位置
 	# 内核代码被loader放在了物理地址0x10_0000上了
	# 在设计地址的时候把0xffff_8000_0000_0000这个高半区地址作为内核程序的线性地址 映射成物理地址0 这个虚拟地址就是内核程序的起始地址
	# 在加载磁盘的内核程序时把它放在了物理地址1M上了 所以就把内核程序起始线性地址偏移1M 就是0xffff_8000_0000_0000 + 0x10_0000
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

	.rodata :
	{
		_rodata = .;
		*(.rodata)
		_erodata = .;
	}
    # 在反推任务指针的时候用rsp&~32767 要求init_task_union落在32KB边界
	. = ALIGN(32768);
	.data.init_task : { *(.data.init_task) }

	.bss :
	{
		_bss = .;
		*(.bss)
		_ebss = .;
	}

	_end = .;
}