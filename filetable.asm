filesystem:

db 'HEFS'

dd 5              ; 5 files

db 'BOOTLOADER '
times 5 db 0   ; filename padding

dd 0            ; starting sector
dd 512           ; size bytes
dd 0             ; flags for file types
dd 0             ; reserved parent for folders

db 'KERNEL '
times 9 db 0

dd 1
dd 16384
dd 0
dd 0

db 'FILETABLE '
times 6 db 0

dd 33
dd 512
dd 0
dd 0

db 'HELLOWORLD '
times 5 db 0

dd 34
dd 512
dd 0
dd 0

db 'SYSCALL '
times 8 db 0

dd 35
dd 1024
dd 0
dd 0

; fill sector
times 512-($-$$) db 0
