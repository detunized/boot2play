MAKEFLAGS += --silent

.PHONY: run
run: run-requirements build
	echo "Launching QEMU (usually starts in the background)"
	echo "Press Ctrl-C to quit"
	qemu-system-i386 -drive file=floppy.img,format=raw,if=floppy,index=0 -boot a -nographic -curses

run-ui: run-requirements build
	echo "Launching QEMU (usually starts in the background)"
	echo "Press Ctrl-C to quit"
	qemu-system-i386 -drive file=floppy.img,format=raw,if=floppy,index=0 -boot a

debug: run-requirements build
	echo "Launching QEMU (usually starts in the background)"
	echo "Connect with gdb: gdb -ex 'set arch i8086' -ex 'target remote localhost:1234' -ex 'br *0x7c3e'"
	echo "Press Ctrl-C to quit"
	qemu-system-i386 -drive file=floppy.img,format=raw,if=floppy,index=0 -boot a -s -S

.PHONY: build
build: build-requirements floppy.img

floppy.img: boot.bin 2ndstage.bin
	dd bs=512 count=2880 if=/dev/zero of=floppy.img
	mformat -i floppy.img -f 1440 -B boot.bin -N 0xDEADBEEF -v boot2play
	mcopy -i floppy.img 2ndstage.bin ::2ndstage.bin

boot.bin: boot.asm
	nasm -f bin -o boot.bin boot.asm

2ndstage.bin:
	ruby -e "print 'DEADBEEF' * 100" > 2ndstage.bin

.PHONY: clean
clean:
	rm -f boot.bin 2ndstage.bin floppy.img

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
