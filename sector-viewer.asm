; Load a sector and display its content.
; Wait for any key and move to the next one.
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

; Wait for any key to be pressed
xor ah, ah
int 0x16

inc word [current_sector]
jmp .load_and_show_sector
