.PHONY: all run clean

all: build-floppy

# 第一阶段 BootLoader boot只能汇编成bin 
build/boot.bin: src/boot.asm
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
build-floppy: dist/floppy.img

# dist/floppy.img: build/boot.bin build/kernel.bin
dist/floppy.img: build/boot.bin
	rm -rf dist
	mkdir dist
	# 1.44MB空镜像
	dd if=/dev/zero of=$@ bs=512 count=2880
	# 写boot
	dd if=build/boot.bin of=$@ conv=notrunc bs=512 count=1
	# 从第2扇区开始写kernel
# 	dd if=build/kernel.bin of=$@ conv=notrunc bs=512 seek=1

clean:
	rm -rf build dist
