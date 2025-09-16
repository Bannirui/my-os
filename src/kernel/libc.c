// 用C语言扩展内核
#include "stringio.h"

// 声明near call 在asm中也要一致 防止程序跑飞
extern void printPos(char* msg, uint16_t len, uint8_t row, uint8_t col);
extern void clearScreen();


// 系统启动界面
// cdecl约定调用函数是near call压栈压IP 2字节
void __attribute__((cdecl)) startUp(void) {
    // 调用liba的函数
    clearScreen();
    char* title = "WELCOME TO MY-OS \r\n";
    printPos(title, strlen(title), 8, 30);
    for(;;);
}