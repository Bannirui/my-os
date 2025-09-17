// 用C语言扩展内核
#include <stdint.h>
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
}

void __attribute__((cdecl)) promptString(void) {
	char* p_string = "MY-OS SHELL#>";
	print(p_string);
}

void __attribute__((cdecl)) showHelp(void) {
	char* help =
        "MY-OS x86 PC\r\n"
        "\r\n"
        "SHELL COMMAND\r\n"
        "\r\n"
        "help\r\n"
        "clear\r\n"
        "time\r\n"
        "protectMode\r\n"
        "powerOff\r\n"
        "date\r\n";
    print(help);
}

void __attribute__((cdecl)) shell(void) {
	clearScreen();
	showHelp();
}