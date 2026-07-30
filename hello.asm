org 0x50000
BITS 32

start:
    mov esi, message
    mov edi, 0xB8000

.print:
    lodsb                  ; load next character

    cmp al, 0              ; end of string?
    je .done

    mov ah, 0x0F           ; white text on black
    mov [edi], ax

    add edi, 2             ; next VGA character
    jmp .print

.done:
    ret


message:
    db 'HELLO WORLD FROM HEFS!',0
times 512-($-$$) db 0
