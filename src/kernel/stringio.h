// 实现C库字符串的子集功能
#include <stdint.h>

extern void putChar(char c);

// 字符串长度
uint16_t strlen(char* str) {
	int count=0;
	while(str[count++]!='\0');
	return count-1;
}

void print(char* str){
	while (*str) {
		putChar(*str);
		str++;
	}
}