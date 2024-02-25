#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

int main(int argc, char* argv[])
{
    int fd, fd_kernel;
    int c;
    char buf[512];

    fd_kernel = open("kernel.bin", O_WRONLY | O_CREAT, 0664);

    // 拷贝boot16
    fd = open("boot16.bin", O_RDONLY);
    while(1)
    {
        c = read(fd, buf, 512);
        if(c>0)
        {
            write(fd_kernel, buf, c);
        }
        else
        {
            break;
        }
    }
    close(fd);

    // 拷贝boot32
    // boot32内核的保护模式部分程序将被加载到内存0x20000处
    // 而kvmtool会将内核映像kernel.bin加载到内存偏移0x10000处
    // 因此boot32.bin在kernel.bin的偏移就是0x20000-0x10000=0x10000
    // 重置读写位置
    lseek(fd_kernel, 0x20000-0x10000, SEEK_SET);
    fd = open("boot32.bin", O_RDONLY);
    while(1)
    {
        c = read(fd, buf, 512);
        if(c>0)
        {
            write(fd_kernel, buf, c);
        }
        else
        {
            break;
        }
    }
    close(fd);
    
    close(fd_kernel);

    return 0;
}
