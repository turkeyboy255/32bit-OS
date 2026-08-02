org 0x7E00
BITS 32

start:
    mov eax,33  ;loads the last saved file table to 0x20000 in memory
    mov edi,0x20000
    call ata_read_sector

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
    call newline
    movzx edi,byte [buffer_pos]
    mov byte [buffer+edi],0

    call command
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
; COMMAND TABLE
; ==========================
command:
    mov edi,help_cmd
    call compare_strings
    cmp edi, 1
    je help
    mov edi,dir_cmd
    call compare_strings
    cmp edi, 1
    je dir
    mov edi,clear_cmd
    call compare_strings
    cmp edi, 1
    je clear
    mov edi,load_cmd
    call compare_strings
    cmp edi, 1
    je load
    ret

; ==========================
; STRING COMPARE
; ==========================
compare_strings:
    mov esi,buffer

.loop:
    mov al,[esi]
    mov bl,[edi]

    cmp al,bl
    jne .done

    cmp al, ' '
    je .match

    cmp al,0
    je .match

    inc esi
    inc edi
    jmp .loop

.match:
    mov edi, 1
    ret
.done:
    mov edi, 0
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
; NEW LINE
; ==========================
newline:
    mov eax,[cursor]

    ; find current column
    sub eax,0xB8000
    xor edx,edx
    mov ecx,160
    div ecx          ; eax = row, edx = offset in row

    ; move to next row
    sub dword [cursor],edx
    add dword [cursor],160

    ret

; ==========================
; ATA DRIVER
; ==========================

ata_wait_busy:
.wait:
    mov dx, 0x1F7
    in  al, dx
    test al, 0x80            ; BSY
    jnz .wait
    ret

ata_wait_drq:
.wait:
    mov dx, 0x1F7
    in  al, dx

    test al, 0x01            ; ERR
    jnz .error

    test al, 0x80            ; BSY
    jnz .wait

    test al, 0x08            ; DRQ
    jz .wait

    ret

.error:
    mov al,'E'
    call print_char_screen
.hang:
    jmp .hang

ata_read_sector:

    push eax
    push ebx
    push ecx
    push edx

    mov ebx,eax

    call ata_wait_busy

    ; sector count
    mov dx,0x1F2
    mov al,1
    out dx,al

    ; LBA 0-7
    mov dx,0x1F3
    mov al,bl
    out dx,al

    ; LBA 8-15
    mov dx,0x1F4
    mov al,bh
    out dx,al

    ; LBA 16-23
    shr ebx,16
    mov dx,0x1F5
    mov al,bl
    out dx,al

    ; LBA 24-27
    shr ebx,8
    mov dx,0x1F6
    mov al,bl
    and al,0x0F
    or al,0xE0
    out dx,al

    ; read command
    mov dx,0x1F7
    mov al,0x20
    out dx,al

    call ata_wait_drq

    mov dx,0x1F0
    mov ecx,256

.read:
    in ax,dx
    mov [edi],ax
    add edi,2
    loop .read

    pop edx
    pop ecx
    pop ebx
    pop eax
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


; ==========================
; COMMANDS
; ==========================

help_cmd:
    db 'HELP',0
help_msg:
    db 'CLEAR DIR HELP LOAD ',0
dir_cmd:
    db 'DIR',0
clear_cmd:
    db 'CLEAR',0
load_cmd:
    db 'LOAD '

help:
    mov esi,help_msg
    call print_string
    call newline
    ret

clear:
    call clear_screen
    ret

dir:
    mov eax,33
    mov edi,0x20000
    call ata_read_sector

    call print_filetable

    ret

load:
    call find_file
    mov edi,0x30000
    call ata_read_sector
    call 0x30000
    ret
; ==========================
; FileTable Helper Commands
; ==========================
find_file:
    ; number of files
    mov eax,[0x20004]
    ; file counter
    xor ebx,ebx
    ; typed filename
    mov esi,buffer
    add esi,5              ; skip "LOAD "
    ; first filename
    mov edi,0x20008
.next_file:
    call .compare_file
    cmp edx,1
    je .match
    ; next file entry
    add edi,32
    inc ebx
    cmp ebx,eax
    jne .next_file
.fail:
    xor eax,eax
    ret
.compare_file:
    push esi
    push edi
.compare_loop:
    mov al,[esi]
    mov ah,[edi]
    cmp al,0
    je .end_compare
    cmp al,ah
    jne .different
    inc esi
    inc edi
    jmp .compare_loop
.end_compare:
    mov edx,1
    pop edi
    pop esi
    ret
.different:
    xor edx,edx
    pop edi
    pop esi
    ret
.match:
    ; EDI points to the matching file entry
    mov eax,[edi+16]       ; starting sector
    mov ebx,[edi+20]       ; file size
    ret

print_filetable:
    mov eax,[0x20004]     ; file count
    xor ebx,ebx           ; index

.loop:
    cmp ebx,eax
    je .done

    mov esi,0x20008       ; first entry
    mov edx,ebx
    imul edx,32           ; entry size
    add esi,edx

    call print_string

    inc ebx
    jmp .loop

.done:
    call newline
    ret

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

times 16384-($-$$) db 0org 0x7E00
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
    call newline
    movzx edi,byte [buffer_pos]
    mov byte [buffer+edi],0

    call command
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
; COMMAND TABLE
; ==========================
command:
    mov edi,help_cmd
    call compare_strings
    cmp edi, 1
    je help
    mov edi,dir_cmd
    call compare_strings
    cmp edi, 1
    je dir
    mov edi,clear_cmd
    call compare_strings
    cmp edi, 1
    je clear
    mov edi,load_cmd
    call compare_strings
    cmp edi, 1
    je load
    ret

; ==========================
; STRING COMPARE
; ==========================
compare_strings:
    mov esi,buffer

.loop:
    mov al,[esi]
    mov bl,[edi]

    cmp al,bl
    jne .done

    cmp al, ' '
    je .match

    cmp al,0
    je .match

    inc esi
    inc edi
    jmp .loop

.match:
    mov edi, 1
    ret
.done:
    mov edi, 0
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
; NEW LINE
; ==========================
newline:
    mov eax,[cursor]

    ; find current column
    sub eax,0xB8000
    xor edx,edx
    mov ecx,160
    div ecx          ; eax = row, edx = offset in row

    ; move to next row
    sub dword [cursor],edx
    add dword [cursor],160

    ret

; ==========================
; ATA DRIVER
; ==========================

ata_wait_busy:
.wait:
    mov dx, 0x1F7
    in  al, dx
    test al, 0x80            ; BSY
    jnz .wait
    ret

ata_wait_drq:
.wait:
    mov dx, 0x1F7
    in  al, dx

    test al, 0x01            ; ERR
    jnz .error

    test al, 0x80            ; BSY
    jnz .wait

    test al, 0x08            ; DRQ
    jz .wait

    ret

.error:
    mov al,'E'
    call print_char_screen
.hang:
    jmp .hang

ata_read_sector:

    push eax
    push ebx
    push ecx
    push edx

    mov ebx,eax

    call ata_wait_busy

    ; sector count
    mov dx,0x1F2
    mov al,1
    out dx,al

    ; LBA 0-7
    mov dx,0x1F3
    mov al,bl
    out dx,al

    ; LBA 8-15
    mov dx,0x1F4
    mov al,bh
    out dx,al

    ; LBA 16-23
    shr ebx,16
    mov dx,0x1F5
    mov al,bl
    out dx,al

    ; LBA 24-27
    shr ebx,8
    mov dx,0x1F6
    mov al,bl
    and al,0x0F
    or al,0xE0
    out dx,al

    ; read command
    mov dx,0x1F7
    mov al,0x20
    out dx,al

    call ata_wait_drq

    mov dx,0x1F0
    mov ecx,256

.read:
    in ax,dx
    mov [edi],ax
    add edi,2
    loop .read

    pop edx
    pop ecx
    pop ebx
    pop eax
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


; ==========================
; COMMANDS
; ==========================

help_cmd:
    db 'HELP',0
help_msg:
    db 'CLEAR DIR HELP LOAD ',0
dir_cmd:
    db 'DIR',0
clear_cmd:
    db 'CLEAR',0
load_cmd:
    db 'LOAD '

help:
    mov esi,help_msg
    call print_string
    call newline
    ret

clear:
    call clear_screen
    ret

dir:
    mov eax,33
    mov edi,0x20000
    call ata_read_sector

    call print_filetable

    ret

load:
    mov eax, 34
    mov edi,0x30000
    call ata_read_sector
    call 0x30000
    ret
; ==========================
; FileTable Helper Commands
; ==========================


print_filetable:
    mov eax,[0x20004]     ; file count
    xor ebx,ebx           ; index

.loop:
    cmp ebx,eax
    je .done

    mov esi,0x20008       ; first entry
    mov edx,ebx
    imul edx,32           ; entry size
    add esi,edx

    call print_string

    inc ebx
    jmp .loop

.done:
    call newline
    ret

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

times 16384-($-$$) db 0
