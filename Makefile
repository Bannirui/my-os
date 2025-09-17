.PHONY: all run clean

# 工具链变量
CC := gcc
LD := ld
NASM := nasm

all: build-floppy
# 制作启动盘
build-floppy: dist/floppy.img

asm_src_files := $(shell find src -name *.asm)
asm_obj_files := $(patsubst src/%.asm, build/%.o, $(asm_src_files))
build/%.bin: src/%.asm
	mkdir -p $(dir $@)
	$(NASM) -o $@ $<

dist/floppy.img: build/boot.bin
	rm -rf dist
	mkdir dist
	# 1.44MB空镜像
	dd if=/dev/zero of=$@ bs=512 count=2880
	# 0#扇区
	dd if=build/boot.bin of=$@ conv=notrunc bs=512 count=1

run: dist/floppy.img
	qemu-system-x86_64 -fda dist/floppy.img -boot a

clean:
	rm -rf build dist