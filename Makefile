MAKEFLAGS += --silent

.PHONY: run
run: run-requirements build
	qemu-system-i386 -drive file=floppy.img,format=raw,if=floppy,index=0

.PHONY: build
build: build-requirements floppy.img

floppy.img: boot.bin
	dd bs=512 count=2880 if=/dev/zero of=floppy.img
	mformat -i floppy.img -f 1440 -B boot.bin -N 0xDEADBEEF -v boot2play

boot.bin: boot.asm
	nasm -f bin -o boot.bin boot.asm

.PHONY: clean
clean:
	rm -f boot.bin floppy.img

.PHONY: run-requirements
run-requirements:
	which qemu-system-i386 > /dev/null || (echo "Looks like 'QEMU' is not installed" && exit 1)

.PHONY: build-requirements
build-requirements:
	which nasm > /dev/null || (echo "Looks like 'nasm' is not installed" && exit 1)
	which mformat > /dev/null || (echo "Looks like 'mtools' is not installed" && exit 1)

.PHONY: dump-boot-sector
dump-boot-sector: floppy.img boot.bin
	echo "===[ boot.bin ]==="
	hexdump -C boot.bin
	echo "===[ floppy.img ]==="
	hexdump -C -n 512 floppy.img

	# Simply calling diff with bash command substitution doesn't work from make
	bash -c 'diff <(hexdump -C boot.bin) <(hexdump -C -n 512 floppy.img)'
