## Linux平台

### 1 Centos安装

| Name              | Version | Link                                            |
| ----------------- | ------- | ----------------------------------------------- |
| vmware fusion pro | 13      |                                                 |
| Centos iso        | 7       | http://mirrors.aliyun.com/centos/7/isos/x86_64/ |

### 2 工具链

| Name  | Version | Link                                                |
| ----- | ------- | --------------------------------------------------- |
| Bochs | 2.6.8   | https://sourceforge.net/projects/bochs/files/bochs/ |

#### 2.1 依赖库

```shell
yum install -y gcc gcc-c++ make SDL-devel wxGTK-devel libX11-devel gtk2-devel
```

#### 2.2 Bochs安装

##### 2.2.1 下载

```shell
wget https://sourceforge.net/projects/bochs/files/bochs/2.6.8/bochs-2.6.8.tar.gz --no-check-certificate
```

##### 2.2.2 解压

```shell
cd /home/dingrui/Apps

tar zxvf bochs-2.6.8.tar.gz 
```

##### 2.2.3 config

```shell
./configure
```

##### 2.2.4 compile

```shell
make && make install
```

##### 2.2.5 配置

```shell
vim boshsrc
```



```shell
boot: floppy
floppya: 1_44="boot.img", status=inserted
floppy_bootsig_check: disabled=0

ata0: enabled=1, ioaddr1=0x1f0, ioaddr2=0x3f0, irq=14
ata0-master: type=none
ata0-slave: type=none
ata1: enabled=1, ioaddr1=0x170, ioaddr2=0x370, irq=15
ata1-master: type=none
ata1-slave: type=none
ata2: enabled=0
ata3: enabled=0


log: bochsout.txt

panic: action=ask
error: action=report
info: action=report
debug: action=ignore, pci=report # report BX_DEBUG from module 'pci'

debugger_log: -

parport1: enabled=1, file="parport.out"

speaker: enabled=1, mode=sound, volume=15
```

##### 2.2.6 启动

```shell
bochs -f boshsrc
```

![Snipaste_2023-07-05_23-19-38](image/Snipaste_2023-07-05_23-19-38.png)

### 2 虚拟软盘

#### 2.1 创建

![Snipaste_2023-07-05_23-22-59](image/Snipaste_2023-07-05_23-22-59.png)

#### 2.2 验证

![Snipaste_2023-07-05_23-23-56](image/Snipaste_2023-07-05_23-23-56.png)

### 3 复制boot程序文件

### 4 boot程序执行

### 4 挂载目录

### 5 复制loader程序文件

### 6 loader程序执行