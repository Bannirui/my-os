# project
SRC_DIR = $(shell pwd)
BOCHS_CFG = $(SRC_DIR)/bochs/boshsrc-archlinux
BOOT_FILE = $(SRC_DIR)/bootloader/boot.bin
LOADER_FILE = $(SRC_DIR)/bootloader/loader.bin
KERNEL_FILE = $(SRC_DIR)/kernel/kernel.bin

# os or env
AS = nasm
BOCHS_DIR = /home/dingrui/Documents/software/bochs
BOCHS_FILE = /usr/bin/bochs
BXIMAGE = /usr/bin/bximage
FLOPPY_MOUNT_POINT = $(SRC_DIR)/tmp/mount_point
FLOPPY_DIR = $(SRC_DIR)/tmp
FLOPPY_IMG = $(FLOPPY_DIR)/my_os_floppy.img

default: kernel

boot: clean compile_boot
	@echo "check..."
	if [ ! -e ${BOCHS_CFG} ]; then echo "boshsrc not found" && exit 1;fi
	rm -rf $(FLOPPY_IMG)
	@echo "floppy..."
	if [ ! -e ${FLOPPY_DIR} ]; then mkdir -p ${FLOPPY_DIR};fi
	$(BXIMAGE) -func=create -fd=1.44M $(FLOPPY_IMG)
	@echo "boot..."
	if [ ! -e ${BOOT_FILE} ]; then echo "boot.bin not found" && exit 1;fi
	dd if=$(BOOT_FILE) of=$(FLOPPY_IMG) bs=512 count=1 conv=notrunc
	@echo "starting..."
	$(BOCHS_FILE) -f $(BOCHS_CFG)

bootloader: clean compile_bootloader
	@echo "check..."
	if [ ! -e ${BOCHS_CFG} ]; then echo "boshsrc not found" && exit 1;fi
	rm -rf $(FLOPPY_IMG)
	@echo "floppy..."
	if [ ! -e ${FLOPPY_DIR} ]; then mkdir -p ${FLOPPY_DIR};fi
	$(BXIMAGE) -func=create -fd=1.44M $(FLOPPY_IMG)
	@echo "boot..."
	if [ ! -e ${BOOT_FILE} ]; then echo "boot.bin not found" && exit 1;fi
	dd if=$(BOOT_FILE) of=$(FLOPPY_IMG) bs=512 count=1 conv=notrunc
	@echo "mount..."
	if [ ! -d ${FLOPPY_MOUNT_POINT} ]; then mkdir -p ${FLOPPY_MOUNT_POINT};fi
	sudo mount -t vfat -o loop --source $(FLOPPY_IMG) --target $(FLOPPY_MOUNT_POINT)
	@echo "loader..."
	if [ ! -e ${LOADER_FILE} ]; then echo "loader.bin not found" && exit 1;fi
	sudo cp $(LOADER_FILE) $(FLOPPY_MOUNT_POINT)/
	sync
	sudo umount $(FLOPPY_MOUNT_POINT)
	@echo "starting..."
	$(BOCHS_FILE) -f $(BOCHS_CFG)

kernel: clean compile_bootloader compile_kernel
	@echo "check..."
	if [ ! -e ${BOCHS_CFG} ]; then echo "boshsrc not found" && exit 1;fi
	rm -rf $(FLOPPY_IMG)
	@echo "floppy..."
	if [ ! -e ${FLOPPY_DIR} ]; then mkdir -p ${FLOPPY_DIR};fi
	$(BXIMAGE) -func=create -fd=1.44M $(FLOPPY_IMG)
	@echo "boot..."
	if [ ! -e ${BOOT_FILE} ]; then echo "boot.bin not found" && exit 1;fi
	dd if=$(BOOT_FILE) of=$(FLOPPY_IMG) bs=512 count=1 conv=notrunc
	@echo "mount..."
	if [ ! -d ${FLOPPY_MOUNT_POINT} ]; then sudo mkdir -p ${FLOPPY_MOUNT_POINT};fi
	sudo mount -t vfat -o loop --source $(FLOPPY_IMG) --target $(FLOPPY_MOUNT_POINT)
	@echo "loader..."
	if [ ! -e ${LOADER_FILE} ]; then echo "loader.bin not found" && exit 1;fi
	sudo cp $(LOADER_FILE) $(FLOPPY_MOUNT_POINT)/
	@echo "kernel..."
	if [ ! -e ${KERNEL_FILE} ]; then echo "kernel.bin not found" && exit 1;fi
	sudo cp $(KERNEL_FILE) $(FLOPPY_MOUNT_POINT)/
	sync
	sudo umount $(FLOPPY_MOUNT_POINT)
	@echo "starting..."
	$(BOCHS_FILE) -f $(BOCHS_CFG)

compile_boot:
	$(AS) $(SRC_DIR)/bootloader/boot.asm -I$(SRC_DIR)/bootloader -o $(BOOT_FILE)

compile_bootloader:
	$(AS) $(SRC_DIR)/bootloader/boot.asm -I$(SRC_DIR)/bootloader -o $(BOOT_FILE)
	$(AS) $(SRC_DIR)/bootloader/loader.asm -I$(SRC_DIR)/bootloader -o $(LOADER_FILE)

compile_kernel: system
	# 剔除system程序里面多余的段信息 提取出二进制程序段数据 包括text段\data段\bss段
	objcopy -I elf64-x86-64 -S -R ".eh_frame" -R ".comment" -O binary kernel/system kernel/kernel.bin

system: head.o main.o
	# .o链接成可执行程序取名为system 链接过程中使用lds文件
	ld -b elf64-x86-64 -o kernel/system kernel/head.o kernel/main.o -T kernel/Kernel.lds

head.o: kernel/head.S
	gcc -E kernel/head.S > kernel/head.s
	as --64 -o kernel/head.o kernel/head.s

main.o: kernel/main.c
	gcc -std=c99 -mcmodel=large -fno-builtin -m64 -c kernel/main.c -o kernel/main.o

.PHONY: clean
clean:
	-rm -f $(BOOT_FILE)
	-rm -f $(LOADER_FILE)
	-sudo umount $(FLOPPY_MOUNT_POINT)
	rm -rf $(FLOPPY_MOUNT_POINT)/*
	-rm -rf $(FLOPPY_IMG)
	-rm -rf $(SRC_DIR)/kernel/*.s
	-rm -rf $(SRC_DIR)/kernel/*.o
	-rm -rf $(SRC_DIR)/kernel/*.bin
	-rm -rf $(SRC_DIR)/kernel/system
