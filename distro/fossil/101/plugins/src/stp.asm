;******************************************************************************
;*
;* Copyright(c) 2020-23 Bob Fossil. All rights reserved.
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

DEFC _stp_data=0xc000
DEFC MAX_SIZE=16384
;DEFC STC_ID_LEN=18

	org PLUGIN_ORG

	jr _plugin_start

_plugin_info:

	defb "BP"				; id
	defb 0					; spare
	defb 0					; spare
	defb PLUGIN_FLAGS1_COPY_SETTINGS	; flags
	defb 0					; flags2

_plugin_user_data:

	defs(PLUGIN_SETTING_MAX)		; reserve space for settings copy

_plugin_id_string:

	defb ".STP file plugin - VfNG/NEW'97 / bob_fossil", $0

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

	ld a, (_plugin_file_handle)	; read file to _stp_data address
	ld hl, _stp_data

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_check

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_check:

;	push hl
;	ld hl, stc_data + 7		; offset for 'SONG BY ST COMPILE'
;	ld de, _stc_id
;	ld b, STC_ID_LEN
;	call _strncmp			; check data + 7 is 'SONG BY ST COMPILE'
;
;	pop hl
;	jr z, _plugin_init
;
;	ld bc, _err_invalid
;	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
;	ld (_plugin_error_ret + 1), a
;	jr _plugin_error

_plugin_init:

	push ix

	ei

	ld hl, _stp_data
	call INIT

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

	call SILENCE

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
;-----------------------------------------
;SOUND TRACKER PRO PLAYER
;DECOMPILED BY VfNG/NEW'97 FOR ECHO-3!
;THANX 2 STALKER 4 XLNT DIZASSEMBLER!
;-----------------------------------------
;MUSIC  EQU     adres skompilirovanogo
;               bloka
;-----------------------------------------
LLC000:
	LD      HL, _stp_data
;        JP      INIT        ;iniczializacziya
;        JP      PLAY        ;proigry`vanie
;        LD      BC,(LLC0FF) ;vy`klyuchenie
;        JP      SILENCE
;;-----------------------------------------
;        DEFB    $00
;        DEFB    "SOUND TRACKER PRO"
;-----------------------------------------
LLC046:
	DEFB $00,$00,$00
LLC049:
	DEFB $70,$80,$F1,$D0,$00
;-----------------------------------------
INIT:
	DI
	LD      (LLC0F0),HL
	LD      A,$FC
	LD      (LLC49C),A
	LD      (LLC506),A
	LD      (LLC573),A
	LD      A,(HL)
	INC     HL
	LD      (LLC114),A
	CALL    LLC0EA
	LD      A,(HL)
	LD      (LLC678),A
	INC     HL
	LD      A,(HL)
	LD      (LLC67C),A
	INC     HL
	LD      (LLC682),HL
	CALL    LLC0E9
	LD      (LLC68A),HL
	PUSH    HL
	CALL    LLC0E9
	LD      (LLC3A3),HL
	LD      (LLC2B3),HL
	LD      (LLC1CD),HL
	CALL    LLC0E9
	LD      (LLC344),HL
	LD      (LLC254),HL
	LD      (LLC180),HL
	EX      DE,HL
	LD      A,(HL)
	LD      (HL),$00
	POP     HL
	OR      A
	JR      Z,LLC0A6
LLC099:
	CALL    LLC0EA
	EX      DE,HL
	DEC     HL
	LD      (HL),D
	DEC     HL
	LD      (HL),E
	INC     HL
	INC     HL
	DEC     A
	JR      NZ,LLC099
LLC0A6:
	LD      HL,LLC049
	LD      C,$03
	LD      (LLC2E5),HL
	LD      (LLC1F5),HL
	LD      (LLC11B),HL
	LD      H,A
	LD      L,A
	LD      (LLC427),HL
	LD      (LLC3E3),HL
	LD      (LLC421),HL
	LD      (LLC3DD),HL
	LD      (LLC10B),A
	DEC     A
	LD      (LLC675),A
SILENCE:
	XOR     A
	LD      (LLC5D3),A
	LD      HL,LLC0F4
	LD      B,$0D
LLC0D2:
	LD      (HL),A
	INC     HL
	DJNZ    LLC0D2
	LD      A,C
	LD      (LLC0FF),A
	LD      BC,$FFFD
	LD      A,$0C
	OUT     (C),A
	XOR     A
	LD      B,$BF
	OUT     (C),A
	JP      LLC5C5
LLC0E9:
	EX      DE,HL
LLC0EA:
	LD      E,(HL)
	INC     HL
	LD      D,(HL)
	INC     HL
	EX      DE,HL
	LD      BC,$0000
LLC0F0: EQU     $-2
        ADD     HL,BC
        RET
;-----------------------------------------
LLC0F4:
	DEFB    $00,$00
LLC0F6:
	DEFB    $00,$00
LLC0F8:
	DEFB    $00,$00
LLC0FA:
	DEFB    $00
LLC0FB:
	DEFB    $00
LLC0FC:
	DEFB    $00
LLC0FD:
	DEFB    $00
LLC0FE:
	DEFB    $00
LLC0FF:
	DEFB    $00
LLC100:
	DEFB    $00
;-----------------------------------------
PLAY:
	DI
	LD      (LLC5C3),SP
	LD      D,$00
	EXX
	LD      BC,$60F0
LLC10B: EQU     $-1
	LD      HL,LLC0FF
	DEC     (HL)
	JP      NZ,LLC1E8
	LD      (HL),$00
LLC114: EQU     $-1
	INC     HL
	DEC     (HL)
	JP      P,LLC3D0
	LD      HL,LLC000
LLC11B: EQU     $-2
	OR      (HL)
	JP      Z,LLC3D0
LLC121:
	LD      A,(HL)
	INC     HL
	CP      $C0
	JR      C,LLC134
	SUB     C
	JR      NC,LLC162
	SUB     C
	JR      NC,LLC16B
	SUB     C
	JR      NC,LLC171
	SUB     C
	JP      LLC19F
LLC134:
	SUB     $80
	JR      NC,LLC199
	SUB     C
	JP      NC,LLC1C4
	SBC     A,C
	JR      NC,LLC17C
	ADD     A,B
	LD      (LLC569),A
	LD      (LLC11B),HL
	XOR     A
	LD      (LLC573),A
	LD      (LLC557),A
	LD      L,A
	LD      H,A
	LD      (LLC5AF),HL
	JP      LLC3CB
LLC155:
	LD      A,(HL)
	INC     HL
	LD      (LLC5B2),A
	RLA
	SBC     A,A
	LD      (LLC5B3),A
	JP      LLC121
LLC162:
	JR      Z,LLC155
	DEC     A
	LD      (LLC58F),A
	JP      LLC121
LLC16B:
	LD      (LLC11B),HL
	JP      LLC3CB
LLC171:
	LD      A,$FC
	LD      (LLC573),A
	LD      (LLC11B),HL
	JP      LLC3CB
LLC17C:
	ADD     A,A
	EXX
	LD      E,A
	LD      HL,LLC000
LLC180: EQU     $-2
	ADD     HL,DE
	LD      SP,HL
	POP     HL
	LD      A,(HL)
	ADD     A,A
	ADD     A,A
	LD      (LLC584),A
	INC     HL
	LD      A,(HL)
	ADD     A,A
	ADD     A,A
	LD      (LLC580),A
	LD      (LLC575),HL
	EXX
	JP      LLC121
LLC199:
	LD      (LLC3CC),A
	JP      LLC121
LLC19F:
	LD      (LLC459),A
	LD      A,$1F
	LD      (LLC59B),A
	LD      A,(HL)
	INC     HL
	LD      (LLC45E),A
	LD      DE,LLC046
	LD      (LLC55A),DE
	XOR     A
	LD      (LLC564),A
	LD      (LLC5B2),A
	LD      (LLC5B3),A
	INC     A
	LD      (LLC560),A
	JP      LLC121
LLC1C4:
	ADD     A,A
	EXX
	LD      E,A
	LD      A,$0F
	LD      (LLC59B),A
	LD      HL,LLC000
LLC1CD: EQU     $-2
	ADD     HL,DE
	LD      SP,HL
	POP     HL
	LD      A,(HL)
	LD      (LLC564),A
	INC     HL
	LD      A,(HL)
	LD      (LLC560),A
	INC     HL
	LD      (LLC55A),HL
	LD      L,D
	LD      H,D
	LD      (LLC5B2),HL
	EXX
	JP      LLC121
LLC1E8:
	LD      A,(HL)
	DEC     A
	JP      NZ,LLC2DB
	LD      HL,LLC0FD
	DEC     (HL)
	JP      P,LLC47F
	LD      HL,LLC000
LLC1F5: EQU     $-2
	OR      (HL)
	JP      Z,LLC47F
LLC1FB:
	LD      A,(HL)
	INC     HL
	CP      $C0
	JR      C,LLC20E
	SUB     C
	JR      NC,LLC236
	SUB     C
	JR      NC,LLC23F
	SUB     C
	JR      NC,LLC245
	SUB     C
	JP      LLC273
LLC20E:
	SUB     $80
	JR      NC,LLC26D
	SUB     C
	JP      NC,LLC2AA
	SBC     A,C
	JR      NC,LLC250
	ADD     A,B
	LD      (LLC407),A
	LD      (LLC1F5),HL
	XOR     A
	LD      (LLC40C),A
	LD      L,A
	LD      H,A
	LD      (LLC3DD),HL
	LD      A,$22
	LD      (LLC3DF),A
	LD      A,$32
	LD      (LLC469),A
	JP      LLC2D3
LLC236:
	JR      Z,LLC29D
	DEC     A
	LD      (LLC3FD),A
	JP      LLC1FB
LLC23F:
	LD      (LLC1F5),HL
	JP      LLC2D3
LLC245:
	LD      A,$FC
	LD      (LLC40C),A
	LD      (LLC1F5),HL
	JP      LLC2D3
LLC250:
	ADD     A,A
	EXX
	LD      E,A
	LD      HL,LLC000
LLC254: EQU     $-2
	ADD     HL,DE
	LD      SP,HL
	POP     HL
	LD      A,(HL)
	ADD     A,A
	ADD     A,A
	LD      (LLC3F8),A
	INC     HL
	LD      A,(HL)
	ADD     A,A
	ADD     A,A
	LD      (LLC3EE),A
	LD      (LLC3D1),HL
	EXX
	JP      LLC1FB
LLC26D:
	LD      (LLC2D4),A
	JP      LLC1FB
LLC273:
	LD      (LLC459),A
	LD      A,$1F
	LD      (LLC402),A
	LD      A,(HL)
	INC     HL
	LD      (LLC45E),A
	LD      DE,LLC046
	LD      (LLC3D7),DE
	LD      A,$22
	LD      (LLC3E5),A
	XOR     A
	LD      (LLC3F3),A
	LD      (LLC3E3),A
	LD      (LLC3E4),A
	INC     A
	LD      (LLC3E9),A
	JP      LLC1FB
LLC29D:
	LD      A,(HL)
	INC     HL
	LD      (LLC3E3),A
	RLA
	SBC     A,A
	LD      (LLC3E4),A
	JP      LLC1FB
LLC2AA:
	ADD     A,A
	EXX
	LD      E,A
	LD      A,$0F
	LD      (LLC402),A
	LD      HL,LLC000
LLC2B3: EQU     $-2
	ADD     HL,DE
	LD      SP,HL
	POP     HL
	LD      A,(HL)
	LD      (LLC3F3),A
	INC     HL
	LD      A,(HL)
	LD      (LLC3E9),A
	INC     HL
	LD      (LLC3D7),HL
	LD      L,D
	LD      H,D
	LD      (LLC3E3),HL
	LD      A,$22
	LD      (LLC3E5),A
	EXX
	JP      LLC1FB
LLC2D3:
	LD      A,$00
LLC2D4: EQU     $-1
	LD      (LLC0FD),A
	JP      LLC47F
LLC2DB:
	DEC     A
	JP      NZ,LLC47F
	DEC     HL
	DEC     (HL)
	JP      P,LLC47F
LLC2E4:
	LD      HL,LLC000
LLC2E5: EQU     $-2
	OR      (HL)
	JP      Z,LLC665
LLC2EB:
	LD      A,(HL)
	INC     HL
	CP      $C0
	JR      C,LLC2FE
	SUB     C
	JR      NC,LLC326
	SUB     C
	JR      NC,LLC32F
	SUB     C
	JR      NC,LLC335
	SUB     C
	JP      LLC363
LLC2FE:
	SUB     $80
	JR      NC,LLC35D
	SUB     C
	JP      NC,LLC39A
	SBC     A,C
	JR      NC,LLC340
	ADD     A,B
	LD      (LLC44B),A
	LD      (LLC2E5),HL
	XOR     A
	LD      (LLC450),A
	LD      L,A
	LD      H,A
	LD      (LLC421),HL
	LD      A,$22
	LD      (LLC423),A
	LD      A,$32
	LD      (LLC466),A
	JP      LLC3C3
LLC326:
	JR      Z,LLC38D
	DEC     A
	LD      (LLC441),A
	JP      LLC2EB
LLC32F:
	LD      (LLC2E5),HL
	JP      LLC3C3
LLC335:
	LD      A,$FC
	LD      (LLC450),A
	LD      (LLC2E5),HL
	JP      LLC3C3
LLC340:
	ADD     A,A
	EXX
	LD      E,A
	LD      HL,LLC000
LLC344: EQU     $-2
	ADD     HL,DE
	LD      SP,HL
	POP     HL
	LD      A,(HL)
	ADD     A,A
	ADD     A,A
	LD      (LLC43C),A
	INC     HL
	LD      A,(HL)
	ADD     A,A
	ADD     A,A
	LD      (LLC432),A
	LD      (LLC415),HL
	EXX
	JP      LLC2EB
LLC35D:
	LD      (LLC3C4),A
	JP      LLC2EB
LLC363:
	LD      (LLC459),A
	LD      A,$1F
	LD      (LLC446),A
	LD      A,(HL)
	INC     HL
	LD      (LLC45E),A
	LD      DE,LLC046
	LD      (LLC41B),DE
	LD      A,$22
	LD      (LLC429),A
	XOR     A
	LD      (LLC437),A
	LD      (LLC427),A
	LD      (LLC428),A
	INC     A
	LD      (LLC42D),A
	JP      LLC2EB
LLC38D:
	LD      A,(HL)
	INC     HL
	LD      (LLC427),A
	RLA
	SBC     A,A
	LD      (LLC428),A
	JP      LLC2EB
LLC39A:
	ADD     A,A
	EXX
	LD      E,A
	LD      A,$0F
	LD      (LLC446),A
	LD      HL,LLC000
LLC3A3: EQU     $-2
	ADD     HL,DE
	LD      SP,HL
	POP     HL
	LD      A,(HL)
	LD      (LLC437),A
	INC     HL
	LD      A,(HL)
	LD      (LLC42D),A
	INC     HL
	LD      (LLC41B),HL
	LD      L,D
	LD      H,D
	LD      (LLC427),HL
	LD      A,$22
	LD      (LLC429),A
	EXX
	JP      LLC2EB
LLC3C3:
	LD      A,$00
LLC3C4: EQU     $-1
	LD      (LLC0FE),A
	JP      LLC47F
LLC3CB:
	LD      A,$00
LLC3CC: EQU     $-1
	LD      (LLC100),A
LLC3D0:
	LD      HL,LLC000
LLC3D1: EQU     $-2
	LD      (LLC508),HL
	LD      HL,LLC000
LLC3D7: EQU     $-2
	LD      (LLC4ED),HL
	LD      HL,LLC000
LLC3DD: EQU     $-2
LLC3DF:
	LD      (LLC543),HL
	LD      HL,LLC000
LLC3E3: EQU     $-2
LLC3E5:
	LD      (LLC546),HL
LLC3E4: EQU     $-4
        LD      A,$00
LLC3E9: EQU     $-1
	LD      (LLC4F3),A
	LD      A,$00
LLC3EE: EQU     $-1
	LD      (LLC513),A
	LD      A,$00
LLC3F3: EQU     $-1
	LD      (LLC4F7),A
	LD      A,$00
LLC3F8: EQU     $-1
	LD      (LLC517),A
	LD      A,$00
LLC3FD: EQU     $-1
	LD      (LLC522),A
	LD      A,$0F
LLC402: EQU     $-1
	LD      (LLC52E),A
	LD      A,$00
LLC407: EQU     $-1
	LD      (LLC4FC),A
	LD      A,$00
LLC40C: EQU     $-1
	CP      $01
	JR      Z,LLC414
	LD      (LLC506),A
LLC414:
	LD      HL,LLC000
LLC415: EQU     $-2
	LD      (LLC49E),HL
	LD      HL,LLC000
LLC41B: EQU     $-2
	LD      (LLC483),HL
	LD      HL,LLC000
LLC421: EQU     $-2
LLC423:
	LD      (LLC4CF),HL
	LD      HL,LLC000
LLC427: EQU     $-2
LLC429:
	LD      (LLC4D2),HL
LLC428: EQU     $-4
	LD      A,$00
LLC42D: EQU     $-1
	LD      (LLC489),A
	LD      A,$00
LLC432: EQU     $-1
	LD      (LLC4A9),A
	LD      A,$00
LLC437: EQU     $-1
        LD      (LLC48D),A
        LD      A,$00
LLC43C: EQU     $-1
	LD      (LLC4AD),A
	LD      A,$00
LLC441: EQU     $-1
	LD      (LLC4B8),A
	LD      A,$0F
LLC446: EQU     $-1
	LD      (LLC4C4),A
	LD      A,$00
LLC44B: EQU     $-1
	LD      (LLC492),A
	LD      A,$00
LLC450: EQU     $-1
	CP      $01
	JR      Z,LLC458
	LD      (LLC49C),A
LLC458:
	LD      A,$00
LLC459: EQU     $-1
	LD      (LLC5D3),A
	LD      A,$00
LLC45E: EQU     $-1
	LD      (LLC5E1),A
	XOR     A
	LD      (LLC459),A
LLC466:
	LD      (LLC480),A
LLC469:
	LD      (LLC4EA),A
	INC     A
	LD      (LLC450),A
	LD      (LLC466),A
	LD      (LLC40C),A
	LD      (LLC469),A
	LD      (LLC423),A
	LD      (LLC3DF),A
LLC47F:
	LD      DE,$0000
LLC480: EQU     $-2
	LD      HL,LLC000
LLC483: EQU     $-2
	ADD     HL,DE
	INC     E
	LD      A,E
	CP      $00
LLC489: EQU     $-1
	JR      NZ,LLC48E
	LD      A,$00
LLC48D: EQU     $-1
LLC48E:
	LD      (LLC480),A
	LD      A,$00
LLC492: EQU     $-1
	ADD     A,(HL)
	ADD     A,A
	LD      E,A
	LD      HL,LLC6A8
	ADD     HL,DE
	LD      SP,HL
	LD      A,$00
LLC49C: EQU     $-1
        LD      HL,LLC000
LLC49E: EQU     $-2
	INC     A
	JP      M,LLC641
	LD      E,A
	ADD     HL,DE
	ADD     A,$03
	CP      $00
LLC4A9: EQU     $-1
        JR      NZ,LLC4AE
        LD      A,$00
LLC4AD: EQU     $-1
LLC4AE:
	LD      (LLC49C),A
	POP     BC
	LD      SP,HL
	POP     DE
	LD      A,E
	AND     $0F
	SUB     $00
LLC4B8: EQU     $-1
	LD      L,A
	CCF
	SBC     A,A
	AND     L
	SRL     D
	JR      NC,LLC4C3
	OR      $10
LLC4C3:
	AND     $00
LLC4C4: EQU     $-1
	LD      (LLC0FA),A
	LD      A,E
	RLCA
	JR      C,LLC4CE
	LD      ixh,D
LLC4CE:
	LD      HL,LLC000
LLC4CF: EQU     $-2
	LD      DE,$0000
LLC4D2: EQU     $-2
	ADD     HL,DE
	LD      (LLC4CF),HL
	ADD     HL,BC
	POP     BC
	ADD     HL,BC
	RLCA
	RLCA
	RLCA
	AND     $0F
	LD      ixl,A
	LD      A,H
	AND     $0F
	LD      H,A
	LD      (LLC0F4),HL
LLC4E9:
	LD      DE,$0000
LLC4EA: EQU     $-2
	LD      HL,LLC000
LLC4ED: EQU     $-2
	ADD     HL,DE
	INC     E
	LD      A,E
	CP      $00
LLC4F3: EQU     $-1
	JR      NZ,LLC4F8
	LD      A,$00
LLC4F7: EQU     $-1
LLC4F8:
	LD      (LLC4EA),A
	LD      A,$0
LLC4FC: EQU     $-1
	ADD     A,(HL)
	ADD     A,A
	LD      E,A
	LD      HL,LLC6A8
	ADD     HL,DE
	LD      SP,HL
	LD      A,$00
LLC506: EQU     $-1
	LD      HL,LLC000
LLC508: EQU     $-2
	INC     A
	JP      M,LLC64B
	LD      E,A
	ADD     HL,DE
	ADD     A,$03
	CP      $00
LLC513: EQU     $-1
	JR      NZ,LLC518
	LD      A,$00
LLC517: EQU     $-1
LLC518:
	LD      (LLC506),A
	POP     BC
	LD      SP,HL
	POP     DE
	LD      A,E
	AND     $0F
	SUB     $00
LLC522: EQU     $-1
	LD      L,A
	CCF
	SBC     A,A
	AND     L
	SRL     D
	JR      NC,LLC52D
	OR      $10
LLC52D:
	AND     $00
LLC52E: EQU     $-1
	LD      (LLC0FB),A
	LD      A,E
	RRCA
	RRCA
	RRCA
	AND     $1E
	OR      ixl
	LD      ixl,A
	AND     $10
	JR      NZ,LLC542
	LD      ixh,D
LLC542:
	LD      HL,LLC000
LLC543: EQU     $-2
	LD      DE,$0000
LLC546: EQU     $-2
	ADD     HL,DE
	LD      (LLC543),HL
	ADD     HL,BC
	POP     BC
	ADD     HL,BC
	LD      A,H
	AND     $0F
	LD      H,A
	LD      (LLC0F6),HL
LLC556:
	LD      DE,$0000
LLC557: EQU     $-2
	LD      HL,LLC000
LLC55A: EQU     $-2
	ADD     HL,DE
	INC     E
	LD      A,E
	CP      $00
LLC560: EQU     $-1
	JR      NZ,LLC565
	LD      A,$00
LLC564: EQU     $-1
LLC565:
	LD      (LLC557),A
	LD      A,$00
LLC569: EQU     $-1
	ADD     A,(HL)
	ADD     A,A
	LD      E,A
	LD      HL,LLC6A8
	ADD     HL,DE
	LD      SP,HL
	LD      A,$00
LLC573: EQU     $-1
	LD      HL,LLC000
LLC575: EQU     $-2
        INC     A
        JP      M,LLC658
        LD      E,A
        ADD     HL,DE
        ADD     A,$03
        CP      $00
LLC580: EQU     $-1
	JR      NZ,LLC585
	LD      A,$00
LLC584: EQU     $-1
LLC585:
	LD      (LLC573),A
	POP     BC
	LD      SP,HL
	POP     DE
	LD      A,E
	AND     $0F
	SUB     $00
LLC58F: EQU     $-1
	LD      L,A
	CCF
	SBC     A,A
	AND     L
	SRL     D
	JR      NC,LLC59A
	OR      $10
LLC59A:
	AND     $00
LLC59B: EQU     $-1
	LD      (LLC0FC),A
	LD      A,E
	RRCA
	RRCA
	AND     $3C
	OR      ixl
	LD      ixl,A
	AND     $20
	JR      NZ,LLC5AE
	LD      ixh,D
LLC5AE:
	LD      HL,LLC000
LLC5AF: EQU     $-2
        LD      DE,$0000
LLC5B2: EQU     $-2
	ADD     HL,DE
LLC5B3: EQU     $-2
	LD      (LLC5AF),HL
	ADD     HL,BC
	POP     BC
	ADD     HL,BC
	LD      A,H
	AND     $0F
	LD      H,A
	LD      (LLC0F8),HL
LLC5C2:
	LD      SP,$0000
LLC5C3: EQU     $-2
LLC5C5:
	LD      HL,LLC0FC
	LD      DE,$FFBF
	LD      BC,$FFFD
	LD      A,$0D
	OUT     (C),A
	LD      A,$00
LLC5D3: EQU     $-1
	OR      A
	JR      Z,LLC5E5
	LD      B,E
	OUT     (C),A
	LD      A,$0B
	LD      B,D
	OUT     (C),A
	LD      B,E
	LD      A,$00
LLC5E1: EQU     $-1
	OUT     (C),A
	LD      B,D
LLC5E5:
	LD      A,$0A
	OUT     (C),A
	LD      B,E
	OUTD
	DEC     A
	LD      B,D
	OUT     (C),A
	LD      B,E
	OUTD
	DEC     A
	LD      B,D
	OUT     (C),A
	LD      B,E
	OUTD
	DEC     A
	LD      B,D
	OUT     (C),A
	LD      B,E
	LD      A,ixl
	OUT     (C),A
	LD      A,$06
	LD      B,D
	OUT     (C),A
	LD      B,E
	LD      A,ixh
	OUT     (C),A
	LD      A,$05
	LD      B,D
	OUT     (C),A
	LD      B,E
	OUTD
	DEC     A
	LD      B,D
	OUT     (C),A
	LD      B,E
	OUTD
	DEC     A
	LD      B,D
	OUT     (C),A
	LD      B,E
	OUTD
	DEC     A
	LD      B,D
	OUT     (C),A
	LD      B,E
	OUTD
	DEC     A
	LD      B,D
	OUT     (C),A
	LD      B,E
	OUTD
	DEC     A
	LD      B,D
	OUT     (C),A
	LD      B,E
	OUTD
	LD      (LLC5D3),A
	LD      HL,$2758
	EXX
	EI
	RET
LLC641:
	XOR     A
	LD      (LLC0FA),A
	LD      ixl,$09
	JP      LLC4E9
LLC64B:
	XOR     A
	LD      (LLC0FB),A
	LD      A,ixl
	OR      $12
	LD      ixl,A
	JP      LLC556
LLC658:
	XOR     A
	LD      (LLC0FC),A
	LD      A,ixl
	OR      $24
	LD      ixl,A
	JP      LLC5C2
LLC665:
	LD      HL,(LLC1F5)
	OR      (HL)
	JP      NZ,LLC47F
	LD      HL,(LLC11B)
	OR      (HL)
	JP      NZ,LLC47F
	LD      B,A
	LD      A,$00
LLC675: EQU     $-1
	INC     A
	CP      $00
LLC678: EQU     $-1
	JR      NZ,LLC67D
	LD      A,$00
LLC67C: EQU     $-1
LLC67D:
	LD      (LLC675),A
	LD      C,A
	LD      HL,LLC000
LLC682: EQU     $-2
	ADD     HL,BC
	ADD     HL,BC
	LD      C,(HL)
	INC     HL
	LD      A,(HL)
	LD      HL,LLC000
LLC68A: EQU     $-2
	ADD     HL,BC
	LD      SP,HL
	POP     HL
	LD      (LLC2E5),HL
	POP     HL
	LD      (LLC1F5),HL
	POP     HL
	LD      (LLC11B),HL
	ADD     A,$60
	LD      (LLC10B),A
	LD      B,A
	LD      C,$F0
	JP      LLC2E4
;-----------------------------------------
        DEFB    "KSA"
;-----------------------------------------
LLC6A8:
	DEFB    $F8,$0E,$10,$0E,$60
        DEFB    $0D,$80,$0C,$D8
        DEFB    $0B,$28,$0B,$88
        DEFB    $0A,$F0,$09,$60
        DEFB    $09,$E0,$08,$58
        DEFB    $08,$E0,$07,$7C
        DEFB    $07,$08,$07,$B0
        DEFB    $06,$40,$06,$EC
        DEFB    $05,$94,$05,$44
        DEFB    $05,$F8,$04,$B0
        DEFB    $04,$70,$04,$2C
        DEFB    $04,$F0,$03,$BE
        DEFB    $03,$84,$03,$58
        DEFB    $03,$20,$03,$F6
        DEFB    $02,$CA,$02,$A2
        DEFB    $02,$7C,$02,$58
        DEFB    $02,$38,$02,$16
        DEFB    $02,$F8,$01,$DF
        DEFB    $01,$C2,$01,$AC
        DEFB    $01,$90,$01,$7B
        DEFB    $01,$65,$01,$51
        DEFB    $01,$3E,$01,$2C
        DEFB    $01,$1C,$01,$0B
        DEFB    $01,$FC,$00,$EF
        DEFB    $00,$E1,$00,$D6
        DEFB    $00,$C8,$00,$BD
        DEFB    $00,$B2,$00,$A8
        DEFB    $00,$9F,$00,$96
        DEFB    $00,$8E,$00,$85
        DEFB    $00,$7E,$00,$77
        DEFB    $00,$70,$00,$6B
        DEFB    $00,$64,$00,$5E
        DEFB    $00,$59,$00,$54
        DEFB    $00,$4F,$00,$4B
        DEFB    $00,$47,$00,$42
        DEFB    $00,$3F,$00,$3B
        DEFB    $00,$38,$00,$35
        DEFB    $00,$32,$00,$2F
        DEFB    $00,$2C,$00,$2A
        DEFB    $00,$27,$00,$25
        DEFB    $00,$23,$00,$21
        DEFB    $00,$1F,$00,$1D
        DEFB    $00,$1C,$00,$1A
        DEFB    $00,$19,$00,$17
        DEFB    $00,$16,$00,$15
        DEFB    $00,$13,$00,$12
        DEFB    $00,$11,$00,$10
        DEFB    $00,$0F,$00
;-----------------------------------------

_err_memory:

	defb "Out of memory!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

_err_invalid:

	defb "Not a valid .STP file!", $0
