; ===========================================================
; GO81 - Full ZX81 ROM Port for Commodore 128 (Z80 Mode)
; ===========================================================
; Runs on C128's Z80 via 8502 bootstrap.
; Memory: $0000 vectors, $0100+ code, $4000 sysvars,
;         $4200 BASIC, $5000 display, $8000 VIC screen,
;         $D000 I/O

    org 0x0000

; ===== Z80 RESTART VECTORS =====
START_VEC:
    DI
    LD SP,0xFFFE
    JP INIT_C128

    org 0x0008
ERROR_1_VEC:
    JP ERROR_1
    org 0x0010
PRINT_A_VEC:
    JP PRINT_A
    org 0x0018
GET_CHAR_VEC:
    JP GET_CHAR
    org 0x0020
NEXT_CHAR_VEC:
    JP NEXT_CHAR
    org 0x0028
FP_CALC_VEC:
    JP FP_CALC
    org 0x0030
BC_SPACES_VEC:
    JP BC_SPACES
    org 0x0038
IRQ_VEC:
    JP IRQ_HANDLER

; ===== CONSTANTS =====
ZX_ROWS equ 24
ZX_COLS equ 32

; System variables at $4000
ERR_NR equ 0x4000
FLAGS equ 0x4001
ERR_SP equ 0x4002
RAMTOP equ 0x4004
E_LINE equ 0x4006
CH_ADD equ 0x4008
X_PTR equ 0x400A
D_FILE equ 0x400C
DF_CC equ 0x400E
VARS equ 0x4010
DEST equ 0x4012
E_LINE_LO equ 0x4014
SPARE1 equ 0x4016
SPARE2 equ 0x4018
LAST_K equ 0x4025
DEBOUNCE equ 0x4027
MARGIN equ 0x4028
FRAMES equ 0x4034
CDFLAG equ 0x403B

; Character codes
ZX_NL equ 0x76
ZX_CRSR equ 0x7F
ZX_SP equ 0x00

; Token values
TK_NEW equ 0xE6
TK_SCROLL equ 0xE7
TK_CONT equ 0xE8
TK_DIM equ 0xE9
TK_REM equ 0xEA
TK_FOR equ 0xEB
TK_GOTO equ 0xEC
TK_GOSUB equ 0xED
TK_INPUT equ 0xEE
TK_LOAD equ 0xEF
TK_LIST equ 0xF0
TK_LET equ 0xF1
TK_PAUSE equ 0xF2
TK_NEXT equ 0xF3
TK_POKE equ 0xF4
TK_PRINT equ 0xF5
TK_PLOT equ 0xF6
TK_RUN equ 0xF7
TK_SAVE equ 0xF8
TK_RAND equ 0xF9
TK_IF equ 0xFA
TK_CLS equ 0xFB
TK_UNPLOT equ 0xFC
TK_CLEAR equ 0xFD
TK_RETURN equ 0xFE
TK_COPY equ 0xFF
TK_STOP equ 0xE3
TK_THEN equ 0xDE
TK_TO equ 0xDF
TK_STEP equ 0xE0
TK_PEEK equ 0xD3
TK_USR equ 0xD4

; ===== RESTART HANDLERS =====
    org 0x0080

ERROR_1:
    LD HL,(CH_ADD)
    LD (X_PTR),HL
ERROR_2:
    POP HL
    LD L,(HL)
    LD (IY+0),L
    LD SP,(ERR_SP)
    JP MAIN_LOOP

PRINT_A:
    AND A
    JP NZ,PRINT_CH
    JP PRINT_SP

GET_CHAR:
    LD HL,(CH_ADD)
    LD A,(HL)
TEST_SP:
    AND A
    RET NZ
    NOP
    NOP

NEXT_CHAR:
    CALL CH_ADD_INC
    JR TEST_SP

CH_ADD_INC:
    LD HL,(CH_ADD)
    INC HL
    LD (CH_ADD),HL
    LD A,(HL)
    CP ZX_CRSR
    RET NZ
    JR CH_ADD_INC

FP_CALC:
    JP CALCULATE
END_CALC:
    POP AF
    EXX
    EX (SP),HL
    EXX
    RET

BC_SPACES:
    PUSH BC
    LD HL,(E_LINE)
    PUSH HL
    JP RESERVE

IRQ_HANDLER:
    RETI

; ===== C128 INITIALIZATION =====
INIT_C128:
    LD IY,0x4000
    LD A,0x3E
    LD BC,0xFF00
    OUT (C),A
    LD A,0x0B ; VIC ctrl1: text mode (bit5=0), video on
    LD BC,0xD011
    OUT (C),A
    LD A,0xC0 ; 40 cols, no multicolor
    LD BC,0xD016
    OUT (C),A
    LD A,0x10 ; VIC: screen $0000 bank, chargen $1000 bank
    LD BC,0xD018
    OUT (C),A
    LD A,0x00
    LD BC,0xD020
    OUT (C),A ; black border
    LD A,0x01
    LD BC,0xD021
    OUT (C),A ; white background

; Select VIC bank 2 ($8000-$BFFF) — screen at $8000, chargen at $9000
    LD BC,0xDD00
    IN A,(C)
    AND 0xFC
    OR 0x01
    OUT (C),A

; Copy font to VIC chargen RAM at $9000 (bank 2, offset $1000)
    LD HL,0x0800
    LD DE,0x9000
    LD BC,0x0200
    LDIR

; Color RAM was filled by 8502 bootstrap

; Init sysvars
    LD HL,0x5000
    LD (D_FILE),HL
    LD HL,0x4200
    LD (VARS),HL
    LD HL,E_LINE_BUF
    LD (E_LINE),HL
    LD (E_LINE_LO),HL
    LD HL,MAIN_LOOP
    LD (ERR_SP),HL

; Clear display file
    LD HL,0x5000
    LD DE,0x5001
    LD BC,ZX_ROWS*(ZX_COLS+1)+1
    LD (HL),ZX_NL
    LDIR

; Init program area (empty)
    LD HL,0x4200
    LD (HL),0x00
    INC HL
    LD (HL),0x00

; Set IY for sysvar access
    LD IY,0x4000

; Show welcome
    LD HL,WELCOME_MSG
    CALL PRINT_STRING

    JP MAIN_LOOP

WELCOME_MSG:
    DB "ZX81 ON C128 (GO81)",ZX_NL
    DB "Z80 MODE V0.1",ZX_NL
    DB ZX_NL
    DB "READY.",ZX_NL
    DB 0

PRINT_STRING:
    LD A,(HL)
    AND A
    RET Z
    CP ZX_NL
    JR Z,PS_NL
    PUSH HL
    LD HL,(DF_CC)
    LD (HL),A
    INC HL
    LD (DF_CC),HL
    POP HL
    INC HL
    JR PRINT_STRING
PS_NL:
    INC HL
    CALL DO_NEWLINE
    JR PRINT_STRING

DO_NEWLINE:
    PUSH HL
    LD HL,(DF_CC)
DN_LP:
    LD A,(HL)
    CP ZX_NL
    JR Z,DN_FOUND
    INC HL
    JR DN_LP
DN_FOUND:
    INC HL
    LD (DF_CC),HL
    POP HL
    RET

; ===== KEYBOARD MAPPING =====
; C128 CIA1 matrix: rows 0-7, cols 0-7
; Maps to ZX81 keyboard. ZX81 layout:
;   Row0: 1 2 3 4 5 6 7 8 9 0
;   Row1: Q W E R T Y U I O P
;   Row2: A S D F G H J K L NL
;   Row3: SHIFT Z X C V B N M . SPACE
; We remap C128 physical layout to ZX81 key codes.

KEYBOARD:
    LD HL,0xFFFF
    LD B,0x08
KB_ROW:
    LD A,B
    DEC A
    LD BC,0xDC00
    OUT (C),A
    NOP
    NOP
    IN A,(C)
    CPL
    AND 0xFF
    JR Z,KB_NEXT
    LD C,A
    LD E,0x00
KB_COL:
    SRL C
    JR C,KB_FOUND
    INC E
    JR KB_COL
KB_FOUND: ; B=row+1 (1-8), E=column (0-7)
    PUSH BC
    PUSH DE
    CALL KEY_MAP
    POP DE
    POP BC
    LD H,B
    LD L,A
KB_NEXT:
    DJNZ KB_ROW
    RET

; Map C128 matrix position to ZX81 character code
; Input: B=row+1, E=col
; Output: A=ZX81 code
KEY_MAP:
    LD HL,KMTAB
    LD A,B
    DEC A
    RLCA
    RLCA
    RLCA
    ADD A,E
    LD C,A
    LD B,0
    ADD HL,BC
    LD A,(HL)
    RET

KMTAB: ; Row 1 (CIA0): INSERT/DEL/HOME etc -> cursor keys
    DB 0x70,0x71,0x72,0x77,0x75,0x00,0x79,0x00 ; up,down,left,del,edit,func
; Row 2 (CIA1): RETURN, SHIFT etc
    DB ZX_NL,0x00,0x00,0x00,0x00,0x00,0x00,0x00
; Row 3 (CIA2): SPACE, numbers
    DB 0x00,0x1D,0x1E,0x1F,0x20,0x21,0x22,0x23 ; space,1,2,3,4,5,6
; Row 4 (CIA3): more numbers
    DB 0x24,0x25,0x1C,0x0E,0x19,0x0B,0x00,0x00 ; 8,9,0,:,;,"
; Row 5 (CIA4): Q-P
    DB 0x36,0x3C,0x2A,0x37,0x39,0x3E,0x3A,0x2E ; Q,W,E,R,T,Y,U,I
; Row 6 (CIA5): A-L
    DB 0x26,0x38,0x29,0x2B,0x2C,0x2D,0x2F,0x30 ; A,S,D,F,G,H,J,K
; Row 7 (CIA6): Z-M
    DB 0x3F,0x3D,0x28,0x3B,0x27,0x32,0x00,0x00 ; Z,X,C,V,B,M
; Row 8 (CIA7): cursor keys / C128 specials
    DB 0x70,0x71,0x72,0x00,0x00,0x00,0x00,0x00 ; up,down,left

; ===== MAIN LOOP =====
MAIN_LOOP:
    CALL UPDATE_DISPLAY
    XOR A
    LD (LAST_K),A
    CALL KEYBOARD
    LD A,H
    AND A
    JR Z,ML_IDLE
    LD A,L
    CALL EDITOR

ML_IDLE:
    LD A,(FLAGS)
    AND 0x20
    JR NZ,ML_RUNPROG
    JR MAIN_LOOP
ML_RUNPROG:
    CALL RUN_PROG
    JR MAIN_LOOP

; ===== LINE EDITOR =====
EDITOR:
    CP ZX_NL
    JR Z,ED_ENTER
    CP 0x77 ; delete
    JR Z,ED_DEL
    CP 0x70 ; cursor up
    RET Z
    CP 0x71 ; cursor down
    RET Z
    CP 0x72 ; cursor left
    RET Z
; Regular char
    PUSH AF
    CALL EL_ADD
    POP AF
    RET

ED_ENTER:
    CALL PROCESS
    RET
ED_DEL:
    CALL EL_DEL
    RET

EL_ADD:
    PUSH AF
    LD HL,(E_LINE)
EA_LP:
    LD A,(HL)
    CP ZX_NL
    JR Z,EA_PUT
    CP 0x00
    JR Z,EA_PUT
    INC HL
    JR EA_LP
EA_PUT:
    POP AF
    LD (HL),A
    INC HL
    LD (HL),ZX_NL
    RET

EL_DEL:
    LD HL,(E_LINE)
    LD DE,E_LINE_BUF
    OR A
    SBC HL,DE
    RET Z
    LD HL,(E_LINE)
ED_LP:
    LD A,(HL)
    CP ZX_NL
    JR Z,ED_BACK
    INC HL
    JR ED_LP
ED_BACK:
    DEC HL
    LD (HL),ZX_NL
    RET

; ===== PROCESS BASIC LINE =====
PROCESS:
    LD HL,E_LINE_BUF
    LD A,(HL)
    CP ZX_NL
    RET Z
    CP ZX_SP
    JR Z,PR_DIRECT
    CP TK_PRINT
    JR Z,PR_DIRECT
    CP TK_LIST
    JR Z,PR_DIRECT
    CP TK_RUN
    JR Z,PR_DIRECT
    CP TK_CLS
    JR Z,PR_DIRECT
    CP TK_REM
    JR Z,PR_DIRECT
    CP TK_LET
    JR Z,PR_DIRECT

; Check for line number (digit 1-9)
    CP 0x1D ; '1'
    JR C,PR_DIRECT
    CP 0x26 ; '9'+1
    JR C,PR_NUMBER

PR_DIRECT: ; Immediate command
    LD HL,E_LINE_BUF
    LD (CH_ADD),HL
    CALL SCAN_LINE
    RET

PR_NUMBER: ; Line with number -> insert into program
; Skip number (simplified - for now treat as comment)
    RET

; ===== SCAN AND EXECUTE BASIC LINE =====
SCAN_LINE:
    LD HL,(CH_ADD)
    LD A,(HL)
    CP ZX_NL
    RET Z
    CP 0x00
    RET Z

; Check command
    CP TK_REM
    JR Z,SL_REM
    CP TK_PRINT
    JR Z,SL_PRINT
    CP TK_LET
    JR Z,SL_LET
    CP TK_GOTO
    JR Z,SL_GOTO
    CP TK_GOSUB
    JR Z,SL_GOSUB
    CP TK_RETURN
    JR Z,SL_RETURN
    CP TK_IF
    JR Z,SL_IF
    CP TK_FOR
    JR Z,SL_FOR
    CP TK_NEXT
    JR Z,SL_NEXT
    CP TK_INPUT
    JR Z,SL_INPUT
    CP TK_LIST
    JR Z,SL_LIST
    CP TK_RUN
    JR Z,SL_RUN
    CP TK_CLS
    JR Z,SL_CLS
    CP TK_CLEAR
    JR Z,SL_CLEAR
    CP TK_POKE
    JR Z,SL_POKE
    CP TK_PAUSE
    JR Z,SL_PAUSE
    CP TK_STOP
    JR Z,SL_STOP
    CP TK_NEW
    JR Z,SL_NEW
    CP TK_RAND
    JR Z,SL_RAND
    CP TK_PLOT
    JR Z,SL_PLOT
    CP TK_UNPLOT
    JR Z,SL_UNPLOT
    CP TK_LOAD
    JR Z,SL_LOAD
    CP TK_SAVE
    JR Z,SL_SAVE

; If not a command, try as LET (variable assignment)
    JR SL_LET

SL_REM:
    CALL SKIP_EOL
    RET
SL_PRINT:
    CALL CMD_PRINT
    RET
SL_LET:
    CALL CMD_LET
    RET
SL_GOTO:
    CALL CMD_GOTO
    RET
SL_GOSUB:
    CALL CMD_GOSUB
    RET
SL_RETURN:
    CALL CMD_RETURN
    RET
SL_IF:
    CALL CMD_IF
    RET
SL_FOR:
    CALL CMD_FOR
    RET
SL_NEXT:
    CALL CMD_NEXT
    RET
SL_INPUT:
    CALL CMD_INPUT
    RET
SL_LIST:
    CALL CMD_LIST
    RET
SL_RUN:
    CALL CMD_RUN
    RET
SL_CLS:
    CALL CMD_CLS
    RET
SL_CLEAR:
    CALL CMD_CLEAR
    RET
SL_POKE:
    CALL CMD_POKE
    RET
SL_PAUSE:
    CALL CMD_PAUSE
    RET
SL_STOP:
    CALL CMD_STOP
    RET
SL_NEW:
    CALL CMD_NEW
    RET
SL_RAND:
    CALL CMD_RAND
    RET
SL_PLOT:
    CALL CMD_PLOT
    RET
SL_UNPLOT:
    CALL CMD_UNPLOT
    RET
SL_LOAD:
    CALL CMD_LOAD
    RET
SL_SAVE:
    CALL CMD_SAVE
    RET

SKIP_EOL:
    LD HL,(CH_ADD)
SE_LP:
    LD A,(HL)
    CP ZX_NL
    RET Z
    CP 0x00
    RET Z
    INC HL
    LD (CH_ADD),HL
    JR SE_LP

; ===== EXPRESSION SCANNER =====
; Returns value on FP stack (5 bytes)
; String results set bit 3 of FLAGS

SCANNING:
    LD HL,(CH_ADD)
; Skip spaces
SC_SKIP:
    LD A,(HL)
    AND A
    JR NZ,SC_NS
    INC HL
    JR SC_SKIP
SC_NS:
    LD (CH_ADD),HL

; Check for number
    CP 0x1C ; '0'
    JR C,SC_NOTNUM
    CP 0x26 ; '9'+1
    JR C,SC_NUM

SC_NOTNUM:
    CP 0x0B ; '"' -> string
    JR Z,SC_STRING
    CP TK_PEEK
    JR Z,SC_PEEK
    CP TK_USR
    JR Z,SC_USR
; Check for variable name (A-Z)
    CP 0x26 ; 'A'
    JR C,SC_SYNTAX
    CP 0x40 ; 'Z'+1
    JR C,SC_VAR
SC_SYNTAX:
; Push zero as default
    CALL STK_ZERO
    RET

SC_NUM: ; Parse decimal number
    CALL DEC_TO_FP
    RET

SC_STRING: ; Parse string literal
    INC HL
    LD DE,FP_STRBUF
    LD B,0
SC_STRLP:
    LD A,(HL)
    CP ZX_NL
    JR Z,SC_STREND
    CP 0x0B ; closing quote
    JR Z,SC_STREND
    CP 0x00
    JR Z,SC_STREND
    LD (DE),A
    INC HL
    INC DE
    INC B
    JR SC_STRLP
SC_STREND:
    INC HL
    LD (CH_ADD),HL
    LD (FP_STRLN),BC
; Set string flag
    LD HL,FLAGS
    RES 3,(HL) ; not numeric
    RET

SC_PEEK:
    INC HL
    LD (CH_ADD),HL
    CALL SCANNING
    CALL FP_TO_BC
    LD H,B
    LD L,C
    LD A,(HL)
    CALL STACK_A
    RET

SC_USR:
    INC HL
    LD (CH_ADD),HL
    CALL SCANNING
; For now, return 0
    CALL STK_ZERO
    RET

SC_VAR: ; Single letter variable
    LD C,A
    LD B,0
    PUSH BC
    INC HL
    LD (CH_ADD),HL
    CALL LOOK_VAR
    POP BC
    RET

; ===== VARIABLE LOOKUP =====
LOOK_VAR: ; C = variable name (letter code)
; Returns value on FP stack
    LD HL,(VARS)
LV_LOOP:
    LD A,(HL)
    CP 0x00
    JR Z,LV_NEW
    CP C
    JR Z,LV_FOUND
; Skip to next variable (5 bytes FP + 1 letter)
    LD A,(HL)
    AND 0x3F
    CP 0x20 ; string variable?
    JR NZ,LV_SKIP_FP
    INC HL ; skip past string
    INC HL
LV_SKIP_FP:
    INC HL
    INC HL
    INC HL
    INC HL
    INC HL
    JR LV_LOOP

LV_NEW: ; Create variable with value 0
    LD A,C
    LD (HL),A
    INC HL
    CALL STK_ZERO
; Copy 5 bytes to variable area
    LD DE,FP_VALUE
    LD B,5
LV_COPY:
    LD A,(DE)
    LD (HL),A
    INC HL
    INC DE
    DJNZ LV_COPY
    LD (HL),0
    RET

LV_FOUND: ; Load value from variable
    INC HL
    LD DE,FP_VALUE
    LD B,5
LV_LOAD:
    LD A,(HL)
    LD (DE),A
    INC HL
    INC DE
    DJNZ LV_LOAD
    RET

; ===== DECIMAL TO FP =====
DEC_TO_FP:
    CALL STK_ZERO
    LD HL,(CH_ADD)
DTF_LP:
    LD A,(HL)
    CP 0x1C ; '0'
    JR C,DTF_DONE
    CP 0x26 ; '9'+1
    JR NC,DTF_DONE
    SUB 0x1C ; digit value
    PUSH AF
; Multiply FP value by 10
    CALL STK_TEN
    CALL FP_MULT
    POP AF
    CALL STACK_A
    CALL FP_ADD
    INC HL
    JR DTF_LP
DTF_DONE:
    LD (CH_ADD),HL
    RET

; ===== FLOATING POINT STACK =====
; 5 bytes per value: 1 exp + 4 mantissa (ZX81 format)
; exp = $80+value, mantissa = 32-bit normalized

STK_ZERO:
    XOR A
STK_A:
    LD HL,FP_VALUE
    LD (HL),A
    INC HL
    LD (HL),0x00
    INC HL
    LD (HL),0x00
    INC HL
    LD (HL),0x00
    INC HL
    LD (HL),0x00
    RET

STACK_A: ; Stack single byte A as integer
    LD C,A
    LD B,0
STACK_BC: ; Fall through

STK_BC: ; Stack BC as integer
    LD A,0x81
    LD (FP_EXP),A
    LD A,B
    LD (FP_HIGH),A
    LD A,C
    LD (FP_LOW+0),A
    XOR A
    LD (FP_LOW+1),A
    LD (FP_LOW+2),A
    CALL FP_NORM
    RET

STK_TEN: ; Load constant 10 into FP
    LD HL,FP_TEN
    LD DE,FP_VALUE
    LD BC,5
    LDIR
    RET

FP_TEN:
    DB 0x84,0x20,0x00,0x00,0x00

STK_ONE:
    LD HL,FP_ONE
    LD DE,FP_VALUE
    LD BC,5
    LDIR
    RET

FP_ONE:
    DB 0x81,0x00,0x00,0x00,0x00

; ===== FP TO INTEGER =====
FP_TO_BC: ; Convert FP to BC (truncated)
    LD HL,FP_VALUE
    LD A,(HL) ; exponent
    SUB 0x81
    JR C,FPBC_ZERO ; < 1 -> 0
    CP 0x10
    JR NC,FPBC_BIG ; too big
; Shift mantissa right
    INC HL
    LD B,(HL)
    INC HL
    LD C,(HL)
    INC HL
    LD D,(HL)
    INC HL
    LD E,(HL)
; Shift left by A bits
    AND 0xFF
    JR Z,FPBC_DONE
FPBC_SH:
    SLA B
    RL C
    RL D
    RL E
    DEC A
    JR NZ,FPBC_SH
FPBC_DONE:
    LD A,B
    LD C,B
    LD B,0x00
    RET
FPBC_ZERO:
    LD BC,0x0000
    RET
FPBC_BIG:
    LD BC,0xFFFF
    RET

FP_NORM: ; Normalize FP value
    LD HL,FP_VALUE
    LD A,(HL) ; exp
    CP 0x00
    RET Z ; zero
    INC HL
    LD B,(HL)
    LD C,0x00
FN_LP:
    LD A,B
    AND 0x80
    JR NZ,FN_DONE
    SLA B
    RL C
    INC HL
    RL (HL)
    DEC HL
    DEC A ; dec exp
    LD (FP_VALUE),A
    JR FN_LP
FN_DONE:
    RET

; ===== FP ARITHMETIC (stubs -> placeholder) =====
FP_ADD:
    RET
FP_MULT:
    RET

CALCULATE: ; FP calculator - processes bytecode stream
; For now, just returns
    RET

; ===== PRINT NUMBER =====
PRINT_NUM: ; Convert FP to decimal string and print
    CALL FP_TO_BC
    LD HL,FP_DECBUF
    LD DE,10000
    CALL PN_DIGIT
    LD DE,1000
    CALL PN_DIGIT
    LD DE,100
    CALL PN_DIGIT
    LD DE,10
    CALL PN_DIGIT
    LD A,C
    ADD A,0x1C ; to ZX81 digit
    LD (HL),A
    INC HL
    LD (HL),0

; Print buffer
    LD HL,FP_DECBUF
PN_LP:
    LD A,(HL)
    AND A
    RET Z
    PUSH HL
    CALL PRINT_CH
    POP HL
    INC HL
    JR PN_LP

PN_DIGIT:
    LD A,0x1C-1 ; '0'-1
PD_LP:
    INC A
    OR A
    SBC HL,DE
    JR NC,PD_LP
    ADD HL,DE
    LD (BC),A
    RET

; ===== COMMAND: PRINT =====
CMD_PRINT:
    LD HL,(CH_ADD)
    INC HL ; skip PRINT token
    LD (CH_ADD),HL

CP_LOOP:
    LD HL,(CH_ADD)
    LD A,(HL)
    CP ZX_NL
    JR Z,CP_NL
    CP 0x00
    JR Z,CP_END
    CP 0x14 ; comma
    JR Z,CP_COMMA
    CP 0x0D ; ';' (actually $0D in ZX81)
    JR Z,CP_SEMI

; Evaluate expression
    CALL SCANNING

; Check if numeric or string
    LD A,(FLAGS)
    AND 0x08 ; numeric flag
    JR NZ,CP_NUM

; Print string
    LD HL,FP_STRLN
    LD C,(HL)
    LD HL,FP_STRBUF
CP_STRLP:
    LD A,C
    AND A
    JR Z,CP_LOOP
    LD A,(HL)
    PUSH HL
    PUSH BC
    CALL PRINT_CH
    POP BC
    POP HL
    INC HL
    DEC C
    JR CP_STRLP

CP_NUM:
    CALL PRINT_NUM
    JR CP_LOOP

CP_COMMA: ; Tab to next column
    INC HL
    LD (CH_ADD),HL
    LD A,0x00 ; space
    CALL PRINT_CH
    CALL PRINT_CH
    JR CP_LOOP

CP_SEMI:
    INC HL
    LD (CH_ADD),HL
    JR CP_LOOP

CP_NL: ; Print newline and end
    CALL DO_NEWLINE
    INC HL
    LD (CH_ADD),HL
CP_END:
    RET

; ===== COMMAND: LET =====
CMD_LET:
    LD HL,(CH_ADD)
    INC HL ; skip LET token
    LD (CH_ADD),HL

; Expect variable letter
    LD HL,(CH_ADD)
    LD A,(HL)
    CP 0x26 ; 'A'
    RET C
    CP 0x40 ; 'Z'+1
    RET NC

    PUSH AF ; save var letter
    INC HL
    LD (CH_ADD),HL

; Expect '=' sign (token $14 in ZX81 or $1B)
    LD HL,(CH_ADD)
    LD A,(HL)
    CP 0x1B ; '.'
    JR Z,CL_EQ
    CP 0x14 ; '='
    JR Z,CL_EQ
    POP AF
    RET

CL_EQ:
    INC HL
    LD (CH_ADD),HL

; Evaluate expression
    CALL SCANNING

; Store result in variable
    POP AF ; var letter
    LD C,A
    CALL LOOK_VAR_MUT

    RET

LOOK_VAR_MUT: ; Like LOOK_VAR but for assignment
; C = variable letter, FP_VALUE has value
    LD HL,(VARS)
LV_M_LOOP:
    LD A,(HL)
    CP 0x00
    JR Z,LV_M_NEW
    CP C
    JR Z,LV_M_FOUND
    INC HL
    INC HL
    INC HL
    INC HL
    INC HL
    INC HL
    JR LV_M_LOOP

LV_M_NEW:
    LD A,C
    LD (HL),A
    INC HL
    LD DE,FP_VALUE
    LD B,5
LV_M_CP:
    LD A,(DE)
    LD (HL),A
    INC HL
    INC DE
    DJNZ LV_M_CP
    LD (HL),0
    RET

LV_M_FOUND:
    INC HL
    LD DE,FP_VALUE
    LD B,5
LV_M_ST:
    LD A,(DE)
    LD (HL),A
    INC HL
    INC DE
    DJNZ LV_M_ST
    RET

; ===== COMMAND: GOTO =====
CMD_GOTO:
    LD HL,(CH_ADD)
    INC HL
    LD (CH_ADD),HL
    CALL SCANNING
    CALL FP_TO_BC
; BC = line number
    CALL FIND_LINE
    LD (CH_ADD),HL
    RET

FIND_LINE: ; BC = line number to find
; Returns HL = CH_ADD, or original if not found
    LD HL,0x4200 ; program start
FL_LP:
    LD A,(HL)
    INC HL
    CP 0x00
    RET Z ; not found, return
    CP C
    JR Z,FL_FOUND
; Skip to next line
FL_SKIP:
    LD A,(HL)
    CP ZX_NL
    JR Z,FL_NEXT
    INC HL
    JR FL_SKIP
FL_NEXT:
    INC HL
    JR FL_LP
FL_FOUND:
    DEC HL
    RET

; ===== COMMAND: GOSUB =====
CMD_GOSUB:
    LD HL,(CH_ADD)
    INC HL
    LD (CH_ADD),HL
    CALL SCANNING
    CALL FP_TO_BC
; Push return address
    LD HL,(CH_ADD)
    PUSH HL
    CALL FIND_LINE
    LD (CH_ADD),HL
    SET 5,(IY+FLAGS-0x4000) ; run flag
    RET

; ===== COMMAND: RETURN =====
CMD_RETURN:
    LD HL,(CH_ADD)
    INC HL
    LD (CH_ADD),HL
    POP HL ; return address
    LD (CH_ADD),HL
    RET

; ===== COMMAND: IF =====
CMD_IF:
    LD HL,(CH_ADD)
    INC HL
    LD (CH_ADD),HL
    CALL SCANNING ; evaluate condition
; Check if result is zero
    LD HL,FP_VALUE
    LD A,(HL)
    AND A
    JR NZ,CI_TRUE
; Find THEN or skip line
    LD HL,(CH_ADD)
CI_SKIP:
    LD A,(HL)
    CP ZX_NL
    RET Z
    CP TK_THEN
    JR Z,CI_THEN
    INC HL
    JR CI_SKIP
CI_TRUE:
    LD HL,(CH_ADD)
CI_THEN:
    LD A,(HL)
    CP TK_THEN
    JR NZ,CI_EXEC
    INC HL
CI_EXEC:
    LD (CH_ADD),HL
    CALL SCAN_LINE
    RET

; ===== COMMAND: FOR =====
CMD_FOR:
    RET

; ===== COMMAND: NEXT =====
CMD_NEXT:
    RET

; ===== COMMAND: INPUT =====
CMD_INPUT:
    RET

; ===== COMMAND: LIST =====
CMD_LIST:
    LD HL,0x4200
    LD DE,0x5000 ; display start
CL_LP:
    LD A,(HL)
    CP 0x00
    RET Z
    LD A,(HL)
    INC HL
    CP ZX_NL
    JR Z,CL_NEXT
; Print char
    PUSH HL
    CALL PRINT_CH
    POP HL
    JR CL_LP
CL_NEXT:
    CALL DO_NEWLINE
    JR CL_LP

; ===== COMMAND: RUN =====
CMD_RUN:
    LD HL,0x4200
    LD (CH_ADD),HL
    SET 5,(IY+FLAGS-0x4000)
    RET

RUN_PROG: ; Execute next statement in running program
    LD HL,(CH_ADD)
    LD A,(HL)
    CP 0x00
    JR Z,RP_END
    CP ZX_NL
    JR Z,RP_NEXT
    CALL SCAN_LINE
    RET
RP_NEXT:
    INC HL
    LD (CH_ADD),HL
    RET
RP_END:
    RES 5,(IY+FLAGS-0x4000)
    RET

; ===== COMMAND: CLS =====
CMD_CLS:
    LD HL,0x5000
    LD BC,ZX_ROWS*(ZX_COLS+1)
CL_LP2:
    LD (HL),0x00
    INC HL
    DJNZ CL_LP2
    LD HL,0x5000
    LD (DF_CC),HL
    RET

; ===== COMMAND: CLEAR =====
CMD_CLEAR: ; Clear variables
    LD HL,0x4200
CLR_LP:
    LD A,(HL)
    AND A
    JR Z,CLR_DONE
    INC HL
    JR CLR_LP
CLR_DONE:
    INC HL
    LD (VARS),HL
    RET

; ===== COMMAND: POKE =====
CMD_POKE:
    LD HL,(CH_ADD)
    INC HL
    LD (CH_ADD),HL
    CALL SCANNING
    CALL FP_TO_BC ; BC = address
    LD H,B
    LD L,C
    PUSH HL
    CALL SCANNING
    CALL FP_TO_BC ; BC = value
    POP HL
    LD A,C
    LD (HL),A
    RET

; ===== COMMAND: PAUSE =====
CMD_PAUSE:
    RET

; ===== COMMAND: STOP =====
CMD_STOP:
    RES 5,(IY+FLAGS-0x4000)
    RET

; ===== COMMAND: NEW =====
CMD_NEW:
    LD HL,0x4200
    LD (HL),0x00
    INC HL
    LD (HL),0x00
    RES 5,(IY+FLAGS-0x4000)
    RET

; ===== COMMAND: RANDOMIZE =====
CMD_RAND:
    RET

; ===== COMMAND: PLOT / UNPLOT =====
CMD_PLOT:
    RET
CMD_UNPLOT:
    RET

; ===== COMMAND: LOAD / SAVE =====
CMD_LOAD:
    RET
CMD_SAVE:
    RET

; ===== DISPLAY UPDATE =====
UPDATE_DISPLAY:
    LD IX,0x5000
    LD IY,0x8000
    LD B,ZX_ROWS
UD_ROW:
    LD A,(IX+0)
    CP ZX_NL
    JR NZ,UD_CO
    INC IX
UD_CO:
    PUSH BC
    LD B,ZX_COLS
UD_CH:
    LD A,(IX+0)
    CP 0x00
    JR Z,UD_SP
    CP ZX_NL
    JR Z,UD_SP
    AND 0x3F
    JR UD_WR
UD_SP:
    LD A,0x20
UD_WR:
    LD (IY+0),A
    INC IX
    INC IY
    DJNZ UD_CH
    LD A,(IX+0)
    CP ZX_NL
    JR NZ,UD_NX
    INC IX
UD_NX:
    POP BC
    DJNZ UD_ROW
    RET

; ===== CHARACTER FONT =====
    org 0x0800

; ZX81 font: 64 chars, 8 bytes each
; Chars $00-$3F
CHAR_SET:
; $00 space
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
; $01-$0A graphics blocks
    DB 0xF0,0xF0,0xF0,0xF0,0x00,0x00,0x00,0x00
    DB 0x0F,0x0F,0x0F,0x0F,0x00,0x00,0x00,0x00
    DB 0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x00,0x00,0xF0,0xF0,0xF0,0xF0
    DB 0xF0,0xF0,0xF0,0xF0,0xF0,0xF0,0xF0,0xF0
    DB 0x0F,0x0F,0x0F,0x0F,0xF0,0xF0,0xF0,0xF0
    DB 0xFF,0xFF,0xFF,0xFF,0xF0,0xF0,0xF0,0xF0
    DB 0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55
    DB 0x00,0x00,0x00,0x00,0xAA,0x55,0xAA,0x55
    DB 0xAA,0x55,0xAA,0x55,0x00,0x00,0x00,0x00
; $0B quote
    DB 0x00,0x24,0x24,0x00,0x00,0x00,0x00,0x00
; $0C pound
    DB 0x00,0x1C,0x22,0x78,0x20,0x20,0x7E,0x00
; $0D dollar
    DB 0x00,0x08,0x3E,0x28,0x3E,0x0A,0x3E,0x08
; $0E colon
    DB 0x00,0x00,0x00,0x10,0x00,0x00,0x10,0x00
; $0F question
    DB 0x00,0x3C,0x42,0x04,0x08,0x00,0x08,0x00
; $10 lparen
    DB 0x00,0x04,0x08,0x08,0x08,0x08,0x04,0x00
; $11 rparen
    DB 0x00,0x20,0x10,0x10,0x10,0x10,0x20,0x00
; $12 greater
    DB 0x00,0x00,0x08,0x3E,0x1C,0x3E,0x08,0x00
; $13 less
    DB 0x00,0x00,0x00,0x10,0x38,0x10,0x00,0x00
; $14 equals
    DB 0x00,0x00,0x00,0x3E,0x00,0x3E,0x00,0x00
; $15 plus
    DB 0x00,0x00,0x08,0x08,0x3E,0x08,0x08,0x00
; $16 minus
    DB 0x00,0x00,0x00,0x00,0x3E,0x00,0x00,0x00
; $17 star/multiply
    DB 0x00,0x00,0x22,0x14,0x08,0x14,0x22,0x00
; $18 slash
    DB 0x00,0x00,0x04,0x08,0x10,0x20,0x00,0x00
; $19 semicolon
    DB 0x00,0x00,0x10,0x00,0x00,0x10,0x20,0x00
; $1A comma
    DB 0x00,0x00,0x00,0x00,0x00,0x08,0x10,0x20
; $1B period
    DB 0x00,0x00,0x00,0x00,0x00,0x08,0x00,0x00
; $1C-25 digits 0-9
    DB 0x00,0x3C,0x44,0x4C,0x54,0x64,0x44,0x3C ; 0
    DB 0x00,0x08,0x18,0x08,0x08,0x08,0x08,0x1C ; 1
    DB 0x00,0x3C,0x44,0x04,0x08,0x10,0x20,0x7C ; 2
    DB 0x00,0x3C,0x44,0x04,0x18,0x04,0x44,0x3C ; 3
    DB 0x00,0x08,0x18,0x28,0x48,0x7C,0x08,0x08 ; 4
    DB 0x00,0x7C,0x40,0x40,0x78,0x04,0x44,0x3C ; 5
    DB 0x00,0x3C,0x44,0x40,0x78,0x44,0x44,0x3C ; 6
    DB 0x00,0x7C,0x04,0x08,0x10,0x10,0x10,0x10 ; 7
    DB 0x00,0x3C,0x44,0x44,0x3C,0x44,0x44,0x3C ; 8
    DB 0x00,0x3C,0x44,0x44,0x3C,0x04,0x44,0x3C ; 9
; $26-$3F letters A-Z and punctuation
    DB 0x00,0x18,0x24,0x44,0x44,0x7C,0x44,0x44 ; A
    DB 0x00,0x78,0x44,0x44,0x78,0x44,0x44,0x78 ; B
    DB 0x00,0x3C,0x44,0x40,0x40,0x40,0x44,0x3C ; C
    DB 0x00,0x78,0x44,0x44,0x44,0x44,0x44,0x78 ; D
    DB 0x00,0x7C,0x40,0x40,0x78,0x40,0x40,0x7C ; E
    DB 0x00,0x7C,0x40,0x40,0x78,0x40,0x40,0x40 ; F
    DB 0x00,0x3C,0x44,0x40,0x40,0x4C,0x44,0x3C ; G
    DB 0x00,0x44,0x44,0x44,0x7C,0x44,0x44,0x44 ; H
    DB 0x00,0x7C,0x10,0x10,0x10,0x10,0x10,0x7C ; I
    DB 0x00,0x04,0x04,0x04,0x04,0x04,0x44,0x3C ; J
    DB 0x00,0x44,0x48,0x50,0x60,0x50,0x48,0x44 ; K
    DB 0x00,0x40,0x40,0x40,0x40,0x40,0x40,0x7C ; L
    DB 0x00,0x44,0x44,0x64,0x54,0x4C,0x44,0x44 ; M
    DB 0x00,0x44,0x44,0x64,0x54,0x4C,0x44,0x44 ; N
    DB 0x00,0x3C,0x44,0x44,0x44,0x44,0x44,0x3C ; O
    DB 0x00,0x78,0x44,0x44,0x78,0x40,0x40,0x40 ; P
    DB 0x00,0x3C,0x44,0x44,0x44,0x54,0x48,0x34 ; Q
    DB 0x00,0x78,0x44,0x44,0x78,0x48,0x44,0x44 ; R
    DB 0x00,0x3C,0x44,0x40,0x3C,0x04,0x44,0x3C ; S
    DB 0x00,0x7C,0x10,0x10,0x10,0x10,0x10,0x10 ; T
    DB 0x00,0x44,0x44,0x44,0x44,0x44,0x44,0x3C ; U
    DB 0x00,0x44,0x44,0x44,0x44,0x44,0x28,0x10 ; V
    DB 0x00,0x44,0x44,0x44,0x54,0x54,0x54,0x28 ; W
    DB 0x00,0x44,0x44,0x28,0x10,0x28,0x44,0x44 ; X
    DB 0x00,0x44,0x44,0x44,0x28,0x10,0x10,0x10 ; Y
    DB 0x00,0x7C,0x04,0x08,0x10,0x20,0x40,0x7C ; Z

; ===== DATA AREAS =====
    org 0x1C00

E_LINE_BUF:
    DS 256, 0x00
    DB ZX_NL

    org 0x1E00

FP_VALUE:
    DS 5 ; exp, high, low, low, low
FP_EXP equ FP_VALUE
FP_HIGH equ FP_VALUE+1
FP_LOW equ FP_VALUE+2
FP_STRLN:
    DS 2
FP_STRBUF:
    DS 80
FP_DECBUF:
    DS 12

; ===== RETURN TO 8502 =====
RETURN:
    LD A,0x3F
    LD BC,0xFF00
    OUT (C),A
    JP 0xFFE0


PRINT_SP:
    ld a,ZX_SP
PRINT_CH:
    push hl
    ld hl,(DF_CC)
    ld (hl),a
    inc hl
    ld (DF_CC),hl
    pop hl
    ret

RESERVE:
    pop hl
    pop bc
    ret

    end
