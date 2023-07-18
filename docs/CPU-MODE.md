## CPU-MODE

通过Bochs的调试模式查看各个阶段CPU处理器的运行模式

### 1 执行bootsect程序

CPU跑在16位实模式下

![](image/image-20230718194337944.png)

### 2 执行loader程序

#### 2.1 切换模式前

![](image/image-20230718194201862.png)

#### 2.2 切换模式后

CPU跑在IA-32e模式下

![](image/image-20230718194546425.png)