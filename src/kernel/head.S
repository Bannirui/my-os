// 内核的头程序 在loader中已经从16位实模式跳到32位保护模式 以及临时切换到IA-32e长模式
// 现在到了内核程序中了 但是这只是临时中转模式 接下来的内核程序将会为系统重建64位IA-32e长模式的段结构和页表结构
// 内核头程序就是内核程序中的一小段汇编代码
// 在链接的时候把0xffff800000000000+0x100000设计成了内核程序的线性地址

#include "linkage.h"

// intel代码风格
.intel_syntax noprefix
.section .text

// GAS编译器将_start作为程序默认的起始位置
ENTRY(_start)
    // 设置数据段选择子 GDT的表项2号是内核64位数据段
    // index=(10)b TI=(00)b RPL=(0)b selector=index<<3 | TI<<2 | RPL = (1,0000)b=0x10
    mov ax, 0x10 // 选择子 内核64位数据段
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov esp, 0x7e00 // 栈倒扣在这个位置往下增长 把栈临时设置在这个位置过渡一下

    lgdt [rip + GDT_POINTER]  // rip是相对寻址 取GDT_POINTER的内容作为GDTR GDTR会拿到那个地方10字节的信息 等于是知道了GDT表的起始和表长
    // 此时执行完lgdt GDT表已经就绪 但是CS还是旧的 没有更新 需要搭配一个far jump或者far call来刷新cs里面的代码段选择子
    lidt [rip + IDT_POINTER]
    // 再次设置数据段寄存器并把栈切换为64位风格的寄存器
    mov ax, 0x10 // 选择子 内核64位数据段
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x7e00

    // 内核的程序被loader加载到内存时->缓存到0x7e00->搬运到0x100000 下面布局PML的时候把PML4的相对内核头程序偏移定为1000 所以PML4的物理地址就是101000 告诉cr3寄存器PML4的物理地址在哪
    mov rax, 0x101000
    mov cr3, rax
    // 把switch_seg这个64位目标地址读到rax寄存器
    mov rax, [rip + switch_seg]
    // GDT表项1号 内核64位代码段的选择子入栈
    push 0x08
    // switch_seg地址入栈
    push rax
    // 现在栈顶依次是switch_seg地址 和 GDT表项1号的内核64位代码段选择子 lretq指令等价于pop rip; pop cs; 一下子就把cs和ip都刷新了 完成了64位的切换
    lretq

// 执行到这的时候已经是在64位模式下了
switch_seg:
    .quad entry64

entry64:
    // GDT表项1号的选在子 内核64位代码段
    mov rax, 0x10
    mov ds, rax
    mov es, rax
    mov gs, rax
    mov ss, rax
    // 内核一进入到64位模式就切到init_task_union的内核栈上
    mov rsp, [rip+_stack_start]

// 内核启动初期非常脆弱 不具备异常处理能力 IDT的初始化模块将ignore_int模块作为所有异常的处理程序
// 把IDT表的256个表项全部填成指向ignore_int的中断门描述符
// 拼一个64位的中断门描述符 64位中断门描述符共16字节 分低8字节 高8字节两部分 rax拼低8字节 rdx拼高8字节
//   字节     位        含义
// 高8字节 [127:96] 保留(设置成0)
// 高8字节 [95:64]  偏移量offset[63:32]
// 低8字节 [63:48]  偏移量offset[31:16]
// 低8字节 [47:40]  属性0x8e含义是 P=1 DPL=0 Type=0xe
// 低8字节 [39:32]  IST+保留(设置成0)
// 低8字节 [31:16]  段选择子
// 低8字节 [15:0]   偏移量offset[15:0]
setup_IDT:
    // ignore_int符号的运行时地址计算出来 RIP相对寻址 LEA(load effective address)取有效地址 算出来ignore_int的运行时地址作为完整的64位offset存到rdx
    lea rdx, [rip + ignore_int]
    // rax存放低8字节 [31:16]放段选择子
    mov rax, 0x08 << 16
    // 低8字节[15:0]放偏移量的[15:0]
    mov ax, dx
    // 低8字节[47:40]
    mov rcx, 0x8E << 40
    add rax, rcx
    // 低8字节的[63:48]放偏移量的[31:16]
    mov ecx, edx // 取偏移量的低32位
    shr ecx, 16 // 偏移量的低32位右移16位就得到了偏移量的[31:16]
    shl rcx, 48 // 再左移48位 把偏移量的[31:16]放到了8字节的[63:48]
    add rax, rcx
    // rdx放的是高8字节 高8字节的高32位放的是0 高8字节的低32位放的是偏移量offset[63:32]
    shr rdx, 32
    // rdi指向IDT表的起始地址作为写入目标
    lea rdi, [rip + IDT_Table]
    // IDT表有256个表项 每个表项16字节 循环写256个表项
    mov rcx, 256
rp_sidt:
    // 写入中断门描述符的低8字节
    mov [rdi], rax
    // 写入中断门描述符的高8字节
    mov [rdi + 8], rdx
    // 指针前进16个字节 指向下一个IDT表的表项
    add rdi, 0x10
    // 计数减1
    dec rcx
    // 计数没有减到0就继续 总共写满IDT表的256个表项
    jne rp_sidt

// 初始化GDT表的TSS描述符
setup_TSS64:
    // rdx=TSS的64位基址
    lea rdx, [rip + TSS64_Table]
    xor rax, rax
    xor rcx, rcx
    // rax[47:40] P=1 DPL=00 S=0 Type=1001 组合起来16进制就是0x89 左移40位就是放到了47到40位
    mov rax, 0x89
    shl rax, 40
    // rax[63:56]设置成Base[31:24]
    mov ecx, edx // 取出base低32位
    shr ecx, 24 // 右移24位 就是取出base[31:24]
    shl rcx, 56 // 把base[31:24]搬到rax[63:56]
    add rax, rcx
    // rax[39:16]设置成Base[23:0]
    xor rcx, rcx
    mov ecx, edx
    and ecx, 0xffffff // 取出Base[23:0]
    shl rcx, 16 // 搬到[39:16]
    add rax, rcx
    // rax[15:0]设置成limit
    add rax, 103 // TSS表用13个8字节的0定义了 总共就是104个字节 段界限=104-1=103 也可以用16进制0x67表示
    // 写入GDT GDT表项是8字节一个 TSS描述符是16字节 写到
    lea rdi, [rip+GDT_Table]
    mov [rdi+80], rax // TSS的低8字节写到GDT表项10号上
    shr rdx, 32 // TSS的低8字节
    mov [rdi+88], rdx // 放到GDT表项11号上

    mov rax, [rip+go_to_kernel]
    push 0x08 // GDT表项1号的选择子 内核64位代码段
    push rax // go_to_kernel标号地址
    // lretq指令相当于执行了pop rip; pop cs; 刷新cs和ip完成执行跳转 也就是在64位长模式下跳转到内核主程序去执行
    lretq

go_to_kernel:
    .quad Start_Kernel // 内核头程序跳到内核主程序Start_Kernel函数中

// 负责异常处理的函数 打印个信息 然后死循环挂着
ignore_int:
    // 保存现场 先保存各个寄存器的值 准备切换到内核数据段
    cld // 为了保证字符串指令的方向正确
    push rax
    push rbx
    push rcx
    push rdx
    push rbp
    push rdi
    push rsi

    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    // 段寄存器不能直接压栈 先挪到rax再压
    mov rax, es
    push rax
    mov rax, ds
    push rax
    // 切换数据段 切换到GDT表项2号的内核64位数据段 把DS和ES段寄存器设置成内核数据段 因为中断可能发生在用户态(ds es是用户数据段) 这里要访问内核的字符串和调用内核函数 必须要用内核段
    mov rax, 0x10
    mov ds, rax
    mov es, rax
    // 要打印的字符串的地址
    lea rax, [rip+int_msg]
    // 压栈 下面会平衡掉
    push rax
    // rdx=fmt
    mov rdx, rax
    // rsi=背景色 黑色
    mov rsi, 0x00000000
    // rdi=前景色 红色
    mov rdi, 0x00ff0000
    // al=0 可变参数用了0个向量寄存器
    mov rax, 0
    // 调用内核函数
    call color_printk
    // 平衡栈 把上面push的地址弹掉
    add rsp, 0x8

Loop:
    // 异常处理函数挂着
    jmp Loop

    // 因为上面的jmp Loop导致下面的代码暂时跑不进来 跟保护现场是对称的弹栈恢复+iretq返回
    pop rax
    mov ds, rax
    pop rax
    mov es, rax

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8

    pop rsi
    pop rdi
    pop rbp
    pop rdx
    pop rcx
    pop rbx
    pop rax
    iretq

int_msg:
    .asciz "Unknown interrupt or fault at RIP\n"

// 内核初始栈指针 栈顶=init_task_union起始+32K(STACK_SIZE) 全局变量_stack_start记录着系统第一个进程的内核层栈基地址
ENTRY(_stack_start)
	.quad	init_task_union + 32768

// 为操作系统创建和初始化页表及页表项
// 在64位IA-32e长模式下 页表被分为4个等级 页表容量都是4KB 每个页表项是8字节 所以用align将对齐标准设置为8字节
// 页表起始地址按照8B对其
.align 8
// 伪指令.org指定页表的起始地址 固定各个页表的起始地址 相对内核头程序起始地址偏移多少的地方
.org 0x1000

// 页表项的格式
//   位     含义
// [63:12] 物理地址
// [11:9]  AVL
// [8]     G 全局页
// [7]     PS 页大小 三层页表表示2MB 二层页表表示1G
// [6]     D 已修改 在四层页表才有意义 脏页
// [5]     A 已访问
// [4:3]   PWT 缓存控制
// [2]     U 用户态可访问
// [1]     R 可写
// [0]     P 是否存在
// 内核代码被放在物理地址0x10_0000上 偏移是0x1000 那么PML4就是在物理地址0x10_1000上
// 在64位的IA-32e模式下 页表最高可分为4个等级 每个页表项由原来的4B扩展至8B 而且分页机制除了提供4KB大小的物理页外 还提供2MB和1GB大小的物理页
// page map level 4
// 顶层页表 512项 顶层页表从物理地址0x101_000开始 占1M
__PML4E:
    .quad 0x102007 // PML4[0]=低地址空间 从虚拟地址0开始
    .fill 255,8,0
    .quad 0x102007 // PML4[256]=高地址空间 从虚拟地址0xffff_8000_0000_0000开始
    .fill 255,8,0
// 在顶层页表中2个页目录指向同一个二层页表的原因是保证CPU模式切换过程中 内核只需要低地址+高半区 没必要全覆盖
.org 0x2000
// page directory pointer table 二层页表 512项 二层页从物理地址0x102_000开始 占1M
__PDPTE:
    .quad 0x103007 // 在顶层页表中低地址和高半区的页表项物理地址都是这个 抹掉低12位就是0x103_000这个物理地址找到3层页表 U/S=1允许用户态访问
    .fill 511,8,0

.org 0x3000
// page directory 三层页表 512项 三层页表从0x103_000开始 占1M
__PDE:
// 三层页表项的低12位属性0x83对应二进制是0000_1000_0011 PS=1表示三层页表项表达的是2MB 2MB大页 不需要4层页表了
// 映射物理内存 0~128MB(64个2MB大页 恒等映射) 这样alloc_pages分配的物理内存都能通过高半区访问
    .set i, 0
    .rept 64
    .quad (i * 0x200000) + 0x87
    .set i, i + 1
    .endr
    // 启动qemu后info pci看到BAR0: 32 bit prefetchable memory at 0xfd000000 [0xfdffffff]
    // 查到显存的物理地址是0xfd000000 映射到虚拟地址0x8000000(PDE[64]) 对应的虚拟地址是0xffff8000008000000
    .quad 0xfd000087 // [0xfd000000...0xfd1fffff]
    .quad 0xfd200087 // [0xfd200000...0xfd3fffff]
    .quad 0xfd400087 // [0xfd400000...0xfd5fffff]
    .quad 0xfd600087 // [0xfd600000...0xfd7fffff]
    .quad 0xfd800087 // [0xfd800000...0xfd9fffff]
    .quad 0xfda00087 // [0xfda00000...0xfdbfffff]
    .quad 0xfdc00087 // [0xfdc00000...0xfddfffff]
    .quad 0xfde00087 // [0xfde00000...0xfdffffff]
    .fill 440,8,0 // 伪指令.fill将数值0填充到剩余的页表项里面
// 在三层页表中用2MB大页表达了3600G的物理内存

// 数据段 把全局描述符表GDT结构 中断描述符表IDT结构 任务状态段TSS结构都放在内核程序的数据段内
.section .data
.globl GDT_Table
// 正式规划的GDT表 段选择子偏移是高13 也就是说段落选择子可以检索的GDT表索引是[0...(1<<13)-1] 总共有1<<13个表项
// 规划了GDT表的规模是17个表项 后10个全部用0占位
// 64位下段的概念已经没有了 依然保留段描述符的意义 1是兼容历史和保证过渡 2是用段描述符中的其他标识位
// 每下GDT表项是8字节
//   位       含义
// [63:56] Base[31:24]
// [55]    G-粒度 64位下忽略 置0就行 0-字节 1-4K
// [54]    D/B-64位置0
// [53]    L 1表示64位代码段
// [52]    AVL 可用
// [51:48] Limit[19:16]
// [47]    P 1表示段存在
// [46:45] DPL 特权级 ring0 ring3
// [44]    S 0表示系统段比如LDT/TSS 1表示代码段/数据段
// [43]    E 0表示数据段 1表示代码段
// [42]    DC 数据段表示向上/向下扩展 代码段表示一致性
// [41]    RW 1表示可读写 0-表示可读
// [40]    A 已访问
// [39:32] Base[23:16]
// [31:16] Base[14:0]
// [15:0]  Limit[15:0]

// GDT表怎么索引呢 用段选择子 段选择子的编码规则是 16位的含义
//   位     含义
// [14:3] 索引Index 指向GDT描述符表中的第几个表项
// [2]    TI表示指示位 0表示GDT 1表示LDT
// [1:0]  RPL 请求特权级 内核=00 用户=11
// 所以拿到段选择子右移3位就是所以Index selector值=GDT的index<<3 | TI<<2 | RPL
GDT_Table:
    .quad 0x0000000000000000 // 0号(0x00) 跟32位保护模式下一样 表的第1个是空的标识作用
    .quad 0x0020980000000000 // 1号(0001<<3=0000,1000=0x08) 内核64位代码段 G=0 D/B=0 L=1 AVL=0 P=1 DPL=00 S=1 E=1 DC=0 RW=0 A=0
    .quad 0x0000920000000000 // 2号(0010<<3=0001,0000=0x10) 内核64位数据段 G=0 D/B=0 L=0 AVL=0 P=1 DPL=00 S=1 E=0 DC=0 RW=1 A=0
    .quad 0x0000f20000000000 // 3号(0011<<3=0001,1000=0x18) 用户64位数据段 G=0 D/B=0 L=0 AVL=0 P=1 DPL=11 S=1 E=0 DC=0 RW=1 A=0
    .quad 0x0020f80000000000 // 4号(0100<<3=0100,0000=0x20) 用户64位代码段 G=0 D/B=0 L=1 AVL=0 P=1 DPL=11 S=1 E=1 DC=0 RW=0 A=0
    .quad 0x0000000000000000 // 5号 占位
    .quad 0x0000000000000000 // 6号 占位
    .quad 0x00cf9a000000ffff // 7号 内核32位代码段 G=1 D/B=1 L=0 AVL=0 P=1 DPL=11 S=1 E=1 DC=0 RW=1 A=0 32位兼容模式代码是可读写的 在32位模式下还是需要段基址和段界限的
    .quad 0x00cf92000000ffff // 8号 内核32位数据段 G=1 D/B=1 L=0 AVL=0 P=1 DPL=11 S=1 E=0 DC=0 RW=1 A=0 32位兼容模式 在32位模式下还是需要段基址和段界限的
    .fill 10,8,0             // 9号空着 10号到11号放TSS描述符
GDT_END:

// 跟32位下的GDT表结构一样 区别在表地址 32位下地址4字节 64位下地址8字节
// 要告诉gdtr 10字节 2字节是表长(GDT表字节数-1)和8字节的GDT表地址
GDT_POINTER:
GDT_LIMIT: .word GDT_END - GDT_Table - 1 // GDT表的表长 也就是0-based的偏移 占2字节
GDT_BASE: .quad GDT_Table // GDT表基址占4字节

.globl IDT_Table
// IDT表 表有256项 每个项占16字节 每个项是中断描述符
// 一个64位的中断门描述符 64位中断门描述符共16字节 分低8字节 高8字节两部分
// 字节       位        含义
// 高8字节 [127:96] 保留(设置成0)
// 高8字节 [95:64]  偏移量offset[63:32]
// 低8字节 [63:48]  偏移量offset[31:16]
// 低8字节 [47:40]  属性0x8e含义是 P=1 DPL=0 Type=0xe
// 低8字节 [39:32]  IST+保留(设置成0)
// 低8字节 [31:16]  段选择子 固定值0x08
// 低8字节 [15:0]   偏移量offset[15:0]
IDT_Table:
    .fill  512,8,0
IDT_END:

IDT_POINTER:
IDT_LIMIT: .word IDT_END - IDT_Table - 1 // IDT表的表长 也就是0-based的偏移 占2字节
IDT_BASE: .quad IDT_Table // IDT表的基址占4字节

// 在GDT表里面构造一个64位的TSS任务状态段描述符 用ltr加载到任务寄存器TR
// TSS在64位模式下主要用于特权级切换时的栈RSP0和IST中段栈指针
// TSS64系统描述符格式
//    位       字段
// [95:64] Base[63:32]
// [63:56] Base[31:24]
// [47]    P 表示存在位
// [46:45] DPL
// [44]    S=0 表示系统段
// [43:40] Type=0x9 表示64位可用TSS
// [39:32] Base[23:16]
// [31:16] Base[15:0]
// [15:0] Limit[15:0]
.globl TSS64_Table
TSS64_Table:
    .fill  13,8,0
TSS64_END:

TSS64_POINTER:
TSS64_LIMIT: .word TSS64_END - TSS64_Table - 1 // TSS的表长 0-based的偏移占2字节
TSS64_BASE: .quad TSS64_Table // TSS表的基址占4字节
