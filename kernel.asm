bits 32
org 0x8200

start:
    ; --------------------------------
    ; Get video information
    ; --------------------------------
    mov eax, [0x5000]
    mov [framebuffer], eax
    mov eax, [0x5004]
    mov [pitch], eax
    mov eax, [0x5008]
    mov [screen_width], eax
    mov eax, [0x500C]
    mov [screen_height], eax
    mov eax, [0x5010]
    mov [bpp], eax
    ; --------------------------------
    ; Test pixels
    ; --------------------------------
    ; Red
    mov eax, 100
    mov ebx, 100
    mov ecx, 0x00FF0000
    call place_pixel

    ; Green
    mov eax, 200
    mov ebx, 100
    mov ecx, 0x0000FF00
    call place_pixel

    ; Blue
    mov eax, 300
    mov ebx, 100
    mov ecx, 0x000000FF
    call place_pixel

    ;mov ebx, 0
    ;mov ecx, 0
    ;mov esi, A
    ;call draw_sprite_from_si
    xor ecx, ecx
    jmp get_input

get_input:
.wait:
    in al, 0x64
    test al, 1
    jz .wait

    in al, 0x60

    ; Ignore key releases
    test al, 0x80
    jnz get_input

    ; Handle special keys
    cmp al, 0x39
    je .SPACE

    cmp al, 0x1C
    je .ENTER

    cmp al, 0x0E
    je .BACK

    ; Look up character sprite by scan code
    movzx eax, al
    mov esi, [scan_table + eax * 4]

    ; Zero means unsupported key
    test esi, esi
    jz get_input

    jmp .draw
.SPACE:
    mov esi, SPACE
    jmp .draw
.ENTER:
    mov dword [buffer], 0
    add ecx, 12
    jmp get_input

.BACK:
    cmp dword [buffer], 0
    je get_input

    sub dword [buffer], 12

    mov ebx, [buffer]
    mov esi, SPACE
    call draw_sprite_from_si

    jmp get_input

.draw:
    mov ebx, [buffer]
    ; ecx = current Y
    call draw_sprite_from_si

    add dword [buffer], 12

    cmp dword [buffer], 1020
    jl get_input

    ; Wrap to next line
    mov dword [buffer], 0
    add ecx, 12

    jmp get_input

align 4

scan_table:
    dd 0          ; 00: none
    dd 0          ; 01: Escape
    dd n1         ; 02: 1
    dd n2         ; 03: 2
    dd n3         ; 04: 3
    dd n4         ; 05: 4
    dd n5         ; 06: 5
    dd n6         ; 07: 6
    dd n7         ; 08: 7
    dd n8         ; 09: 8
    dd n9         ; 0A: 9
    dd n0         ; 0B: 0
    dd 0          ; 0C: -
    dd 0          ; 0D: =
    dd 0          ; 0E: Backspace
    dd 0          ; 0F: Tab
    dd Q          ; 10: Q
    dd W          ; 11: W
    dd E          ; 12: E
    dd R          ; 13: R
    dd T          ; 14: T
    dd Y          ; 15: Y
    dd U          ; 16: U
    dd I          ; 17: I
    dd O          ; 18: O
    dd P          ; 19: P
    dd 0          ; 1A: [
    dd 0          ; 1B: ]
    dd 0          ; 1C: Enter
    dd 0          ; 1D: Ctrl
    dd A          ; 1E: A
    dd S          ; 1F: S
    dd D          ; 20: D
    dd F          ; 21: F
    dd G          ; 22: G
    dd H          ; 23: H
    dd J          ; 24: J
    dd K          ; 25: K
    dd L          ; 26: L
    dd 0          ; 27: ;
    dd 0          ; 28: '
    dd 0          ; 29: `
    dd 0          ; 2A: Left Shift
    dd 0          ; 2B: backslash
    dd Z          ; 2C: Z
    dd X          ; 2D: X
    dd C          ; 2E: C
    dd V          ; 2F: V
    dd B          ; 30: B
    dd N          ; 31: N
    dd M          ; 32: M
    dd 0          ; 33: ,
    dd 0          ; 34: .
    dd 0          ; 35: /
    dd 0          ; 36: Right Shift
    dd 0          ; 37: Keypad *
    dd 0          ; 38: Alt
    dd SPACE      ; 39: Space






buffer dd 0
command db 0
; ============================================================
; draw_sprite_from_si
;
; ESI = sprite address
; EBX = X
; ECX = Y
;
; Sprite format:
;
; byte 0 = width
; byte 1 = height
;
; Then width * height 32-bit pixels:
;
; 0x00RRGGBB
;
; 0x00000000 = transparent
; ============================================================

draw_sprite_from_si:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    ; --------------------------------
    ; Read width
    ; --------------------------------
    xor eax, eax
    lodsb
    mov edx, eax            ; EDX = width
    ; --------------------------------
    ; Read height
    ; --------------------------------
    xor eax, eax
    lodsb
    mov ebp, eax            ; EBP = height
    ; --------------------------------
    ; Calculate framebuffer position
    ;
    ; framebuffer
    ; + Y * pitch
    ; + X * 4
    ; --------------------------------
    mov edi, [framebuffer]
    mov eax, ecx
    imul eax, [pitch]
    add edi, eax
    mov eax, ebx
    shl eax, 2
    add edi, eax
    ; --------------------------------
    ; Draw rows
    ; --------------------------------
.row_loop:
    push edi                 ; save beginning of row
    mov ecx, edx             ; ECX = width
.col_loop:
    ; Read 32-bit VBE color
    lodsd                    ; EAX = pixel
    ; --------------------------------
    ; Transparent?
    ; --------------------------------
    test eax, eax
    jz .skip_pixel
    ; --------------------------------
    ; Write 32-bit pixel
    ; --------------------------------
    mov [edi], eax

.skip_pixel:
    add edi, 4
    loop .col_loop
    ; --------------------------------
    ; Move to next row
    ; --------------------------------
    pop edi
    add edi, [pitch]
    ; --------------------------------
    ; Next row
    ; --------------------------------
    dec ebp
    jnz .row_loop

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax

    ret

; ============================================================
; place_pixel
; EAX = X
; EBX = Y
; ECX = color
; 32-bit BGR/RGB framebuffer
; ============================================================
place_pixel:
    push eax
    push ebx
    push edx
    push edi
    ; EDI = framebuffer
    mov edi, [framebuffer]
    ; offset = Y * pitch
    mov edx, ebx
    imul edx, [pitch]
    add edi, edx
    ; offset += X * 4
    mov edx, eax
    shl edx, 2
    add edi, edx
    ; Write pixel
    mov [edi], ecx
    pop edi
    pop edx
    pop ebx
    pop eax
    ret



; ===================
; DRIVERS/DATA
; ===================
%include "fonts.asm"
%include "atadrivers.asm"
; ============================================================
; Variables
; ============================================================
framebuffer   dd 0
pitch         dd 0
screen_width  dd 0
screen_height dd 0
bpp           dd 0

