# GO81
Sinclair ZX81 for Commodore 128
* https://www.zimmers.net/anonftp/pub/cbm/c128/programming/d-ass.txt
* https://gist.githubusercontent.com/0xcafed00d/94989b94a1261fe73370bd2af309c8d3/raw/805efa3637c75ada04bb224265cf69629eb97452/zx81%2520rom%2520listing

## Overview
GO81 runs Sinclair ZX81 on the Commodore 128 in native Z80 mode.
The system uses an 8502 bootstrap to configure hardware registers and switch processor control to the Z80 CPU.

## Building with vasm
To build the Z80 binary `zx81.bin` using the vasm Z80 assembler:
```bash
vasmz80_oldstyle -Fbin -o zx81.bin zx81.s
```

## Running the BASIC 7.0 Bootstrap
1. Load `zx81.bin` and `go81` onto your Commodore 128 disk image.
2. In C128 mode (BASIC 7.0):
```basic
DLOAD "GO81"
RUN
```
The bootstrap program sets up screen colors, loads `ZX81.BIN` into Bank 0, configures the Z80 boot-link vector at `$FFEE`, and transfers CPU control to the Z80.
