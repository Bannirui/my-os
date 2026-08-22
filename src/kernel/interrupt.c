//
// Created by dingrui on 8/21/26.
//

#include "interrupt.h"

#include "linkage.h"
#include "lib.h"
#include "printk.h"
#include "memory.h"
#include "gate.h"
#include "ptrace.h"


#define SAVE_ALL		\
	"cld\n\t"		    \
	"push rax\n\t"		\
	"push rax\n\t"		\
	"mov rax, es\n\t"	\
	"push rax\n\t"		\
	"mov rax, ds\n\t"	\
	"push rax\n\t"		\
	"xor rax, rax\n\t"	\
	"push rbp\n\t"		\
	"push rdi\n\t"		\
	"push rsi\n\t"		\
	"push rdx\n\t"		\
	"push rcx\n\t"		\
	"push rbx\n\t"		\
	"push r8\n\t"	    \
	"push r9\n\t"       \
	"push r10\n\t"		\
	"push r11\n\t"		\
	"push r12\n\t"		\
	"push r13\n\t"		\
	"push r14\n\t"		\
	"push r15\n\t"		\
	"mov rdx, 0x10\n\t" \
	"mov ds, rdx\n\t"   \
	"mov es, rdx\n\t"

#define IRQ_NAME2(nr) nr##_interrupt(void)
#define IRQ_NAME(nr) IRQ_NAME2(IRQ##nr)


#define Build_IRQ(nr)							     \
void IRQ_NAME(nr);						             \
__asm__ (	SYMBOL_NAME_STR(IRQ)#nr"_interrupt:\n\t" \
			".intel_syntax noprefix\n\t"             \
			"push 0\n\t"                             \
			SAVE_ALL                                 \
			"mov rdi, rsp\n\t"                       \
			"lea rax, [rip + ret_from_intr]\n\t"     \
			"push rax\n\t"                           \
			"mov rsi, "#nr"\n\t"                     \
			"jmp do_IRQ\n\t"                         \
			".att_syntax prefix\n\t");


Build_IRQ(0x20)
Build_IRQ(0x21)
Build_IRQ(0x22)
Build_IRQ(0x23)
Build_IRQ(0x24)
Build_IRQ(0x25)
Build_IRQ(0x26)
Build_IRQ(0x27)
Build_IRQ(0x28)
Build_IRQ(0x29)
Build_IRQ(0x2a)
Build_IRQ(0x2b)
Build_IRQ(0x2c)
Build_IRQ(0x2d)
Build_IRQ(0x2e)
Build_IRQ(0x2f)
Build_IRQ(0x30)
Build_IRQ(0x31)
Build_IRQ(0x32)
Build_IRQ(0x33)
Build_IRQ(0x34)
Build_IRQ(0x35)
Build_IRQ(0x36)
Build_IRQ(0x37)

void (*interrupt[24])(void) = {
    IRQ0x20_interrupt,
    IRQ0x21_interrupt,
    IRQ0x22_interrupt,
    IRQ0x23_interrupt,
    IRQ0x24_interrupt,
    IRQ0x25_interrupt,
    IRQ0x26_interrupt,
    IRQ0x27_interrupt,
    IRQ0x28_interrupt,
    IRQ0x29_interrupt,
    IRQ0x2a_interrupt,
    IRQ0x2b_interrupt,
    IRQ0x2c_interrupt,
    IRQ0x2d_interrupt,
    IRQ0x2e_interrupt,
    IRQ0x2f_interrupt,
    IRQ0x30_interrupt,
    IRQ0x31_interrupt,
    IRQ0x32_interrupt,
    IRQ0x33_interrupt,
    IRQ0x34_interrupt,
    IRQ0x35_interrupt,
    IRQ0x36_interrupt,
    IRQ0x37_interrupt,
};

void init_interrupt() {
    int i;
    for (i = 32; i < 56; i++) {
        set_intr_gate(i, 2, interrupt[i - 32]);
    }

    color_printk(RED,BLACK, "8259A init \n");

    //8259A-master	ICW1-4
    io_out8(0x20, 0x11);
    io_out8(0x21, 0x20);
    io_out8(0x21, 0x04);
    io_out8(0x21, 0x01);

    //8259A-slave	ICW1-4
    io_out8(0xa0, 0x11);
    io_out8(0xa1, 0x28);
    io_out8(0xa1, 0x02);
    io_out8(0xa1, 0x01);

    //8259A-M/S	OCW1
    io_out8(0x21, 0xfd);
    io_out8(0xa1, 0xff);

    sti();
}

void do_IRQ(struct pt_regs *regs, unsigned long nr) {
    color_printk(RED,BLACK, "do_IRQ:%#018lx\t", nr);
    unsigned char x = io_in8(0x60);
    color_printk(RED,BLACK, "key code:%#018lx\t", x);
    io_out8(0x20, 0x20);
    color_printk(RED,BLACK, "regs:%#018lx\t<RIP:%#018lx\tRSP:%#018lx>\n", regs, regs->rip, regs->rsp);
}
