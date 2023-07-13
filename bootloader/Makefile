AS = nasm
SRC = $(wildcard *.asm)
OBJS = $(patsubst %.asm, %.bin, $(SRC))

DEV_DIR = /home/dingrui/Dev/bootloader
BOCHS_DIR = /home/dingrui/Apps/bochs-2.6.8
FLOPPY_MOUNT_POINT = $(BOCHS_DIR)/tmp
BOOT = boot.bin
LOADER = loader.bin
FLOPPY_IMG = boot.img

default: $(OBJS)
	@echo "check..."
	@if [ ! -e ${DEV_DIR}/${BOOT} ]; then echo "boot.bin not found" && exit 1;fi
	@if [ ! -e ${DEV_DIR}/${LOADER} ]; then echo "loader.bin not found" && exit 1;fi
	@if [ ! -e ${BOCHS_DIR}/bochs ]; then echo "bochs not found" && exit 1;fi
	@if [ ! -e ${BOCHS_DIR}/boshsrc ]; then echo "boshsrc not found" && exit 1;fi
	@if [ ! -e ${BOCHS_DIR}/bximage ]; then echo "bximage not found" && exit 1;fi
	@rm -rf $(BOCHS_DIR)/$(FLOPPY_IMG)
	@echo "floppy..."
	$(BOCHS_DIR)/bximage
	dd if=$(DEV_DIR)/$(BOOT) of=$(DEV_DIR)/$(FLOPPY_IMG) bs=512 count=1 conv=notrunc
	if [ ! -d ${FLOPPY_MOUNT_POINT} ]; then mkdir -p ${FLOPPY_MOUNT_POINT};fi
	mount $(DEV_DIR)/$(FLOPPY_IMG) $(FLOPPY_MOUNT_POINT)/ -t vfat -o loop
	cp $(DEV_DIR)/$(LOADER) $(FLOPPY_MOUNT_POINT)/
	sync
	umount $(FLOPPY_MOUNT_POINT)
	@echo "starting..."
	$(BOCHS_DIR)/bochs -f $(BOCHS_DIR)/boshsrc

%.bin: %.asm
	$(AS) $< -o $@

.PHONY: clean
clean:
	-rm -f $(OBJS)
	-rm -rf $(DEV_DIR)/$(FLOPPY_IMG)
	-umount $(FLOPPY_MOUNT_POINT)
