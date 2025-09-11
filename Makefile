.PHONY: all run clean

all: build-disk

# 第一阶段 BootLoader只能汇编成bin 
# 硬盘
build/boot/disk/mbr.bin: src/boot/disk/mbr.asm
	mkdir -p $(dir $@)
	nasm -f bin -o $@ $<
build/boot/disk/loader.bin: src/boot/disk/loader.asm
	mkdir -p $(dir $@)
	nasm -f bin $< -o $@
# 软盘
build/boot/floppy/mbr.bin: src/boot/floppy/mbr.asm
	mkdir -p $(dir $@)
	nasm -f bin -o $@ $<
build/boot/floppy/loader.bin: src/boot/floppy/loader.asm
	mkdir -p $(dir $@)
	nasm -f bin $< -o $@

build/kernel/kernel.bin: src/kernel/kernel.asm
	mkdir -p $(dir $@)
	nasm -f bin $< -o $@

# 第二阶段 内核
# find递归找所有asm源文件
# asm_source_files := $(shell find src/kernel -name *.asm)
# 源码文件对应o文件路径
# asm_object_files := $(patsubst src/kernel/%.asm, build/kernel/%.o, $(asm_source_files))
# 汇编
# $(asm_object_files): build/kernel/%.o: src/kernel/%.asm
# 	mkdir -p $(dir $@)
# 	nasm -f elf64 $< -o $@
# 链接内核
# build/kernel.elf: $(asm_object_files)
# 	x86_64-elf-ld -n -o $@ -T targets/boot/linker.ld $(asm_object_files)
# 转换为二进制
# build/kernel.bin: build/kernel.elf
# 	objcopy -O binary $< $@

# 制作软盘
build-disk: dist/disk.img
build-floppy: dist/floppy.img

dist/disk.img: build/boot/disk/mbr.bin build/boot/disk/loader.bin build/kernel/kernel.bin
	rm -rf dist
	mkdir dist
	# 1.44MB空镜像
	dd if=/dev/zero of=$@ bs=512 count=2880
	# 0#扇区
	dd if=build/boot/disk/mbr.bin of=$@ conv=notrunc bs=512 count=1
	# 1#扇区
	dd if=build/boot/disk/loader.bin of=$@ conv=notrunc bs=512 count=1 seek=1
	# 8#扇区
	dd if=build/kernel/kernel.bin of=$@ conv=notrunc bs=512 count=1 seek=8
dist/floppy.img: build/boot/floppy/mbr.bin build/boot/floppy/loader.bin
	rm -rf dist
	mkdir dist
	# 1.44MB空镜像
	dd if=/dev/zero of=$@ bs=512 count=2880
	# 0#扇区
	dd if=build/boot/floppy/mbr.bin of=$@ conv=notrunc bs=512 count=1
	# 1#扇区
	dd if=build/boot/floppy/loader.bin of=$@ conv=notrunc bs=512 count=1 seek=1
clean:
	rm -rf build dist
