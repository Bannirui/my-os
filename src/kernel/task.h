//
// Created by dingrui on 8/21/26.
//

#pragma once

#include "memory.h"
#include "cpu.h"
#include "ptrace.h"

#define KERNEL_CS 	(0x08)
#define	KERNEL_DS 	(0x10)

#define	USER_CS		(0x20)
#define USER_DS		(0x18)

#define CLONE_FS	(1 << 0)
#define CLONE_FILES	(1 << 1)
#define CLONE_SIGNAL	(1 << 2)

// stack size 32K
#define STACK_SIZE 32768

extern unsigned long _stack_start;

// 进程状态
// 运行态
#define TASK_RUNNING		 (1 << 0)
// 可中断
#define TASK_INTERRUPTIBLE	 (1 << 1)
#define	TASK_UNINTERRUPTIBLE (1 << 2)
#define	TASK_ZOMBIE		     (1 << 3)
// 停止态
#define	TASK_STOPPED		 (1 << 4)

// 内存空间分布描述了进程的页表结构和各程序段信息
struct mm_struct {
	// 内存页表
    pml4t_t* pgd;
	// 代码段空间
    unsigned long start_code, end_code;
	// 数据段空间
    unsigned long start_data, end_data;
	// 只读数据段空间
    unsigned long start_rodata, end_rodata;
	// 动态内存分配区 堆区域
    unsigned long start_brk, end_brk;
	// 应用层栈基地址
    unsigned long start_stack;
};

// 每当进程发生调度切换时 都必须将寄存器的值保存起来 以备再次执行时使用 将这些数据保存在结构体里面
struct thread_struct {
	// 内核层栈基地址
    unsigned long rsp0;
	// 内核层代码指针
    unsigned long rip;
	// 内核层当前栈指针
    unsigned long rsp;
	// FS段寄存器
    unsigned long fs;
	// GS段寄存器
    unsigned long gs;
	// CR2控制寄存器
    unsigned long cr2;
	// 产生异常的异常号
    unsigned long trap_nr;
	// 异常的错误码
    unsigned long error_code;
};

// 进程标志 进程 线程 内核线程
#define PF_KTHREAD	(1 << 0)

struct task_struct {
	// 双链表 连接各个进程控制结构体
    struct List list;
	// 进程状态
    volatile long state;
	// 进程标志 进程 线程 内核线程
    unsigned long flags;
	// 内存空间分布结构体 记录内存页表和程序段信息
    struct mm_struct* mm;
	// 进程切换时保留的状态信息
    struct thread_struct* thread;
	// 进程地址空间范围
	// 0x0000,0000,0000,0000 - 0x0000,7fff,ffff,ffff user
    // 0xffff,8000,0000,0000 - 0xffff,ffff,ffff,ffff kernel
    unsigned long addr_limit;
	// 进程id号
    long pid;
	// 进程可用时间片
    long counter;
	// 进程持有的信号
    long signal;
	// 进程优先级
    long priority;
};

union task_union {
    struct task_struct task;
    unsigned long stack[STACK_SIZE / sizeof(unsigned long)];
}__attribute__((aligned (8))); //8Bytes align

extern struct mm_struct init_mm;
extern struct thread_struct init_thread;

#define INIT_TASK(tsk)	\
{			\
	.state = TASK_UNINTERRUPTIBLE,		\
	.flags = PF_KTHREAD,		\
	.mm = &init_mm,			\
	.thread = &init_thread,		\
	.addr_limit = 0xffff800000000000,	\
	.pid = 0,			\
	.counter = 1,		\
	.signal = 0,		\
	.priority = 0		\
}

extern union task_union init_task_union;

extern struct task_struct *init_task[NR_CPUS];

struct tss_struct {
    unsigned int reserved0;
    unsigned long rsp0;
    unsigned long rsp1;
    unsigned long rsp2;
    unsigned long reserved1;
    unsigned long ist1;
    unsigned long ist2;
    unsigned long ist3;
    unsigned long ist4;
    unsigned long ist5;
    unsigned long ist6;
    unsigned long ist7;
    unsigned long reserved2;
    unsigned short reserved3;
    unsigned short iomapbaseaddr;
}__attribute__((packed));

#define INIT_TSS \
{	.reserved0 = 0,	 \
	.rsp0 = (unsigned long)(init_task_union.stack + STACK_SIZE / sizeof(unsigned long)),	\
	.rsp1 = (unsigned long)(init_task_union.stack + STACK_SIZE / sizeof(unsigned long)),	\
	.rsp2 = (unsigned long)(init_task_union.stack + STACK_SIZE / sizeof(unsigned long)),	\
	.reserved1 = 0,	 \
	.ist1 = 0xffff800000007c00,	\
	.ist2 = 0xffff800000007c00,	\
	.ist3 = 0xffff800000007c00,	\
	.ist4 = 0xffff800000007c00,	\
	.ist5 = 0xffff800000007c00,	\
	.ist6 = 0xffff800000007c00,	\
	.ist7 = 0xffff800000007c00,	\
	.reserved2 = 0,	\
	.reserved3 = 0,	\
	.iomapbaseaddr = 0	\
}

extern struct tss_struct init_tss[NR_CPUS];

static inline struct task_struct* get_current() {
    struct task_struct *current = NULL;
    __asm__ __volatile__ (".intel_syntax noprefix	\n\t"
                          "and	%0,	rsp		\n\t"
                          ".att_syntax prefix	\n\t"
                          :"=r"(current):"0"(~32767UL));
    return current;
}

#define current get_current()

#define GET_CURRENT			\
	"mov	rbx,	rsp	\n\t"	\
	"and	rbx,	-32768	\n\t"

#define switch_to(prev,next)			\
do{							\
	__asm__ __volatile__ (	".intel_syntax noprefix		\n\t"	\
				"push	rbp		\n\t"	\
				"push	rax		\n\t"	\
				"mov	[%0],	rsp	\n\t"	\
				"mov	rsp,	[%2]	\n\t"	\
				"lea	rax,	[rip + 1f]	\n\t"	\
				"mov	[%1],	rax	\n\t"	\
				"push	qword ptr [%3]		\n\t"	\
				"jmp	__switch_to		\n\t"	\
				"1:				\n\t"	\
				"pop	rax			\n\t"	\
				"pop	rbp			\n\t"	\
				".att_syntax prefix		\n\t"	\
				::"r"(&prev->thread->rsp),"r"(&prev->thread->rip),	\
				  "r"(&next->thread->rsp),"r"(&next->thread->rip),"D"(prev),"S"(next)	\
				:"memory"		\
				);			\
}while(0)

unsigned long do_fork(struct pt_regs *regs, unsigned long clone_flags, unsigned long stack_start,
                      unsigned long stack_size);

void task_init();
