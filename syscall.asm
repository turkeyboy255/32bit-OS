org 0x30000
bits 32

start:
    mov eax, 1
    mov ebx, 'H'
    int 0x80

ret
