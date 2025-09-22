.PHONY: all run clean

# 工具链变量
CC := gcc
LD := ld
NASM := nasm
AS = as

all: build-floppy
# 制作启动盘
build-floppy: dist/floppy.img

# boot程序
build/boot/floppy/boot/boot.bin: src/boot/floppy/boot/boot.asm
	mkdir -p $(dir $@)
	$(NASM) -f bin -I src/boot -o $@ $<
# loader程序
loader_asm_src_files := $(shell find src/boot/floppy/loader -name *.asm)
loader_asm_obj_files := $(patsubst src/boot/floppy/loader/%.asm, build/boot/floppy/loader/%.o, $(loader_asm_src_files))
build/boot/floppy/loader/%.bin: src/boot/floppy/loader/%.asm
	mkdir -p $(dir $@)
	$(NASM) -f bin -I src/boot -o $@ $<

# kernel程序
# 汇编代码
kernel_asm_src_files := $(shell find src/kernel -name *.S)
kernel_asm_obj_files := $(patsubst src/kernel/%.S, build/kernel/%.o, $(kernel_asm_src_files))
build/kernel/%.s: src/kernel/%.S
	mkdir -p $(dir $@)
	$(CC) -E $< > $@
build/kernel/%.o: build/kernel/%.s
	mkdir -p $(dir $@)
	$(AS) --64 -o $@ $<
# c代码
kernel_c_src_files := $(shell find src/kernel -name *.c)
kernel_c_obj_files := $(patsubst src/kernel/%.c, build/kernel/%.o, $(kernel_c_src_files))
# -fno-builtin 禁用内建函数 避免编译器优化成库函数调用
# -ffreestanding 告诉编译器我们在写OS 不要假设有标准库
# -fno-stack-protector 禁用栈保护 避免 __stack_chk_fail
build/kernel/%.o: src/kernel/%.c
	mkdir -p $(dir $@)
	$(CC) -mcmodel=large -m64 \
		-fno-builtin \
		-ffreestanding \
		-fno-stack-protector \
		-I src/kernel -c -o $@ $^
# 链接
build/kernel/kernel.elf: $(kernel_asm_obj_files) $(kernel_c_obj_files)
	$(LD) -b elf64-x86-64 -T targets/kernel.lds -o $@ $^
# 提取二进制 剔除多余段信息 只保留程序段数据text data bss
build/kernel/%.bin: build/kernel/%.elf
	objcopy -I elf64-x86-64 -S -R ".eh_frame" -R ".comment" -O binary $< $@

dist/floppy.img: build/boot/floppy/boot/boot.bin build/boot/floppy/loader/loader.bin build/kernel/kernel.bin
	rm -rf dist
	mkdir dist
	# 1.44MB空镜像
	dd if=/dev/zero of=$@ bs=512 count=2880
	# 0#扇区
	dd if=build/boot/floppy/boot/boot.bin of=$@ conv=notrunc bs=512 count=1
	# 烧录loader程序和kernel程序到软盘
	# 用来挂载的空目录
	mkdir -p dist/mnt
	# 指定待挂载目录media 磁盘文件类型 负责把文件描述成磁盘分区
	mount $@ dist/mnt/ -t vfat -o loop
	rm -rf dist/mnt/*
	cp build/boot/floppy/loader/loader.bin dist/mnt/
	cp build/kernel/kernel.bin dist/mnt
	# 强制同步
	sync
	umount dist/mnt
	rmdir dist/mnt

run-qume: dist/floppy.img
	qemu-system-x86_64 -fda $^ -boot a
run-bochs: dist/floppy.img bochsrc
	bochs -f bochsrc -q
run: run-bochs

clean:
	rm -rf build dist