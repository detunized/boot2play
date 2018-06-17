; In:
;     DS:SI: buffer
;        CX: length
; Out:
;     DS:SI: past end of the string
;        CX: 0
print_string:
    jcxz .done
    push ax
    mov ah, 0x0E
.print_char:
    lodsb
    int 0x10
    loop .print_char
    pop ax
.done:
    ret

print_endl:
    push ax
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    pop ax
    ret

; In:
;     DS:SI: buffer
;        CX: length
; Out:
;     DS:SI: past end of the string
;        CX: 0
puts:
    call print_string
    jmp print_endl
