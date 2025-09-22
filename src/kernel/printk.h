#ifndef __PRINTK_H__
#define __PRINTK_H__

#include <stdarg.h> // 是GUN C编译环境自带的头文件 因为有些函数需要可变函数 所以需要这个头文件的支持
#include "font.h"
#include "linkage.h"

#define ZEROPAD 1 /* pad with zero */
#define SIGN 2 /* unsigned/signed long */
#define PLUS 4 /* show plus */
#define SPACE 8 /* space if plus */
#define LEFT 16 /* left justified */
#define SPECIAL 32 /* 0x */
#define SMALL 64 /* use 'abcdef' instead of 'ABCDEF' */

#define is_digit(c) ((c) >= '0' && (c) <= '9')

#define WHITE 0x00ffffff //白
#define BLACK 0x00000000 //黑
#define RED 0x00ff0000 //红
#define ORANGE 0x00ff8000 //橙
#define YELLOW 0x00ffff00 //黄
#define GREEN 0x0000ff00 //绿
#define BLUE 0x000000ff //蓝
#define INDIGO 0x0000ffff //靛
#define PURPLE 0x008000ff //紫

struct position
{
	int XResolution; // 横向分辨率
	int YResolution; // 纵向分辨率

	int XPosition; // 当前光标位置
	int YPosition; // 当前光标位置

	int XCharSize; // 字符宽度 像素
	int YCharSize; // 字符高度 像素

	unsigned int* FB_addr; // 帧缓冲区的起始虚拟地址
	unsigned long FB_length; // 帧缓冲区总长度 字节数 32位像素是1像素占4字节 这个值就是XResolution*YResolution*4
};
extern struct position Pos; // 这里只是声明 不分配存储

void putchar(unsigned int* fb, int Xsize, int x, int y, unsigned int FRcolor, unsigned int BKcolor, unsigned char font);
int skip_atoi(const char **s);

#define do_div(n,base) ({ \
    int __res; \
    __asm__("divq %%rcx":"=a" (n),"=d" (__res):"0" (n),"1" (0),"c" (base)); \
    __res; })

static char* number(char* str, long num, int base, int size, int precision ,int type);
int vsprintf(char* buf,const char* fmt, va_list args);
int color_printk(unsigned int FRcolor, unsigned int BKcolor, const char* fmt,...);

#endif