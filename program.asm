bits 32
org 0x30000

%include "libraries/testlib.asm"

start:
    call test_function

.hang:
    jmp .hang