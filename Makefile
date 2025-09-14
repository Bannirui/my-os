.PHONY: all run clean

all: build-disk

# 第一阶段 BootLoader只能汇编成bin
# 硬盘
build/boot/disk/mbr.bin: src/boot/disk/mbr.asm
	mkdir -p $(dir $@)
	nasm -f bin -o $@ $<
build/boot/disk/loader.bin: src/boot/disk/loader.asm
	mkdir -p $(dir $@)
	nasm -f bin -o $@ $<

# 第二阶段 内核
# 编译
# find递归找所有asm源文件 对应o文件路径
asm_source_files := $(shell find src/kernel -name *.asm)
asm_object_files := $(patsubst src/kernel/%.asm, build/kernel/%.o, $(asm_source_files))
build/kernel/%.o: src/kernel/%.asm
	mkdir -p $(dir $@)
	nasm -f elf32 -o $@ $<

c_source_files := $(shell find src/kernel -name *.c)
c_object_files := $(patsubst src/kernel/%.c, build/kernel/%.o, $(c_source_files))
build/kernel/%.o: src/kernel/%.c
	mkdir -p $(dir $@)
	gcc -c -m16 -march=i386 -masm=intel -nostdlib -ffreestanding -mpreferred-stack-boundary=2 -lgcc -fno-pic -fno-pie -o $@ $<

# 链接
build/kernel/kernel.bin: ${asm_object_files} ${c_object_files}
	ld -m elf_i386 -N -T targets/linker.ld --oformat binary -o $@ $^

# 制作启动盘
build-disk: dist/disk.img

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
	dd if=build/kernel/kernel.bin of=$@ bs=512 count=100 seek=8

run: dist/disk.img
	qemu-system-x86_64 -hda dist/disk.img
	#qemu-system-i386 -hda dist/disk.img

clean:
	rm -rf build dist
