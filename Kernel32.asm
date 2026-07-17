org 0x7E00
BITS 32

start:
    jmp get_inp

; ==========================
; KEYBOARD INPUT
; ==========================
get_inp:
.wait:
    in al,0x64
    test al,1
    jz .wait

    in al,0x60

    ; ignore key releases
    test al,0x80
    jnz get_inp

    cmp al,0x1C
    je enter_key

    cmp al,0x0E
    je backspace

    cmp al,0x39
    je spacebar

    ; letters
    movzx ebx,al
    mov al,[keymap+ebx]

    cmp al,0
    je get_inp

    call print_char
    jmp get_inp


; ==========================
; ENTER
; ==========================
enter_key:
    movzx edi,byte [buffer_pos]
    mov byte [buffer+edi],0

    call compare_strings
    call clear_buffer
    jmp get_inp

; ==========================
; BACKSPACE
; ==========================
backspace:
    cmp byte [buffer_pos],0
    je get_inp

    dec byte [buffer_pos]
    sub dword [cursor],2
    mov edi,[cursor]

    mov ax,0x0F20
    mov [edi],ax

    jmp get_inp


; ==========================
; SPACE
; ==========================
spacebar:
    mov al,' '
    call print_char
    jmp get_inp


; ==========================
; PRINT CHARACTER
; ==========================
print_char:
    push eax
    mov edi,[cursor]
    mov ah,0x0F
    mov [edi],ax
    add dword [cursor],2
    pop eax
    call store_char
    ret


; ==========================
; STORE INPUT
; ==========================
store_char:
    movzx edi,byte [buffer_pos]
    mov [buffer+edi],al
    inc byte [buffer_pos]
    ret


; ==========================
; STRING COMPARE
; ==========================
compare_strings:
    mov esi,buffer
    mov edi,help_cmd

.loop:
    mov al,[esi]
    mov bl,[edi]

    cmp al,bl
    jne .done

    cmp al,0
    je .match

    inc esi
    inc edi
    jmp .loop

.match:
    call clear_screen

    mov esi,help_msg
    call print_string
.done:
    ret


; ==========================
; PRINT STRING
; ==========================
print_string:
.next:
    lodsb
    cmp al,0
    je .done
    call print_char_screen
    jmp .next
.done:
    ret
; version without storing
print_char_screen:
    mov edi,[cursor]
    mov ah,0x0F
    mov [edi],ax
    add dword [cursor],2
    ret


; ==========================
; CLEAR BUFFER
; ==========================
clear_buffer:
    mov edi,buffer
    mov ecx,64
    xor al,al
.loop:
    mov [edi],al
    inc edi
    loop .loop
    mov byte [buffer_pos],0
    ret
; ==========================
; CLEAR SCREEN
; ==========================
clear_screen:
    mov edi,0xB8000
    mov ecx,2000
    mov ax,0x0F20
.loop:
    mov [edi],ax
    add edi,2
    loop .loop
    mov dword [cursor],0xB8000
    ret

; ==========================
; DATA
; ==========================
cursor:
    dd 0xB8000

buffer_pos:
    db 0
buffer:
    times 64 db 0

help_cmd:
    db 'HELP',0
help_msg:
    db 'NO HELP FROM HERE',0

; ==========================
; SCAN CODE TABLE
; ==========================
keymap:
times 0x10 db 0
db 'Q'
db 'W'
db 'E'
db 'R'
db 'T'
db 'Y'
db 'U'
db 'I'
db 'O'
db 'P'
times (0x1E-0x1A) db 0
db 'A'
db 'S'
db 'D'
db 'F'
db 'G'
db 'H'
db 'J'
db 'K'
db 'L'
times (0x2C-0x27) db 0
db 'Z'
db 'X'
db 'C'
db 'V'
db 'B'
db 'N'
db 'M'
