AS = nasm
SRC = $(wildcard *.asm)
OBJS = $(patsubst %.asm, %.bin, $(SRC))

default: $(OBJS)

%.bin: %.asm
	$(AS) $< -o $@

.PHONY: clean
clean:
	-rm -f $(OBJS)