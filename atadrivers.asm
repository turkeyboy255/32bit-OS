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
    mov esi,'e'
    call draw_sprite_from_si
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
