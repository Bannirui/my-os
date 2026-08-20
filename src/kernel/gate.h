//
// Created by dingrui on 8/20/26.
//

#pragma once


struct desc_struct {
    unsigned char x[8];
};

struct gate_struct {
    unsigned char x[16];
};

extern struct desc_struct GDT_Table[];
// 在内核头文件head.S中用.global IDT_Table声明了
extern struct gate_struct IDT_Table[];
extern unsigned int TSS64_Table[26];

/**
 * 向IDT表某个表项写入一个16字节的门描述符 中断门 陷阱门 把异常向量号 处理器入口地址 属性 IST索引打包进去
 * 一个64位的中断门描述符 64位中断门描述符共16字节 分低8字节 高8字节两部分
 * 字节       位        含义
 * 高8字节 [127:96] 保留(设置成0)
 * 高8字节 [95:64]  偏移量offset[63:32]
 * 低8字节 [63:48]  偏移量offset[31:16]
 * 低8字节 [47:40]  属性0x8e含义是 P=1 DPL=0 Type=0xe
 * 低8字节 [39:32]  IST+保留(设置成0)
 * 低8字节 [31:16]  段选择子 固定值0x08
 * 低8字节 [15:0]   偏移量offset[15:0]
 * @param gate_selector_addr 门描述符的地址 要写IDT表的哪个表项
 * @param attr P DPL Type的属性字节 取值0x8e 0x8f 0xef 0xee
 * @param ist Interrupt Stack Table的索引 3位 取值0到7
 * @param code_addr 一场处理函数的入口地址 就是描述符的offset字段
 */
#define _set_gate(gate_selector_addr,attr,ist,code_addr)	                \
do {								                                        \
	unsigned long __d0,__d1;				                                \
	__asm__ __volatile__(	".intel_syntax noprefix\n\t"	                \
				"mov ax, dx\n\t"		                                    \
				"and rcx, 0x7\n\t"		                                    \
				"add rcx, %5\n\t"		                                    \
				"shl rcx, 32\n\t"		                                    \
				"add rax, rcx\n\t"		                                    \
				"xor rcx, rcx\n\t"		                                    \
				"mov ecx, edx\n\t"		                                    \
				"shr rcx, 16\n\t"		                                    \
				"shl rcx, 48\n\t"		                                    \
				"add rax, rcx\n\t"		                                    \
				"mov [%6], rax\n\t"		                                    \
				"shr rdx, 32\n\t"		                                    \
				"mov [%6 + 8], rdx\n\t"	                                    \
				".att_syntax prefix\n\t"	                                \
				:"=&a"(__d0),"=&d"(__d1)	                                \
				:"0"(0x8 << 16),"1"((unsigned long *)(code_addr)),"c"(ist),	\
				 "r"((unsigned long)(attr << 8)),				            \
				 "r"((unsigned long)(gate_selector_addr))			        \
				:"memory");				                                    \
} while(0)


/**
 * TSS段描述符的段选择子加载到TR寄存器
 * 任务寄存器TR加载为某个TSS描述符的选择子 让CPU知道TSS在哪儿
 * GDT表怎么索引呢 用段选择子 段选择子的编码规则是 16位的含义
 *   位     含义
 * [14:3] 索引Index 指向GDT描述符表中的第几个表项
 * [2]    TI表示指示位 0表示GDT 1表示LDT
 * [1:0]  RPL 请求特权级
 * 所以拿到段选择子右移3位就是所以Index
 * @param n TSS描述符在GDT表的索引项 比如8 那么对应二进制就是0000 0000 0000 1000
 *          然后第2位TI标识是0表示GDT
 *          第[1:0]RPL特权级内核就是0
 *          组合起来就是0 0000 0000 1000 000
 *          也就是说TR寄存器里面的值是0x0040
 */
#define load_TR(n) 							                    \
do{									                            \
	__asm__ __volatile__(	".intel_syntax noprefix\n\t"		\
				"ltr ax\n\t"				                    \
				".att_syntax prefix\n\t"		                \
				:					                            \
				:"a"(n << 3)				                    \
				:"memory");				                        \
}while(0)

/**
 * 中断门
 * @param n IDT表的第几个表项
 * @param ist 索引值0到7
 * @param addr 异常处理函数的地址
 */
static inline void set_intr_gate(unsigned int n, unsigned char ist, void *addr) {
    _set_gate(IDT_Table + n, 0x8E, ist, addr); //P,DPL=0,TYPE=E
}


/**
 * 陷阱门
 * @param n IDT表的第几个表项 也就是CPU拿着异常号会去找哪个IDT表项
 * @param ist 索引值0到7
 * @param addr 异常处理函数的地址
 */
static inline void set_trap_gate(unsigned int n, unsigned char ist, void *addr) {
    _set_gate(IDT_Table + n, 0x8F, ist, addr); //P,DPL=0,TYPE=F
}


/**
 * 陷阱门 用户可调
 * @param n IDT表的第几个表项
 * @param ist 索引值0到7
 * @param addr 异常处理函数的地址
 */
static inline void set_system_gate(unsigned int n, unsigned char ist, void *addr) {
    _set_gate(IDT_Table + n, 0xEF, ist, addr); //P,DPL=3,TYPE=F
}


/**
 * 中断门 用户可调
 * @param n IDT表的第几个表项
 * @param ist 索引值0到7
 * @param addr 异常处理函数的地址
 */
static inline void set_system_intr_gate(unsigned int n, unsigned char ist, void *addr) //int3
{
    _set_gate(IDT_Table + n, 0xEE, ist, addr); //P,DPL=3,TYPE=E
}


// 配置TSS段内的各个RSP和IST项
static inline void set_tss64(unsigned long rsp0, unsigned long rsp1, unsigned long rsp2,
			   unsigned long ist1, unsigned long ist2, unsigned long ist3, unsigned long ist4, unsigned long ist5, unsigned long ist6, unsigned long ist7) {
    *(unsigned long *) (TSS64_Table + 1) = rsp0;
    *(unsigned long *) (TSS64_Table + 3) = rsp1;
    *(unsigned long *) (TSS64_Table + 5) = rsp2;
    *(unsigned long *) (TSS64_Table + 9) = ist1;
    *(unsigned long *) (TSS64_Table + 11) = ist2;
    *(unsigned long *) (TSS64_Table + 13) = ist3;
    *(unsigned long *) (TSS64_Table + 15) = ist4;
    *(unsigned long *) (TSS64_Table + 17) = ist5;
    *(unsigned long *) (TSS64_Table + 19) = ist6;
    *(unsigned long *) (TSS64_Table + 21) = ist7;
}
