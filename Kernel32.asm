org 0x7E00
BITS 32

start:
    call init_idt
    mov eax,33              ; filetable is stored at sector 33 on the disk
    mov edi,0x20000         ; where filetable is loaded for later refrence
    call ata_read_sector    ; loads the filetable

    jmp get_inp             ; runs the basic command line

; ==========================
; KEYBOARD INPUT
; ==========================
get_inp:
.wait:                      ; read keys loop
    ; waits till key pressed
    in al,0x64
    test al,1
    jz .wait

    in al,0x60

    ; ignore key releases
    test al,0x80
    jnz get_inp

    ; special keys
    cmp al,0x1C
    je enter_key

    cmp al,0x0E
    je backspace

    cmp al,0x39
    je spacebar

    ; letters
    movzx ebx,al
    mov al,[keymap+ebx]     ; uses the keymap to find the correct key to load

    cmp al,0
    je get_inp

    ; prints characters to the screen then continues the loop
    call print_char
    jmp get_inp


; ==========================
; ENTER
; ==========================
enter_key:
    call newline
    movzx edi,byte [buffer_pos]
    mov byte [buffer+edi],0

    call command            ; compares the buffer to stored commands to execute
    call clear_buffer       ; clears the buffer

    jmp get_inp             ; continues the command line loop

; ==========================
; BACKSPACE
; ==========================
backspace:
    ; reoves the last entry from the buffer and backs the pointer up
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
    ; i forgot to add spaces to the keymap so i just added a subroutine
    mov al,' '
    call print_char
    jmp get_inp


; ==========================
; PRINT CHARACTER
; ==========================
print_char:
    ; loads the last pressed character to the screen then stores it to the buffer
    push eax
    mov edi,[cursor]            ; starts the cursor to track the point on the screen
    mov ah,0x0F                 
    mov [edi],ax                
    add dword [cursor],2        ; moves the cursor to keep track of the screen
    pop eax
    call store_char
    ret


; ==========================
; STORE INPUT
; ==========================
store_char:
    ; stores the last pressed character to the buffer
    movzx edi,byte [buffer_pos] ; allocates one byte for the character
    mov [buffer+edi],al         ; stores the character
    inc byte [buffer_pos]       ; increments the buffer pointer
    ret

; ==========================
; COMMAND TABLE
; ==========================
; list of executable commands
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
; compares the strings for command execution
compare_strings:
    mov esi,buffer

.loop:
    mov al,[esi]    ; loads the buffer
    mov bl,[edi]    ; loads the command

    cmp al,bl       ; checks the command and buffer
    jne .done       

    cmp al, ' '     ; for the load function because it is two words
    je .match

    cmp al,0        ; end of the string \ null terminator
    je .match

    inc esi         ; next entry
    inc edi         ; next entry
    jmp .loop       ; repeat

.match:
    mov edi, 1      ; sets flag true
    ret
.done:
    mov edi, 0      ; sets flag false
    ret


; ==========================
; PRINT STRING
; ==========================
; print string routines
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
    ; resets the cursor and 0s the screen
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
    ; moves the cursor along one line of the screen
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

; ------------------------------------------------
; ata_write_sector
;
; EAX = LBA sector
; ESI = address of 512-byte buffer
; ------------------------------------------------

ata_write_sector:

    ; -------------------------
    ; Select drive + LBA bits 24-27
    ; -------------------------

    mov edx, eax
    shr edx, 24
    and dl, 0x0F
    or dl, 0xE0

    mov dx, 0x1F6
    out dx, al


    ; -------------------------
    ; Sector count = 1
    ; -------------------------

    mov dx, 0x1F2
    mov al, 1
    out dx, al


    ; -------------------------
    ; LBA bits 0-7
    ; -------------------------

    mov dx, 0x1F3
    mov eax, eax
    out dx, al


    ; LBA bits 8-15
    mov dx, 0x1F4
    shr eax, 8
    out dx, al


    ; LBA bits 16-23
    mov dx, 0x1F5
    shr eax, 8
    out dx, al


    ; -------------------------
    ; WRITE SECTORS
    ; -------------------------

    mov dx, 0x1F7
    mov al, 0x30
    out dx, al


    ; -------------------------
    ; Wait until drive is ready
    ; -------------------------

.wait:

    in al, dx

    test al, 0x80       ; BSY
    jnz .wait

    test al, 0x08       ; DRQ
    jz .wait


    ; -------------------------
    ; Send 512 bytes
    ; -------------------------

    mov dx, 0x1F0
    mov ecx, 256

.write:

    mov ax, [esi]
    out dx, ax

    add esi, 2
    loop .write


    ; -------------------------
    ; Wait for completion
    ; -------------------------

    mov dx, 0x1F7

.done:

    in al, dx

    test al, 0x80       ; BSY
    jnz .done

    test al, 0x01       ; ERR
    jnz .error

    ret


.error:
    ; Handle ATA error here
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
add_cmd:
    db 'ADD '



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
    call find_file      ; calls routine to find infornation about the file
    cmp eax, 1
    je .fail
    call malloc
    mov edi, 0x30000
    add edi, [allocatedmem]

.loadnext:
    call ata_read_sector; loads sector
    sub ebx, 512        ; decriments remaining sectors
    add eax, 1          ; next sector on disk
    cmp ebx, 0          ; checks for finished routine
    je .done
    jmp .loadnext       ; repeats
.fail:
    ret
.done:
    call clear
    mov eax, 0x30000
    add eax, [allocatedmem]
    call eax        ; loads program memory
    call newline
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
    mov eax, 1
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
    cmp eax,ebx
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
; MEMORY ALLOCATOR
; ==========================
malloc:
    ; takes into account file size and finds the best memory address after 0x30000 to alloacte to a file then return the memory address to edi
    mov edi, 0x30000
    add edi, [allocatedmem]
    add [allocatedmem], ebx
    ret

allocatedmem db 0   ; total bytes allocated so far

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




; =============================
; INTERRUPT DESCRIPTOR TABLE
; =============================

idt:
    times 256 dq 0

idt_descriptor:
    dw 2048-1
    dd idt

; EAX = handler address
; EBX = interrupt number
set_idt_gate:

    mov edi,idt

    imul ebx,8
    add edi,ebx

    ; offset low
    mov word [edi],ax

    ; code segment selector
    mov word [edi+2],0x08

    ; reserved
    mov byte [edi+4],0

    ; flags:
    ; present
    ; ring 0
    ; 32-bit interrupt gate
    mov byte [edi+5],0x8E

    ; offset high
    shr eax,16
    mov word [edi+6],ax

    ret


init_idt:

    mov eax,syscall_handler
    mov ebx,0x80

    call set_idt_gate

    lidt [idt_descriptor]

    ret

; ==========================
; SYSCALL HANDLER
; ==========================

syscall_handler:

    pusha

    cmp eax,1
    je sys_putchar

    cmp eax,2
    je sys_print

    cmp eax,3
    je sys_malloc

    cmp eax,4
    je sys_exit

    jmp syscall_done


; ==========================
; PRINT CHARACTER
; EBX = character
; ==========================

sys_putchar:

    mov al,bl
    call print_char_screen

    jmp syscall_done


; ==========================
; PRINT STRING
; ESI = string pointer
; ==========================

sys_print:

    call print_string

    jmp syscall_done


; ==========================
; MALLOC
; EBX = size
; returns EAX = address
; ==========================

sys_malloc:
    call malloc
    mov eax,edi
    jmp syscall_done

; ==========================
; EXIT PROGRAM
; ==========================

sys_exit:
    ; for now return to shell
    jmp start


syscall_done:
    popa
    iret

times 16384-($-$$) db 0
