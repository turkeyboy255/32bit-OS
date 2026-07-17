org 0x7C00
use16

jmp 0x0000:start ;Some BIOSes would jump to 07C0:0000 which would make CS be 0x07C0.

start:
    cli
    cld
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov bp, 0x7000
    mov ss, ax
    mov sp, bp ;Load SP right after loading SS
    mov [boot_drive], dl
    mov di, 5

;Set video mode 0x03
    mov ax, 0x0003
    int 0x10

enable_a20:
    in al, 0x92
    or al, 0x2
    out 0x92, al
    sti

read_disk:
    mov ah, 0x02
    mov al, 0x20
    mov ch, 0x00
    mov cl, 0x02
    mov dh, 0x00
    mov dl, [boot_drive]
    mov bx, 0x7E00
    int 0x13
    jnc read_successfully

    mov ax, 0 ;Reset Disk
    int 0x13
    dec di
    jnz read_disk
    jmp disk_error

CODE_OFFSET equ gdt_code - gdt_start ;Also a synonym to 0x08
DATA_OFFSET equ gdt_data - gdt_start ;Also a synonym to 0x10

read_successfully:
load_gdt:
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp CODE_OFFSET:start_protected

use32
start_protected:
    mov ax, DATA_OFFSET
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    mov edi, 0xB8000
    mov al, '?'
    mov ah, 0x0F
    mov [edi], ax

    jmp 0x08:0x7E00

align 16
gdt_start:
gdt_null:
    dd 0x0
    dd 0x0
gdt_code:
    dw 0xFFFF
    dw 0
    db 0
    db 10011011b ;Changed "Accessed" bit to 1 to avoid #GP exception
    db 11001111b
    db 0
gdt_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010011b ;Changed "Accessed" bit to 1 to avoid #GP exception
    db 11001111b
    db 0
gdt_end:
gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

disk_error:
    mov ah, 0x0E
    mov al, '!'
    mov bh, 0
    int 0x10

    cli
    hlt
    jmp $-2

boot_drive db 0x00

times 510-($-$$) db 0
dw 0xAA55
