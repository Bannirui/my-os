// 用C语言扩展内核
#include "stringio.h"

extern void printPos(char*msg,uint16_t len,uint8_t row,uint8_t col);

// 系统启动界面
// cdecl约定调用函数是near call压栈只压IP 2字节
void __attribute__((cdecl)) startUp(void) {
    // 调用liba的函数
    // clearScreen();
    char* title = "WELCOME TO MY-OS\r\n";
    printPos(title, strlen(title), 5, 10);
}