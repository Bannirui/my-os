//
// Created by dingrui on 8/21/26.
//

#include "task.h"

#include "ptrace.h"
#include "printk.h"
#include "lib.h"
#include "memory.h"
#include "gate.h"

extern void system_call(void);

extern void ret_system_call(void);

struct mm_struct init_mm = {0};

struct thread_struct init_thread =
{
    // 全局变量_stack_start保存的值跟这个地方rsp0成员变量的值 是一样的 都指向了系统第一个进程的内核层栈基地址
    .rsp0 = (unsigned long) (init_task_union.stack + STACK_SIZE / sizeof(unsigned long)),
    .rsp = (unsigned long) (init_task_union.stack + STACK_SIZE / sizeof(unsigned long)),
    .fs = KERNEL_DS,
    .gs = KERNEL_DS,
    .cr2 = 0,
    .trap_nr = 0,
    .error_code = 0
};

#define MAX_SYSTEM_CALL_NR 128

typedef unsigned long (*system_call_t)(struct pt_regs* regs);

unsigned long no_system_call(struct pt_regs* regs) {
    color_printk(RED,BLACK, "no_system_call is calling,NR:%#04x\n", regs->rax);
    return -1;
}

// 系统调用处理函数 系统调用向量号是1
unsigned long sys_printf(struct pt_regs* regs) {
    color_printk(BLACK,WHITE, (char *) regs->rdi);
    return 1;
}

system_call_t system_call_table[MAX_SYSTEM_CALL_NR] =
{
    [0] = no_system_call,
    [1] = sys_printf,
    [2 ... MAX_SYSTEM_CALL_NR - 1] = no_system_call
};

union task_union init_task_union __attribute__((__section__ (".data.init_task"))) = {INIT_TASK(init_task_union.task)};

struct task_struct *init_task[NR_CPUS] = {&init_task_union.task, 0};

struct tss_struct init_tss[NR_CPUS] = {[0 ... NR_CPUS - 1] = INIT_TSS};

/**
 * sysenter/sysexit指令并不具备保存程序执行环境的功能
 * sysexit指令的执行必须要向RCX与RDX寄存器提供应用程序的返回地址和栈顶地址
 * 在执行sysenter指令前 将应用程序的返回地址和栈顶地址保存在这两个寄存器内
 *
 * 这个函数是系统调用在应用层的核心
 * 通过汇编lea取得标识符sysexit_return_address的有效地址 并将有效地址保存到RDX寄存器
 * RCX寄存器保存着应用层的当前指针
 * RAX寄存器是系统调用API的向量号
 * 当系统调用处理函数执行结束 系统调用处理函数便借助RAX寄存器把执行结果返回到应用层并保存在变量ret中
 */
void user_level_function() {
    long ret = 0;
    char string[] = "Hello World!\n";
    // 约束"0"(1)把rax设置成了1
    // "D"(string)把rdi设置成了字符串地址
    // 然后sysenter进入了entry.S的system_call
    __asm__ __volatile__ ( ".intel_syntax noprefix\n\t"
        "syscall\n\t"
        ".att_syntax prefix\n\t"
        :"=a"(ret):"0"(1),"D"(string):"rcx","r11","memory");
    while (1);
}

/**
 * @param regs 应用程序的执行环境
 */
unsigned long do_execve(struct pt_regs *regs) {
    regs->rdx = 0x800000; // RIP (sysexit约定 保留)
    regs->rcx = 0x9ff000; // RSP (sysexit约定 保留)
    regs->rip = 0x800000; // RIP sysret用
    regs->rsp = 0x9ff000; // RSP sysret用
    regs->rflags = (1 << 9); // IF sysret用
    regs->rax = 1;
    regs->ds = 0;
    regs->es = 0;
    color_printk(RED,BLACK, "do_execve task is running\n");
    // 把应用层的执行函数复制到线性地址0x800000上 当处理器切换到应用层后 应用程序将会从这个地址开始执行
    memcpy(user_level_function, (void *) 0x800000, 1024);

    return 0;
}

unsigned long init(unsigned long arg) {
    struct pt_regs *regs;

    color_printk(RED,BLACK, "init task is running,arg:%#018lx\n", arg);

    current->thread->rip = (unsigned long) ret_system_call;
    current->thread->rsp = (unsigned long) current + STACK_SIZE - sizeof(struct pt_regs);
    regs = (struct pt_regs *) current->thread->rsp;
    // 系统还没有应用程序 现在的init依然是个内核线程 执行execve系统调用API 可使init内核线程执行新的程序 进而转变为应用程序
    // 调用execve系统调用API的处理函数do_exceve 借助push指令将程序的返回地址压入栈 采用jmp指令调用函数do_execve
    __asm__ __volatile__ ( ".intel_syntax noprefix\n\t"
        "mov rsp, %1\n\t"
        "push %2\n\t"
        "jmp do_execve\n\t"
        ".att_syntax prefix\n\t"
        ::"D"(regs),"r"(current->thread->rsp),"r"(current->thread->rip):"memory");

    return 1;
}

unsigned long do_fork(struct pt_regs *regs, unsigned long clone_flags, unsigned long stack_start,
                      unsigned long stack_size) {
    struct task_struct *tsk = NULL;
    struct thread_struct *thd = NULL;
    struct Page *p = NULL;

    color_printk(WHITE,BLACK, "alloc_pages,bitmap:%#018lx\n", *memory_management_struct.bits_map);

    p = alloc_pages(ZONE_NORMAL, 1,PG_PTable_Maped | PG_Active | PG_Kernel);

    color_printk(WHITE,BLACK, "alloc_pages,bitmap:%#018lx\n", *memory_management_struct.bits_map);

    tsk = (struct task_struct *) Phy_To_Virt(p->PHY_address);
    color_printk(WHITE,BLACK, "struct task_struct address:%#018lx\n", (unsigned long) tsk);

    memset(tsk, 0, sizeof(*tsk));
    *tsk = *current;

    list_init(&tsk->list);
    list_add_to_before(&init_task_union.task.list, &tsk->list);
    tsk->pid++;
    tsk->state = TASK_UNINTERRUPTIBLE;

    thd = (struct thread_struct *) (tsk + 1);
    tsk->thread = thd;

    memcpy(regs, (void *) ((unsigned long) tsk + STACK_SIZE - sizeof(struct pt_regs)), sizeof(struct pt_regs));

    thd->rsp0 = (unsigned long) tsk + STACK_SIZE;
    thd->rip = regs->rip;
    thd->rsp = (unsigned long) tsk + STACK_SIZE - sizeof(struct pt_regs);

    if (!(tsk->flags & PF_KTHREAD)) {
        // ret_from_intr模块使用的是汇编代码iretq
        // ret_from_call模块使用的是汇编代码sysexit
        // 作为一个系统调用的处理函数 应该返回ret_system_call
        thd->rip = regs->rip = (unsigned long) ret_system_call;
    }

    tsk->state = TASK_RUNNING;

    return 0;
}

unsigned long do_exit(unsigned long code) {
    color_printk(RED,BLACK, "exit task is running,arg:%#018lx\n", code);
    while (1);
}

unsigned long system_call_function(struct pt_regs *regs) {
    return system_call_table[regs->rax](regs);
}

extern void kernel_thread_func(void);
__asm__ (
    ".intel_syntax noprefix\n\t"
    ".globl kernel_thread_func\n\t"
    "kernel_thread_func:\n\t"
    "   pop r15\n\t"
    "   pop	r14\n\t"
    "   pop	r13\n\t"
    "   pop	r12\n\t"
    "	pop	r11\n\t"
    "	pop	r10\n\t"
    "	pop	r9\n\t"
    "	pop	r8\n\t"
    "	pop	rbx\n\t"
    "	pop	rcx\n\t"
    "	pop	rdx\n\t"
    "	pop	rsi\n\t"
    "	pop	rdi\n\t"
    "	pop	rbp\n\t"
    "	pop	rax\n\t"
    "	mov	ds,	rax\n\t"
    "	pop	rax\n\t"
    "	mov	es,	rax\n\t"
    "	pop	rax\n\t"
    "	add	rsp, 0x38\n\t"
    "	mov	rdi, rdx\n\t"
    "	call rbx\n\t"
    "	mov	rdi, rax\n\t"
    "	call do_exit\n\t"
    ".att_syntax prefix\n\t"
);

int kernel_thread(unsigned long (*fn)(unsigned long), unsigned long arg, unsigned long flags) {
    struct pt_regs regs;
    memset(&regs, 0, sizeof(regs));

    regs.rbx = (unsigned long) fn;
    regs.rdx = (unsigned long) arg;

    regs.ds = KERNEL_DS;
    regs.es = KERNEL_DS;
    regs.cs = KERNEL_CS;
    regs.ss = KERNEL_DS;
    regs.rflags = (1 << 9);
    regs.rip = (unsigned long) kernel_thread_func;

    return do_fork(&regs, flags, 0, 0);
}

void __switch_to(struct task_struct *prev, struct task_struct *next) {
    init_tss[0].rsp0 = next->thread->rsp0;

    set_tss64(init_tss[0].rsp0, init_tss[0].rsp1, init_tss[0].rsp2, init_tss[0].ist1, init_tss[0].ist2,
              init_tss[0].ist3, init_tss[0].ist4, init_tss[0].ist5, init_tss[0].ist6, init_tss[0].ist7);

    __asm__ __volatile__(
        ".intel_syntax noprefix\n\t"
        "mov %0, fs\n\t"
        ".att_syntax prefix\n\t"
        :
        "=a"(prev->thread->fs));

    __asm__ __volatile__(
        ".intel_syntax noprefix\n\t"
        "mov %0,	gs\n\t"
        ".att_syntax prefix\n\t"
        :
        "=a"(prev->thread->gs));

    __asm__ __volatile__(
        ".intel_syntax noprefix\n\t"
        "mov fs, %0\n\t"
        ".att_syntax prefix\n\t"
        ::
        "a"(next->thread->fs));

    __asm__ __volatile__(
        ".intel_syntax noprefix\n\t"
        "mov gs, %0\n\t"
        ".att_syntax prefix\n\t"
        ::
        "a"(next->thread->gs));

    color_printk(WHITE,BLACK, "prev->thread->rsp0:%#018lx\n", prev->thread->rsp0);
    color_printk(WHITE,BLACK, "next->thread->rsp0:%#018lx\n", next->thread->rsp0);
}

void task_init() {
    struct task_struct *p = NULL;

    init_mm.pgd = (pml4t_t *) Global_CR3;

    init_mm.start_code = memory_management_struct.start_code;
    init_mm.end_code = memory_management_struct.end_code;

    init_mm.start_data = (unsigned long) &_data;
    init_mm.end_data = memory_management_struct.end_data;

    init_mm.start_rodata = (unsigned long) &_rodata;
    init_mm.end_rodata = (unsigned long) &_erodata;

    init_mm.start_brk = 0;
    init_mm.end_brk = memory_management_struct.end_brk;

    init_mm.start_stack = _stack_start;
    // 由于IA32_SYSENTER_CS寄存器位于寄存器组0x174地址处 所以处理器只能借助WRMSR汇编指令才能向MSR寄存器写入数据
    wrmsr(0xC0000080, rdmsr(0xC0000080) | 1);         // EFER.SCE 使能syscall/sysret
    wrmsr(0xC0000081, ((unsigned long)0x10 << 48) | ((unsigned long)0x08 << 32)); // STAR
    wrmsr(0xC0000082, (unsigned long) system_call);   // LSTAR
    wrmsr(0xC0000084, 0x200);                         // SFMASK 屏蔽IF system_call入口sti开启
    //	init_thread,init_tss
    set_tss64(init_thread.rsp0, init_tss[0].rsp1, init_tss[0].rsp2, init_tss[0].ist1, init_tss[0].ist2,
              init_tss[0].ist3, init_tss[0].ist4, init_tss[0].ist5, init_tss[0].ist6, init_tss[0].ist7);

    init_tss[0].rsp0 = init_thread.rsp0;

    list_init(&init_task_union.task.list);

    kernel_thread(init, 10,CLONE_FS | CLONE_FILES | CLONE_SIGNAL);

    init_task_union.task.state = TASK_RUNNING;

    p = container_of(list_next(&current->list), struct task_struct, list);

    switch_to(current, p);
}
