// 用C语言扩展内核
#include "stringio.h"

#define BUFLEN 16

// 系统启动界面
void startUp() {
	char* title = "TinyOS Oerating System version 1.0";
	char* subTitle = "Designed by DJH-sudo";
	char* copyRight = "Coypleft by GNU";
	char* hint = "System is ready.Press ENTER\r\n";
    // 调用liba的函数
	printInPos(title,strlen(title),5,23);
	printInPos(subTitle,strlen(subTitle),6,23);
	printInPos(copyRight,strlen(copyRight),8,23);
	printInPos(hint,strlen(hint),15,23);
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