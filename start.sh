nasm -f bin Bootloader.asm -o Bootloader.bin
nasm -f bin Kernel32.asm -o Kernel32.bin
nasm -f bin filetable.asm -o filetable.bin



dd if=/dev/zero of=os.img bs=512 count=2880

dd if=Bootloader.bin of=os.img bs=512 count=1 conv=notrunc
dd if=Kernel32.bin of=os.img bs=512 seek=1 conv=notrunc

dd if=filetable.bin of=os.img bs=512 seek=33 conv=notrunc

qemu-system-i386 -drive format=raw,file=os.img
