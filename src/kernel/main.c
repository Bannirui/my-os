// 内核的主程序 进行各个系统模块的初始化 完成后创建出系统的第一个进程init进程 然后将控制权给init进程
void Start_Kernel(void)
{
    int *addr = (int *)0xffff800000a00000;
    int i;
    for(i = 0 ;i<1440*20;i++)
    {
        *((char *)addr+0)=(char)0x00;
        *((char *)addr+1)=(char)0x00;
        *((char *)addr+2)=(char)0xff;
        *((char *)addr+3)=(char)0x00;
        addr +=1;
    }
    for(i = 0 ;i<1440*20;i++)
    {
        *((char *)addr+0)=(char)0x00;
        *((char *)addr+1)=(char)0xff;
        *((char *)addr+2)=(char)0x00;
        *((char *)addr+3)=(char)0x00;
        addr +=1;
    }

    while(1);
}