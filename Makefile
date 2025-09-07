.PHONY: all run clean

all: build/floppy.img

# 生成二进制boot扇区512字节
build/boot.bin: src/HelloWorld.asm
	mkdir -p build
	nasm -f bin $< -o $@

# 把boot.bin写到软盘镜像
build/floppy.img: build/boot.bin
	rm -rf dist
	dd if=/dev/zero of=$@ bs=512 count=2880 # 1.44MB空镜像
	dd if=$< of=$@ conv=notrunc
	mkdir dist
	cp build/floppy.img dist/floppy.img

clean:
	rm -rf build dist
