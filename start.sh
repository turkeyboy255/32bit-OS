nasm -f bin bootloader.asm -o bootloader.bin
nasm -f bin stage2.asm -o stage2.bin
nasm -f bin kernel.asm -o kernel.bin
nasm -f bin fonts.asm -o fonts.bin

dd if=/dev/zero of=os.img bs=512 count=2880


dd if=bootloader.bin of=os.img bs=512 seek=0 conv=notrunc


dd if=stage2.bin of=os.img bs=512 seek=1 conv=notrunc


dd if=kernel.bin of=os.img bs=512 seek=9 conv=notrunc


dd if=filetable.bin of=os.img bs=512 seek=73 conv=notrunc

qemu-system-i386 -drive format=raw,file=os.img
