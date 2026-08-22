#pragma once

// 为内核写的通用宏定义

#define L1_CACHE_BYTES 32

#define asmlinkage __attribute__((regparm(0)))

#define ____cacheline_aligned __attribute__((__aligned__(L1_CACHE_BYTES)))

#define SYMBOL_NAME(X) X

#define SYMBOL_NAME_STR(X) #X

#define SYMBOL_NAME_LABEL(X) X##:

// 伪指令.globl相当于extern的作用 被修饰的东西可以被外部程序引用或访问
#define ENTRY(name)           \
    .globl SYMBOL_NAME(name); \
    SYMBOL_NAME_LABEL(name)
