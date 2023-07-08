obj = boot.bin loader.bin

all: $(obj)

boot.bin:
	nasm boot.asm -o boot.bin

loader.bin:
	nasm loader.asm -o loader.bin

.PHONY: clean
clean:
	-rm $(obj)