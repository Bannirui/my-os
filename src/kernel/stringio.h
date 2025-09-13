/// 实现C库字符串的子集功能
# include <stdint.h>

extern void printInPos(char* msg, uint16_t len, uint8_t row, uint8_t col);
extern void putchar(char c);
extern char getch();

// 字符串长度
uint16_t strlen(char* str) {
    int count=0;
    while(str[count++]!='\0');
    return count-1;
}

// 比较字符串
uint8_t strcmp(char* str1, char* str2) {
    int i=0;
    while(1) {
        if(str1[i]=='\0' || str2[i]=='\0') { break; }
        if(str1[i] != str2[i]) { break; }
        i++;
    }
    return str1[i]-str2[i];
}

// 在光标处显示字符串
void print(char* str) {
    for(int i=0,len=strlen(str);i<len;i++) {
        putchar(str[i]);
    }
}

// 取得字符串中的第一个单词
void getFirstWord(char* str, char* buf) {
    int i=0;
    while(str[i] && str[i]!=' ') {
        buf[i]=str[i];
        i++;
    }
    buf[i]='\0';
}

// 读取字符串到缓冲区
void readToBuf(char* buffer, uint16_t maxlen) {
    int i=0;
    while(1) {
        char tmp=getch();
        // 非法字符
        if(!(tmp==0xd || tmp=='\b'|| tmp>=32 && tmp<=127)) { continue; }
        if(i>0 && i<maxlen-1) {
            // 按下回车键 停止读取
            if(tmp==0x0d) { break; }
            else if(tmp=='\b') { // 按下退格删除
                putchar('\b');
                putchar(' ');
                putchar('\b');
                i--;
            } else {
                putchar(tmp); 
                buffer[i]=tmp;
                i++;
            }
        } else if(i>=maxlen-1) {
            if(tmp=='\b') { // 按下退格删除
                putchar('\b');
                putchar(' ');
                putchar('\b');
                i--;
            } else if(tmp==0x0d) {
                break;
            }
        } else if(i<=0) {
            if(tmp==0x0d) { break; }
            else if(tmp!='\b') {
                putchar(tmp);
                buffer[i]=tmp;
                i++;
            }
        }
    }
    putchar('\r');
    putchar('\n');
    buffer[i]='\0';
}