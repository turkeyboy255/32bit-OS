filesystem:

db 'JFS1'

dd 2              ; 2 files


; ----------------
; FILE 1
; ----------------

db 'BOOTLOADER'
times 6 db 0   ; filename padding

dd 0            ; starting sector
dd 512           ; size bytes
dd 0             ; flags
dd 0             ; reserved


; ----------------
; FILE 2
; ----------------

db 'KERNEL'
times 10 db 0

dd 1
dd 16384
dd 0
dd 0


; fill sector
times 512-($-$$) db 0
