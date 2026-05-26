;******************************************************************************
;*
;* Copyright(c) 2024 Bob Fossil. All rights reserved.
;*
;* This program is free software; you can redistribute it and/or modify it
;* under the terms of version 2 of the GNU General Public License as
;* published by the Free Software Foundation.
;*
;* This program is distributed in the hope that it will be useful, but WITHOUT
;* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;* FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
;* more details.
;*
;* You should have received a copy of the GNU General Public License along with
;* this program; if not, write to the Free Software Foundation, Inc.,
;* 51 Franklin Street, Fifth Floor, Boston, MA 02110, USA
;*
;*
;******************************************************************************/

include "plugin.asm"
include "../esxdos.asm"

	org PLUGIN_ORG

	jr _plugin_start

DEFC FXM_MODULE=$c000
DEFC FXM_ID_LEN=4
DEFC MAX_SIZE=16384

_plugin_info:

	defb "BP"			; id
	defb 0				; spare
	defb 0				; spare
					; flags
	defb PLUGIN_FLAGS1_COPY_SETTINGS
	defb 0				; flags2

_plugin_user_data:

	defs(PLUGIN_SETTING_MAX)	; reserve space for settings copy

_plugin_id_string:

	defb "Fuxoft Module plugin - budder, bob_fossil", $0

_plugin_start:

					; filename in hl
	xor a
	ld (_plugin_file_handle), a

	ld a, ESXDOS_CURRENT_DRIVE	; *
	ld b, ESXDOS_MODE_READ

	rst ESXDOS_SYS_CALL		; open file
	defb ESXDOS_SYS_F_OPEN

	jr nc, _plugin_stat

	ld bc, _err_file
	ld a, PLUGIN_ERROR
	ret

_plugin_stat:

	ld (_plugin_file_handle), a
	ld hl, _plugin_file_stat
	rst ESXDOS_SYS_CALL		; get file information
	defb ESXDOS_SYS_F_FSTAT

	jr nc, _plugin_size

	ld bc, _err_io
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_size:

	ld hl, (_plugin_file_stat + 7)	; put 16 bit file size into hl
					; check if filesize HL < 16384
	push hl

	ld bc, MAX_SIZE			; check data is in RAM
	or a
	sbc hl, bc

	pop bc				; pop hl size into bc

	jr c, _plugin_read

	ld bc, _err_memory
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_read:

	ld a, (_plugin_file_handle)	; read file to FXM_MODULE address
	ld hl, FXM_MODULE

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_check

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_check:

	ld hl, FXM_MODULE		; offset for 'FXSM'
	ld de, _fxm_id
	ld b, FXM_ID_LEN
	call _strncmp			; check for 'FXSM'

	jr z, _plugin_init

	ld bc, _err_invalid
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jr _plugin_error

_plugin_init:

	push ix

	call INIT
	ei

	ld hl, _plugin_status_playing
	call _set_status_icon

	call _plugin_wait_for_no_keys

_plugin_playback:

	halt
	call PLAY

	call _plugin_in_inkey		; get scancode into l

					; check key up
	ld de, _plugin_user_data + PLUGIN_SETTING_OFFSET_KEY_UP
	ld a, (de)
	cp l
	jr nz, _plugin_key_down

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_FIRST
	ld hl, _plugin_status_seek_previous
	jr _plugin_done

_plugin_key_down:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_left

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_LAST
	ld hl, _plugin_status_seek_next
	jr _plugin_done

_plugin_key_left:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_right

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_PREVIOUS
	ld hl, _plugin_status_seek_previous
	jr _plugin_done

_plugin_key_right:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_break

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_NEXT
	ld hl, _plugin_status_seek_next
	jr _plugin_done

_plugin_key_break:

	ld a, $20			; Space
	cp l
	jr nz, _plugin_playback

	call _plugin_shift_pressed
	ld a, l
	and SHIFT_CAPS			; shift + space, so return

	jr z, _plugin_playback

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS
	ld hl, 0

_plugin_done:

	push bc				; save navigation
	push af				; save return code

	call _set_status_icon

	call STOP

	di

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop af				; restore return code
	pop bc				; restore navigation

	pop ix

	ret

_plugin_error:

	push bc

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop bc

_plugin_error_ret:

	ld a, 0
	ret


_plugin_file_handle:

	defb 0

_plugin_file_stat:
;struct esxdos_stat
;{
;   uint8_t  drive;
;   uint8_t  device;
;   uint8_t  attr;
;   uint32_t date;
;   uint32_t size;
;};
	defs(12)


_set_status_icon:

	ld a, h
	or l
	ret z

					; hl points to status graphic
	ld de, PLUGIN_STATUS_SCREEN_ADDR
	ld b, 8

_set_status_icon_loop:

	ld a, (hl)
	ld (de), a
	inc hl
	inc d
	djnz _set_status_icon_loop
	ret


_plugin_status_playing:

	defb %00000000
	defb %00100000
	defb %00110000
	defb %00111000
	defb %00110000
	defb %00100000
	defb %00000000
	defb %00000000

_plugin_status_seek_next:

	defb %00000000
	defb %01000100
	defb %01100110
	defb %01110111
	defb %01100110
	defb %01000100
	defb %00000000
	defb %00000000

_plugin_status_seek_previous:

	defb %00000000
	defb %00100010
	defb %01100110
	defb %11101110
	defb %01100110
	defb %00100010
	defb %00000000
	defb %00000000

include "plugin_keyboard.asm"

;

;        ORG #C000
;---------------------------------------
;START   JP INIT
;        JP STOP
;        JP PLAY
;---------------------------------------
INIT:
	LD DE,(FXM_MODULE+4);Only for FXM files
	LD HL,FXM_MODULE+6
	OR A
	SBC HL,DE
	LD (MKR+1),HL
	LD (MR2+1),HL
	LD (MR3+1),HL
	LD (MR4+1),HL
	LD (MR5+1),HL
	LD (MR6+1),HL
	LD (MR7+1),HL
	EX DE,HL
;-------
	DI
	LD HL,(FXM_MODULE+0+6)
	ADD HL,DE
	LD (AA13),HL
	LD HL,(FXM_MODULE+2+6)
	ADD HL,DE
	LD (AA27),HL
	LD HL,(FXM_MODULE+4+6)
	ADD HL,DE
	LD (AA3B),HL

	LD A,1
	LD (AA15),A
	LD (AA29),A
	LD (AA3D),A
	LD A,8
	LD (AA16),A
	LD (AA2A),A
	LD (AA3E),A

	LD HL,A9D3
	LD DE,$20
	LD (A9AD),HL
	ADD HL,DE
	LD (A9AF),HL
	ADD HL,DE
	LD (A9B1),HL

	LD HL,0
	LD (AA21),HL
	LD (AA35),HL
	LD (AA49),HL
	LD (AA23),HL
	LD (AA37),HL
	LD (AA4B),HL

	XOR A
	LD (A9A7),A
	EI
	RET

STOP:
	DI
	LD A,$FF
	LD D,$07
	CALL AB4E
	CALL AB38
	EI
	RET

;---------------------------------------
;                                   DATA
A999:    ds (13)
A9A6:    defb 0
A9A7:    defb 0
A9A8:    defb 0
A9A9:    defw 0
A9AB:    defw 0
A9AD:    defw 0
A9AF:    defw 0
A9B1:    ds (34)
A9D3:    ds (64)
AA13:    defw 0
AA15:    defb 0
AA16:    ds (11)
AA21:    defw 0
AA23:    ds (4)
AA27:    defw 0
AA29:    defb 0
AA2A:    ds (11)
AA35:    defw 0
AA37:    ds (4)
AA3B:    defw 0
AA3D:    defb 0
AA3E:    ds (11)
AA49:    defw 0
AA4B:    ds (4)

TABLE:
	defb $BF,$0F,$DC,$0E
	defb $07,$0E,$3D,$0D
	defb $7F,$0C,$CC,$0B
	defb $22,$0B,$82,$0A
	defb $EB,$09,$5D,$09
	defb $D6,$08,$57,$08
	defb $DF,$07,$6E,$07
	defb $03,$07,$9F,$06
	defb $40,$06,$E6,$05
	defb $91,$05,$41,$05
	defb $F6,$04,$AE,$04
	defb $6B,$04,$2C,$04
	defb $F0,$03,$B7,$03
	defb $82,$03,$4F,$03
	defb $20,$03,$F3,$02
	defb $C8,$02,$A1,$02
	defb $7B,$02,$57,$02
	defb $36,$02,$16,$02
	defb $F8,$01,$DC,$01
	defb $C1,$01,$A8,$01
	defb $90,$01,$79,$01
	defb $64,$01,$50,$01
	defb $3D,$01,$2C,$01
	defb $1B,$01,$0B,$01
	defb $FC,$00,$EE,$00
	defb $E0,$00,$D4,$00
	defb $C8,$00,$BD,$00
	defb $B2,$00,$A8,$00
	defb $9F,$00,$96,$00
	defb $8D,$00,$85,$00
	defb $7E,$00,$77,$00
	defb $70,$00,$6A,$00
	defb $64,$00,$5E,$00
	defb $59,$00,$54,$00
	defb $4F,$00,$4B,$00
	defb $47,$00,$43,$00
	defb $3F,$00,$3B,$00
	defb $38,$00,$35,$00
	defb $32,$00,$2F,$00
	defb $2D,$00,$2A,$00
	defb $28,$00,$25,$00
	defb $23,$00,$21,$00

;---------------------------------------
;                                 Player
PLAY:
	LD IX,AA13
	LD HL,(A9AD)
	LD A,1
	CALL AB63
	LD (A9AD),HL

	LD IX,AA27
	LD HL,(A9AF)
	LD A,2
	CALL AB63
	LD (A9AF),HL

	LD IX,AA3B
	LD HL,(A9B1)
	LD A,3
	CALL AB63
	LD (A9B1),HL

	LD A,(AA3E)
	RLCA
	LD B,A
	LD A,(AA2A)
	OR B
	RLCA
AB2E:
	LD B,A
	LD A,(AA16)
	OR B
	LD D,7
	CALL AB4E
AB38:
	LD D,$0D
	LD HL,A9A6
AB3D:
	LD A,D
	LD BC,$FFFD
	OUT (C),A
	LD A,(HL)
	LD B,$BF
	OUT (C), A
	DEC HL
	DEC D
	JP P,AB3D
	RET

AB4E:
	LD BC,A999
	LD L, D
	LD H, 0
	ADD HL,BC
	LD (HL),A
	RET

AB57:
	LD (A9AB),SP
	LD HL,(A9AB)
	LD SP,(A9A9)
	RET

AB63:
	LD (A9A9),SP
	LD SP,HL
	LD (A9A8),A
	DEC (IX+2)
	JP Z,AC72
AB71:
	DEC (IX+6)
	JR NZ,ABAC
UM0:
	LD L,(IX+4)
	LD H,(IX+5)
	LD A,(HL)
	CP $80
	JR NZ,UM1
	INC HL
	LD E,(HL)
	INC HL
	LD D,(HL)

	PUSH HL
MKR:
	LD HL,0
	ADD HL,DE
	EX DE,HL
	POP HL

	LD (IX+4),E
	LD (IX+5),D
	JR UM0

UM1:
	CP $1E
	JR C,AB9D
	SUB $32
	LD (IX+9),A
	LD (IX+6),1
	INC HL
	JR ABA6

AB9D:
	LD (IX+9),A
	INC HL
	LD A,(HL)
	LD (IX+6),A
	INC HL
ABA6:
	LD (IX+4),L
	LD (IX+5),H
ABAC:
	LD A,(IX+7)
	OR (IX+8)
	JP Z,AC35
	BIT 2,(IX+$0E)
	JP NZ,AC35
	LD L,(IX+$0C)
	LD H,(IX+$0D)
ABC2:
	LD A,(HL)
	INC HL
	LD (IX+$0C),L
	LD (IX+$0D),H
	CP $80
	JR NZ,ABD4
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A

	PUSH DE
MR2:
	LD DE,0
	ADD HL,DE
	POP DE
	JR ABC2

ABD4:
	CP $82
	JP NZ,ABE0
	SET 3,(IX+$0E)
	JP ABC2

ABE0:
	CP $83
	JP NZ,ABEC
	RES 3,(IX+$0E)
	JP ABC2

ABEC:
	CP $84
	JP NZ,ABFC
	LD A,9
	XOR (IX+$03)
	LD (IX+$03),A
	JP ABC2

ABFC:
	BIT 3,(IX+$0E)
	JP Z,AC1E
	ADD A,(IX+$12)
	LD (IX+$12),A
	DEC A
	ADD A,A
	LD E,A
	LD D,0
	LD HL,TABLE
	ADD HL,DE
	LD A,(HL)
	LD (IX+7),A
	INC HL
	LD A,(HL)
	LD (IX+8),A
	JP AC35

AC1E:
	LD E,A
	LD D,0
	LD L,(IX+7)
	LD H,(IX+8)
	AND $80
	JP Z,AC2E
	LD D,$FF
AC2E:
	ADD HL,DE
	LD (IX+7),L
	LD (IX+8),H
AC35:
	LD A,(A9A7)
	LD D,6
	CALL AB4E
	RES 2,(IX+$0E)
	LD A,(A9A8)
	ADD A,7
	LD D,A
	LD A,(IX+7)
	OR (IX+8)
	JR Z,AC52
	LD A,(IX+9)
AC52:
	CALL AB4E
	LD A,(A9A8)
	DEC A
	ADD A,A
	LD D,A
	LD A,(IX+7)
	CALL AB4E
	INC D
	LD A,(IX+8)
	CALL AB4E
	JP AB57

AC6B:
	LD (IX+0),L
	LD (IX+1),H
	RET

AC72:
	LD L,(IX+0)
	LD H,(IX+1)
	LD A,(HL)
	INC HL

	CALL AC6B
	BIT 7,A
	JP NZ,ACEF

	LD (A9AB),HL
	OR A
	JR Z,ACA3

	ADD A,(IX+$0F)
	LD (IX+$12),A
	RES 3,(IX+$0E)

	DEC A
	ADD A,A

	LD E,A
	LD D,0
	LD HL,TABLE
	ADD HL,DE

	LD E,(HL)
	INC HL
	LD D,(HL)
	LD HL,(A9AB)
	JR ACA6

ACA3:
	LD DE,0
ACA6:
	LD A,(HL)
	INC HL
	CALL AC6B
	LD (IX+2),A
	LD (IX+7),E
	LD (IX+8),D

	LD A,(IX+$10)
	LD (IX+$0C),A
	LD A,(IX+$11)
	LD (IX+$0D),A

	SET 2,(IX+$0E)
	BIT 1,(IX+$0E)
	JP NZ,AB71
	BIT 0,(IX+$0E)
	JP Z,ACD6
	SET 1,(IX+$0E)

ACD6:
	LD C,(IX+$0A)
	LD B,(IX+$0B)
	LD A,(BC)
	LD (IX+9),A
	INC BC
	LD A,(BC)
	INC BC
	LD (IX+6),A
	LD (IX+4),C
	LD (IX+5),B
	JP AC35

ACEF:
	AND $7F
	LD (A9AB),HL
	ADD A,A
	LD E,A
	LD D,0
	LD HL,AD05
	ADD HL,DE
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A

	PUSH HL
	LD HL,(A9AB)
	RET

AD05:
	defw AD23
	defw AD2F
	defw AD3D
	defw AD47
	defw AD59
	defw AD64
	defw AD91
	defw AD6F
	defw AD7F
	defw AD8A
	defw ADA1
	defw ADAF
	defw ADBD
	defw ADCA
	defw ADDA
;---------------------------------------
AD23:
	PUSH DE
	LD E,(HL)
	INC HL
	LD D,(HL)
	PUSH HL
MR3:
	LD HL,0
	ADD HL,DE
	LD (IX+0),L
	LD (IX+1),H
	POP HL
	POP DE
	JP AC72

AD2F:
	PUSH DE
	LD E,(HL)
	INC HL
	LD D,(HL)
	INC HL
	PUSH HL
MR4:
	LD HL,0
	ADD HL,DE
	LD (IX+0),L
	LD (IX+1),H
	POP HL
	POP DE

	PUSH HL
	JP AC72

AD3D:
	LD B,(HL)
	PUSH BC
	INC HL
	PUSH HL
	CALL AC6B
	JP AC72

AD47:
	POP DE
	POP BC
	DJNZ AD4E
	JP AC72

AD4E:
	PUSH BC
	PUSH DE
	LD (IX+0),E
	LD (IX+1),D
	JP AC72

AD59:
	LD A,(HL)
	INC HL
	LD (A9A7),A
	CALL AC6B
	JP AC72

AD64:
	LD A,(HL)
	INC HL
	CALL AC6B
	LD (IX+3),A
	JP AC72

AD6F:
	PUSH DE
	LD E,(HL)
	INC HL
	LD D,(HL)
	INC HL
	PUSH HL

MR5:
	LD HL,0
	ADD HL,DE
	LD (IX+$0A),L
	LD (IX+$0B),H
	POP HL
	POP DE

	CALL AC6B
	JP AC72

AD7F:
	LD A,(HL)
	INC HL
	CALL AC6B
	LD (IX+$0F),A
	JP AC72

AD8A:
	POP HL
	CALL AC6B
	JP AC72

AD91:
	PUSH DE
	LD E,(HL)
	INC HL
	LD D,(HL)
	INC HL
	PUSH HL

MR7:
	LD HL,0
	ADD HL,DE
	LD (IX+$10),L
	LD (IX+$11),H
	POP HL
	POP DE

	CALL AC6B
	JP AC72

ADA1:
	SET 0,(IX+$0E)
	RES 1,(IX+$0E)
	CALL AC6B
	JP AC72

ADAF:
	RES 0,(IX+$0E)
	RES 1,(IX+$0E)
	CALL AC6B
	JP AC72

ADBD:
	LD E,(HL)
	INC HL
	LD D,(HL)
	INC HL
	PUSH HL

MR6:
	LD HL,0
	ADD HL,DE
	EX DE,HL
	POP HL

	CALL AC6B
	LD BC,AC72
	PUSH BC
	PUSH DE
	RET

ADCA:
	LD A,(A9A7)
	ADD A,(HL)
	AND $1F
	LD (A9A7),A
	INC HL
	CALL AC6B
	JP AC72

ADDA:
	LD A,(HL)
	ADD A,(IX+$0F)
	LD (IX+$0F),A
	INC HL
	CALL AC6B
	JP AC72

;---------------------------------------
;                                 Module
;MUZ
;---------------------------------------


	; function to compare n characters of two strings
	;
	; hl source string
	; de dest string
	; b length to compare
	;
	; returns z set if all characters matched
_strncmp:

	ld a, (de)
	cp (hl)
	jr nz, _strncmp_done

	inc de
	inc hl

	djnz _strncmp

_strncmp_done:

	ld a, b
	and a
	ret

;

_fxm_id:

	defb "FXSM"

_err_memory:

	defb "Out of memory!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

_err_invalid:

	defb "Not a valid .FXM file!", $0
