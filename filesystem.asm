; ============================================================
; COMMANDS
; ============================================================

help:
    mov esi, help_msg
    call print_string
    call newline
    ret

help_msg db 'HELP CLEAR DIR LOAD', 0


clear:
    call clear_screen
    ret


dir:
    mov eax,73
    mov edi,0x20000
    call ata_read_sector

    call print_filetable

    ret

; ==========================
; Load Command
; ==========================


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
    mov esi,commandbuffer
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


align 4
load_address dd 0


; ============================================================
; CLEAR SCREEN
; Clears the VBE framebuffer to black.
; ============================================================

clear_screen:
    push eax
    push ecx
    push edi

    mov edi, [framebuffer]
    xor eax, eax

    ; Total framebuffer bytes = pitch * height
    mov ecx, [pitch]
    imul ecx, [screen_height]

    ; Number of 32-bit words
    shr ecx, 2

    cld
    rep stosd

    pop edi
    pop ecx
    pop eax
    ret


; ============================================================
; NEWLINE
; ============================================================

newline:
    mov dword [buffer], 0
    add ecx, 12
    ret


; ============================================================
; PRINT STRING
;
; Input:
;   ESI = address of null-terminated string
;
; Uses:
;   buffer = X position
;   ECX    = Y position
; ============================================================

print_string:
    push eax
    push ebx
    push edx
    push esi

.next_char:
    lodsb
    test al, al
    jz .done

    cmp al, 10
    je .newline

    cmp al, ' '
    je .space

    ; Convert lowercase to uppercase
    cmp al, 'a'
    jb .lookup
    cmp al, 'z'
    ja .lookup
    sub al, 32

.lookup:
    cmp al, 'A'
    jb .skip
    cmp al, 'Z'
    ja .skip

    ; Save the string pointer after LODSB
    push esi

    movzx eax, al
    sub eax, 'A'
    mov esi, [ascii_letter_table + eax * 4]

    mov ebx, [buffer]
    call draw_sprite_from_si

    ; Restore string pointer
    pop esi

    add dword [buffer], 12
    jmp .next_char

.space:
    add dword [buffer], 12
    jmp .next_char

.newline:
    mov dword [buffer], 0
    add ecx, 12
    jmp .next_char

.skip:
    jmp .next_char

.done:
    pop esi
    pop edx
    pop ebx
    pop eax
    ret


align 4

ascii_letter_table:
    dd A, B, C, D, E, F, G
    dd H, I, J, K, L, M, N
    dd O, P, Q, R, S, T, U
    dd V, W, X, Y, Z