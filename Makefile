AS = nasm

SRC_DIR = $(shell pwd)
BOCHS_CFG = $(SRC_DIR)/cfg/boshsrc
BOOT_FILE = $(SRC_DIR)/bootloader/boot.bin
LOADER_FILE = $(SRC_DIR)/bootloader/loader.bin
KERNEL_FILE = $(SRC_DIR)/kernel/kernel.bin

BOCHS_DIR = /home/dingrui/Apps/bochs-2.6.8
BOCHS_FILE = $(BOCHS_DIR)/bochs

FLOPPY_MOUNT_POINT = $(BOCHS_DIR)/tmp
FLOPPY_IMG = $(SRC_DIR)/a.img

default: kernel

boot: clean cb
	@echo "check..."
	@if [ ! -e ${BOCHS_FILE} ]; then echo "bochs not found" && exit 1;fi
	@if [ ! -e ${BOCHS_CFG} ]; then echo "boshsrc not found" && exit 1;fi
	@if [ ! -e ${BOCHS_DIR}/bximage ]; then echo "bximage not found" && exit 1;fi
	@rm -rf $(FLOPPY_IMG)
	@echo "floppy..."
	$(BOCHS_DIR)/bximage
	@echo "boot..."
	@if [ ! -e ${BOOT_FILE} ]; then echo "boot.bin not found" && exit 1;fi
	dd if=$(BOOT_FILE) of=$(FLOPPY_IMG) bs=512 count=1 conv=notrunc
	@echo "starting..."
	$(BOCHS_FILE) -f $(BOCHS_CFG)

loader: clean cb
	@echo "check..."
	@if [ ! -e ${BOCHS_FILE} ]; then echo "bochs not found" && exit 1;fi
	@if [ ! -e ${BOCHS_CFG} ]; then echo "boshsrc not found" && exit 1;fi
	@if [ ! -e ${BOCHS_DIR}/bximage ]; then echo "bximage not found" && exit 1;fi
	@rm -rf $(FLOPPY_IMG)
	@echo "floppy..."
	$(BOCHS_DIR)/bximage
	@echo "boot..."
	@if [ ! -e ${BOOT_FILE} ]; then echo "boot.bin not found" && exit 1;fi
	dd if=$(BOOT_FILE) of=$(FLOPPY_IMG) bs=512 count=1 conv=notrunc
	@echo "mount..."
	if [ ! -d ${FLOPPY_MOUNT_POINT} ]; then mkdir -p ${FLOPPY_MOUNT_POINT};fi
	mount $(FLOPPY_IMG) $(FLOPPY_MOUNT_POINT)/ -t vfat -o loop
	@echo "loader..."
	@if [ ! -e ${LOADER_FILE} ]; then echo "loader.bin not found" && exit 1;fi
	cp $(LOADER_FILE) $(FLOPPY_MOUNT_POINT)/
	sync
	umount $(FLOPPY_MOUNT_POINT)
	@echo "starting..."
	$(BOCHS_FILE) -f $(BOCHS_CFG)

kernel: clean cb ck
	@echo "check..."
	@if [ ! -e ${BOCHS_FILE} ]; then echo "bochs not found" && exit 1;fi
	@if [ ! -e ${BOCHS_CFG} ]; then echo "boshsrc not found" && exit 1;fi
	@if [ ! -e ${BOCHS_DIR}/bximage ]; then echo "bximage not found" && exit 1;fi
	@rm -rf $(FLOPPY_IMG)
	@echo "floppy..."
	$(BOCHS_DIR)/bximage
	@echo "boot..."
	@if [ ! -e ${BOOT_FILE} ]; then echo "boot.bin not found" && exit 1;fi
	dd if=$(BOOT_FILE) of=$(FLOPPY_IMG) bs=512 count=1 conv=notrunc
	@echo "mount..."
	if [ ! -d ${FLOPPY_MOUNT_POINT} ]; then mkdir -p ${FLOPPY_MOUNT_POINT};fi
	mount $(FLOPPY_IMG) $(FLOPPY_MOUNT_POINT)/ -t vfat -o loop
	@echo "loader..."
	@if [ ! -e ${LOADER_FILE} ]; then echo "loader.bin not found" && exit 1;fi
	cp $(LOADER_FILE) $(FLOPPY_MOUNT_POINT)/
	@echo "kernel..."
	@if [ ! -e ${KERNEL_FILE} ]; then echo "kernel.bin not found" && exit 1;fi
	cp $(KERNEL_FILE) $(FLOPPY_MOUNT_POINT)/
	sync
	umount $(FLOPPY_MOUNT_POINT)
	@echo "starting..."
	$(BOCHS_FILE) -f $(BOCHS_CFG)

cb:
	$(AS) $(SRC_DIR)/bootloader/boot.asm -I$(SRC_DIR)/bootloader -o $(BOOT_FILE)
	$(AS) $(SRC_DIR)/bootloader/loader.asm -I$(SRC_DIR)/bootloader -o $(LOADER_FILE)

ck: system
	objcopy -I elf64-x86-64 -S -R ".eh_frame" -R ".comment" -O binary kernel/system kernel/kernel.bin

system: head.o main.o
	ld -b elf64-x86-64 -o kernel/system kernel/head.o kernel/main.o -T kernel/Kernel.lds

main.o: kernel/main.c
	gcc -mcmodel=large -fno-builtin -m64 -c kernel/main.c -o kernel/main.o

head.o: kernel/head.s
	gcc -E kernel/head.s > kernel/head.txt
	as --64 -o kernel/head.o kernel/head.txt

.PHONY: clean
clean:
	-rm -f $(BOOT_FILE)
	-rm -f $(LOADER_FILE)
	-umount $(FLOPPY_MOUNT_POINT)
	-rm -rf $(FLOPPY_IMG)
	-rm -rf $(SRC_DIR)/kernel/*.txt
	-rm -rf $(SRC_DIR)/kernel/*.o
	-rm -rf $(SRC_DIR)/kernel/*.bin
	-rm -rf $(SRC_DIR)/kernel/system
