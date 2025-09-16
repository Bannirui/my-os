// 用C语言扩展内核

extern void clearScreen();

// 系统启动界面
void __attribute__((cdecl)) startUp(void) {
    // 调用liba的函数
    clearScreen();
}