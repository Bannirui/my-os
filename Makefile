.PHONY: all run clean

# 工具链变量
CC := gcc
LD := ld
NASM := nasm
NASM_FLAGS = -f bin -I src/

all: build-floppy
# 制作启动盘
build-floppy: dist/floppy.img

asm_src_files := $(shell find src -name *.asm)
asm_obj_files := $(patsubst src/%.asm, build/%.o, $(asm_src_files))
build/%.bin: src/%.asm
	mkdir -p $(dir $@)
	$(NASM) $(NASM_FLAGS) -o $@ $<

dist/floppy.img: build/boot.bin build/loader.bin
	rm -rf dist
	mkdir dist
	# 用来挂载的空目录
	mkdir -p dist/mnt
	# 1.44MB空镜像
	dd if=/dev/zero of=$@ bs=512 count=2880
	# 格式化为FAT12
	mkfs.vfat $@
	# 0#扇区
	dd if=build/boot.bin of=$@ conv=notrunc bs=512 count=1
	# 指定待挂载目录media 磁盘文件类型 负责把文件描述成磁盘分区
	mount $@ dist/mnt -t vfat -o loop
	cp build/loader.bin dist/mnt
	# 强制同步
	sync
	umount dist/mnt

run: dist/floppy.img
	qemu-system-x86_64 -fda dist/floppy.img -boot a

clean:
	rm -rf build dist