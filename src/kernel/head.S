// 内核的头程序 在loader中已经从16位实模式跳到32位保护模式 以及临时切换到IA-32e长模式
// 现在到了内核程序中了 需要依赖内核头程序为系统重建64位IA-32e长模式的段结构和页表结构
// 代码风格是AT&T
// 在链接的时候把0xffff800000000000+0x100000设计成了内核程序的线性地址
.section .text

.globl _start
// GAS编译器将_start作为程序默认的起始位置
_start:
    // 准备重建GDT和IDT结构 设置数据段选择子
    mov $0x10, %ax // 0x10高13位是2 设置数据段选择子 对应的GDT表索引是2
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %ss
    mov $0x7E00, %esp // 栈倒扣在这个位置往下增长

    lgdt GDT_POINTER(%rip) // rip是相对寻址 取GDT_POINTER的内容作为GDTR GDTR会拿到那个地方10字节的信息 等于是知道了GDT表的起始和表长

    lidt IDT_POINTER(%rip)

    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss
    movq $0x7E00, %rsp

    movq $0x101000, %rax
    movq %rax, %cr3
    movq switch_seg(%rip), %rax
    pushq $0x08
    pushq %rax
    lretq

switch_seg:
    .quad entry64

entry64:
    movq $0x10, %rax
    movq %rax, %ds
    movq %rax, %es
    movq %rax, %gs
    movq %rax, %ss
    movq $0xffff800000007E00, %rsp

    movq go_to_kernel(%rip), %rax
    pushq $0x08
    pushq %rax
    lretq

go_to_kernel:
    .quad Start_Kernel // 内核头程序跳到内核主程序Start_Kernel函数中

// 为操作系统创建和初始化页表及页表项
.align 8 // 在64位IA-32e长模式下 页表被分为4个等级 每个页表项是8字节 所以用align将对齐标准设置为8字节

.org 0x1000 // 指定页表的起始地址 固定各个页表的起始地址 相对内核头程序起始地址偏移多少的地方
__PML4E:
    .quad 0x102007
    .fill 255,8,0
    .quad 0x102007
    .fill 255,8,0

.org 0x2000
__PDPTE:
    .quad 0x103003
    .fill 511,8,0

.org 0x3000
__PDE:
    .quad 0x000083
    .quad 0x200083
    .quad 0x400083
    .quad 0x600083
    .quad 0x800083
    .quad 0xe0000083
    .quad 0xe0200083
    .quad 0xe0400083
    .quad 0xe0600083
    .quad 0xe0800083
    .quad 0xe0a00083
    .quad 0xe0c00083
    .quad 0xe0e00083
    .fill 499,8,0

// 数据段 把全局描述符表GDT结构 中断描述符表IDT结构 任务状态段TSS结构都放在内核程序的数据段内
.section .data
.globl GDT_Table
// 正式规划的GDT表 段选择子偏移是高13 也就是说段落选择子可以检索的GDT表索引是[0...(1<<13)-1] 总共有1<<13个表项
// 规划了GDT表的规模是17个表项 后10个全部用0占位
//   15    14    13    12    11    10    9     8     7     6     5     4     3     2     1     0
//+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
//|                   Base[31:24]                 |  G  | D/B |  L  | AVL |      Limit[19:16]     |
//+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
//|  P  |     DPL   |  S  |  E  |  DC | RW  |  A  |              Base[23:16]                      |
//+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
//|                                     Base[15:0]                                                |
//+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
//|                                    Limit[15:0]                                                |
//+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
// 64位下段的概念已经没有了 依然保留段描述符的意义 1是兼容历史和保证过渡 2是用段描述符中的其他标识位
// G-粒度 64位下忽略 置0就行 0-字节 1-4K
// D/B-64位置0
// L-1表示64位代码段
// AVL-可用
// P-1表示段存在
// DPL-特权级 ring0 ring3
// S-0表示系统段比如LDT/TSS 1表示代码段/数据段
// E-0表示数据段 1表示代码段
// DC-数据段表示向上/向下扩展 代码段表示一致性
// RW-1表示可读写 0-表示可读
// A-已访问
GDT_Table:
    .quad 0x0000000000000000 // 跟32位保护模式下一样 表的第1个是空的标识作用
    .quad 0x0020980000000000 // 内核代码段 G=0 D/B=0 L=1 AVL=0 P=1 DPL=00 S=1 E=1 DC=0 RW=0 A=0
    .quad 0x0000920000000000 // 内核数据段 G=0 D/B=0 L=0 AVL=0 P=1 DPL=00 S=1 E=0 DC=0 RW=1 A=0
    .quad 0x0020f80000000000 // 用户代码段 G=0 D/B=0 L=1 AVL=0 P=1 DPL=11 S=1 E=1 DC=0 RW=0 A=0
    .quad 0x0000f20000000000 // 用户数据段 G=0 D/B=0 L=0 AVL=0 P=1 DPL=11 S=1 E=0 DC=0 RW=1 A=0
    .quad 0x00cf9a000000ffff // 32位代码段 G=1 D/B=1 L=0 AVL=0 P=1 DPL=11 S=1 E=1 DC=0 RW=1 A=0 32位兼容模式代码是可读写的 在32位模式下还是需要段基址和段界限的
    .quad 0x00cf92000000ffff // 32位数据段 G=1 D/B=1 L=0 AVL=0 P=1 DPL=11 S=1 E=0 DC=0 RW=1 A=0 32位兼容模式 在32位模式下还是需要段基址和段界限的
    .fill 10,8,0
GDT_END:

// 跟32位下的GDT表结构一样 区别在表地址 32位下地址4字节 64位下地址8字节
// 要告诉gdtr 10字节 2字节是表长(GDT表字节数-1)和8字节的GDT表地址
GDT_POINTER:
GDT_LIMIT: .word GDT_END - GDT_Table - 1 // 2字节
GDT_BASE: .quad GDT_Table // 4字节

.globl IDT_Table
IDT_Table:
    .fill  512,8,0
IDT_END:

IDT_POINTER:
IDT_LIMIT: .word IDT_END - IDT_Table - 1
IDT_BASE: .quad IDT_Table

.globl TSS64_Table
TSS64_Table:
    .fill  13,8,0
TSS64_END:

TSS64_POINTER:
TSS64_LIMIT: .word TSS64_END - TSS64_Table - 1
TSS64_BASE: .quad TSS64_Table