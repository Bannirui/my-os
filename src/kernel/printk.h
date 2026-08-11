#pragma once

#include <stdarg.h> // 是GUN C编译环境自带的头文件 因为有些函数需要可变参数 所以需要这个头文件的支持

// 左侧补0 %05d
#define ZEROPAD 1
// 有符号数%d
#define SIGN 2
// 强制显示+号
#define PLUS 4
// 正数前面加空格
#define SPACE 8
// 左对齐 %-d
#define LEFT 16
// 特殊前缀 %#x
#define SPECIAL 32
// 小写字母 %x用abc %X用ABC
#define SMALL 64

#define is_digit(c) ((c) >= '0' && (c) <= '9')

// 32位像素模式1个像素占4字节 RGBA 枚举的颜色1个int是4个字节从高到低对应ARGB
#define WHITE 0x00ffffff //白
#define BLACK 0x00000000 //黑
#define RED 0x00ff0000 //红
#define ORANGE 0x00ff8000 //橙
#define YELLOW 0x00ffff00 //黄
#define GREEN 0x0000ff00 //绿
#define BLUE 0x000000ff //蓝
#define INDIGO 0x0000ffff //靛
#define PURPLE 0x008000ff //紫

// 屏幕信息
struct Position {
    // 屏幕分辨率
    int XResolution; // 横向
    int YResolution; // 纵向

    // 字符光标所在位置 是字符位置 屏幕左上角是(0,0) 横向是x 纵向是y 往右下角增长
    int XPosition; // 列
    int YPosition; // 行

    // 字符像素矩阵尺寸 几个像素
    int XCharSize; // 宽度
    int YCharSize; // 高度

    // 帧缓冲区的起始虚拟地址
    unsigned int *FB_addr;
    // 帧缓冲区容量大小 字节数 32位像素是1像素占4字节 这个值就是XResolution*YResolution*4
    unsigned long FB_length;
};

// 这里只是声明 不分配存储 多个文件都要用到这个全局变量
extern struct Position Pos;

/**
 * 通过帧缓冲区打印在屏幕上
 * @param fb 帧缓冲区的线性地址
 * @param Xsize 行分辨率
 * @param x 字符串要显示在哪儿 横向像素占位置
 * @param y 字符串要显示在哪儿 纵向像素点位置
 * @param FRcolor 字体颜色
 * @param BKcolor 字体背景色
 * @param font 要显示的字符
*/
void putchar(unsigned int *fb, int Xsize, int x, int y, unsigned int FRcolor, unsigned int BKcolor, unsigned char font);

/**
 * @param s 字符串的指针
 * @return 解析出字符串中连续的数字 被解析的数字部分丢掉
 */
int skip_atoi(const char **s);

// 做除法并回写 num/base的商被回写到num上 返回值__res是余数
// 被除数 rds:rax 128位
// 除数 rcx 64位
// 结果 商->rax 余数->rdx
#define do_div(num,base) ({ \
    int __res; \
    __asm__(".intel_syntax noprefix\n\t" \
            "div %4\n\t" \
            ".att_syntax prefix" \
            :"=a" (num),"=d" (__res) \
            :"0" (num),"1" (0),"c" (base)); \
    __res; })

/**
 * 数字转换成字符串 按照指定的进制和精度
 * @param str 放结果
 * @param num 要转换的数字
 * @param base 进制 2到36
 * @param size 宽度
 * @param precision 精度
 * @param type
 * @return
 */
static char *number(char *str, long num, int base, int size, int precision, int type);

/**
 * 处理格式化字符串可变参数的参数列表 把格式化字符串替换成实际的字符串
 * @param buf 处理完的格式化字符串 处理结果
 * @param fmt 格式化字符串
 * @param args 参数变量 用来替换格式化修饰符的
 * @return buf字符串长度是多少 不包含结束符\0在内的长度
 */
int vsprintf(char *buf, const char *fmt, va_list args);

/**
 * 打印字符串
 * @param FRcolor 前景色
 * @param BKcolor BKcolor 背景色
 * @param fmt 格式化字符串
 * @return 字符串长度
 */
int color_printk(unsigned int FRcolor, unsigned int BKcolor, const char *fmt, ...);
