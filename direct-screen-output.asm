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
    push di
    push es
    mov cx, fs
    mov es, cx
    mov cx, 80 * 25
    xor di, di
    repne stosw
    pop es
    pop di
    pop cx
    ret
