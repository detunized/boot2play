.PHONY: run
run: boot.bin
	qemu-system-i386 -drive file=boot.bin,format=raw

boot.bin: boot.asm
	nasm -f bin -o boot.bin boot.asm
