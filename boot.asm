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
; +-------------+--------+-----------------+
; | Range       | Size   | Description     |
; +-------------+--------+-----------------+
; | 00000-003FF | 1024   | interrupt table |
; | 00400-004FF | 256    | BIOS data area  |
; | 00500-07BFF | 30464  | free memory     |
; | 07C00-07DFF | 512    | boot sector     |
; | 07E00-09CFF | 8192   | stack           |
; | 09E00-7FFFF | 492032 | free memory     |
; +----------------------------------------+


; Set up DS to 07C0:0000. It's also possible to use 0000:7C00
; but then we would need to offset this code via ORG.
; Next 8kb after this boot sector is the stack 07E0:0000-07E0:1FFF
cli
mov ax, 0x07C0
mov ds, ax
mov ax, 0x07E0
mov ss, ax
mov sp, 8192
sti

; On boot the boot drive index is stored in DL
mov [boot_drive], dl

; FS is 0xB800 through out the entire program
mov ax, 0xB800
mov fs, ax

; The direction flag is cleared through out the entire program
cld

; Clear the screen first
mov ax, 0x0720
call clear_screen

; Read drive parameters
mov ah, 0x08
mov dl, [boot_drive]
xor di, di
mov es, di
int 0x13
jc halt

; Store disk parameters
; DH contains the max head index, adding 1 to convert to count
inc dh
mov [num_heads], dh
; CX contains both cylinders and sectors per track
; Lower 6 bits contain number of sectors per track
mov ax, cx
and al, (1 << 6) - 1
mov [num_sectors_per_track], al
; Higher 8 bits contain lower 8 bits of max cylinder index
; Bits 6 and 7 are the high order bits of max cylinder index
; Adding 1 to convert to count
ror cx, 8
shr ch, 6
inc cx
mov [num_cylinders], cx

.load_and_show_sector:
mov ax, [current_sector]
mov bx, 0x09E0
mov es, bx
xor bx, bx
call read_linear_sector
jc halt

mov si, 0x2200 ; 09E0:0000 = 07C0:2200 = ds:2200
mov bx, 0
mov cx, 0
mov ah, 0xF1
call display_memory_dump_16x16

mov si, 0x2300
mov bx, 34
mov cx, 0
mov ah, 0xF1
call display_memory_dump_16x16

xor ah, ah
int 0x16

inc word [current_sector]
jmp .load_and_show_sector

; Halt
halt:
    jmp halt

; AL: char
; AH: attr
; BX: x
; CX: y
; FS: 0xB800
put_char:
    shl bx, 1  ; bx = x * 2
    shl cx, 5
    add bx, cx ; bx = x * 2 + y * 32
    shl cx, 2
    add bx, cx ; bx = x * 2 + y * (32 + 128)
    mov [fs:bx], ax
    ret

; AL: nibble (upper 4 bits must be zero)
; AH: attr
; BX: x
; CX: y
; FS: 0xB800
put_hex_nibble:
    add al, '0'
    cmp al, '9'
    jle .call_put_char
    add al, 'A' - '0' - 10
.call_put_char:
    jmp put_char ; tail call

; AL: byte
; AH: attr
; BX: x
; CX: y
; FS: 0xB800
put_hex_byte:
    push cx
    push bx
    push ax
    shr al, 4
    call put_hex_nibble
    pop ax
    and al, 0x0F
    pop bx
    inc bx
    pop cx
    jmp put_hex_nibble ; tail call

; DX: word
; AH: attr
; BX: x
; CX: y
; FS: 0xB800
put_hex_word:
    push dx
    push cx
    push bx
    push ax
    mov al, dh
    call put_hex_byte
    pop ax
    pop bx
    pop cx
    pop dx
    mov al, dl
    add bx, 2
    jmp put_hex_byte; tail call

; SI: bytes
; DX: length
; AH: attr
; BX: x
; CX: y
; FS: 0xB800
put_hex_string:
    push di
    mov di, ax
.loop:
    or dx, dx
    jz .done
    push cx
    push bx
    mov ax, di
    mov al, [ds:si]
    call put_hex_byte
    pop bx
    add bx, 2
    pop cx
    inc si
    dec dx
    jmp .loop
.done:
    pop di
    ret

; DS:SI: bytes
; AH: attr
; BX: x
; CX: y
; FS: 0xB800
display_memory_dump_16x16:
; Print memory dump of [0x00400, 0x00500)
    push bp
    mov bp, sp

    push bx ; x:     bp - 2
    push cx ; y:     bp - 4
    push 0  ; row:   bp - 6
    push si ; bytes: bp - 8
    push ax ; attr:  bp - 10

    .row:
    mov bx, [bp - 2]; x
    mov cx, [bp - 4]; y
    add cx, [bp - 6]; y + row
    mov dx, 16
    mov si, [bp - 8]
    mov ax, [bp - 10]
    call put_hex_string

    add word [bp - 8], 16

    inc word [bp - 6]
    cmp word [bp - 6], 16
    jl .row

    mov sp, bp
    pop bp
    ret

; AL: char
; AH: attr
; FS: 0xB800
clear_screen:
    push cx
    push es
    mov cx, fs
    mov es, cx
    mov cx, 80 * 25
    repne stosw
    pop es
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

boot_drive db 0
num_heads db 0
num_cylinders dw 0
num_sectors_per_track db 0

current_sector dw 0

times 510 - ($ - $$) db 0
db 0x55
db 0xAA
