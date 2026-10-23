bits 16
org 0x7E00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax

    ; --------------------------------
    ; Save boot drive
    ; --------------------------------
    mov [boot_drive], dl
    ; --------------------------------
    ; Set VBE mode
    ;
    ; 0x144 = 1024x768x32
    ; 0x4000 = linear framebuffer
    ; --------------------------------
    mov ax, 0x4F02
    mov bx, 0x4144
    int 0x10

    cmp ax, 0x004F
    jne vbe_error
    ; --------------------------------
    ; Get VBE mode information
    ;
    ; ES:DI -> 512-byte buffer
    ; --------------------------------
    xor ax, ax
    mov es, ax

    mov ax, 0x4F01
    mov cx, 0x144
    mov di, 0x9000

    int 0x10

    cmp ax, 0x004F
    jne vbe_error

    ; --------------------------------
    ; Read pitch
    ;
    ; ModeInfoBlock + 0x10
    ; --------------------------------
    movzx eax, word [0x9010]
    mov [pitch], eax

    ; --------------------------------
    ; Read framebuffer address
    ;
    ; ModeInfoBlock + 0x28
    ; --------------------------------
    mov eax, [0x9028]
    mov [framebuffer], eax

    ; --------------------------------
    ; Read actual resolution
    ; --------------------------------
    movzx eax, word [0x9012]
    mov [screen_width], eax

    movzx eax, word [0x9014]
    mov [screen_height], eax


    ; --------------------------------
    ; Read bits per pixel
    ; --------------------------------
    movzx eax, byte [0x9019]
    mov [bpp], eax


    ; --------------------------------
    ; Read color layout
    ; --------------------------------

    ; Red mask size
    movzx eax, byte [0x901B]
    mov [red_mask], eax

    ; Red field position
    movzx eax, byte [0x901C]
    mov [red_position], eax

    ; Green mask size
    movzx eax, byte [0x901D]
    mov [green_mask], eax

    ; Green field position
    movzx eax, byte [0x901E]
    mov [green_position], eax

    ; Blue mask size
    movzx eax, byte [0x901F]
    mov [blue_mask], eax

    ; Blue field position
    movzx eax, byte [0x9020]
    mov [blue_position], eax


    ; --------------------------------
    ; Load kernel
    ; --------------------------------

    mov ah, 0x02
    mov al, KERNEL_SECTORS

    mov ch, 0
    mov cl, KERNEL_START_SECTOR
    mov dh, 0
    mov dl, [boot_drive]

    mov bx, KERNEL_LOAD

    int 0x13

    jc disk_error


    ; --------------------------------
    ; Enter protected mode
    ; --------------------------------

    cli

    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp CODE_SEG:protected_mode


; ============================================================
; Protected mode
; ============================================================

bits 32

protected_mode:

    mov ax, DATA_SEG

    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, 0x90000


    ; --------------------------------
    ; Pass video information to kernel
    ; --------------------------------

    mov eax, [framebuffer]
    mov [0x5000], eax

    mov eax, [pitch]
    mov [0x5004], eax

    mov eax, [screen_width]
    mov [0x5008], eax

    mov eax, [screen_height]
    mov [0x500C], eax

    mov eax, [bpp]
    mov [0x5010], eax


    ; --------------------------------
    ; Color information
    ; --------------------------------

    mov eax, [red_mask]
    mov [0x5014], eax

    mov eax, [red_position]
    mov [0x5018], eax

    mov eax, [green_mask]
    mov [0x501C], eax

    mov eax, [green_position]
    mov [0x5020], eax

    mov eax, [blue_mask]
    mov [0x5024], eax

    mov eax, [blue_position]
    mov [0x5028], eax


    ; --------------------------------
    ; Jump to kernel
    ; --------------------------------

    jmp KERNEL_LOAD


; ============================================================
; GDT
; ============================================================

gdt_start:

gdt_null:
    dq 0

gdt_code:
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 11001111b
    db 0

gdt_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0

gdt_end:


gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start


CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start


; ============================================================
; Variables
; ============================================================

boot_drive db 0

framebuffer dd 0
pitch       dd 0

screen_width  dd 0
screen_height dd 0
bpp           dd 0

red_mask       dd 0
red_position   dd 0

green_mask     dd 0
green_position dd 0

blue_mask      dd 0
blue_position  dd 0


; ============================================================
; Error messages
; ============================================================

vbe_error_msg db "VBE error", 0
disk_error_msg db "Disk error", 0


; ============================================================
; Error handlers
; ============================================================

bits 16

vbe_error:

    mov si, vbe_error_msg

.vbe_print:
    lodsb
    or al, al
    jz .hang

    mov ah, 0x0E
    int 0x10

    jmp .vbe_print

.hang:
    cli
    hlt
    jmp .hang


disk_error:

    mov si, disk_error_msg

.disk_print:
    lodsb
    or al, al
    jz .hang

    mov ah, 0x0E
    int 0x10

    jmp .disk_print
.hang:
    cli
    hlt
    jmp .hang


; ============================================================
; Constants
; ============================================================

KERNEL_LOAD         equ 0x8200
KERNEL_START_SECTOR equ 10
KERNEL_SECTORS      equ 64


; Stage 2 is 8 sectors
times 4096 - ($ - $$) db 0
