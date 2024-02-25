/**
 * 链接脚本
 * 为了保证内核执行头程序能够位于整个内核程序的起始处
 * 将编译好的各个程序片段按照该脚本定义好的地址空间布局 填充到内核程序文件中
 * 内核层的线性地址0xffff800000000000对应着物理地址0 因此内核程序的起始线性地址=0xffff800000000000+0x100000
 */
OUTPUT_FORMAT("elf64-x86-64","elf64-x86-64","elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)
SECTIONS
{

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