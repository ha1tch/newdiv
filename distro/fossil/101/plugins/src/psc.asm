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

DEFC PSC_MODULE=$c000
DEFC PSC_ID_LEN=8
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

	defb "PSC plugin - KVA, bob_fossil", $0

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

	ld a, (_plugin_file_handle)	; read file to PSC_MODULE address
	ld hl, PSC_MODULE

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_check

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_check:

	ld hl, PSC_MODULE		; offset for 'PSC V1.0'
	ld de, _psc_id
	ld b, PSC_ID_LEN
	call _strncmp			; check data is 'PSC V1.0'

	jr z, _plugin_check2

	ld bc, _err_invalid
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_check2:

	ld a, (PSC_MODULE + 8)
	cp $30
	jr nz, _plugin_init

					; 'PSC V1.00' isn't supported
	ld bc, _err_invalid2
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jr _plugin_error

_plugin_init:

	push ix

	call _PSC_INIT
	ei

	ld hl, _plugin_status_playing
	call _set_status_icon

	call _plugin_wait_for_no_keys

_plugin_playback:

	halt
	call _PSC_PLAY

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

	call _PSC_INIT

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

_PSC_INIT:

	LD HL,PSC_MODULE
	JP LC020

_PSC_PLAY:

	JP LC094

	; DEFB "PSC V1.20 PLAYER BY KVA"

LC020:
	LD (LC0B2 + 1), HL
	EX DE, HL
	LD HL, $004C
	ADD HL,DE
	LD (LC152 + 1), HL
	LD (LC25B + 1), HL
	LD (LC340 + 1), HL
	DEC HL
	DEC HL
	LD A, (HL)
	INC HL
	LD H, (HL)
	LD L, A
	ADD HL, DE
	LD (LC167 + 1), HL
	LD (LC26F + 1), HL
	LD (LC355 + 1), HL
	LD A, $18
	LD (LC3CD), A
	LD HL, $0000
	LD (LC92F + 1), HL
	LD (LC3E2 + 1), HL
	LD (LC4A0 + 1), HL
	XOR A
	LD (LC55E + 1), A
	LD (LC579 + 1), A
	LD (LC688 + 1), A
	LD (LC79D + 1), A
	INC A
	LD (LC0AA + 1), A
	LD A, $03
	LD (LC0A1 + 1), A
	PUSH DE
	POP IX
	LD A, (IX + 73)
	LD (LC3C2 + 1), A
	LD L, (IX + 71)
	LD H, (IX + 72)
	ADD HL,DE
	LD (LC0B5 + 1), HL
	LD HL, LCB9D
	LD B, $0D
	XOR A

LC081:

	LD (HL), A
	INC HL
	DJNZ LC081
	LD HL, LC0AA
	LD (LC0A7 + 1), HL
	LD IX, $0000
	ADD IX,SP
	JP LC8AF

LC094:

	LD IX, $0000
	ADD IX,SP
	LD BC,$3E18
	XOR A
	LD (LCBA4), A

LC0A1:

	LD A,$00
	DEC A
	LD (LC0A1 + 1),A

LC0A7:

	JP $0000

LC0AA:

	LD A, $00
	DEC A
	LD (LC0AA + 1), A
	JR NZ,LC0E3

LC0B2:

	LD DE,$0000

LC0B5:

	LD SP,$0000

LC0B8:

	POP AF
	CP $FF
	JR NZ, LC0C2
	POP HL
	ADD HL, DE
	LD SP, HL
	JR LC0B8

LC0C2:

	POP HL
	ADD HL, DE
	LD (LC0EE + 1), HL
	POP HL
	ADD HL, DE
	LD (LC1F9 + 1), HL
	POP HL
	ADD HL, DE
	LD (LC0B5 + 1), SP
	LD (LC2DC + 1), HL
	LD (LC0AA + 1), A
	LD A, $01
	LD (LC0E3 + 1), A
	LD (LC1EE + 1), A
	LD (LC2D1 + 1), A

LC0E3:

	LD A, $00
	LD BC, $0000
	DEC A
	LD (LC0E3 + 1), A
	JR NZ, LC107

LC0EE:

	LD HL, $0000

LC0F1:

	LD A, (HL)
	INC HL
	CP $7C
	JR C, LC11E
	CP $A0
	JR C, LC111
	CP $C0
	JR C, LC160
	SUB $BF
	LD (LC0E3 + 1), A
	LD (LC0EE + 1), HL

LC107:

	LD HL,LC1EE
	LD (LC92F + 1), BC
	JP LC3B8

LC111:

	CP $7E
	JR NC, LC14B
	CP $7D
	JR Z, LC13C
	LD B, $04
	JP LC0F1

LC11E:

	CP $67
	JR NC, LC175
	CP $57
	JR C, LC141
	SUB $57
	JR NZ, LC12C
	LD A, $0F

LC12C:

	LD (LC962 + 1), A
	LD A, $10
	JR Z, LC134
	XOR A

LC134:

	LD (LC967 + 1), A
	SET 6, B
	JP LC0F1

LC13C:

	SET 3, C
	JP LC0F1

LC141:

	LD (LC94D + 1), A
	SET 7, B
	SET 6, B
	JP LC0F1

LC14B:

	SUB $80
	ADD A, A
	EXX
	LD L,A
	LD H,$00

LC152:

	LD DE, $0000
	ADD HL, DE
	LD SP, HL
	POP HL
	ADD HL, DE
	LD (LC952 + 1), HL
	EXX
	JP LC0F1

LC160:

	SUB $A0
	ADD A, A
	EXX
	LD L, A
	LD H, $00

LC167:

	LD DE, $0000
	ADD HL, DE
	LD SP, HL
	POP HL
	ADD HL, DE
	LD (LC958 + 1), HL
	EXX
	JP LC0F1

LC175:

	SUB $6B
	JR Z, LC18F
	DEC A
	JR Z, LC193
	DEC A
	JR Z, LC1A2
	DEC A
	JR Z, LC1AC
	DEC A
	JR Z, LC1B4
	DEC A
	JR Z, LC1BA
	DEC A
	JR Z, LC1C4
	INC HL
	JP LC0F1

LC18F:

	LD A, $18
	JR LC195

LC193:

	LD A, $3E

LC195:

	LD (LC974), A
	SET 5, B
	LD A, (HL)
	LD (LC970 + 1), A
	INC HL
	JP LC0F1

LC1A2:

	SET 4, B
	LD A,(HL)
	INC HL
	LD (LC9A2 + 1), A
	JP LC0F1

LC1AC:

	LD A,(HL)
	INC HL
	LD (LC3C2 + 1), A
	JP LC0F1

LC1B4:

	SET 1, B
	INC HL
	JP LC0F1

LC1BA:

	SET 3, B
	LD A, (HL)
	INC HL
	LD (LC9BF + 1), A
	JP LC0F1

LC1C4:

	SET 0, C
	INC HL
	JP LC0F1

LC1CA:

	LD A,(HL)
	INC HL
	LD (LC55E + 1),A
	JR LC1FC

LC1D1:

	CP $7A
	JP C, LC27C
	JR NZ, LC1CA
	LD A, (HL)
	LD (LC3D5 + 1), A
	INC HL
	LD A, (HL)
	LD (LC3CF + 1), A
	INC HL
	LD A, (HL)
	LD (LC3CF + 2), A
	INC HL
	LD A, $3E
	LD (LC3CD), A
	JR LC1FC

LC1EE:

	LD A, $00
	LD BC, $0000
	DEC A
	LD (LC1EE + 1), A
	JR NZ,LC212

LC1F9:

	LD HL, $0000

LC1FC:

	LD A,(HL)
	INC HL
	CP $7C
	JR C, LC229
	CP $A0
	JR C, LC21C
	CP $C0
	JR C, LC268
	SUB $BF
	LD (LC1EE + 1), A
	LD (LC1F9 + 1), HL

LC212:

	LD   HL,LC2D1
	LD   (LC3E2 + 1),BC
	JP   LC3B8
LC21C:
	CP   $7E
	JR   NC,LC254
	CP   $7D
	JR   Z,LC247
	LD   B,$04
	JP   LC1FC
LC229:
	CP   $67
	JR   NC,LC1D1
	CP   $57
	JR   C,LC24B
	SUB  $57
	JR   NZ,LC237
	LD   A,$0F
LC237:
	LD   (LC415 + 1),A
	LD   A,$10
	JR   Z,LC23F
	XOR  A
LC23F:
	LD   (LC41A + 1),A
	SET  6,B
	JP   LC1FC
LC247:
	SET  3,C
	JR   LC1FC
LC24B:
	LD   (LC400 + 1),A
	SET  7,B
	SET  6,B
	JR   LC1FC
LC254:
	SUB  $80
	ADD  A,A
	EXX  
	LD   L,A
	LD   H,$00
LC25B:
	LD   DE,$0000
	ADD  HL,DE
	LD   SP,HL
	POP  HL
	ADD  HL,DE
	LD   (LC405 + 1),HL
	EXX  
	JR   LC1FC
LC268:
	SUB  $A0
	ADD  A,A
	EXX  
	LD   L,A
	LD   H,$00
LC26F:
	LD   DE,$0000
	ADD  HL,DE
	LD   SP,HL
	POP  HL
	ADD  HL,DE
	LD   (LC40B + 1),HL
	EXX  
	JR   LC1FC
LC27C:
	SUB  $6B
	JR   Z,LC296
	DEC  A
	JR   Z,LC29A
	DEC  A
	JR   Z,LC2A9
	DEC  A
	JR   Z,LC2B3
	DEC  A
	JR   Z,LC2BB
	DEC  A
	JR   Z,LC2C1
	DEC  A
	JR   Z,LC2CB
	INC  HL
	JP   LC1FC
LC296:
	LD   A,$18
	JR   LC29C
LC29A:
	LD   A,$3E
LC29C:
	LD   (LC427),A
	SET  5,B
	LD   A,(HL)
	LD   (LC423 + 1),A
	INC  HL
	JP   LC1FC
LC2A9:
	SET  4,B
	LD   A,(HL)
	INC  HL
	LD   (LC455 + 1),A
	JP   LC1FC
LC2B3:
	LD   A,(HL)
	INC  HL
	LD   (LC3C2 + 1),A
	JP   LC1FC
LC2BB:
	SET  1,B
	INC  HL
	JP   LC1FC
LC2C1:
	SET  3,B
	LD   A,(HL)
	INC  HL
	LD   (LC472 + 1),A
	JP   LC1FC
LC2CB:
	SET  0,C
	INC  HL
	JP   LC1FC
LC2D1:
	LD   A,$00
	LD   BC,$0000
	DEC  A
	LD   (LC2D1 + 1),A
	JR   NZ,LC2F5
LC2DC:
	LD   HL,$0000
LC2DF:
	LD   A,(HL)
	INC  HL
	CP   $7C
	JR   C,LC30C
	CP   $A0
	JR   C,LC2FF
	CP   $C0
	JR   C,LC34E
	SUB  $BF
	LD   (LC2D1 + 1),A
	LD   (LC2DC + 1),HL
LC2F5:
	LD   HL,LC3BB
	LD   (LC4A0 + 1),BC
	JP   LC3B8
LC2FF:
	CP   $7E
	JR   NC,LC339
	CP   $7D
	JR   Z,LC32A
	LD   B,$04
	JP   LC2DF
LC30C:
	CP   $67
	JR   NC,LC363
	CP   $57
	JR   C,LC32F
	SUB  $57
	JR   NZ,LC31A
	LD   A,$0F
LC31A:
	LD   (LC4D3 + 1),A
	LD   A,$10
	JR   Z,LC322
	XOR  A
LC322:
	LD   (LC4D8 + 1),A
	SET  6,B
	JP   LC2DF
LC32A:
	SET  3,C
	JP   LC2DF
LC32F:
	LD   (LC4BE + 1),A
	SET  7,B
	SET  6,B
	JP   LC2DF
LC339:
	SUB  $80
	ADD  A,A
	EXX  
	LD   L,A
	LD   H,$00
LC340:
	LD   DE,$0000
	ADD  HL,DE
	LD   SP,HL
	POP  HL
	ADD  HL,DE
	LD   (LC4C3 + 1),HL
	EXX  
	JP   LC2DF
LC34E:
	SUB  $A0
	ADD  A,A
	EXX  
	LD   L,A
	LD   H,$00
LC355:
	LD   DE,$0000
	ADD  HL,DE
	LD   SP,HL
	POP  HL
	ADD  HL,DE
	LD   (LC4C9 + 1),HL
	EXX  
	JP   LC2DF
LC363:
	SUB  $6B
	JR   Z,LC37D
	DEC  A
	JR   Z,LC381
	DEC  A
	JR   Z,LC390
	DEC  A
	JR   Z,LC39A
	DEC  A
	JR   Z,LC3A2
	DEC  A
	JR   Z,LC3A8
	DEC  A
	JR   Z,LC3B2
	INC  HL
	JP   LC2DF
LC37D:
	LD   A,$18
	JR   LC383
LC381:
	LD   A,$3E
LC383:
	LD   (LC4E5),A
	SET  5,B
	LD   A,(HL)
	LD   (LC4E1 + 1),A
	INC  HL
	JP   LC2DF
LC390:
	SET  4,B
	LD   A,(HL)
	INC  HL
	LD   (LC513 + 1),A
	JP   LC2DF
LC39A:
	LD   A,(HL)
	INC  HL
	LD   (LC3C2 + 1),A
	JP   LC2DF
LC3A2:
	SET  1,B
	INC  HL
	JP   LC2DF
LC3A8:
	SET  3,B
	LD   A,(HL)
	INC  HL
	LD   (LC530 + 1),A
	JP   LC2DF
LC3B2:
	SET  0,C
	INC  HL
	JP   LC0F1
LC3B8:
	LD   (LC0A7 + 1),HL
LC3BB:
	LD   A,(LC0A1 + 1)
	OR   A
	JP   NZ,LC575
LC3C2:
	LD   A,$03
	LD   (LC0A1 + 1),A
	LD   HL,LC0AA
	LD   (LC0A7 + 1),HL
LC3CD:
	JR   LC3E2
LC3CF:
	LD   HL,$0000
	LD   (LCBA8),HL
LC3D5:
	LD   A,$00
	LD   (LCB9C),A
	LD   (LCBAA),A
	LD   A,$18
	LD   (LC3CD),A
LC3E2:
	LD   BC,$0000
	LD   A,(LC688 + 1)
	OR   C
	LD   C,A
	RL   B
	JR   NC,LC411
	LD   C,$06
	LD   HL,$0000
	LD   (LC6DE + 1),HL
	LD   (LC6EC + 1),HL
	XOR  A
	LD   (LC690 + 1),A
	LD   (LC719 + 1),A
LC400:
	LD   A,$00
	LD   (LC688 + 2),A
LC405:
	LD   HL,$0000
	LD   (LC6DB + 1),HL
LC40B:
	LD   HL,$0000
	LD   (LC697 + 1),HL
LC411:
	RL   B
	JR   NC,LC41F
LC415:
	LD   A,$00
	LD   (LC727 + 1),A
LC41A:
	LD   A,$00
	LD   (LC74A + 1),A
LC41F:
	RL   B
	JR   NC,LC439
LC423:
	LD   L,$00
	LD   H,$00
LC427:
	JR   LC42F
	LD   H,$FF
	LD   A,L
	CPL  
	LD   L,A
	INC  HL
LC42F:
	LD   (LC6EF + 1),HL
	LD   A,$18
	LD   (LC6F3),A
	SET  4,C
LC439:
	RL   B
	JR   NC,LC46E
	LD   A,(LC688 + 2)
	ADD  A,A
	LD   L,A
	LD   H,$00
	LD   DE,LC9F0
	ADD  HL,DE
	LD   SP,HL
	POP  DE
	LD   HL,(LCB9F)
	OR   A
	SBC  HL,DE
	LD   (LC6EC + 1),HL
	LD   E,$30
LC455:
	LD   A,$00
	BIT  7,H
	LD   L,A
	LD   H,$00
	JR   NZ,LC465
	CPL  
	LD   L,A
	LD   H,$FF
	INC  HL
	LD   E,$38
LC465:
	LD   (LC6EF + 1),HL
	LD   A,E
	LD   (LC6F3),A
	SET  4,C
LC46E:
	RL   B
	JR   NC,LC48A
LC472:
	LD   A,$00
	LD   E,$04
	BIT  6,A
	JR   Z,LC480
	LD   E,$05
	OR   $80
	NEG  
LC480:
	LD   (LC719 + 1),A
	LD   (LC722 + 1),A
	LD   A,E
	LD   (LC721),A
LC48A:
	RL   B
	JR   NC,LC490
	LD   C,$00
LC490:
	RL   B
	JR   NC,LC496
	RES  1,C
LC496:
	LD   A,C
	LD   (LC688 + 1),A
	LD   HL,$0000
	LD   (LC3E2 + 1),HL
LC4A0:
	LD   BC,$0000
	LD   A,(LC79D + 1)
	OR   C
	LD   C,A
	RL   B
	JR   NC,LC4CF
	LD   C,$06
	LD   HL,$0000
	LD   (LC801 + 1),HL
	LD   (LC7F3 + 1),HL
	XOR  A
	LD   (LC7A5 + 1),A
	LD   (LC82F + 1),A
LC4BE:
	LD   A,$00
	LD   (LC79D + 2),A
LC4C3:
	LD   HL,$0000
	LD   (LC7F0 + 1),HL
LC4C9:
	LD   HL,$0000
	LD   (LC7AC + 1),HL
LC4CF:
	RL   B
	JR   NC,LC4DD
LC4D3:
	LD   A,$00
	LD   (LC83D + 1),A
LC4D8:
	LD   A,$00
	LD   (LC860 + 1),A
LC4DD:
	RL   B
	JR   NC,LC4F7
LC4E1:
	LD   L,$00
	LD   H,$00
LC4E5:
	JR   LC4ED
	LD   H,$FF
	LD   A,L
	CPL  
	LD   L,A
	INC  HL
LC4ED:
	LD   (LC804 + 1),HL
	LD   A,$18
	LD   (LC808),A
	SET  4,C
LC4F7:
	RL   B
	JR   NC,LC52C
	LD   A,(LC79D + 2)
	ADD  A,A
	LD   L,A
	LD   H,$00
	LD   DE,LC9F0
	ADD  HL,DE
	LD   SP,HL
	POP  DE
	LD   HL,(LCBA1)
	OR   A
	SBC  HL,DE
	LD   (LC801 + 1),HL
	LD   E,$30
LC513:
	LD   A,$00
	BIT  7,H
	LD   L,A
	LD   H,$00
	JR   NZ,LC523
	CPL  
	LD   L,A
	LD   H,$FF
	INC  HL
	LD   E,$38
LC523:
	LD   (LC804 + 1),HL
	LD   A,E
	LD   (LC808),A
	SET  4,C
LC52C:
	RL   B
	JR   NC,LC548
LC530:
	LD   A,$00
	LD   E,$04
	BIT  6,A
	JR   Z,LC53E
	LD   E,$05
	OR   $80
	NEG  
LC53E:
	LD   (LC82F + 1),A
	LD   (LC838 + 1),A
	LD   A,E
	LD   (LC837),A
LC548:
	RL   B
	JR   NC,LC54E
	LD   C,$00
LC54E:
	RL   B
	JR   NC,LC554
	RES  1,C
LC554:
	LD   A,C
	LD   (LC79D + 1),A
	LD   HL,$0000
	LD   (LC4A0 + 1),HL
LC55E:
	LD   L,$00
	LD   A,(LC581 + 1)
	ADD  A,L
	LD   (LC581 + 1),A
	LD   A,(LC690 + 1)
	ADD  A,L
	LD   (LC690 + 1),A
	LD   A,(LC7A5 + 1)
	ADD  A,L
	LD   (LC7A5 + 1),A
LC575:
	XOR  A
	LD   (LCBA5),A
LC579:
	LD   DE,$0000
	BIT  2,E
	JP   Z,LC684
LC581:
	LD   A,$00
	BIT  1,E
	JP   Z,LC5BC
LC588:
	LD   HL,$0000
	LD   SP,HL
	POP  BC
	ADD  A,C
	EX   AF,AF'
	LD   A,D
	ADD  A,B
	JP   P,LC596
	SUB  $AA
LC596:
	LD   D,A
	SUB  $56
	JR   C,LC59C
	LD   D,A
LC59C:
	LD   A,C
	RLA  
	JR   C,LC5A3
	LD   (LC5AA + 1),HL
LC5A3:
	RLA  
	JR   C,LC5B2
	BIT  0,E
	JR   NZ,LC5B0
LC5AA:
	LD   SP,$0000
	JP   LC5B7
LC5B0:
	RES  0,E
LC5B2:
	RLA
	JR   C,LC5B7
	RES  1,E
LC5B7:
	LD   (LC588 + 1),SP
	EX   AF,AF'
LC5BC:
	EX   AF,AF'
	LD   A,D
	LD   (LC579 + 2),A
	ADD  A,A
	LD   L,A
	LD   H,$00
	LD   A,E
	LD   DE,LC9F0
	ADD  HL,DE
	LD   SP,HL
	POP  BC
LC5CC:
	LD   SP,$0000
LC5CF:
	LD   DE,$0000
	POP  HL
	ADD  HL,DE
	LD   (LC5CF + 1),HL
	ADD  HL,BC
	BIT  4,A
	JR   Z,LC5EC
	EX   DE,HL
LC5DD:
	LD   HL,$0000
LC5E0:
	LD   BC,$0000
	ADD  HL,BC
LC5E4:
	JR   LC5E8
	RES  4,A
LC5E8:
	LD   (LC5DD + 1),HL
	ADD  HL,DE
LC5EC:
	LD   (LCB9D),HL
	POP  HL
	POP  DE
	LD   D,A
	LD   A,E
	AND  $09
	LD   (LCBA4),A
	LD   B,$00
	BIT  1,E
	JR   Z,LC5FF
	INC  B
LC5FF:
	BIT  2,E
	JR   Z,LC604
	DEC  B
LC604:
	LD   A,$00
	DEC  A
	JP   M,LC612
	JR   NZ,LC60F
LC60C:
	DEC  B
LC60D:
	LD   A,$00
LC60F:
	LD   (LC604 + 1),A
LC612:
	LD   A,$00
	ADD  A,B
	JP   P,LC619
	XOR  A
LC619:
	CP   $10
	JR   C,LC61F
	LD   A,$0F
LC61F:
	LD   (LC612 + 1),A
	RLCA 
	RLCA 
	RLCA 
	RLCA 
	ADD  A,H
	EXX  
	LD   L,A
	LD   H,$00
	LD   DE,LCA9C
	ADD  HL,DE
	LD   A,(HL)
	EXX  
	BIT  4,E
	JR   NZ,LC637
LC635:
	OR   $00
LC637: 
	LD   (LCBA5),A
	BIT  4,A
	JR   Z,LC650
	BIT  3,E
	JR   Z,LC650
	LD   A,L
	RLA  
	SBC  A,A
	LD   H,A
	LD   BC,(LCBA8)
	ADD  HL,BC
	LD   (LCBA8),HL
	JR   LC65A
LC650:
	EX   AF,AF'
	ADD  A,L
	BIT  3,E
	JR   NZ,LC659
	LD   (LCBA3),A
LC659:
	EX   AF,AF'
LC65A:
	LD   A,E
	RLA  
	JR   C,LC664
	LD   HL,(LC5CC + 1)
	LD   (LC66B + 1),HL
LC664:
	RLA
	JR   C,LC673
	BIT  3,D
	JR   NZ,LC671
LC66B:
	LD   SP,$0000
	JP   LC678
LC671:
	RES  3,D
LC673:
	RLA 
	JR   C,LC678
	RES  2,D
LC678:
	LD   (LC5CC + 1),SP
	LD   A,D
	LD   (LC579 + 1),A
	EX   AF,AF'
	LD   (LC581 + 1),A
LC684:
	XOR  A
	LD   (LCBA6),A
LC688:
	LD   DE,$0000
	BIT  2,E
	JP   Z,LC799
LC690:
	LD   A,$00
	BIT  1,E
	JP   Z,LC6CB
LC697:
	LD   HL,$0000
	LD   SP,HL
	POP  BC
	ADD  A,C
	EX   AF,AF'
	LD   A,D
	ADD  A,B
	JP   P,LC6A5
	SUB  $AA
LC6A5:
	LD   D,A
	SUB  $56
	JR   C,LC6AB
	LD   D,A
LC6AB:
	LD   A,C
	RLA  
	JR   C,LC6B2
	LD   (LC6B9 + 1),HL
LC6B2:
	RLA  
	JR   C,LC6C1
	BIT  0,E
	JR   NZ,LC6BF
LC6B9:
	LD   SP,$0000
	JP   LC6C6
LC6BF:
	RES  0,E
LC6C1:
	RLA  
	JR   C,LC6C6
	RES  1,E
LC6C6:
	LD   (LC697 + 1),SP
	EX   AF,AF'
LC6CB:
	EX   AF,AF'
	LD   A,D
	LD   (LC688 + 2),A
	ADD  A,A
	LD   L,A
	LD   H,$00
	LD   A,E
	LD   DE,LC9F0
	ADD  HL,DE
	LD   SP,HL
	POP  BC
LC6DB:
	LD   SP,$0000
LC6DE:
	LD   DE,$0000
	POP  HL
	ADD  HL,DE
	LD   (LC6DE + 1),HL
	ADD  HL,BC
	BIT  4,A
	JR   Z,LC6FB
	EX   DE,HL
LC6EC:
	LD   HL,$0000
LC6EF:
	LD   BC,$0000
	ADD  HL,BC
LC6F3:
	JR   LC6F7
	RES  4,A
LC6F7:
	LD   (LC6EC + 1),HL
	ADD  HL,DE
LC6FB:
	LD   (LCB9F),HL
	POP  HL
	POP  DE
	LD   D,A
	LD   A,E
	RLA  
	AND  $12
	LD   C,A
	LD   A,(LCBA4)
	OR   C
	LD   (LCBA4),A
	LD   B,$00
	BIT  1,E
	JR   Z,LC714
	INC  B
LC714:
	BIT  2,E
	JR   Z,LC719
	DEC  B
LC719:
	LD   A,$00
	DEC  A
	JP   M,LC727
	JR   NZ,LC724
LC721:
	DEC  B
LC722:
	LD   A,$00
LC724:
	LD   (LC719 + 1),A
LC727:
	LD   A,$00
	ADD  A,B
	JP   P,LC72E
	XOR  A
LC72E:
	CP   $10
	JR   C,LC734
	LD   A,$0F
LC734:
	LD   (LC727 + 1),A
	RLCA 
	RLCA 
	RLCA 
	RLCA 
	ADD  A,H
	EXX  
	LD   L,A
	LD   H,$00
	LD   DE,LCA9C
	ADD  HL,DE
	LD   A,(HL)
	EXX  
	BIT  4,E
	JR   NZ,LC74C
LC74A:
	OR   $00
LC74C:
	LD   (LCBA6),A
	BIT  4,A
	JR   Z,LC765
	BIT  3,E
	JR   Z,LC765
	LD   A,L
	RLA  
	SBC  A,A
	LD   H,A
	LD   BC,(LCBA8)
	ADD  HL,BC
	LD   (LCBA8),HL
	JR   LC76F
LC765:
	EX   AF,AF'
	ADD  A,L
	BIT  3,E
	JR   NZ,LC76E
	LD   (LCBA3),A
LC76E:
	EX   AF,AF'
LC76F:
	LD   A,E
	RLA  
	JR   C,LC779
	LD   HL,(LC6DB + 1)
	LD   (LC780 + 1),HL
LC779:
	RLA  
	JR   C,LC788
	BIT  3,D
	JR   NZ,LC786
LC780:
	LD   SP,$0000
	JP   LC78D
LC786:
	RES  3,D
LC788:
	RLA  
	JR   C,LC78D
	RES  2,D
LC78D:
	LD   (LC6DB + 1),SP
	LD   A,D
	LD   (LC688 + 1),A
	EX   AF,AF'
	LD   (LC690 + 1),A
LC799:
	XOR  A
	LD   (LCBA7),A
LC79D:
	LD   DE,$0000
	BIT  2,E
	JP   Z,LC8AF
LC7A5:
	LD   A,$00
	BIT  1,E
	JP   Z,LC7E0
LC7AC:
	LD   HL,$0000
	LD   SP,HL
	POP  BC
	ADD  A,C
	EX   AF,AF'
	LD   A,D
	ADD  A,B
	JP   P,LC7BA
	SUB  $AA
LC7BA:
	LD   D,A
	SUB  $56
	JR   C,LC7C0
	LD   D,A
LC7C0:
	LD   A,C
	RLA  
	JR   C,LC7C7
	LD   (LC7CE + 1),HL
LC7C7:
	RLA  
	JR   C,LC7D6
	BIT  0,E
	JR   NZ,LC7D4
LC7CE:
	LD   SP,$0000
	JP   LC7DB
LC7D4:
	RES  0,E
LC7D6:
	RLA  
	JR   C,LC7DB
	RES  1,E
LC7DB:
	LD   (LC7AC + 1),SP
	EX   AF,AF'
LC7E0:
	EX   AF,AF'
	LD   A,D
	LD   (LC79D + 2),A
	ADD  A,A
	LD   L,A
	LD   H,$00
	LD   A,E
	LD   DE,LC9F0
	ADD  HL,DE
	LD   SP,HL
	POP  BC
LC7F0:
	LD   SP,$0000
LC7F3:
	LD   DE,$0000
	POP  HL
	ADD  HL,DE
	LD   (LC7F3 + 1),HL
	ADD  HL,BC
	BIT  4,A
	JR   Z,LC810
	EX   DE,HL
LC801:
	LD   HL,$0000
LC804:
	LD   BC,$0000
	ADD  HL,BC
LC808:
	JR   LC80C
	RES  4,A
LC80C:
	LD   (LC801 + 1),HL
	ADD  HL,DE
LC810:
	LD   (LCBA1),HL
	POP  HL
	POP  DE
	LD   D,A
	LD   A,E
	RLA  
	RLA  
	AND  $24
	LD   C,A
	LD   A,(LCBA4)
	OR   C
	LD   (LCBA4),A
	LD   B,$00
	BIT  1,E
	JR   Z,LC82A
	INC  B
LC82A:
	BIT  2,E
	JR   Z,LC82F
	DEC  B
LC82F:
	LD   A,$00
	DEC  A
	JP   M,LC83D
	JR   NZ,LC83A
LC837:
	DEC  B
LC838:
	LD   A,$00
LC83A:
	LD   (LC82F + 1),A
LC83D:
	LD   A,$00
	ADD  A,B
	JP   P,LC844
	XOR  A
LC844:
	CP   $10
	JR   C,LC84A
	LD   A,$0F
LC84A:
	LD   (LC83D + 1),A
	RLCA 
	RLCA 
	RLCA 
	RLCA 
	ADD  A,H
	EXX  
	LD   L,A
	LD   H,$00
	LD   DE,LCA9C
	ADD  HL,DE
	LD   A,(HL)
	EXX  
	BIT  4,E
	JR   NZ,LC862
LC860:
	OR   $00
LC862:
	LD   (LCBA7),A
	BIT  4,A
	JR   Z,LC87B
	BIT  3,E
	JR   Z,LC87B
	LD   A,L
	RLA  
	SBC  A,A
	LD   H,A
	LD   BC,(LCBA8)
	ADD  HL,BC
	LD   (LCBA8),HL
	JR   LC885
LC87B:
	EX   AF,AF'
	ADD  A,L
	BIT  3,E
	JR   NZ,LC884
	LD   (LCBA3),A
LC884:
	EX   AF,AF'
LC885:
	LD   A,E
	RLA  
	JR   C,LC88F
	LD   HL,(LC7F0 + 1)
	LD   (LC896 + 1),HL
LC88F:
	RLA  
	JR   C,LC89E
	BIT  3,D
	JR   NZ,LC89C
LC896:
	LD   SP,$0000
	JP   LC8A3
LC89C:
	RES  3,D
LC89E:
	RLA  
	JR   C,LC8A3
	RES  2,D
LC8A3:
	LD   (LC7F0 + 1),SP
	LD   A,D
	LD   (LC79D + 1),A
	EX   AF,AF'
	LD   (LC7A5 + 1),A
LC8AF:
	LD   DE,$FFBF
	LD   C,$FD
	LD   A,(LCBAA)
	CP   $FF
	LD   HL,LCBA9
	LD   A,$0C
	JR   Z,LC8C9
	INC  HL
	INC  A
	LD   B,D
	OUT  (C),A
	LD   B,E
	OUTD 
	DEC  A

LC8C9:
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
	LD A, $FF
	LD (LCBAA), A
	LD A, (LC0A1 + 1)
	DEC A
	JP NZ,LC9ED

LC92F:

	LD BC, $0000
	LD A, (LC579 + 1)
	OR C
	LD C, A
	RL B
	JR NC, LC95E
	LD C, $06
	LD HL, $0000
	LD (LC5CF + 1), HL
	LD (LC5DD + 1), HL
	XOR A
	LD (LC581 + 1), A
	LD (LC604 + 1), A

LC94D:

	LD A,$00
	LD (LC579 + 2), A

LC952:

	LD HL, $0000
	LD (LC5CC + 1), HL

LC958:

	LD HL, $0000
	LD (LC588 + 1), HL

LC95E:
	RL B
	JR NC, LC96C

LC962:

	LD A,$00
	LD (LC612 + 1), A

LC967:

	LD A, $00
	LD (LC635 + 1), A

LC96C:

	RL B
	JR NC, LC986

LC970:

	LD L, $00
	LD H, $00

LC974:

	JR LC97C
	LD H, $FF
	LD A, L
	CPL
	LD L, A
	INC HL

LC97C:

	LD (LC5E0 + 1), HL
	LD A, $18
	LD (LC5E4), A
	SET 4, C

LC986:

	RL B
	JR NC, LC9BB
	LD A, (LC579 + 2)
	ADD A, A
	LD L, A
	LD H, $00
	LD DE, LC9F0
	ADD HL, DE
	LD SP, HL
	POP DE
	LD HL, (LCB9D)
	OR A
	SBC HL, DE
	LD (LC5DD + 1), HL
	LD E, $30

LC9A2:

	LD A,$00
	BIT 7, H
	LD L, A
	LD H, $00
	JR NZ, LC9B2
	CPL
	LD L, A
	LD H, $FF
	INC HL
	LD E, $38

LC9B2:

	LD (LC5E0 + 1), HL
	LD A, E
	LD (LC5E4), A
	SET 4, C

LC9BB:

	RL B
	JR NC, LC9D7

LC9BF:

	LD A, $00
	LD E, $04
	BIT 6, A
	JR Z, LC9CD
	LD E, $05
	OR $80
	NEG

LC9CD:

	LD (LC604 + 1), A
	LD (LC60D + 1), A
	LD A, E
	LD (LC60C), A

LC9D7:

	RL B
	JR NC, LC9DD
	LD C, $00

LC9DD:

	RL B
	JR NC, LC9E3
	RES 1,C

LC9E3:

	LD A, C
	LD (LC579 + 1), A
	LD HL, $0000
	LD (LC92F + 1), HL

LC9ED:

	LD SP,IX
	DEFB $C9

LC9F0:

	DEFB $DC,$0E,$07
	DEFB $0E,">",$0D
	DEFB $80,$0C,$CC
	DEFB $0B,$22,$0B
	DEFB $82,$0A,$EC
	DEFB $09,$5C,$09
	DEFB $D6,$08,"X"
	DEFB $08,$E0,$07
	DEFB "n",$07,$04
	DEFB $07,$9F,$06
	DEFB "@",$06,$E6
	DEFB $05,$91,$05
	DEFB "A",$05,$F6
	DEFB $04,$AE,$04
	DEFB "k",$04,","
	DEFB $04,$F0,$03
	DEFB $B7,$03,$82
	DEFB $03,"O",$03
	DEFB " ",$03,$F3
	DEFB $02,$C8,$02
	DEFB $A1,$02,"{"
	DEFB $02,"W",$02
	DEFB "6",$02,$16
	DEFB $02,$F8,$01
	DEFB $DC,$01,$C1
	DEFB $01,$A8,$01
	DEFB $90,$01,"y"
	DEFB $01,"d",$01
	DEFB "P",$01,"="
	DEFB $01,",",$01
	DEFB $1B,$01,$0B
	DEFB $01,$FC,$00
	DEFB $EE,$00,$E0
	DEFB $00,$D4,$00
	DEFB $C8,$00,$BD
	DEFB $00,$B2,$00
	DEFB $A8,$00,$9F
	DEFB $00,$96,$00
	DEFB $8D,$00,$85
	DEFB $00,"~",$00
	DEFB "w",$00,"p"
	DEFB $00,"j",$00
	DEFB "d",$00,"^"
	DEFB $00,"Y",$00
	DEFB "T",$00,"P"
	DEFB $00,"K",$00
	DEFB "G",$00,"C"
	DEFB $00,"?",$00
	DEFB "<",$00,"8"
	DEFB $00,"5",$00
	DEFB "2",$00,"/"
	DEFB $00,"-",$00
	DEFB "*",$00,"("
	DEFB $00,"&",$00
	DEFB "$",$00,$22
	DEFB $00," ",$00
	DEFB $1E,$00,$1C
	DEFB $00

LCA9C:

	DEFB $00,$00,$00
	DEFB $00,$00,$00
	DEFB $00,$00,$00
	DEFB $00,$00,$00
	DEFB $00,$00,$00
	DEFB $00,$00,$00
	DEFB $00,$00,$00
	DEFB $00,$00,$00
	DEFB $01,$01,$01
	DEFB $01,$01,$01
	DEFB $01,$01,$00
	DEFB $00,$00,$00
	DEFB $00,$00,$01
	DEFB $01,$01,$01
	DEFB $01,$02,$02
	DEFB $02,$02,$02
	DEFB $00,$00,$00
	DEFB $00,$01,$01
	DEFB $01,$01,$02
	DEFB $02,$02,$02
	DEFB $03,$03,$03
	DEFB $03,$00,$00
	DEFB $00,$00,$01
	DEFB $01,$01,$02
	DEFB $02,$02,$03
	DEFB $03,$03,$04
	DEFB $04,$04,$00
	DEFB $00,$00,$01
	DEFB $01,$01,$02
	DEFB $02,$03,$03
	DEFB $03,$04,$04
	DEFB $04,$05,$05
	DEFB $00,$00,$00
	DEFB $01,$01,$02
	DEFB $02,$03,$03
	DEFB $03,$04,$04
	DEFB $05,$05,$06
	DEFB $06,$00,$00
	DEFB $01,$01,$02
	DEFB $02,$03,$03
	DEFB $04,$04,$05
	DEFB $05,$06,$06
	DEFB $07,$07,$00
	DEFB $00,$01,$01
	DEFB $02,$02,$03
	DEFB $03,$04,$05
	DEFB $05,$06,$06
	DEFB $07,$07,$08
	DEFB $00,$00,$01
	DEFB $01,$02,$03
	DEFB $03,$04,$05
	DEFB $05,$06,$06
	DEFB $07,$08,$08
	DEFB $09,$00,$00
	DEFB $01,$02,$02
	DEFB $03,$04,$04
	DEFB $05,$06,$06
	DEFB $07,$08,$08
	DEFB $09,$0A,$00
	DEFB $00,$01,$02
	DEFB $03,$03,$04
	DEFB $05,$06,$06
	DEFB $07,$08,$09
	DEFB $09,$0A,$0B
	DEFB $00,$00,$01
	DEFB $02,$03,$04
	DEFB $04,$05,$06
	DEFB $07,$08,$08
	DEFB $09,$0A,$0B
	DEFB $0C,$00,$00
	DEFB $01,$02,$03
	DEFB $04,$05,$06
	DEFB $07,$07,$08
	DEFB $09,$0A,$0B
	DEFB $0C,$0D,$00
	DEFB $00,$01,$02
	DEFB $03,$04,$05
	DEFB $06,$07,$08
	DEFB $09,$0A,$0B
	DEFB $0C,$0D,$0E
	DEFB $00,$01,$02
	DEFB $03,$04,$05
	DEFB $06,$07,$08
	DEFB $09,$0A,$0B
	DEFB $0C,$0D,$0E
	DEFB $0F

LCB9C:
	DEFB $00
LCB9D:
	DEFB $00,$00
LCB9F:
	DEFB $00,$00
LCBA1:
	DEFB $00,$00
LCBA3:
	DEFB $00
LCBA4:
	DEFB $00
LCBA5:
	DEFB $00
LCBA6:
	DEFB $00
LCBA7:
	DEFB $00
LCBA8:
	DEFB $00
LCBA9:
	DEFB $00
LCBAA:
	DEFB $00

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


_psc_id:

	defb "PSC V1.0"

_err_memory:

	defb "Out of memory!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

_err_invalid:

	defb "Not a valid .PSC file!", $0

_err_invalid2:

	defb "PSC v1.00 playback not supported!", $0
