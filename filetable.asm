filesystem:

db 'HEFS'

dd 5              ; 5 files

db 'bootloader '
times 5 db 0   ; filename padding

dd 0            ; starting sector
dd 512           ; size bytes
dd 0             ; flags for file types
dd 0             ; reserved parent for folders

db 'stage2 '
times 9 db 0

dd 1
dd 4096
dd 0
dd 0

db 'kernel '
times 9 db 0

dd 9
dd 32768
dd 0
dd 0

db 'filetable '
times 6 db 0

dd 73
dd 512
dd 0
dd 0

db 'program '
times 8 db 0

dd 100
dd 512
dd 0
dd 0

; fill sector
times 512-($-$$) db 0
