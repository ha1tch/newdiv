;******************************************************************************
;*
;* Copyright(c) 2020-22 Bob Fossil. All rights reserved.
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

DEFC pt1_data=0xc000
DEFC MAX_SIZE=16384

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

	defb ".PT1 file plugin - bob_fossil", $0

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

	ld a, (_plugin_file_handle)	; read file to pt1_data address
	ld hl, pt1_data

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_init

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jr _plugin_error

_plugin_init:

	push ix


	ei

	call _pt1_init

;	CALL START+5
;	XOR A
;	IN A,(#FE)
;	CPL
;	AND 15
;	JR Z,_LP
;	JR START+8

	ld hl, _plugin_status_playing
	call _set_status_icon

	call _plugin_wait_for_no_keys

_plugin_playback:

	halt
	call _pt1_play

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

;	ld bc, $fefe
;	in a, (c)
;	and %00000001			; shift pressed?
;	jr nz, _plugin_playback
;
;;	xor a
;;	in a, (254)
;;	cpl
;;	and $1f
;;	jr z, _plugin_playback
;
;	ld b, $f7
;	in a, (c)
;	and %00010000			; check for shift + 5
;	jr nz, _plugin_skip_prev
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_PREVIOUS
;	jr _plugin_done
;
;_plugin_skip_prev:
;
;	ld b, $ef
;	in a, (c)
;	ld b, a
;	and %00000100			; check for shift + 8
;	jr nz, _plugin_skip_next
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_NEXT
;	jr _plugin_done
;
;_plugin_skip_next:
;
;	ld a, b
;	and %00001000			; check for shift + 7
;	jr nz, _plugin_skip_last
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_FIRST
;	jr _plugin_done
;
;_plugin_skip_last:
;
;	ld a, b
;	and %00010000			; check for shift + 6
;	jr nz, _plugin_skip_first
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_LAST
;	jr _plugin_done
;
;_plugin_skip_first:
;
;	ld b, $7f
;	in a, (c)
;	and %00000001			; check for shift + space
;
;;	xor a
;;	in a, (254)
;;	cpl
;;	and $1f
;
;	jr nz, _plugin_playback

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS
	ld hl, 0

_plugin_done:

	push bc				; save navigation
	push af				; save return code

	call _set_status_icon

	call _pt1_init

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


_err_memory:

	defb "Out of memory!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0


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

	; protracker 1.0x replayer code
	; extracted from compiled module loaded to 49152
	; code dumped from 49152 using SpecEmu source code ripper

_pt1_init:
	LD   HL, pt1_data
	JP   L49762
_pt1_play:
	CALL L50439
	JP   L50122
L49164:	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
L49196:	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
L49228:	RET  M
	LD   C,16
	LD   C,96
	DEC  C
	ADD  A,B
	INC  C
	RET  C
	DEC  BC
	JR   Z,L49251
	ADC  A,B
	LD   A,(BC)
	RET  P
	ADD  HL,BC
	LD   H,B
	ADD  HL,BC
	RET  PO
	EX   AF,AF'
	LD   E,B
	EX   AF,AF'
	RET  PO
L49251:	RLCA
	LD   A,H
	RLCA
	EX   AF,AF'
	RLCA
	OR   B
	LD   B,64
	LD   B,236
	DEC  B
	SUB  H
	DEC  B
	LD   B,H
	DEC  B
	RET  M
	INC  B
	OR   B
	INC  B
	LD   (HL),B
	INC  B
	INC  L
	INC  B
	
	defb $fd			; this wasn't picked up by SpecEmu!

	INC  BC
	CP   (HL)
	INC  BC
	ADD  A,H
	INC  BC
	LD   E,B
	INC  BC
	JR   NZ,L49286+1
	OR   2
L49286:	
	JP   Z,41474
	LD   (BC),A
	LD   A,H
	LD   (BC),A
	LD   E,B
	LD   (BC),A
	JR   C,L49298
	LD   D,2
L49298:	RET  M
	LD   BC,479
	JP   NZ,44033
	LD   BC,400
	LD   A,E
	LD   BC,357
	LD   D,C
	LD   BC,318
	INC  L
	LD   BC,284
	DEC  BC
	LD   BC,252
	RST  40
	NOP
	POP  HL
	NOP
	SUB  0
	RET  Z
	NOP
	CP   L
	NOP
	OR   D
	NOP
	XOR  B
	NOP
	SBC  A,A
	NOP
	SUB  (HL)
	NOP
	ADC  A,(HL)
	NOP
	ADD  A,L
	NOP
	LD   A,(HL)
	NOP
	LD   (HL),A
	NOP
	LD   (HL),B
	NOP
	LD   L,E
	NOP
	LD   H,H
	NOP
	LD   E,(HL)
	NOP
	LD   E,C
	NOP
	LD   D,H
	NOP
	LD   C,A
	NOP
	LD   C,E
	NOP
	LD   B,A
	NOP
	LD   B,D
	NOP
	CCF
	NOP
	DEC  SP
	NOP
	JR   C,L49376
L49376:	DEC  (HL)
	NOP
	LD   (12032),A
	NOP
	INC  L
	NOP
	LD   HL,(9984)
	NOP
	DEC  H
	NOP
	INC  HL
	NOP
	LD   HL,7936
	NOP
	DEC  E
	NOP
	INC  E
	NOP
	LD   A,(DE)
	NOP
	ADD  HL,DE
	NOP
	RLA
	NOP
	LD   D,0
	DEC  D
	NOP
	INC  DE
	NOP
	LD   (DE),A
	NOP
	LD   DE,4096
	NOP
	RRCA
	NOP
L49420:	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	LD   BC,257
	LD   BC,257
	LD   BC,1
	NOP
	NOP
	NOP
	LD   BC,257
	LD   BC,257
	LD   BC,513
	LD   (BC),A
	LD   (BC),A
	LD   (BC),A
	NOP
	NOP
	NOP
	LD   BC,257
	LD   BC,513
	LD   (BC),A
	LD   (BC),A
	LD   (BC),A
	LD   (BC),A
	INC  BC
	INC  BC
	INC  BC
	NOP
	NOP
	LD   BC,257
	LD   BC,514
	LD   (BC),A
	LD   (BC),A
	INC  BC
	INC  BC
	INC  BC
	INC  BC
	INC  B
	INC  B
	NOP
	NOP
	LD   BC,257
	LD   (BC),A
	LD   (BC),A
	LD   (BC),A
	INC  BC
	INC  BC
	INC  BC
	INC  B
	INC  B
	INC  B
	DEC  B
	DEC  B
	NOP
	NOP
	LD   BC,513
	LD   (BC),A
	LD   (BC),A
	INC  BC
	INC  BC
	INC  B
	INC  B
	INC  B
	DEC  B
	DEC  B
	LD   B,6
	NOP
	NOP
	LD   BC,513
	LD   (BC),A
	INC  BC
	INC  BC
	INC  B
	INC  B
	DEC  B
	DEC  B
	LD   B,6
	RLCA
	RLCA
	NOP
	LD   BC,513
	LD   (BC),A
	INC  BC
	INC  BC
	INC  B
	INC  B
	DEC  B
	DEC  B
	LD   B,6
	RLCA
	RLCA
	EX   AF,AF'
	NOP
	LD   BC,513
	LD   (BC),A
	INC  BC
	INC  B
	INC  B
	DEC  B
	DEC  B
	LD   B,7
	RLCA
	EX   AF,AF'
	EX   AF,AF'
	ADD  HL,BC
	NOP
	LD   BC,513
	INC  BC
	INC  BC
	INC  B
	DEC  B
	DEC  B
	LD   B,7
	RLCA
	EX   AF,AF'
	ADD  HL,BC
	ADD  HL,BC
	LD   A,(BC)
	NOP
	LD   BC,513
	INC  BC
	INC  B
	INC  B
	DEC  B
	LD   B,7
	RLCA
	EX   AF,AF'
	ADD  HL,BC
	LD   A,(BC)
	LD   A,(BC)
	DEC  BC
	NOP
	LD   BC,514
	INC  BC
	INC  B
	DEC  B
	LD   B,6
	RLCA
	EX   AF,AF'
	ADD  HL,BC
	LD   A,(BC)
	LD   A,(BC)
	DEC  BC
	INC  C
	NOP
	LD   BC,770
	INC  BC
	INC  B
	DEC  B
	LD   B,7
	EX   AF,AF'
	ADD  HL,BC
	LD   A,(BC)
	LD   A,(BC)
	DEC  BC
	INC  C
	DEC  C
	NOP
	LD   BC,770
	INC  B
	DEC  B
	LD   B,7
	RLCA
	EX   AF,AF'
	ADD  HL,BC
	LD   A,(BC)
	DEC  BC
	INC  C
	DEC  C
L49659:
	LD   C,0
	LD   BC,770
	INC  B
	DEC  B
	LD   B,7
	EX   AF,AF'
	ADD  HL,BC
	LD   A,(BC)
	DEC  BC
	INC  C
	DEC  C
	LD   C,15
L49676:	NOP
L49677:	NOP
	NOP
L49679:	NOP
L49680:	NOP
	NOP
L49682:	NOP
L49683:	NOP
L49684:	NOP
	NOP
L49686:	NOP
L49687:	NOP
	NOP
	NOP
L49690:	NOP
L49691:	NOP
	NOP
L49693:	NOP
L49694:	NOP
L49695:	NOP
	NOP
L49697:	NOP
L49698:	NOP
	NOP
	NOP
L49701:	NOP
L49702:	NOP
	NOP
L49704:	NOP
L49705:	NOP
L49706:	NOP
	NOP
L49708:	NOP
L49709:	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
L49716:	RST  56
L49717:	NOP
	NOP
	NOP
L49720:	NOP
L49721:	NOP
L49722:	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
L49729:	RST  56
L49730:	NOP
	NOP
	NOP
L49733:	NOP
L49734:	NOP
L49735:	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
L49742:	RST  56
L49743:	NOP
	NOP
	NOP
L49746:	NOP
L49747:	NOP
L49748:	NOP
L49749:	NOP
L49750:	NOP
	NOP
L49752:	NOP
	NOP
L49754:	NOP
L49755:	NOP
L49756:	NOP
L49757:	NOP
L49758:	NOP
L49759:	NOP
	NOP
L49761:	NOP
L49762:	LD   (L49934+1),HL
	LD   (L49905+1),HL
	LD   (L49982+1),HL
	PUSH HL
	LD   A,(HL)
	LD   (L50666+1),A
	LD   (L50439+1),A
	INC  HL
	INC  HL
	LD   A,(HL)
	POP  HL
	PUSH AF
	PUSH HL
	LD   DE,3
	ADD  HL,DE
	LD   (L49890+1),HL
	LD   DE,32
	ADD  HL,DE
	LD   (L49919+1),HL
	ADD  HL,DE
	LD   E,(HL)
	INC  HL
	LD   D,(HL)
	INC  HL
	LD   BC,30
	ADD  HL,BC
	LD   (L49949+1),HL
	POP  HL
	ADD  HL,DE
	LD   (L49969+1),HL
	LD   HL,L49748
	LD   DE,L49749
	LD   BC,13
	LD   (HL),B
	LDIR
	LD   HL,L49676
	LD   DE,L49677
	LD   BC,71
	LD   (HL),B
	LDIR
	LD   A,255
	LD   (L49716),A
	LD   (L49729),A
	LD   (L49742),A
	LD   (L49683),A
	LD   (L49694),A
	LD   (L49705),A
	LD   HL,L49659+1
	LD   (L49717),HL
	LD   (L49730),HL
	LD   (L49743),HL
	POP  AF
	LD   HL,(L49949+1)
	ADD  A,L
	LD   L,A
	ADC  A,H
	SUB  L
	LD   H,A
	LD   (L49957+1),HL
	CALL L49949
	CALL L50402
L49890:	
	LD   HL,0
	LD   DE,L49164
	LD   A,16
L49898:	LD   C,(HL)
	INC  HL
	LD   B,(HL)
	INC  HL
	PUSH HL
	LD   L,C
	LD   H,B
L49905:
	LD   BC,0
	ADD  HL,BC
	EX   DE,HL
	LD   (HL),E
	INC  HL
	LD   (HL),D
	INC  HL
	EX   DE,HL
	POP  HL
	DEC  A
	JR   NZ,L49898
L49919:	
	LD   HL,0
	LD   DE,L49196	
	LD   A,16
L49927:	LD   C,(HL)
	INC  HL
	LD   B,(HL)
	INC  HL
	PUSH HL
	LD   H,B
	LD   L,C
L49934:
	LD   BC,0
	ADD  HL,BC
	EX   DE,HL
	LD   (HL),E
	INC  HL
	LD   (HL),D
	INC  HL
	EX   DE,HL
	POP  HL
	DEC  A
	JR   NZ,L49927
	RET
L49949:	LD   HL,0
	LD   A,(HL)
	ADD  A,A
	JP   NC,L49962
L49957:
	LD   HL,0
	LD   A,(HL)
	ADD  A,A
L49962:	INC  HL
	LD   (L49949+1),HL
	LD   C,A
	ADD  A,A
	ADD  A,C
L49969:	
	LD   HL,0
	ADD  A,L
	LD   L,A
	ADC  A,H
	SUB  L
	LD   H,A
	LD   E,(HL)
	INC  HL
	LD   D,(HL)
	INC  HL
	EX   DE,HL
L49982:
	LD   BC,0
	ADD  HL,BC
	LD   (L50476+1),HL
	EX   DE,HL
	LD   E,(HL)
	INC  HL
	LD   D,(HL)
	INC  HL
	EX   DE,HL
	ADD  HL,BC
	LD   (L50506+1),HL
	EX   DE,HL
	LD   E,(HL)
	INC  HL
	LD   D,(HL)
	INC  HL
	EX   DE,HL
	ADD  HL,BC
	LD   (L50538+1),HL
	RET
L50010:	LD   HL,0
	ADD  A,L
	LD   L,A
	ADC  A,H
	SUB  L
	LD   H,A
	LD   A,(HL)
L50019:
	OR   0
	RET
L50022:	LD   A,0
	LD   (L50090+1),A
L50027:
	LD   IX,0
	LD   D,0
	LD   E,A
	ADD  A,A
	ADD  A,E
	LD   E,A
	ADD  IX,DE
	LD   A,(IX+1)
	BIT  7,A
	LD   C,16
	JP   NZ,L50050
	LD   C,D
L50050:	BIT  6,A
	LD   B,2
	JP   NZ,L50058
	LD   B,D
L50058:	AND  31
	LD   H,A
	LD   A,(IX+0)
	LD   E,A
	AND  240
	RRCA
	RRCA
	RRCA
	RRCA
	LD   D,A
	LD   A,E
	AND  15
	LD   L,A
	LD   E,(IX+2)
	BIT  5,(IX+1)
	RET  Z
	SET  7,D
	RET
L50087:	LD   HL,0
L50090:
	LD   BC,0
	ADD  HL,BC
	LD   A,(HL)
L50095:
	ADD  A,0
	LD   HL,L49228
	ADD  A,A
	ADD  A,L
	LD   L,A
	ADC  A,H
	SUB  L
	LD   H,A
	LD   A,(HL)
	INC  HL
	LD   H,(HL)
	LD   L,A
	BIT  7,D
	JR   Z,L50118
	RES  7,D
	ADD  HL,DE
	RET
L50118:	AND  A
	SBC  HL,DE
	RET
L50122:	LD   IX,L49676
	LD   A,(L49683)
	INC  A
	JR   Z,L50205
	DEC  A
	LD   (L50019+1),A
	LD   HL,(L49676)
	LD   (L50027+2),HL
	LD   HL,(L49680)
	LD   (L50087+1),HL
	LD   HL,(L49684)
	LD   (L50010+1),HL
	LD   A,(L49686)
	LD   (L50095+1),A
	LD   A,(L49682)
	LD   (L50022+1),A
	INC  A
	LD   (L49682),A
	CP   (IX+2)
	JP   NZ,L50182
	LD   A,(L49679)
	LD   (L49682),A
L50182:	CALL L50022
	LD   A,C
	RRCA
	RRC  B
	OR   B
	LD   (L49755),A
	DEC  C
	JP   P,L50201
	LD   A,H
	LD   (L49754),A
L50201:	LD   A,L
	CALL L50010
L50205:	LD   (L49756),A
	CALL L50087
	LD   (L49748),HL
	LD   IX,L49687
	LD   A,(L49694)
	INC  A
	JR   Z,L50297
	DEC  A
	LD   (L50019+1),A
	LD   HL,(L49687)
	LD   (L50027+2),HL
	LD   HL,(L49691)
	LD   (L50087+1),HL
	LD   HL,(L49695)
	LD   (L50010+1),HL
	LD   A,(L49697)
	LD   (L50095+1),A
	LD   A,(L49693)
	LD   (L50022+1),A
	INC  A
	LD   (L49693),A
	CP   (IX+2)
	JP   NZ,L50274
	LD   A,(L49690)
	LD   (L49693),A
L50274:	CALL L50022
	LD   A,(L49755)
	OR   C
	OR   B
	LD   (L49755),A
	DEC  C
	JP   P,L50293
	LD   A,H
	LD   (L49754),A
L50293:	LD   A,L
	CALL L50010
L50297:	LD   (L49757),A
	CALL L50087
	LD   (L49750),HL
	LD   IX,L49698
	LD   A,(L49705)
	INC  A
	JR   Z,L50393
	DEC  A
	LD   (L50019+1),A
	LD   HL,(L49698)
	LD   (L50027+2),HL
	LD   HL,(L49702)
	LD   (L50087+1),HL
	LD   HL,(L49706)
	LD   (L50010+1),HL
	LD   A,(L49708)
	LD   (L50095+1),A
	LD   A,(L49704)
	LD   (L50022+1),A
	INC  A
	LD   (L49704),A
	CP   (IX+2)
	JP   NZ,L50366
	LD   A,(L49701)
	LD   (L49704),A
L50366:	CALL L50022
	LD   A,(L49755)
	RLC  C
	RLC  B
	OR   C
	OR   B
	LD   (L49755),A
	DEC  C
	JP   P,L50389
	LD   A,H
	LD   (L49754),A
L50389:	LD   A,L
	CALL L50010
L50393:	LD   (L49758),A
	CALL L50087
	LD   (L49752),HL
L50402:	LD   HL,L49761
	LD   DE,65471
	LD   C,253
	XOR  A
	OR   (HL)
	LD   A,13
	JR   NZ,L50421
	SUB  3
	DEC  HL
	DEC  HL
	DEC  HL
L50421:	LD   B,D
	OUT  (C),A
	LD   B,E
	OUTD
	DEC  A
	JP   P,L50421
	XOR  A
	LD   (L49755),A
	LD   (L49761),A
	RET
L50439:	LD   A,1
	DEC  A
	LD   (L50439+1),A
	JP   Z,L50522
	DEC  A
	JP   Z,L50492
	DEC  A
	RET  NZ
	LD   IX,L49709
	DEC  (IX+11)
	RET  P
	LD   A,(L49721)
	LD   (L49720),A
	LD   HL,(L50476+1)
	LD   A,(HL)
	INC  A
	CALL Z,L49949
L50476:	
	LD   HL,0
	LD   DE,24688
	CALL L50685
	LD   (L50476+1),HL
	LD   (L50553+1),A
	RET
L50492:	LD   IX,L49722
	DEC  (IX+11)
	RET  P
	LD   A,(L49734)
	LD   (L49733),A
L50506:
	LD   HL,0
	LD   DE,24688
	CALL L50685
	LD   (L50506+1),HL
	LD   (L50587+1),A
	RET
L50522:	LD   IX,L49735
	DEC  (IX+11)
	JP   P,L50553
	LD   A,(L49747)
	LD   (L49746),A
L50538:
	LD   HL,0
	LD   DE,24688
	CALL L50685
	LD   (L50538+1),HL
	LD   (L50621+1),A
L50553:	LD   A,0
	AND  A
	JP   Z,L50587
	LD   HL,L49709
	LD   DE,L49676
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
L50587:	LD   A,0
	AND  A
	JP   Z,L50621
	LD   HL,L49722
	LD   DE,L49687
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
L50621:	LD   A,0
	AND  A
	JP   Z,L50655
	LD   HL,L49735
	LD   DE,L49698
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
	LDI
L50655:	LD   A,0
	LD   (L49761),A
L50660:
	LD   HL,0
	LD   (L49759),HL
L50666:
	LD   A,5
	LD   (L50439+1),A
	XOR  A
	LD   (L50553+1),A
	LD   (L50587+1),A
	LD   (L50621+1),A
	LD   (L50655+1),A
	RET
L50685:	LD   A,(HL)
	INC  HL
	CP   D
	JP   C,L50732
	CP   E
	JP   C,L50754
	CP   128
	JP   C,L50791
	JP   Z,L50814
	CP   144
	JP   C,L50821
	JP   Z,L50853
	CP   161
	JP   C,L50855
	CP   177
	JP   C,L50863
	SUB  177
	LD   (IX+11),A
	LD   (IX+12),A
	JP   L50685
L50732:	LD   (IX+10),A
	LD   (IX+6),0
	LD   A,(IX+7)
	CP   16
	JP   Z,L50748
	XOR  A
L50748:	LD   (IX+7),A
	LD   A,255
	RET
L50754:	SUB  96
	LD   BC,L49164
	ADD  A,A
	ADD  A,C
	LD   C,A
	ADC  A,B
	SUB  C
	LD   B,A
	LD   A,(BC)
	INC  BC
	EX   AF,AF'
	LD   A,(BC)
	LD   B,A
	EX   AF,AF'
	LD   C,A
	LD   A,(BC)
	LD   (IX+2),A
	INC  BC
	LD   A,(BC)
	LD   (IX+3),A
	INC  BC
	LD   (IX+0),C
	LD   (IX+1),B
	JP   L50685
L50791:	SUB  112
	LD   BC,L49196
	ADD  A,A
	ADD  A,C
	LD   C,A
	ADC  A,B
	SUB  C
	LD   B,A
	LD   A,(BC)
	LD   (IX+4),A
	INC  BC
	LD   A,(BC)
	LD   (IX+5),A
	JP   L50685
L50814:	LD   (IX+7),255
	LD   A,255
	RET
L50821:	SUB  129
	JP   NZ,L50833
	XOR  A
	LD   (IX+7),A
	JP   L50685
L50833:	LD   (IX+7),16
	LD   (L50655+1),A
	LD   A,(HL)
	LD   (L50660+1),A
	INC  HL
	LD   A,(HL)
	LD   (L50660+2),A
	INC  HL
	JP   L50685
L50853:	XOR  A
	RET
L50855:	SUB  145
	LD   (L50666+1),A
	JP   L50685
L50863:	SUB  161
	ADD  A,A
	ADD  A,A
	ADD  A,A
	ADD  A,A
	LD   BC,L49420
	ADD  A,C
	LD   C,A
	ADC  A,B
	SUB  C
	LD   B,A
	LD   (IX+8),C
	LD   (IX+9),B
	JP   L50685

