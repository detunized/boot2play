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

; TODO: set up the registers and the stack

; Memory map (see https://wiki.osdev.org/Memory_Map_(x86))
; +-------------+--------+-------------------+-----------------+
; | Range       | Size   | Offset from 7C000 | Description     |
; +-------------+--------+-------------------+-----------------+
; | 00000-003FF | 1024   | -                 | interrupt table |
; | 00400-004FF | 256    | -                 | BIOS data area  |
; | 00500-07BFF | 30464  | -                 | free memory     |
; | 07C00-07DFF | 512    | 0                 | boot sector     |
; | 07E00-09CFF | 8192   | 512 or 0x200      | stack           |
; | 09E00-7FFFF | 492032 | 8704 or 0x2200    | free memory     |
; +-------------+--------+-------------------+-----------------+

; Set up DS to 07C0:0000. It's also possible to use 0000:7C00
; but then we would need to offset this code via ORG.
; Next 8kb after this boot sector is the stack.
; All segment registers are the equal.
cli
mov ax, 0x07C0
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x2200
sti

; On boot the boot drive index is stored in DL
mov [boot_drive], dl

; FS is 0xB800 through out the entire program.
; This is only needed for direct screen output routines.
mov ax, 0xB800
mov fs, ax

; The direction flag is cleared through out the entire program
cld

; Clear the screen first
mov ax, 0x0720
call clear_screen

; Set cursor to 0:0
mov ah, 2
xor bh, bh
xor dx, dx
int 0x10

; Read drive parameters
push es ; ES:DI will be overwritten
mov ah, 0x08
mov dl, [boot_drive]
int 0x13
pop es
jc halt

; Store disk parameters
; DH contains the max head index, adding 1 to convert to count
inc dh
mov [num_heads], dh
; CX contains both cylinders and sectors per track
; Lower 6 bits contain number of sectors per track
and cl, (1 << 6) - 1
mov [num_sectors_per_track], cl

;
; Iterate over root directory to find "2ndstage.bin"
;

mov bp, sp
mov ax, 19          ; Root directory starts at sector 19
push ax             ; sector: bp - 2

.next_sector:
mov bx, 0x2200
call read_linear_sector

; Scan all entries for "2NDSTAGEBIN"
mov dx, 16

.next_entry:

; When the first byte of the name is 0,
; the rest of the entries should be skipped.
cmp byte [bx], 0
je .skip_remainig_entries

; print filename
mov cx, 11
mov si, bx
call puts

; Compare filenames
mov cx, 11
lea si, [second_stage_name]
mov di, bx
repe cmpsb
je .check_file_attributes

; Move to the next entry
add bx, 32
dec dx
jnz .next_entry

.skip_remainig_entries:
mov ax, [bp - 2]
inc ax
mov [bp - 2], ax
cmp ax, 32          ; Root directory ends at sector 32
jle .next_sector

; Done: nothing found.
jmp .done

.check_file_attributes:
; This should be a regular file.
; Volume label (0x08) and directory (0x10) attributes should not be set.
test byte [bx + 11], 0x18
jnz halt

; The file is found
mov ax, 0x1721
call clear_screen

.done:
mov sp, bp

jmp halt

; Halt
halt:
jmp halt

; AL: char
; AH: attr
clear_screen:
    push cx
    push di
    push es
    mov cx, 0xB800
    mov es, cx
    mov cx, 80 * 25
    xor di, di
    repne stosw
    pop es
    pop di
    pop cx
    ret

; AX: linear sector index
; ES:BX: destination
; TODO: What happens when the index is too big?
; TODO: In the current version cylinder index is always < 256.
read_linear_sector:
    push cx
    push dx
    div byte [num_sectors_per_track]
    mov cl, ah ; linear_sector % num_sectors_per_track
    inc cl     ; sectors start at 1
    xor ah, ah
    div byte [num_heads]
    mov dh, ah ; linear_sector / num_sectors_per_track % num_heads
    mov ch, al ; linear_sector / num_sectors_per_track / num_heads
    mov ah, 2
    mov al, 1 ; number of sectors
    mov dl, [boot_drive]
    int 0x13
    pop dx
    pop cx
    ret

%include "bios-screen-output.asm"

boot_drive db 0
num_heads db 0
num_sectors_per_track db 0
second_stage_name db "2NDSTAGEBIN"

times 510 - ($ - $$) db 0
db 0x55
db 0xAA
