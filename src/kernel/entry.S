#include "linkage.h"

.intel_syntax noprefix

// 异常的处理过程会涉及到执行现场的保存工作 由于C语言没办法实现寄存器的压栈操作 就先借助汇编在异常处理成语的入口处保存程序的现场环境 然后再执行C语言的异常处理函数

R15	= 0x00
R14	= 0x08
R13	= 0x10
R12	= 0x18
R11	= 0x20
R10	= 0x28
R9 = 0x30
R8 = 0x38
RBX	= 0x40
RCX	= 0x48
RDX	= 0x50
RSI	= 0x58
RDI	= 0x60
RBP	= 0x68
DS = 0x70
ES = 0x78
RAX	= 0x80
FUNC = 0x88
ERRCODE	= 0x90
RIP	= 0x98
CS = 0xa0
RFLAGS = 0xa8
OLDRSP = 0xb0
OLDSS = 0xb8

RESTORE_ALL:
    pop	r15
	pop	r14
	pop	r13
	pop	r12
	pop	r11
	pop	r10
	pop	r9
	pop	r8
	pop	rbx
	pop	rcx
	pop	rdx
	pop	rsi
	pop	rdi
	pop	rbp
	pop	rax
	mov	ds,	rax
	pop	rax
	mov	es,	rax
	pop	rax
	add	rsp, 0x10
	iretq

#define GET_CURRENT(reg) \
	mov	reg, -32768	     \
	and	reg, rsp

// GET_CURRENT(ebx) need rewrite
ret_from_exception:
ENTRY(ret_from_intr)
    jmp	RESTORE_ALL

// 保存用户栈指针 供system_call入口切换到内核栈使用
.section .bss
.globl syscall_user_rsp
syscall_user_rsp:
    .quad 0
.section .text

// 系统调用API的接口
// 当应用程序执行syscall指令进入内核层时 会通过system_call模块保存应用程序的执行现场 随后使用call指令调用system_call_function函数
// syscall指令把用户返回地址保存到RCX 用户RFLAGS保存到R11 但不自动切换栈 需要手动保存用户RSP并切换到内核栈(TSS.rsp0)
ENTRY(system_call)
    // 保存用户RSP 切换到内核栈(TSS.rsp0)
    mov [rip + syscall_user_rsp], rsp
    lea rdx, [rip + TSS64_Table]
    mov rsp, [rdx + 4] // TSS.rsp0 内核栈顶
    sub rsp, 0x38 // 预留 func/errcode/rip/cs/rflags/rsp/ss 7个qword
    // 填 rip/cs/rflags/rsp/ss
    mov [rsp + 0x10], rcx // rip = 用户返回地址
    mov qword ptr [rsp + 0x18], 0x20 // cs = USER_CS
    mov [rsp + 0x20], r11 // rflags = 用户RFLAGS
    mov rdx, [rip + syscall_user_rsp]
    mov [rsp + 0x28], rdx // rsp = 用户RSP
    mov qword ptr [rsp + 0x30], 0x18 // ss = USER_DS
    sti
    // 保存通用寄存器
    push rax // rax(0x80) 系统调用号
    mov rax, es
    push rax // es(0x78)
    mov rax, ds
    push rax // ds(0x70)
    push rbp // rbp(0x68)
    push rdi // rdi(0x60)
    push rsi // rsi(0x58)
    push rdx // rdx(0x50)
    push rcx // rcx(0x48)
    push rbx // rbx(0x40)
    push r8 // r8(0x38)
    push r9 // r9(0x30)
    push r10 // r10(0x28)
    push r11 // r11(0x20)
    push r12 // r12(0x18)
    push r13 // r13(0x10)
    push r14 // r14(0x08)
    push r15 // r15(0x00)
    mov rdx, 0x10
    mov ds, rdx
    mov es, rdx
    mov rdi, rsp

    call system_call_function

// 系统调用返回 sysretq要求RCX=用户返回地址 R11=用户RFLAGS RSP=用户栈 CS/SS由STAR决定
ENTRY(ret_system_call)
    mov [rsp + 0x80], rax // 保存返回值到 regs->rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbx
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rbp
    pop rax
    mov ds, rax
    pop rax
    mov es, rax
    pop rax
    // rsp现在指向0x88(func) [rsp+0x10]=rip [rsp+0x20]=rflags [rsp+0x28]=用户rsp
    mov rcx, [rsp + 0x10] // rcx = 用户返回地址
    mov r11, [rsp + 0x20] // r11 = 用户rflags
    mov rsp, [rsp + 0x28] // rsp = 用户栈
    sysretq

ENTRY(divide_error)
	push 0
	push rax
	lea	rax, [rip + do_divide_error]
	xchg [rsp],	rax

error_code:
	push rax
	mov	rax, es
	push rax
	mov	rax, ds
	push rax
	xor	rax, rax

	push rbp
	push rdi
	push rsi
	push rdx
	push rcx
	push rbx
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15

	cld
	mov	rsi, [rsp + ERRCODE]
	mov	rdx, [rsp + FUNC]

	mov	rdi, 0x10
	mov	ds,	rdi
	mov	es,	rdi

	mov	rdi, rsp

	call rdx

	jmp	ret_from_exception

ENTRY(debug)
	push 0
	push rax
	lea	rax, [rip + do_debug]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(nmi)
	push rax
	cld
	push rax

	push rax
	mov	rax, es
	push rax
	mov	rax, ds
	push rax
	xor	rax, rax

	push rbp
	push rdi
	push rsi
	push rdx
	push rcx
	push rbx
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15

	mov	rdx, 0x10
	mov	ds,	rdx
	mov	es,	rdx

	mov	rsi, 0
	mov	rdi, rsp

	call do_nmi

	jmp	RESTORE_ALL

ENTRY(int3)
	push 0
	push rax
	lea	rax, [rip + do_int3]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(overflow)
	push 0
	push rax
	lea	rax, [rip + do_overflow]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(bounds)
	push 0
	push rax
	lea	rax, [rip + do_bounds]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(undefined_opcode)
	push 0
	push rax
	lea	rax, [rip + do_undefined_opcode]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(dev_not_available)
	push 0
	push rax
	lea	rax, [rip + do_dev_not_available]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(double_fault)
	push rax
	lea	rax, [rip + do_double_fault]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(coprocessor_segment_overrun)
	push 0
	push rax
	lea	rax, [rip + do_coprocessor_segment_overrun]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(invalid_TSS)
	push rax
	lea	rax, [rip + do_invalid_TSS]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(segment_not_present)
	push rax
	lea	rax, [rip + do_segment_not_present]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(stack_segment_fault)
	push rax
	lea	rax, [rip + do_stack_segment_fault]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(general_protection)
	push rax
	lea	rax, [rip + do_general_protection]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(page_fault)
	push rax
	lea	rax, [rip + do_page_fault]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(x87_FPU_error)
	push 0
	push rax
	lea	rax, [rip + do_x87_FPU_error]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(alignment_check)
	push rax
	lea	rax, [rip + do_alignment_check]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(machine_check)
	push 0
	push rax
	lea	rax, [rip + do_machine_check]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(SIMD_exception)
	push 0
	push rax
	lea	rax, [rip + do_SIMD_exception]
	xchg [rsp],	rax
	jmp	error_code

ENTRY(virtualization_exception)
	push 0
	push rax
	lea	rax, [rip + do_virtualization_exception]
	xchg [rsp],	rax
	jmp	error_code
