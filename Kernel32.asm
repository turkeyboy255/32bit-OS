org 0x7E00
BITS 32

start:
    call get_inp
    
get_inp:
    in al, 0x64
    test al, 1
    jz get_inp
    in al, 0x60
    cmp al, 0x10
    je .Q_key
    cmp al, 0x11
    je .W_key
    cmp al, 0x12
    je .E_key
    cmp al, 0x13
    je .R_key
    cmp al, 0x14
    je .T_key
    cmp al, 0x15
    je .Y_key
    cmp al, 0x16
    je .U_key
    cmp al, 0x17
    je .I_key
    cmp al, 0x18
    je .O_key
    cmp al, 0x19
    je .P_key
    cmp al, 0x1E
    je .A_key
    cmp al, 0x1F
    je .S_key
    cmp al, 0x20
    je .D_key
    cmp al, 0x21
    je .F_key
    cmp al, 0x22
    je .G_key
    cmp al, 0x23
    je .H_key
    cmp al, 0x24
    je .J_key
    cmp al, 0x25
    je .K_key
    cmp al, 0x26
    je .L_key
    cmp al, 0x2C
    je .Z_key
    cmp al, 0x2D
    je .X_key
    cmp al, 0x2E
    je .C_key
    cmp al, 0x2F
    je .V_key
    cmp al, 0x30
    je .B_key
    cmp al, 0x31
    je .N_key
    cmp al, 0x32
    je .M_key
    cmp al, 0x0E
    je .backspace
    cmp al, 0x39
    je .spacebar
    jmp get_inp

.Q_key:
    mov al, 'Q'
    jmp print_char
.W_key:
    mov al, 'W'
    jmp print_char
.E_key:
    mov al, 'E'
    jmp print_char
.R_key:
    mov al, 'R'
    jmp print_char
.T_key:
    mov al, 'T'
    jmp print_char
.Y_key:
    mov al, 'Y'
    jmp print_char
.U_key:
    mov al, 'U'
    jmp print_char
.I_key:
    mov al, 'I'
    jmp print_char
    ret
.O_key:
    mov al, 'O'
    jmp print_char
.P_key:
    mov al, 'P'
    jmp print_char
.A_key:
    mov al, 'A'
    jmp print_char
.S_key:
    mov al, 'S'
    jmp print_char
.D_key:
    mov al, 'D'
    jmp print_char
.F_key:
    mov al, 'F'
    jmp print_char
.G_key:
    mov al, 'G'
    jmp print_char
.H_key:
    mov al, 'H'
    jmp print_char
.J_key:
    mov al, 'J'
    jmp print_char
.K_key:
    mov al, 'K'
    jmp print_char
.L_key:
    mov al, 'L'
    jmp print_char
.Z_key:
    mov al, 'Z'
    jmp print_char
.X_key:
    mov al, 'X'
    jmp print_char
.C_key:
    mov al, 'C'
    jmp print_char
.V_key:
    mov al, 'V'
    jmp print_char
.B_key:
    mov al, 'B'
    jmp print_char
.N_key:
    mov al, 'N'
    jmp print_char
.M_key:
    mov al, 'M'
    jmp print_char

.backspace:
    mov edi, [cursor]
    sub dword [cursor], 2
    mov al, ' '
    mov ah, 0x0F
    mov [edi], ax

    ret
.spacebar
    mov al, ' '
    jmp print_char
    

print_char:
    mov edi, [cursor]   ; VGA memory start
    mov ah, 0x0F       ; white on black
    mov [edi], ax      ; write character + color
    add dword [cursor], 2
    ret


cursor dd 0xB8000
