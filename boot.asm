; 1.44 MB floppy boot sector

; Entry point
jmp bootstrap

; We have one byte unused, usually it's a nop instruction.
; But since 'boot2play' doesn't fit into the OEM name field in
; the BIOS parameter block, we can make a little trick here.
db 'b'

; See http://www.ntfs.com/fat-partition-sector.htm
; See https://www.win.tue.nl/~aeb/linux/fs/fat/fat-1.html

db 'oot2play' ; OEM name

; Extended BIOS parameter block
dw 512           ; number of bytes per sector
db 1             ; number of sectors per cluster
dw 1             ; number of reserved sectors including the boot sector
db 2             ; number of FATs
dw 224           ; number of root entries
dw 2880          ; number of sectors on the disk
db 0xF0          ; media type (f0 - floppy)
dw 9             ; number of sectors per FAT
dw 18            ; number of sectors per track
dw 2             ; number of heads
dd 0             ; number of hidden sectors
dd 0             ; number of large sectors
db 0             ; physical disk number (0 - A:)
db 0             ; current head
db 0x29          ; signature (must be 0x29 for WinNT to recognize)
dd 0xDEADBEEF    ; volume serial number
db 'boot2play  ' ; volume label
db 'FAT12   '    ; file system type


; The actual bootstrap code starts here
bootstrap:

; Make sure the
%if bootstrap - $$ != 0x3E
%error "The bootstrap code must start at 0x3E"
%endif

mov ax, 0xB800
mov es, ax

mov al, 'X'
mov ah, 0xCF
mov bx, 39
mov cx, 12
call put_char

jmp $

; AL: char
; AH: attr
; BX: x
; CX: y
; ES: 0xB800
put_char:
    shl bx, 1  ; bx = x * 2
    shl cx, 5
    add bx, cx ; bx = x * 2 + y * 32
    shl cx, 2
    add bx, cx ; bx = x * 2 + y * (32 + 128)
    mov [es:bx], ax
    ret

times 510 - ($ - $$) db 0
db 0x55
db 0xAA
