// 内核的主程序
// 内核主程序 也叫内核主函数 相当于应用程序的主函数 跟主函数的不同在于 内核主程序在正常情况下是不会返回的 因为内核执行头程序没有给内核主程序提供返回地址 而且关机 重启等功能也并非在内核主程序返回的过程里实现的 所以没有必要让内核主程序返回
// 进行各个系统模块的初始化 完成后创建出系统的第一个进程init进程 然后将控制权给init进程

#include "printk.h"
#include "gate.h"
#include "trap.h"
#include "memory.h"
#include "interrupt.h"
#include "task.h"

// 没有返回地址 一旦进入就死循环
void Start_Kernel(void) {
    // 字符串打印
    init_print();

    // 编码一个TSS段选择子给TR寄存器 指向GDT表的第8项
    load_TR(8);
    // 配置TSS段内的各个RSP和IST项
    set_tss64(0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00,
              0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00);

    // 初始化IDT
    sys_vector_init();

    // 物理内存布局
    color_printk(RED,BLACK, "memory init \n");
    init_memory();

    color_printk(RED,BLACK,"interrupt init \n");
	init_interrupt();

    color_printk(RED,BLACK,"task_init \n");
	task_init();

    while (1);
}
