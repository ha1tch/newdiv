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

DEFC FTC_MODULE=$c000
DEFC FTC_ID_LEN=16
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

	defb "Fast Tracker plugin - sandrowski/mayHem, bob_fossil", $0

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

	ld a, (_plugin_file_handle)	; read file to FTC_MODULE address
	ld hl, FTC_MODULE

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_check

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_check:

	ld hl, FTC_MODULE + $33		; offset for 'Fast Tracker v1.'
	ld de, _ftc_id
	ld b, FTC_ID_LEN
	call _strncmp			; check for 'Fast Tracker v1.'

	jr z, _plugin_init

	ld bc, _err_invalid
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jr _plugin_error

_plugin_init:

	push ix

	call PLAYAIN
	ei

	ld hl, _plugin_status_playing
	call _set_status_icon

	call _plugin_wait_for_no_keys

_plugin_playback:

	halt
	call FSTPPLAY

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

	call PLAYAIN

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

;FastTrackerPlayer 1.07 (for ftr1.07 or lower)
;coded by orion/digital reality'97-98
;disassembled & modfied by sandrowski/mayHem'2o18
;thx ivan roshin for table-generator idea
;this player uses two tonetbls: #01-CLASSIC & #02-1.75+mHz
;lenght of original #B65, lenght of current #BB0


;main codes of ftrplaya (based on JAMdemo by D.R.)

PLAYAIN:

	LD HL, FTC_MODULE
	JP FSTPINI

FSTPPLAY:

	DI
	LD HL, FSTPKNT
	DEC (HL)
	JP NZ, FTRC5

FSTPPL1:

	LD (HL), 0
	LD A, 2
	EX AF, AF'
	CALL FSTXA
	LD A, C
	OR A
	JR NZ, FTRA5

FTPORTA:

	LD A, 0
	PUSH AF

FTRA2:

	LD A, 0
	CALL FTRTONT2
	LD E, (HL)
	INC HL
	LD D, (HL)
	LD A, (FSTPA36+1)
	CALL FTRTONT2
	LD C, (HL)
	INC HL
	LD B, (HL)
	EX DE, HL
	POP AF
	LD E, A
	OR A
	SBC HL, BC
	LD (FSTPA39+1), HL
	LD A, $C2
	JR C, FTRA3
	LD A, $CA

FTRA3:

	LD (FSTPA41), A
	LD H, 0
	LD L, E
	JR C, FTRA4
	LD L, H
	LD D, L
	OR A
	SBC HL, DE

FTRA4:

	LD (FSTPA40+1), HL

FTRA5:

	LD A, 2
	EX AF, AF'
	CALL FSTXB
	LD A,C
	OR A
	JR NZ, FTRB5

FTPORTB:

	LD A, 0
	PUSH AF

FTRB2:

	LD A, 0
	CALL FTRTONT2
	LD E, (HL)
	INC HL
	LD D, (HL)
	LD A, (FSTPB36+1)
	CALL FTRTONT2
	LD C, (HL)
	INC HL
	LD B, (HL)
	EX DE, HL
	POP AF
	LD E, A
	OR A
	SBC HL, BC
	LD (FSTPB39+1), HL
	LD A, $C2
	JR C, FTRB3
	LD A, $CA

FTRB3:

	LD (FSTPB41), A
	LD H, 0
	LD L, E
	JR C, FTRB4
	LD L, H
	LD D, L
	OR A
	SBC HL, DE

FTRB4:

	LD (FSTPB40+1), HL

FTRB5:

	LD A, 2
	EX AF, AF'
	CALL FSTXC
	LD A, C
	OR A
	JR NZ, FTRC5

FTPORTC:

	LD A, 0
	PUSH AF

FTRC2:

	LD A, 0
	CALL FTRTONT2
	LD E, (HL)
	INC HL
	LD D, (HL)
	LD A, (FSTPC36+1)
	CALL FTRTONT2
	LD C, (HL)
	INC HL
	LD B, (HL)
	EX DE, HL
	POP AF
	LD E,A
	OR A
	SBC HL,BC
	LD (FSTPC39+1), HL
	LD A, $C2
	JR C, FTRC3
	LD A, $CA

FTRC3:

	LD (FSTPC41), A
	LD H, 0
	LD L, E
	JR C, FTRC4
	LD L, H
	LD D, L
	OR A
	SBC HL, DE

FTRC4:

	LD (FSTPC40+1), HL

FTRC5:

	CALL FSTPA
	CALL FSTPB
	CALL FSTPC
	LD A, ixl
	LD (FTRCXV), A
	XOR A
	JP FTRIN4

FTPATT:

	LD HL, 0
	LD A, (HL)
	INC HL
	LD C, (HL)
	ADD A, A
	JR NC, FTPAT2

FTPAT1:

	LD HL, 0
	LD A, (HL)
	INC HL
	LD C, (HL)
	ADD A, A

FTPAT2:

	INC HL
	LD (FTPATT+1), HL
	LD L,A
	LD H,0
	ADD A, A
	ADD A, L
	LD L, A
	JR NC,FTPAT3
	INC H

FTPAT3:

	LD DE, 0                 ;smeshhenie 1
	ADD HL, DE
	LD A, C
	LD (FSTXA16+1), A
	LD (FSTXB16+1), A
	LD (FSTXC16+1), A
	LD (FTPAT4+1), SP
	LD SP, HL
	POP HL
	LD (FSTXA1+1), HL
	EX DE, HL
	POP HL
	LD (FSTXB1+1), HL
	POP HL
	LD (FSTXC1+1), HL

FTPAT4:

	LD SP, 0
	RET

FSTXA:

	LD HL, FTPXA1
	DEC (HL)
	RET P
	INC (HL)

FSTXA1:

	LD DE, 0
	LD A, (DE)
	INC A
	CALL Z, FTPATT
	CALL FSTXA10
	LD (FSTXA1+1), DE
	RET

FSTXA2:

	LD (FTPXA1), A
	LD C, 1
	RET

FSTXA3:

	LD HL,0
	CALL FTRPO1
	INC HL
	LD A, (HL)
	INC HL
	LD (FSTPA2+1), A
	XOR A
	LD B, (HL)
	INC B
	INC HL
	LD C, A
	LD (FSTPA1+1), BC
	LD (FSTPA+1), HL
	LD (FSTPA7+1), A
	LD (FSTPA5+1), A
	JR FSTXA10

FSTXA4:

	LD HL, 0
	CALL FTRPO1
	INC HL
	LD A, (HL)
	INC HL
	LD (FSTPA12+1), A
	LD A,  (HL)
	INC A
	INC HL
	LD (FSTPA11+2),  A
	LD (FSTPA10+1),  HL
	JR FSTXA10

FSTXA5:

	JR Z, FSTXA7
	CP $F
	JR Z, FSTXA6

FTPXA5A:

	LD (FTPXA0), A
	LD A, $37
	LD (FSTPA31), A
	LD A, (DE)
	INC DE
	LD L, A
	LD A, (DE)
	LD H, A
	LD (FSTPA30+1), HL
	OR $FF
	LD (FTRIN5+1), A
	LD L, A
	LD H, A
	LD (FTRIN6+1), HL
	JR FSTXA8

FSTXA6:

	LD A, $B7
	LD (FSTPA31), A
	JR FSTXA10

FSTXA7:

	LD A, $B7
	LD (FSTPA9), A
	JP FSTXA17

FSTXA8:

	INC DE

FSTXA10:

	LD A, (DE)
	INC DE
	ADD A, $13
	ADD A, $21
	JR C, FSTXA3
	ADD A, $6C
	JR C, FSTXA15
	ADD A, $20
	JR C, FSTXA2
	ADD A, $10
	JR C, FSTXA5
	ADD A, $10
	JR C, FSTXA14
	ADD A, $20
	JR C, FSTXA4
	ADD A, $13
	JR Z, FSTXA12
	DEC A
	JR Z, FSTXA11
	DEC A
	JR Z, FSTXA13
	LD A, (DE)
	LD (FSTPKNT), A
	LD (FSTPPL1+1), A
	JR FSTXA8

FSTXA11:

	LD A, (DE)
	LD (FTPORTA+1), A
	XOR A
	EX AF, AF'
	JR FSTXA8

FSTXA12:

	LD A, (DE)
	LD L, A
	INC DE
	LD A, (DE)
	LD H, A
	LD (FSTPA40+1), HL
	LD A, 1
	EX AF, AF'
	JR FSTXA8

FSTXA13:

	LD A, (DE)
	LD (FSTPA16+1), A
	JR FSTXA8

FSTXA14:

	CALL FTRVOLT1
	LD (FSTPA33+1), HL
	JP FSTXA10

FSTXA15:

	PUSH AF
	LD A, (FSTPA36+1)
	LD (FTRA2+1), A
	POP AF

FSTXA16:

	ADD A, 0
	LD (FSTPA36+1), A
	LD A, $37
	LD (FSTPA9), A

FSTXA17:

	XOR A
	LD (FSTPA11+1), A
	LD (FSTPA14+1), A
	LD (FSTPA21+1), A
	LD (FSTPA7+1), A
	LD (FSTPA5+1), A
	LD (FSTPA1+1), A
	LD H, A
	LD L, A
	LD (FSTPA18+1), HL
	LD (FSTPA28+1), HL
	EX AF, AF'
	LD C, A
	OR A
	RET Z
	LD (FSTPA39+1), HL
	DEC A
	LD A, $C3
	LD (FSTPA41), A
	RET Z
	LD (FSTPA40+1), HL
	RET

FSTPA:

	LD DE, 0                 ;smeshhenie A

FSTPA1:

	LD HL, 0
	LD A, L
	CP H
	JR NZ, FSTPA3

FSTPA2:

	LD L, 0
	LD A, L

FSTPA3:

	INC L
	LD (FSTPA1+1), HL
	ADD A, A
	ADD A, E
	LD E, A
	JR NC, FSTPA4
	INC D

FSTPA4:

	EX DE, HL
	LD (FSTPA35+1), SP
	LD SP, HL
	POP BC

FSTPA5:

	LD A, 0
	ADD A, B
	BIT 6, C
	JR Z, FSTPA6
	LD (FSTPA5+1), A

FSTPA6:

	LD (FSTPA37+1), A

FSTPA7:

	LD A, 0
	ADD A, C
	BIT 7, C
	JR Z, FSTPA8
	LD (FSTPA7+1), A

FSTPA8:

	LD (FSTPA17+1), A

FSTPA9:

	NOP
	JP NC,  FSTPA43

FSTPA10:

	LD DE, 0

FSTPA11:

	LD HL, 0
	LD A, L
	CP H
	JR NZ, FSTPA13

FSTPA12:

	LD L, 0
	LD A, L

FSTPA13:

	INC L
	LD (FSTPA11+1), HL
	LD L, A
	LD C, A
	LD H, 0
	LD B, H
	ADD HL, HL
	ADD HL, HL
	ADD HL, BC
	ADD HL, DE
	LD SP, HL

FSTPA14:

	LD A, 0
	POP BC
	DEC SP
	ADD A, C
	BIT 7, C
	JR Z, FSTPA15
	LD (FSTPA14+1), A

FSTPA15:

	BIT 6, C
	LD E, $FF
	JR NZ, FSTPA18

FSTPA16:

	ADD A, 0

FSTPA17:

	ADD A, 0
	LD (FSTPABC), A
	RES 3, E

FSTPA18:

	LD HL, 0
	POP BC
	ADD HL, BC
	BIT 7, B
	JR Z, FSTPA19
	LD (FSTPA18+1), HL

FSTPA19:

	BIT 6, B
	JR NZ, FSTPA20
	RES 0, E

FSTPA20:

	LD ixl, E
	LD (FSTPA38+1), HL
	POP BC
	XOR A

FSTPA21:

	LD D, 0
	BIT 5, C
	JR Z, FSTPA25
	DEC A
	BIT 4, C
	JR NZ, FSTPA22
	AND 1

FSTPA22:

	ADD A, D
	JP P, FSTPA23
	CP $F1
	ADC A, 0
	JR FSTPA24

FSTPA23:

	CP $10
	ADC A, $FF

FSTPA24:

	LD (FSTPA21+1), A
	LD D, A

FSTPA25:

	LD A, C
	AND $F
	ADD A, D
	JP P, FSTPA26
	XOR A

FSTPA26:

	CP $10
	JR C, FSTPA27
	LD A, $F

FSTPA27:

	LD E, A

FSTPA28:

	LD HL, 0
	LD D, C
	LD C, B
	RLC B
	SBC A, A
	LD B, A
	ADD HL, BC
	BIT 7, D
	JR Z, FSTPA29
	LD (FSTPA28+1), HL

FSTPA29:

	OR A
	LD C, L
	LD B, H

FSTPA30:

	LD HL, 0
	SBC HL, BC
	XOR A
	BIT 6, D
	JR Z, FSTPA32

FSTPA31:

	NOP
	JR NC,  FSTPA32
	LD (FTPA31HL),  HL
	OR $10

FSTPA32:
	LD D, 0

FSTPA33:

	LD HL, 0
	ADD HL, DE
	OR (HL)

FSTPA34:

	LD (FSTPVA1), A

FSTPA35:

	LD SP, 0

FSTPA36:

	LD A, 0

FSTPA37:

	ADD A, 0

FSTPA38:

	LD DE, 0
	CALL FTRTONT1

FSTPA39:
	LD HL, 0

FSTPA40:

	LD BC, 0
	ADD HL, BC
	LD (FSTPA39+1), HL
	BIT 7, H

FSTPA41:

	JP FSTPA42
	ADD HL, DE
	LD (FSTPVA), DE
	LD HL, 0
	LD (FSTPA39+1), HL
	LD (FSTPA40+1), HL
	RET

FSTPA42:

	ADD HL, DE
	LD (FSTPVA), HL
	RET

FSTPA43:

	XOR A
	LD ixl, $FF
	JR FSTPA34

FSTXB:

	LD HL, FTPXB1
	DEC (HL)
	RET P
	INC (HL)

FSTXB1:

	LD DE, 0
	CALL FSTXB10
	LD (FSTXB1+1), DE
	RET

FSTXB2:

	LD (FTPXB1), A
	LD C, 1
	RET

FSTXB3:

	LD HL, 0
	CALL FTRPO1
	INC HL
	LD A, (HL)
	INC HL
	LD (FSTPB2+1), A
	XOR A
	LD B, (HL)
	INC B
	INC HL
	LD C, A
	LD (FSTPB1+1), BC
	LD (FSTPB+1), HL
	LD (FSTPB7+1), A
	LD (FSTPB5+1), A
	JR FSTXB10

FSTXB4:

	LD HL, 0
	CALL FTRPO1
	INC HL
	LD A, (HL)
	INC HL
	LD (FSTPB12+1), A
	LD A, (HL)
	INC A
	INC HL
	LD (FSTPB11+2), A
	LD (FSTPB10+1), HL
	JR FSTXB10

FSTXB5:

	JR Z, FSTXB7
	CP $F
	JR Z, FSTXB6
	LD (FTPXA0), A
	LD A, $37
	LD (FSTPB31), A
	LD A, (DE)
	INC DE
	LD L, A
	LD A, (DE)
	LD H, A
	LD (FSTPB30+1), HL
	OR $FF
	LD (FTRIN5+1), A
	LD L, A
	LD H, A
	LD (FTRIN6+1), HL
	JR FSTXB8

FSTXB6:

	LD A, $B7
	LD (FSTPB31), A
	JR FSTXB10

FSTXB7:

	LD A, $B7
	LD (FSTPB9), A
	JP FSTXB17

FSTXB8:

	INC DE

FSTXB10:

	LD A, (DE)
	INC DE
	ADD A, $13
	ADD A, $21
	JR C, FSTXB3
	ADD A, $6C
	JR C, FSTXB15
	ADD A, $20
	JR C, FSTXB2
	ADD A, $10
	JR C, FSTXB5
	ADD A, $10
	JR C, FSTXB14
	ADD A, $20
	JR C, FSTXB4
	ADD A, $13
	JR Z, FSTXB12
	DEC A
	JR Z, FSTXB11
	DEC A
	JR Z, FSTXB13
	LD A, (DE)
	LD (FSTPKNT), A
	LD (FSTPPL1+1), A
	JR FSTXB8

FSTXB11:

	LD A, (DE)
	LD (FTPORTB+1), A
	XOR A
	EX AF, AF'
	JR FSTXB8

FSTXB12:

	LD A, (DE)
	LD L, A
	INC DE
	LD A, (DE)
	LD H, A
	LD (FSTPB40+1), HL
	LD A, 1
	EX AF, AF'
	JR FSTXB8

FSTXB13:

	LD A, (DE)
	LD (FSTPB16+1), A
	JR FSTXB8

FSTXB14:

	CALL FTRVOLT1
	LD (FSTPB33+1), HL
	JP FSTXB10

FSTXB15:

	PUSH AF
	LD A, (FSTPB36+1)
	LD (FTRB2+1), A
	POP AF

FSTXB16:

	ADD A, 0
	LD (FSTPB36+1), A
	LD A, $37
	LD (FSTPB9), A

FSTXB17:

	XOR A
	LD (FSTPB11+1), A
	LD (FSTPB14+1), A
	LD (FSTPB21+1), A
	LD (FSTPB7+1), A
	LD (FSTPB5+1), A
	LD (FSTPB1+1), A
	LD H, A
	LD L, A
	LD (FSTPB18+1), HL
	LD (FSTPB28+1), HL
	EX AF, AF'
	LD C, A
	OR A
	RET Z
	LD (FSTPB39+1), HL
	DEC A
	LD A, $C3
	LD (FSTPB41), A
	RET Z
	LD (FSTPB40+1), HL
	RET

FSTPB:

	LD DE, 0                 ;smeshhenie B

FSTPB1:

	LD HL, 0
	LD A, L
	CP H
	JR NZ, FSTPB3

FSTPB2:

	LD L, 0
	LD A, L

FSTPB3:

	INC L
	LD (FSTPB1+1), HL
	ADD A, A
	ADD A, E
	LD E, A
	JR NC, FSTPB4
	INC D

FSTPB4:

	EX DE, HL
	LD (FSTPB35+1), SP
	LD SP, HL
	POP BC

FSTPB5:

	LD A, 0
	ADD A, B
	BIT 6, C
	JR Z, FSTPB6
	LD (FSTPB5+1), A

FSTPB6:

	LD (FSTPB37+1), A

FSTPB7:

	LD A, 0
	ADD A, C
	BIT 7, C
	JR Z, FSTPB8
	LD (FSTPB7+1), A

FSTPB8:

	LD (FSTPB17+1), A

FSTPB9:

	NOP
	JP NC, FSTPB43

FSTPB10:

	LD DE, 0

FSTPB11:

	LD HL, 0
	LD A, L
	CP H
	JR NZ, FSTPB13

FSTPB12:

	LD L, 0
	LD A, L

FSTPB13:

	INC L
	LD (FSTPB11+1), HL
	LD L, A
	LD C, A
	LD H, 0
	LD B, H
	ADD HL, HL
	ADD HL, HL
	ADD HL, BC
	ADD HL, DE
	LD SP, HL

FSTPB14:

	LD A, 0
	POP BC
	DEC SP
	ADD A, C
	BIT 7, C
	JR Z, FSTPB15
	LD (FSTPB14+1), A

FSTPB15:

	BIT 6, C
	LD E, ixl
	JR NZ, FSTPB18

FSTPB16:

	ADD A, 0

FSTPB17:

	ADD A, 0
	LD (FSTPABC), A
	RES 4, E

FSTPB18:

	LD HL, 0
	POP BC
	ADD HL, BC
	BIT 7, B
	JR Z, FSTPB19
	LD (FSTPB18+1), HL

FSTPB19:

	BIT 6, B
	JR NZ, FSTPB20
	RES 1, E

FSTPB20:

	LD ixl, E
	LD (FSTPB38+1), HL
	POP BC
	XOR A

FSTPB21:

	LD D, 0
	BIT 5, C
	JR Z, FSTPB25
	DEC A
	BIT 4, C
	JR NZ, FSTPB22
	AND 1

FSTPB22:

	ADD A, D
	JP P, FSTPB23
	CP $F1
	ADC A, 0
	JR FSTPB24

FSTPB23:

	CP $10
	ADC A, $FF

FSTPB24:

	LD (FSTPB21+1), A
	LD D, A

FSTPB25:

	LD A, C
	AND $F
	ADD A, D
	JP P, FSTPB26
	XOR A

FSTPB26:

	CP $10
	JR C, FSTPB27
	LD A, $F

FSTPB27:

	LD E, A

FSTPB28:

	LD HL, 0
	LD D, C
	LD C, B
	RLC B
	SBC A, A
	LD B, A
	ADD HL, BC
	BIT 7, D
	JR Z, FSTPB29
	LD (FSTPB28+1), HL

FSTPB29:

	OR A
	LD C, L
	LD B, H

FSTPB30:

	LD HL, 0
	SBC HL, BC
	XOR A
	BIT 6, D
	JR Z, FSTPB32

FSTPB31:

	NOP
	JR NC, FSTPB32
	LD (FTPA31HL), HL
	OR $10

FSTPB32:

	LD D, 0

FSTPB33:

	LD HL, 0
	ADD HL, DE
	OR (HL)

FSTPB34:

	LD (FSTPVB1), A

FSTPB35:

	LD SP, 0

FSTPB36:

	LD A, 0

FSTPB37:

	ADD A, 0

FSTPB38:

	LD DE, 0
	CALL FTRTONT1

FSTPB39:

	LD HL, 0

FSTPB40:

	LD BC, 0
	ADD HL, BC
	LD (FSTPB39+1), HL
	BIT 7, H

FSTPB41:

	JP FSTPB42
	ADD HL, DE
	LD (FSTPVB), DE
	LD HL, 0
	LD (FSTPB39+1), HL
	LD (FSTPB40+1), HL
	RET

FSTPB42:

	ADD HL, DE
	LD (FSTPVB), HL
	RET

FSTPB43:

	LD A, ixl
	OR $12
	LD ixl, A
	XOR A
	JR FSTPB34

FSTXC:

	LD HL, FTPXC1
	DEC (HL)
	RET P
	INC (HL)

FSTXC1:

	LD DE, 0
	CALL FSTXC10
	LD (FSTXC1+1), DE
	RET

FSTXC2:

	LD (FTPXC1), A
	LD C, 1
	RET

FSTXC3:

	LD HL, 0
	CALL FTRPO1
	INC HL
	LD A, (HL)
	INC HL
	LD (FSTPC2+1), A
	XOR A
	LD B, (HL)
	INC B
	INC HL
	LD C, A
	LD (FSTPC1+1), BC
	LD (FSTPC+1), HL
	LD (FSTPC7+1), A
	LD (FSTPC5+1), A
	JR FSTXC10

FSTXC4:

	LD HL, 0
	CALL FTRPO1
	INC HL
	LD A, (HL)
	INC HL
	LD (FSTPC12+1), A
	LD A, (HL)
	INC A
	INC HL
	LD (FSTPC11+2), A
	LD (FSTPC10+1), HL
	JR FSTXC10

FSTXC5:

	JR Z, FSTXC7
	CP $F
	JR Z, FSTXC6
	LD (FTPXA0), A
	LD A, $37
	LD (FSTPC31), A
	LD A, (DE)
	INC DE
	LD L, A
	LD A, (DE)
	LD H, A
	LD (FSTPC30+1), HL
	OR $FF
	LD (FTRIN5+1), A
	LD L, A
	LD H, A
	LD (FTRIN6+1), HL
	JR FSTXC8

FSTXC6:

	LD A, $B7
	LD (FSTPC31), A
	JR FSTXC10

FSTXC7:

	LD A, $B7
	LD (FSTPC9), A
	JP FSTXC17

FSTXC8:

	INC DE

FSTXC10:

	LD A, (DE)
	INC DE
	ADD A, $13
	ADD A, $21
	JR C, FSTXC3
	ADD A, $6C
	JR C, FSTXC15
	ADD A, $20
	JR C, FSTXC2
	ADD A, $10
	JR C, FSTXC5
	ADD A, $10
	JR C, FSTXC14
	ADD A, $20
	JR C, FSTXC4
	ADD A, $13
	JR Z, FSTXC12
	DEC A
	JR Z, FSTXC11
	DEC A
	JR Z, FSTXC13
	LD A, (DE)
	LD (FSTPKNT), A
	LD (FSTPPL1+1), A
	JR FSTXC8

FSTXC11:

	LD A, (DE)
	LD (FTPORTC+1), A
	XOR A
	EX AF, AF'
	JR FSTXC8

FSTXC12:

	LD A, (DE)
	LD L, A
	INC DE
	LD A, (DE)
	LD H, A
	LD (FSTPC40+1), HL
	LD A, 1
	EX AF, AF'
	JR FSTXC8

FSTXC13:

	LD A, (DE)
	LD (FSTPC16+1), A
	JR FSTXC8

FSTXC14:

	CALL FTRVOLT1
	LD (FSTPC33+1), HL
	JP FSTXC10

FSTXC15:

	PUSH AF
	LD A, (FSTPC36+1)
	LD (FTRC2+1), A
	POP AF

FSTXC16:

	ADD A, 0
	LD (FSTPC36+1), A
	LD A, $37
	LD (FSTPC9), A

FSTXC17:

	XOR A
	LD (FSTPC11+1), A
	LD (FSTPC14+1), A
	LD (FSTPC21+1), A
	LD (FSTPC7+1), A
	LD (FSTPC5+1), A
	LD (FSTPC1+1), A
	LD H, A
	LD L, A
	LD (FSTPC18+1), HL
	LD (FSTPC28+1), HL
	EX AF, AF'
	LD C, A
	OR A
	RET Z
	LD (FSTPC39+1), HL
	DEC A
	LD A, $C3
	LD (FSTPC41), A
	RET Z
	LD (FSTPC40+1), HL
	RET

FSTPC:

	LD DE, 0                 ;smeshhenie C

FSTPC1:

	LD HL, 0
	LD A, L
	CP H
	JR NZ, FSTPC3

FSTPC2:

	LD L, 0
	LD A, L

FSTPC3:

	INC L
	LD (FSTPC1+1), HL
	ADD A, A
	ADD A, E
	LD E, A
	JR NC, FSTPC4
	INC D

FSTPC4:
	EX DE, HL
	LD (FSTPC35+1), SP
	LD SP, HL
	POP BC

FSTPC5:

	LD A, 0
	ADD A, B
	BIT 6, C
	JR Z, FSTPC6
	LD (FSTPC5+1), A

FSTPC6:

	LD (FSTPC37+1), A

FSTPC7:

	LD A, 0
	ADD A, C
	BIT 7, C
	JR Z, FSTPC8
	LD (FSTPC7+1), A

FSTPC8:

	LD (FSTPC17+1), A

FSTPC9:

	NOP
	JP NC, FSTPC43

FSTPC10:

	LD DE, 0

FSTPC11:

	LD HL, 0
	LD A, L
	CP H
	JR NZ, FSTPC13

FSTPC12:

	LD L, 0
	LD A, L

FSTPC13:

	INC L
	LD (FSTPC11+1), HL
	LD L, A
	LD C, A
	LD H, 0
	LD B, H
	ADD HL, HL
	ADD HL, HL
	ADD HL, BC
	ADD HL, DE
	LD SP, HL

FSTPC14:

	LD A, 0
	POP BC
	DEC SP
	ADD A, C
	BIT 7, C
	JR Z, FSTPC15
	LD (FSTPC14+1), A

FSTPC15:

	BIT 6, C
	LD E, ixl
	JR NZ, FSTPC18

FSTPC16:

	ADD A, 0

FSTPC17:

	ADD A, 0
	LD (FSTPABC), A
	RES 5, E

FSTPC18:

	LD HL, 0
	POP BC
	ADD HL, BC
	BIT 7, B
	JR Z, FSTPC19
	LD (FSTPC18+1), HL

FSTPC19:

	BIT 6, B
	JR NZ, FSTPC20
	RES 2, E

FSTPC20:

	LD ixl, E
	LD (FSTPC38+1), HL
	POP BC
	XOR A

FSTPC21:

	LD D, 0
	BIT 5, C
	JR Z, FSTPC25
	DEC A
	BIT 4, C
	JR NZ, FSTPC22
	AND 1

FSTPC22:

	ADD A, D
	JP P, FSTPC23
	CP $F1
	ADC A, 0
	JR FSTPC24

FSTPC23:

	CP $10
	ADC A, $FF

FSTPC24:

	LD (FSTPC21+1), A
	LD D, A

FSTPC25:

	LD A, C
	AND $F
	ADD A, D
	JP P, FSTPC26
	XOR A

FSTPC26:

	CP $10
	JR C, FSTPC27
	LD A, $F

FSTPC27:

	LD E, A

FSTPC28:

	LD HL, 0
	LD D, C
	LD C, B
	RLC B
	SBC A, A
	LD B, A
	ADD HL, BC
	BIT 7, D
	JR Z, FSTPC29
	LD (FSTPC28+1), HL

FSTPC29:

	OR A
	LD C, L
	LD B, H

FSTPC30:

	LD HL, 0
	SBC HL, BC
	XOR A
	BIT 6, D
	JR Z, FSTPC32

FSTPC31:

	NOP
	JR NC, FSTPC32
	LD (FTPA31HL), HL
	OR $10

FSTPC32:

	LD D, 0

FSTPC33:

	LD HL, 0
	ADD HL, DE
	OR (HL)

FSTPC34:

	LD (FSTPVC1), A

FSTPC35:

	LD SP, 0

FSTPC36:

	LD A, 0

FSTPC37:

	ADD A, 0

FSTPC38:

	LD DE, 0
	CALL FTRTONT1

FSTPC39:

	LD HL, 0

FSTPC40:

	LD BC, 0
	ADD HL, BC
	LD (FSTPC39+1), HL
	BIT 7, H

FSTPC41:

	JP FSTPC42
	ADD HL, DE
	LD (FSTPVC), DE
	LD HL, 0
	LD (FSTPC39+1), HL
	LD (FSTPC40+1), HL
	RET

FSTPC42:

	ADD HL, DE
	LD (FSTPVC), HL
	RET

FSTPC43:

	LD A, ixl
	OR $24
	LD ixl, A
	XOR A
	JR FSTPC34

;---------------------------init play---
FSTPINI:

	DI
	PUSH HL

;check table from module (adrmodul+#32)
;old ver. was #3B-set table to str (only)
;new ver. now #01-set table STR,  #02-set table 1.75mHz+

	LD HL, FSTT_175s
	LD A, (FTC_MODULE+$32)
	CP 2
	JR Z, $+5
	LD HL, FSTT_STR  ;depack tone table from HL
	LD DE, FSTTONTB  ;tontable place

make_ft:

	LD B, 12

mftr1:

	PUSH BC
	LD C, (HL)
	INC HL
	PUSH HL
	LD B, (HL)
	PUSH DE
	EX DE, HL
	LD DE, 23
	LD A, 8

mftr2:
	SRL B
	RR C
	LD (HL), C
	INC HL
	LD (HL), B
	ADD HL, DE
	DEC A
	JR NZ, mftr2
	POP DE
	INC DE
	INC DE
	POP HL
	INC HL
	POP BC
	DJNZ mftr1
	POP HL

;continue init

	PUSH HL
	LD BC, $45       ;mod+#45
	ADD HL, BC       ;tempo
	LD A, (HL)
	INC HL          ;loop
	LD (FSTPPL1+1), A
	LD A, 1
	LD (FSTPKNT), A
	LD A, (HL)
	ADD A, A
	POP BC
	LD HL, $D4
	LD E, A
	LD D, H
	ADD HL, BC
	LD (FTPATT+1), HL
	ADD HL, DE
	LD (FTPAT1+1), HL
	LD HL, $52
	ADD HL, BC
	LD (FSTPI6+1), SP
	PUSH HL
	LD (FSTXA4+1), HL
	LD (FSTXB4+1), HL
	LD (FSTXC4+1), HL
	LD HL, $92
	ADD HL, BC
	LD (FSTXA3+1), HL
	LD (FSTXB3+1), HL
	LD (FSTXC3+1), HL
	POP HL
	LD SP, HL
	INC HL
	LD A, (HL)
	CP $40
	JR NC, FSTPI2
	LD A, $41

FSTPI1:

	POP HL
	ADD HL, BC
	PUSH HL
	POP HL
	DEC A
	JR NZ, FSTPI1

FSTPI2:

	LD HL, $4B
	ADD HL, BC
	LD SP, HL
	POP HL
	ADD HL, BC
	LD (FTPAT3+1), HL
	LD SP, HL
	INC HL
	LD A, (HL)
	CP $40
	JR NC, FSTPI5

FSTPI3:

	POP HL
	LD A, H
	INC A
	JR NZ, FSTPI4
	LD A, L
	INC A
	JR Z, FSTPI5

FSTPI4:

	ADD HL, BC
	PUSH HL
	POP HL
	JR FSTPI3

FSTPI5:

	LD HL, $52
	ADD HL, BC
	LD (FSTPA10+1), HL
	LD (FSTPB10+1), HL
	LD (FSTPC10+1), HL
	LD HL, $92
	ADD HL,BC
	LD SP, HL
	POP HL
	LD (FSTPA+1), HL
	LD (FSTPB+1), HL
	LD (FSTPC+1), HL
	XOR A
	LD (FSTPA16+1), A
	LD (FSTPB16+1), A
	LD (FSTPC16+1), A
	LD (FSTPA7+1), A
	LD (FSTPB7+1), A
	LD (FSTPC7+1), A
	LD (FSTPA5+1), A
	LD (FSTPB5+1), A
	LD (FSTPC5+1), A
	LD (FSTPA2+1), A
	LD (FSTPB2+1), A
	LD (FSTPC2+1), A
	LD (FTPORTA+1), A
	LD (FTPORTB+1), A
	LD (FTPORTC+1), A
	LD HL, $100
	LD (FSTPA1+1), HL
	LD (FSTPB1+1), HL
	LD (FSTPC1+1), HL
	LD A, $B7
	LD (FSTPA9), A
	LD (FSTPB9), A
	LD (FSTPC9), A
	LD (FSTPA31), A
	LD (FSTPB31), A
	LD (FSTPC31), A
	LD HL, FSTPTB3
	LD (FSTPA33+1), HL
	LD (FSTPB33+1), HL
	LD (FSTPC33+1), HL
	LD HL, FTRIN3+1
	LD (FSTXA1+1), HL

FSTPI6:

	LD SP, 0
	JP FTRIN1

FTRTONT1:

	ADD A, A
	ADD A, FSTTONTB & $00ff   ;$d7;.FSTTONTB
	LD L, A
	ADC A, FSTTONTB >> 8   ;$c8;'FSTTONTB
	SUB L
	LD H, A
	LD A, (HL)
	INC HL
	LD H, (HL)
	LD L, A
	ADD HL, DE
	EX DE, HL
	RET

FTRPO1:

	ADD A, A
	LD C, A
	LD B, 0
	ADD HL, BC
	LD A,(HL)
	INC HL
	LD H, (HL)
	LD L, A
	RET

FTRVOLT1:

	ADD A, A
	ADD A, A
	ADD A, A
	ADD A, A
	ADD A, FSTVOLTB & $00ff   ;$af;.FSTVOLTB
	LD L,A
	ADC A, FSTVOLTB >> 8   ;$c9;'FSTVOLTB
	SUB L
	LD H,A
	RET

FTRTONT2:

	ADD A, A
	ADD A, FSTTONTB & $00ff   ;$d7;.FSTTONTB
	LD L, A
	ADC A, FSTTONTB >> 8   ;$c8;'FSTTONTB
	SUB L
	LD H, A
	RET

;classic table  (aka whittaker's, aka soundtracker's)
FSTT_STR:

	defw $0EF8*2,$0E10*2,$0D60*2,$0C80*2,$0BD8*2,$0B28*2
	defw $0A88*2,$09F0*2,$0960*2,$08E0*2,$0858*2,$07E0*2

;1.75+mHz table (aka sandrowski's)
FSTT_175s:

	defw 3344*2,3160*2,2976*2,2816*2,2656*2,2504*2
	defw 2368*2,2232*2,2112*2,1984*2,1872*2,1776*2

;tonetables places here
FSTTONTB:

	defs (192)         ;192 bytes for standart 8oktaves
                        ;216 bytes for 9oktaves
;space reserved for sub-contr octave
;we can remove it from player (i think :)
;;; DW 0,0,0,0,0,0,0,0,0,0,0,0

;volume table original
FSTVOLTB:

	defb 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	defb 0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1
	defb 0,0,0,0,1,1,1,1,1,1,1,1,2,2,2,2
	defb 0,0,0,1,1,1,1,1,2,2,2,2,2,3,3,3
	defb 0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4
	defb 0,0,1,1,1,2,2,2,3,3,3,4,4,4,5,5
	defb 0,0,1,1,2,2,2,3,3,4,4,4,5,5,6,6
	defb 0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7
	defb 0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8
	defb 0,1,1,2,2,3,4,4,5,5,6,7,7,8,8,9
	defb 0,1,1,2,3,3,4,5,5,6,7,7,8,9,9,$A
	defb 0,1,1,2,3,4,4,5,6,7,7,8,9,$A,$A,$B
	defb 0,1,2,2,3,4,5,6,6,7,8,9,$A,$A,$B,$C
	defb 0,1,2,3,3,4,5,6,7,8,9,$A,$A,$B,$C,$D
	defb 0,1,2,3,4,5,6,7,7,8,9,$A,$B,$C,$D,$E

FSTPTB3:

	defb 0,1,2,3,4,5,6,7,8,9,$A,$B,$C,$D,$E,$F

FTRIN1:

	LD BC, $1100
	LD HL, FSTPVA

FTRIN2:

	LD (HL), C
	INC HL
	DJNZ FTRIN2

FTRIN3:

	OR $FF
	LD (FTRIN5+1), A
	LD L, A
	LD H, A
	LD (FTRIN6+1), HL

FTRIN4:

	LD HL, FTPXA0
	LD C, $FD
	LD DE, $FFBF
	LD A, (HL)

FTRIN5:

	CP 0
	JR Z,FTRIN6
	LD (FTRIN5+1), A
	PUSH AF
	LD A, $D
	LD B, D
	OUT (C), A
	LD B, E
	POP AF
	OUT (C), A

FTRIN6:

	LD DE, 0
	LD HL, (FTPA31HL)
	OR A
	SBC HL, DE
	LD DE, $FFBF
	JR Z, FTRIN7
	LD HL, (FTPA31HL)
	LD (FTRIN6+1), HL
	LD A, $C
	LD B, D
	OUT (C), A
	LD B,E
	OUT (C), H
	DEC A
	LD B, D
	OUT (C), A
	LD B, E
	OUT (C), L

FTRIN7:

	LD HL, FSTPVC1
	LD A, $A
	LD B, D
	OUT (C),A
	LD B,E
	OUTD
	DEC A
	LD B, D
	OUT (C), A
	LD B, E
	OUTD
	DEC A
	LD B, D
	OUT (C), A
	LD B, E
	OUTD
	DEC A
	LD B, D
	OUT (C), A
	LD B, E
	OUTD
	DEC A
	LD B, D
	OUT (C), A
	LD B, E
	OUTD
	DEC A
	LD B, D
	OUT (C), A
	LD B, E
	OUTD
	DEC A
	LD B,D
	OUT (C), A
	LD B, E
	OUTD
	DEC A
	LD B, D
	OUT (C), A
	LD B, E
	OUTD
	DEC A
	LD B, D
	OUT (C), A
	LD B, E
	OUTD
	DEC A
	LD B, D
	OUT (C), A
	LD B, E
	OUTD
	DEC A
	LD B, D
	OUT (C), A
	LD B, E
	OUTD
	EI
	RET

FSTPVA:

	defw 0

FSTPVB:

	defw 0

FSTPVC:

	defw 0

FSTPABC:

	db 0

FTRCXV:

	db 0

FSTPVA1:

	db 0   ;volA

FSTPVB1:

	db 0   ;volB

FSTPVC1:

	db 0   ;volC

FTPA31HL:

	defw 0

FTPXA0:

	db 0

FTPXA1:

	db 0

FTPXB1:

	db 0

FTPXC1:

	db 0

FSTPKNT:

	db 0   ;kountdel

;place module here
;FSTMODULE       DISPLAY	"Module Adress:",FSTMODULE
;                DISPLAY	"Player Lenght:",FSTMODULE-PLAYAIN
;             INCBIN	"20SILENS.Y"        ;module file
;    ORG	#6000
;warn!   o6yazatel`no stav`te nomer sample v pattern kotory`j
;        6udet pervy`m v spiske positions

;-----------------------------------------


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

_ftc_id:

	defb "Fast Tracker v1."

_err_memory:

	defb "Out of memory!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

_err_invalid:

	defb "Not a valid .FTC file!", $0
