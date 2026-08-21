#pragma once

// 为内核写的通用库函数

#define NULL 0

/**
 * 获取init内核线程的进程控制结构体
 * @param ptr 表示结构体变量内的某个成员变量的基址 通过该地址可以推算出成员变量所在的父结构体的基地址
 * @param type 成员变量所在的结构体
 * @param member 成员变量名
 */
#define container_of(ptr,type,member)                                   \
({                                                                      \
    typeof(((type *)0)->member) * p = (ptr);                            \
    (type *)((unsigned long)p - (unsigned long)&(((type *)0)->member)); \
})

#define sti() __asm__ __volatile__ ("sti \n\t":::"memory")
#define cli() __asm__ __volatile__ ("cli \n\t":::"memory")
#define nop() __asm__ __volatile__ ("nop \n\t")
#define io_mfence() __asm__ __volatile__ ("mfence \n\t":::"memory")

struct List {
    struct List *prev;
    struct List *next;
};

static inline void list_init(struct List *list) {
    list->prev = list;
    list->next = list;
}

static inline void list_add_to_behind(struct List *entry, struct List *new) {
    new->next = entry->next;
    new->prev = entry;
    new->next->prev = new;
    entry->next = new;
}

static inline void list_add_to_before(struct List *entry, struct List *new) {
    new->next = entry;
    entry->prev->next = new;
    new->prev = entry->prev;
    entry->prev = new;
}

static inline void list_del(struct List *entry) {
    entry->next->prev = entry->prev;
    entry->prev->next = entry->next;
}

static inline long list_is_empty(struct List *entry) {
    if (entry == entry->next && entry->prev == entry) {
        return 1;
    } else {
        return 0;
    }
}

static inline struct List *list_prev(struct List *entry) {
    if (entry->prev != NULL) {
        return entry->prev;
    } else {
        return NULL;
    }
}

static inline struct List *list_next(struct List *entry) {
    if (entry->next != NULL) {
        return entry->next;
    } else {
        return NULL;
    }
}

static inline void *memcpy(void *From, void *To, long Num) {
    int d0, d1, d2;
    __asm__ __volatile__ ( ".intel_syntax noprefix\n\t"
        "cld \n\t"
        "rep movsq \n\t"
        "test %b4, 4 \n\t"
        "je 1f \n\t"
        "movsd \n\t"
        "1:\ttest %b4, 2 \n\t"
        "je 2f \n\t"
        "movsw \n\t"
        "2:\ttest %b4, 1 \n\t"
        "je 3f \n\t"
        "movsb \n\t"
        "3: \n\t"
        ".att_syntax prefix\n\t"
        :"=&c"(d0),"=&D"(d1),"=&S"(d2)
        :"0"(Num / 8),"q"(Num),"1"(To),"2"(From)
        :"memory"
    );
    return To;
}

static inline int memcmp(void *FirstPart, void *SecondPart, long Count) {
    register int __res;
    __asm__ __volatile__ (".intel_syntax noprefix\n\t"
        "cld \n\t"
        "repe cmpsb \n\t"
        "je 1f \n\t"
        "mov eax, 1 \n\t"
        "jl	1f \n\t"
        "neg eax \n\t"
        "1: \n\t"
        ".att_syntax prefix\n\t"
        :"=a"(__res)
        :"0"(0),"D"(FirstPart),"S"(SecondPart),"c"(Count)
        :
    );
    return __res;
}

static inline void *memset(void *Address, unsigned char C, long Count) {
    int d0, d1;
    unsigned long tmp = C * 0x0101010101010101UL;
    __asm__ __volatile__ (".intel_syntax noprefix\n\t"
        "cld \n\t"
        "rep stosq\n\t"
        "test %b3, 4\n\t"
        "je	1f\n\t"
        "stosd\n\t"
        "1:\ttest %b3, 2\n\t"
        "je 2f\n\t"
        "stosw\n\t"
        "2:\ttest %b3, 1\n\t"
        "je 3f\n\t"
        "stosb\n\t"
        "3:\n\t"
        ".att_syntax prefix\n\t"
        :"=&c"(d0),"=&D"(d1)
        :"a"(tmp),"q"(Count),"0"(Count / 8),"1"(Address)
        :"memory"
    );
    return Address;
}

static inline char *strcpy(char *Dest, char *Src) {
    __asm__ __volatile__(".intel_syntax noprefix\n\t"
        "cld\n\t"
        "1:\n\t"
        "lodsb\n\t"
        "stosb\n\t"
        "test al, al\n\t"
        "jne 1b\n\t"
        ".att_syntax prefix\n\t"
        :
        :"S"(Src),"D"(Dest)
        :
    );
    return Dest;
}

static inline char *strncpy(char *Dest, char *Src, long Count) {
    __asm__ __volatile__ (".intel_syntax noprefix\n\t"
        "cld \n\t"
        "1: \n\t"
        "dec %2\n\t"
        "js 2f\n\t"
        "lodsb\n\t"
        "stosb\n\t"
        "test al, al\n\t"
        "jne 1b\n\t"
        "rep stosb\n\t"
        "2:\n\t"
        ".att_syntax prefix\n\t"
        :
        :"S"(Src),"D"(Dest),"c"(Count)
        :
    );
    return Dest;
}

static inline char *strcat(char *Dest, char *Src) {
    __asm__ __volatile__(".intel_syntax noprefix\n\t"
        "cld\n\t"
        "repne scasb\n\t"
        "dec %1\n\t"
        "1:\n\t"
        "lodsb\n\t"
        "stosb\n\r"
        "test al, al\n\t"
        "jne 1b\n\t"
        ".att_syntax prefix\n\t"
        :
        :"S"(Src),"D"(Dest),"a"(0),"c"(0xffffffff)
        :
    );
    return Dest;
}

static inline int strcmp(char *FirstPart, char *SecondPart) {
    register int __res;
    __asm__ __volatile__(".intel_syntax noprefix\n\t"
        "cld\n\t"
        "1:\n\t"
        "lodsb\n\t"
        "scasb\n\t"
        "jne 2f\n\t"
        "test al, al\n\t"
        "jne 1b\n\t"
        "xor eax, eax\n\t"
        "jmp 3f\n\t"
        "2:\n\t"
        "mov eax, 1\n\t""jl 3f\n\t"
        "neg eax\n\t"
        "3:\n\t"
        ".att_syntax prefix\n\t"
        :"=a"(__res)
        :"D"(FirstPart),"S"(SecondPart)
        :
    );
    return __res;
}

static inline int strncmp(char *FirstPart, char *SecondPart, long Count) {
    register int __res;
    __asm__ __volatile__(".intel_syntax noprefix\n\t"
        "cld\n\t"
        "1:\n\t"
        "dec %3\n\t"
        "js 2f\n\t"
        "lodsb\n\t"
        "scasb\n\t"
        "jne 3f\n\t"
        "test al, al\n\t"
        "jne 1b\n\t"
        "2: \n\t"
        "xor eax, eax\n\t"
        "jmp 4f\n\t"
        "3:\n\t"
        "mov eax, 1\n\t"
        "jl 4f\n\t"
        "neg eax\n\t"
        "4:\n\t"
        ".att_syntax prefix\n\t"
        :"=a"(__res)
        :"D"(FirstPart),"S"(SecondPart),"c"(Count)
        :
    );
    return __res;
}

static inline int strlen(char *String) {
    register int __res;
    __asm__ __volatile__(".intel_syntax noprefix\n\t"
        "cld\n\t"
        "repne scasb\n\t"
        "not %0\n\t"
        "dec %0\n\t"
        ".att_syntax prefix\n\t"
        :"=c"(__res)
        :"D"(String),"a"(0),"0"(0xffffffff)
        :
    );
    return __res;
}

static inline unsigned long bit_set(unsigned long *addr, unsigned long nr) {
    return *addr | (1UL << nr);
}

static inline unsigned long bit_get(unsigned long *addr, unsigned long nr) {
    return *addr & (1UL << nr);
}

static inline unsigned long bit_clean(unsigned long *addr, unsigned long nr) {
    return *addr & (~(1UL << nr));
}

static inline unsigned char io_in8(unsigned short port) {
    unsigned char ret = 0;
    __asm__ __volatile__(".intel_syntax noprefix\n\t"
        "in %0, dx\n\t"
        "mfence\n\t"
        ".att_syntax prefix\n\t"
        :"=a"(ret)
        :"d"(port)
        :"memory");
    return ret;
}

static inline unsigned int io_in32(unsigned short port) {
    unsigned int ret = 0;
    __asm__ __volatile__(".intel_syntax noprefix\n\t"
        "in %0, dx\n\t"
        "mfence\n\t"
        ".att_syntax prefix\n\t"
        :"=a"(ret)
        :"d"(port)
        :"memory");
    return ret;
}

static inline void io_out8(unsigned short port, unsigned char value) {
    __asm__ __volatile__(".intel_syntax noprefix\n\t"
        "out dx, %0\n\t"
        "mfence\n\t"
        ".att_syntax prefix\n\t"
        :
        :"a"(value),"d"(port)
        :"memory");
}

static inline void io_out32(unsigned short port, unsigned int value) {
    __asm__ __volatile__(".intel_syntax noprefix\n\t"
        "out dx, %0\n\t"
        "mfence \n\t"
        ".att_syntax prefix\n\t"
        :
        :"a"(value),"d"(port)
        :"memory");
}

#define port_insw(port, buffer, nr) \
__asm__ __volatile__("cld;rep;insw;mfence;"::"d"(port),"D"(buffer),"c"(nr):"memory")

#define port_outsw(port,buffer,nr) \
__asm__ __volatile__("cld;rep;outsw;mfence;"::"d"(port),"S"(buffer),"c"(nr):"memory")

static inline unsigned long rdmsr(unsigned long address) {
    unsigned int tmp0 = 0;
    unsigned int tmp1 = 0;
    __asm__ __volatile__("rdmsr \n\t":"=d"(tmp0),"=a"(tmp1):"c"(address):"memory");
    return (unsigned long) tmp0 << 32 | tmp1;
}

// 将WRMSR汇编指令封装
static inline void wrmsr(unsigned long address, unsigned long value) {
    __asm__ __volatile__("wrmsr \n\t"::"d"(value >> 32),"a"(value & 0xffffffff),"c"(address):"memory");
}
