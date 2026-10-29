all: zx81.bin bootstrap.prg

zx81.bin: zx81-c128.z80 asm.py
	python3 asm.py zx81-c128.z80 zx81.bin zx81.lst

bootstrap.prg: bootstrap.s zx81.bin
	vasm6502_oldstyle -Fbin -o bootstrap.tmp bootstrap.s
	# Prepend load address $2000 (little-endian) for PRG format
	python3 -c "import sys; sys.stdout.buffer.write(b'\x00\x20' + open('bootstrap.tmp','rb').read())" > $@
	rm -f bootstrap.tmp

run: bootstrap.prg
	x128 -autostart bootstrap.prg -warp -limitcycles 100000000 -40col -exitscreenshotvicii /tmp/go81_shot.png

clean:
	rm -f zx81.bin zx81.lst bootstrap.prg bootstrap.tmp
