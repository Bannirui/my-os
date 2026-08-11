#include "printk.h"

#include "lib.h"
#include "font.h"
#include "linkage.h"

// 用来收vsprintf解析出来的格式化字符串结果
char buf[4096] = {0};

// 在这里真正定义Pos
struct Position Pos;

void putchar(unsigned int *fb, int Xsize, int x, int y, unsigned int FRcolor, unsigned int BKcolor,
             unsigned char font) {
    /**
     * 8*16的点阵字体位图
     * 按照索引找到每个ASCII字符
     * 每个字符
     *   - 16行 高度16像素
     *   - 每行1个字节 宽度8像素
     * 每个bit对应一个像素
     *   - 1 亮 前景
     *   - 0 暗 背景
     * 在字符显示过程中 只要把位图中为1的位写入字体颜色值 0的位写入字体背景颜色值 就可以将字符显示在屏幕上
     */
    unsigned char *fontp = font_ascii[font]; // 找到字符对应的字模 16个字节
    for (int i = 0; i < 16; i++) {
        // 每个字符高16像素
        // 字符左上角第一个像素点的偏移 得到待显示字符矩阵的起始线性地址
        unsigned int *addr = fb + Xsize * (y + i) + x;
        int testval = 0x100;
        // 然后从字符首像素地址开始 逐个把字体颜色和背景色的数值填充到线性地址空间
        for (int j = 0; j < 8; j++) {
            // 每个字符宽8像素
            testval = testval >> 1;
            if (*fontp & testval) {
                // 点亮前景色
                *addr = FRcolor;
            } else {
                // 点亮背景色
                *addr = BKcolor;
            }
            addr++;
        }
        // 处理字模的下一行
        fontp++;
    }
}

int skip_atoi(const char **s) {
    int i = 0;
    while (is_digit(**s)) {
        i = i * 10 + *((*s)++) - '0';
    }
    return i;
}

static char *number(char *str, long num, int base, int size, int precision, int type) {
    char c, sign, tmp[50];
    const char *digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    int i;
    if (type & SMALL) digits = "0123456789abcdefghijklmnopqrstuvwxyz";
    if (type & LEFT) type &= ~ZEROPAD;
    if (base < 2 || base > 36) {
        return 0;
    }
    c = (type & ZEROPAD) ? '0' : ' ';
    sign = 0;
    if (type & SIGN && num < 0) {
        sign = '-';
        num = -num;
    } else {
        sign = (type & PLUS) ? '+' : ((type & SPACE) ? ' ' : 0);
    }
    if (sign) { size--; }
    if (type & SPECIAL) {
        if (base == 16) { size -= 2; } else if (base == 8) { size--; }
    }
    i = 0;
    if (num == 0) {
        tmp[i++] = '0';
    } else {
        while (num != 0) {
            tmp[i++] = digits[do_div(num, base)];
        }
    }
    if (i > precision) { precision = i; }
    size -= precision;
    if (!(type & (ZEROPAD + LEFT))) {
        while (size-- > 0) {
            *str++ = ' ';
        }
    }
    if (sign) { *str++ = sign; }
    if (type & SPECIAL) {
        if (base == 8) {
            *str++ = '0';
        } else if (base == 16) {
            *str++ = '0';
            *str++ = digits[33];
        }
    }
    if (!(type & LEFT)) {
        while (size-- > 0) { *str++ = c; }
    }
    while (i < precision--) { *str++ = '0'; }
    while (i-- > 0) { *str++ = tmp[i]; }
    while (size-- > 0) { *str++ = ' '; }
    return str;
}

int vsprintf(char *buf, const char *fmt, va_list args) {
    char *str, *s;
    int flags;
    int field_width;
    int precision;
    int len, i;
    int qualifier;
    // 找格式化字符串中要替换的占位 用实际参数替换 最终buf中就是处理后的字符串
    for (str = buf; *fmt; fmt++) {
        if (*fmt != '%') {
            *str++ = *fmt;
            continue;
        }
        flags = 0;
    repeat:
        // fmt指向了%符号 开始解析后面的格式化内容
        fmt++;
        switch (*fmt) {
            case '-': flags |= LEFT;
                goto repeat;
            case '+': flags |= PLUS;
                goto repeat;
            case ' ': flags |= SPACE;
                goto repeat;
            case '#': flags |= SPECIAL;
                goto repeat;
            case '0': flags |= ZEROPAD;
                goto repeat;
        }
        field_width = -1;
        if (is_digit(*fmt)) {
            field_width = skip_atoi(&fmt);
        } else if (*fmt == '*') {
            fmt++;
            field_width = va_arg(args, int);
            if (field_width < 0) {
                field_width = -field_width;
                flags |= LEFT;
            }
        }
        precision = -1;
        if (*fmt == '.') {
            fmt++;
            if (is_digit(*fmt)) {
                precision = skip_atoi(&fmt);
            } else if (*fmt == '*') {
                fmt++;
                precision = va_arg(args, int);
            }
            if (precision < 0) {
                precision = 0;
            }
        }
        qualifier = -1;
        if (*fmt == 'h' || *fmt == 'l' || *fmt == 'L' || *fmt == 'Z') {
            qualifier = *fmt;
            fmt++;
        }
        switch (*fmt) {
            case 'c': {
                if (!(flags & LEFT)) {
                    while (--field_width > 0) {
                        *str++ = ' ';
                    }
                }
                *str++ = (unsigned char) va_arg(args, int);
                while (--field_width > 0) {
                    *str++ = ' ';
                }
                break;
            }
            case 's': {
                s = va_arg(args, char *);
                if (!s) { s = '\0'; }
                len = strlen(s);
                if (precision < 0) { precision = len; } else if (len > precision) { len = precision; }
                if (!(flags & LEFT)) {
                    while (len < field_width--) { *str++ = ' '; }
                }
                for (i = 0; i < len; i++) { *str++ = *s++; }
                while (len < field_width--) { *str++ = ' '; }
                break;
            }
            case 'o': {
                if (qualifier == 'l') {
                    str = number(str,va_arg(args, unsigned long), 8, field_width, precision, flags);
                } else { str = number(str,va_arg(args, unsigned int), 8, field_width, precision, flags); }
                break;
            }
            case 'p': {
                if (field_width == -1) {
                    field_width = 2 * sizeof(void *);
                    flags |= ZEROPAD;
                }
                str = number(str, (unsigned long) va_arg(args, void *), 16, field_width, precision, flags);
                break;
            }
            case 'x': {
                flags |= SMALL;
            }
            case 'X': {
                if (qualifier == 'l') {
                    str = number(str,va_arg(args, unsigned long), 16, field_width, precision, flags);
                } else { str = number(str,va_arg(args, unsigned int), 16, field_width, precision, flags); }
                break;
            }
            case 'd':
            case 'i': {
                flags |= SIGN;
            }
            case 'u': {
                if (qualifier == 'l') {
                    str = number(str,va_arg(args, unsigned long), 10, field_width, precision, flags);
                } else { str = number(str,va_arg(args, unsigned int), 10, field_width, precision, flags); }
                break;
            }
            case 'n': {
                if (qualifier == 'l') {
                    long *ip = va_arg(args, long*);
                    *ip = (str - buf);
                } else {
                    int *ip = va_arg(args, int*);
                    *ip = (str - buf);
                }
                break;
            }
            case '%': {
                *str++ = '%';
                break;
            }
            default: {
                *str++ = '%';
                if (*fmt) { *str++ = *fmt; } else { fmt--; }
                break;
            }
        }
    }
    *str = '\0';
    return str - buf;
}

int color_printk(unsigned int FRcolor, unsigned int BKcolor, const char *fmt, ...) {
    // 变长参数初始化
    va_list args; // 用来保存可变参数指针
    va_start(args, fmt); // 让args指向fmt后面的参数列表第1个参数
    // 格式化后的字符串结果保存到一个4096B的缓冲区buf 返回字符串长度
    int len = vsprintf(buf, fmt, args);
    va_end(args);
    for (int i = 0; i < len; i++) {
        char curCh = buf[i];
        if (curCh == '\n') {
            // 换行 到下一行行首
            Pos.YPosition++;
            Pos.XPosition = 0;
        } else if (curCh == '\b') {
            // 退格 就是删除前一个字符
            Pos.XPosition--;
            if (Pos.XPosition < 0) {
                // 光标已经移动到行首了 就要到上一行去 跳到上一行最后位置
                Pos.XPosition = (Pos.XResolution / Pos.XCharSize - 1) * Pos.XCharSize;
                Pos.YPosition--;
                if (Pos.YPosition < 0) {
                    // 光标已经到第1行了 就要跳到最后一行
                    Pos.YPosition = (Pos.YResolution / Pos.YCharSize - 1) * Pos.YCharSize;
                }
                // 比如当前光标在(0,0) 是屏幕左上角 退格一下 到屏幕右下角
            }
            // 在光标位置上打印空格盖掉之前的字符内容达到删除的效果
            putchar(Pos.FB_addr, Pos.XResolution,
                    Pos.XPosition * Pos.XCharSize, Pos.YPosition * Pos.YCharSize,
                    FRcolor, BKcolor, ' ');
        } else if (curCh == '\t') {
            // 制表符
            // 制表符是8个字符 所以多个制表符一定是8的倍数 怎么求8的倍数 就是抹掉低3位 就是求与
            // x+8先给一个制表符宽度 然后抹掉低3位 就是>=x的最小的8的倍数
            // 得到的结果就是当前光标到下一个制表符位置需要填多少个空格
            int spaces = ((Pos.XPosition + 8) & 0xfff8) - Pos.XPosition;
            while (spaces--) {
                putchar(Pos.FB_addr, Pos.XResolution,
                        Pos.XPosition * Pos.XCharSize, Pos.YPosition * Pos.YCharSize,
                        FRcolor, BKcolor, ' ');
                Pos.XPosition++;
            }
        } else {
            // 遇到的是正常要显示的字符
            putchar(Pos.FB_addr, Pos.XResolution,
                    Pos.XPosition * Pos.XCharSize, Pos.YPosition * Pos.YCharSize,
                    FRcolor, BKcolor, curCh);
            Pos.XPosition++;
        }
        // 看看现在字符显示位置是不是已经到了屏幕边界
        if (Pos.XPosition >= (Pos.XResolution / Pos.XCharSize)) {
            // 已经到行末了 跳到下一行首
            Pos.YPosition++;
            Pos.XPosition = 0;
        }
        if (Pos.YPosition >= (Pos.YResolution / Pos.YCharSize)) {
            // 到了整个屏幕最后一行了 再跳回行第1行
            Pos.YPosition = 0;
        }
    }
    return len;
}
