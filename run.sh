set -e

FILE="dino"

echo "[+] Assembling..."
nasm -f elf32 $FILE.asm -o $FILE.o

echo "[+] Linking..."
ld -m elf_i386 $FILE.o -o $FILE

echo "[+] Running..."
./$FILE
