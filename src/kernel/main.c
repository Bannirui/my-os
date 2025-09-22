// 内核的主程序 进行各个系统模块的初始化 完成后创建出系统的第一个进程init进程 然后将控制权给init进程

#include "printk.h"

#define WIDTH 1440
#define HEIGHT 900

void Start_Kernel(void)
{
    // 关于虚拟地址映射的物理地址
    // 1 0xffff800000a00000这个虚拟地址的有效地址位是低48位0x800000a00_000
    // 2 把48位分成5个部分
    //   顶层页表的索引9位 1_0000_0000=0x100=256
    //   2层页表的索引9位 000000000=0x0=0
    //   3层页表的索引9位 000000101=0x5=5
    //   4层页表的索引9位 000000000=0x0=0
    //   页内偏移12位 0x0
    // 3 cr3寄存器中存着PML4的基址 从cr3寄存器中读出来0x101000
    // 4 在顶层页表找到页表项地址0x101000 偏移256的地址=0x101000+8*256=0x101800 这个页表项里面存放着0x102007
    // 5 找到2层页表地址0x102000 偏移0的地址 还是0x102000 这个页表项里面存放着0x103003
    // 6 0x103003抹掉它的低12位后物理地址是0x103000 找到这个物理地址是3层页表项 3层页表的偏移是5拿到的3层页表表项里面存着0xe0000083
    // 7 0xe0000083的低12位0x83标志位PS=1 表示3层页表用的大页2MB 没有4层页表的事情了 这个表项表达的物理地址区间是[0xe0000000...E01FFFFF]
    // 8 页内偏移是0 所以最终的物理地址是0xe0000000
    int* addr = (int*)0xffff800000a00000; // 显存的虚拟地址
    int i;
    Pos.XResolution = WIDTH;
    Pos.YResolution = HEIGHT;
    Pos.XPosition = 0;
    Pos.YPosition = 0;
    Pos.XCharSize = 8;
    Pos.YCharSize = 16;

    Pos.FB_addr = (int*)0xffff800000a00000; // 帧缓冲区地址
    Pos.FB_length = (Pos.XResolution * Pos.YResolution * 4); // 缓冲区多少字节 32位像素 1像素占4字节

    // 红色 R=0xff B=0x00 G=0x00 A=0x00 绘制一个色块 长WIDTH 高20像素
    for(i=0 ;i<WIDTH*HEIGHT; i++) {
        // 绘制1个像素占4字节 写完1个像素后移4字节准备写下一个像素
        *addr++=BLUE;
    }
    color_printk(YELLOW,BLACK,"HELLO WORLD\t\nThis is Dingrui, welcome to my Operating System.\nNumber is %d", 1);

    while(1);
}