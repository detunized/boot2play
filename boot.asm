; Entry point
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
