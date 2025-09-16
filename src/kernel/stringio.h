// 实现C库字符串的子集功能
#include <stdint.h>

extern void putChar(char c);

// 字符串长度
uint16_t strlen(const char* str) {
    int count=0;
    while(str[count++]!='\0');
    return count-1;
}

void print(char*str){
	uint16_t len = strlen(str);
	for(int i = 0; i < len; i++) {
		putChar(str[i]);
	}
}