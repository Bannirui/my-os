// 用C语言扩展内核
#include "stringio.h"

#define BUFLEN 16

// 系统启动界面
void startUp() {
    char* title="MY-OS";
    char* hint="System is running, press ENTER to startup shell.";
    // 调用liba的函数
    printInPos(title,strlen(title),2,10);
    printInPos(hint,strlen(hint),5,10);
}

// 打印shell提示符
void promptString() {
    char* pmt_str="MY-OS #";
    // 调用stringio的函数
    print(pmt_str);
}

void showHelp() {
    char* help_str=
    "Shell for MY-OS\r\n"
    "\r\n"
    " clear    - clear the terminal \r\n"
    " time     - get the current time \r\n"
    " poweroff - force shutdown the pc \r\n";
    // 调用stringio的函数
    print(help_str);
}

void shell() {
    showHelp();
}