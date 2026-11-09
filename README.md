# GO81
Sinclair ZX81 for Commodore 128
* https://www.zimmers.net/anonftp/pub/cbm/c128/programming/d-ass.txt
* https://gist.githubusercontent.com/0xcafed00d/94989b94a1261fe73370bd2af309c8d3/raw/805efa3637c75ada04bb224265cf69629eb97452/zx81%2520rom%2520listing

## Overview
GO81 runs Sinclair ZX81 on the Commodore 128 in native Z80 mode.
The system uses an 8502 bootstrap (`go81`) to configure hardware registers, relocate the Z80 binary to `$0000`, and switch processor control to the Z80 CPU.

## Building with vasm
To build the Z80 binary `zx81.bin` using the vasm Z80 assembler:
```bash
vasmz80_oldstyle -Fbin -o zx81.bin zx81.s
```

## Running the BASIC 7.0 Bootstrap
1. Place `zx81.bin` and `go81` onto your Commodore 128 disk image.
2. In C128 mode (BASIC 7.0):
```basic
DLOAD "GO81"
RUN
```

### Bootstrap Architecture & Safe Loading
Loading a binary directly to `$0000` via `BLOAD "ZX81.BIN",B0,P0` will corrupt Page 0 and the 8502 call stack, causing BASIC 7.0 and Kernal routines to crash during load.

To prevent this:
1. `go81` loads `ZX81.BIN` into a safe staging area at `$2000` (`BLOAD "ZX81.BIN",B0,P8192`).
2. An 8502 helper at `$1300` disables interrupts (`SEI`), configures MMU Bank 0 to all-RAM (`$3E`), and copies the binary to `$0000–$1FFF`.
3. The helper sets the Z80 boot-link jump instruction (`JP $0000`) at `$FFEE–$FFF0` and triggers the Z80 by writing `$B0` to mode configuration register `$D505`.
