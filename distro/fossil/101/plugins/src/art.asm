;******************************************************************************
;*
;* Copyright(c) 2021 Bob Fossil. All rights reserved.
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

; https://www.c64-wiki.com/wiki/Standard_Bitmap_Mode
;
; https://codebase64.org/doku.php?id=base:c64_grafix_files_specs_list_v0.03

include "plugin.asm"
include "../esxdos.asm"

DEFC ART_ADDR=49152
DEFC ART_SIZE=9002

DEFC C64_BITMAP_ADDR=ART_ADDR+2
DEFC C64_COLOUR_ADDR=C64_BITMAP_ADDR+8000

DEFC ULA_PLUS_REGISTER_PORT=48955
DEFC ULA_PLUS_REGISTER_DATA=65339
DEFC ULA_PLUS_PALETTE_SIZE=64
DEFC ULA_PLUS_REGISTER_GROUP_MODE=64

DEFC SCREEN_ROWS=24
DEFC ATTRIBUTES_START=22528

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

	defb ".ART/IPH file plugin - bob_fossil", $0


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

	ld bc, ART_SIZE			; check data is in RAM
	or a
	sbc hl, bc
	jr c, _plugin_size_error	; c cleared if hl >= bc

	ld a, h				; hl should be 0 if size is 6144
	cp 2				; some ART files are 9003 bytes
	jr c, _plugin_read

_plugin_size_error:

	ld bc, _err_unknown
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_read:

	ld a, (_plugin_file_handle)	; read file to data_addr
	ld hl, ART_ADDR

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_init

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_init:

	push ix

	call _init_ula_plus

_plugin_draw:

	call _draw_screen
	call _convert_colours

_plugin_wait:

	call _plugin_wait_for_no_keys

_plugin_main:

	call _plugin_in_inkey		; get scancode into l

					; check key up
	ld de, _plugin_user_data + PLUGIN_SETTING_OFFSET_KEY_UP
	ld a, (de)
	cp l
	jr nz, _plugin_key_down

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_FIRST
	jp _plugin_done

_plugin_key_down:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_left

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_LAST
	jp _plugin_done

_plugin_key_left:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_right

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_PREVIOUS
	jr _plugin_done

_plugin_key_right:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_one

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_NEXT
	jr _plugin_done

_plugin_key_one:

	ld a, $31
	cp l
	jr nz, _plugin_key_two

	ld hl, 0
	ld (_image_y_offset), hl
	ld (_image_y_colour_offset), hl

	jr _plugin_draw

_plugin_key_two:

	ld a, $32
	cp l
	jr nz, _plugin_key_three

	ld hl, 320
	ld (_image_y_offset), hl
	ld hl, 40
	ld (_image_y_colour_offset), hl

	jr _plugin_draw

_plugin_key_three:

	ld a, $33
	cp l
	jr nz, _plugin_key_four

	ld a, (_image_x_offset)
	and a				; don't decrement if 0
	jr z, _plugin_main
	
	sub 8
	ld (_image_x_offset), a
	srl a
	srl a
	srl a
	ld (_image_x_colour_offset), a

	jr _plugin_draw

_plugin_key_four:

	ld a, $34
	cp l
	jr nz, _plugin_key_break

	ld a, (_image_x_offset)
	cp 64				; don't increment if 64
	jp nc, _plugin_main
	
	add 8
	ld (_image_x_offset), a
	srl a
	srl a
	srl a
	ld (_image_x_colour_offset), a

	jp _plugin_draw

_plugin_key_break:

	ld a, $20			; Space
	cp l
	jp nz, _plugin_main

	call _plugin_shift_pressed
	ld a, l
	and SHIFT_CAPS			; shift + space, so return

	jp z, _plugin_main


	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_RESTORE_SCREEN

_plugin_done:

	push bc				; save navigation
	push af				; save return code

	xor a
	ld hl, ATTRIBUTES_START
	ld (hl), a
	ld de, ATTRIBUTES_START + 1
	ld bc, 767
	ldir

	call _ula_plus_off

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


_draw_screen:

	ld hl, C64_BITMAP_ADDR
	ld bc, (_image_y_offset)	; y offset
	add hl, bc

	ld b, 0
	ld a, (_image_x_offset)
	ld c, a
	add hl, bc

	ld de, 16384
	ld b, SCREEN_ROWS

_draw_screen_main:

	push bc				; bc

	ld b, 32

	push de				; de bc

_draw_screen_row:

	push bc				; bc de bc

	ld b, 8
	ld c, d

_draw_screen_block:

	ld a, (hl)
	ld (de), a
	inc hl
	inc d
	djnz _draw_screen_block
;
	ld d, c
	inc e

	pop bc				; de bc
	djnz _draw_screen_row

	pop de				; bc - restore screen address
	ld a, d
	add a, 7
	ld d, a

	inc d				; work out next screen line
	ld a, d
	and 7
	jr nz, _draw_screen_next
	ld a, e
	add a, 32
	ld e, a
	jr c, _draw_screen_next
	ld a, d
	sub 8
	ld d, a

_draw_screen_next:

	ld bc, 64
	add hl, bc

	pop bc				; ---

	djnz _draw_screen_main

	ret


_convert_colours:

	ld de, ATTRIBUTES_START
	ld hl, C64_COLOUR_ADDR
	ld bc, (_image_y_colour_offset)
	add hl, bc

	ld b, 0
	ld a, (_image_x_colour_offset)
	ld c, a
	add hl, bc

	ld b, SCREEN_ROWS

_convert_colours_loop:

	push bc

	ld b, 32

_convert_colours_row:

	ld a, b				; save b

	ld c, (hl)
	ld b, 0

	ld ix, _colour_lookup
	add ix, bc

	ld b, a				; restore b

	ld a, (ix + 0)
	ld (de), a

	inc de
	inc hl

	djnz _convert_colours_row

	ld bc, 8
	add hl, bc

	pop bc

	djnz _convert_colours_loop

	ret


_apply_palette:

	xor a

_apply_palette_set:

	ld bc, ULA_PLUS_REGISTER_PORT	; set ULAPlus colour
	out (c), a

	ld e, a				; save a in e

	ld a, (hl)			; send colour
	ld bc, ULA_PLUS_REGISTER_DATA
	out (c), a

	ld a, e				; restore a

	inc a
	inc hl

	cp ULA_PLUS_PALETTE_SIZE
	jr nz, _apply_palette_set

	ret


_ula_plus_off:

	ld hl, _ula_plus_palette_copy
	call _apply_palette

	ld bc, ULA_PLUS_REGISTER_PORT	; disable 64 colour ULA plus mode
	ld a, 64
	out (c), a

	xor a
	ld bc, ULA_PLUS_REGISTER_DATA
	out (c), a
	ret


_init_ula_plus:

	ld bc, ULA_PLUS_REGISTER_PORT
	ld a, ULA_PLUS_REGISTER_GROUP_MODE
	out (c), a

	ld a, 1
	ld bc, ULA_PLUS_REGISTER_DATA
	out (c), a			; enable 64 colour ULAPlus mode

	xor a
	ld hl, _ula_plus_palette_copy	; make a copy of the existing palette

_init_ula_copy:

	ld bc, ULA_PLUS_REGISTER_PORT
	out (c), a

	ld e, a				; save a in e

	ld bc, ULA_PLUS_REGISTER_DATA	; select colour

	nop

	in a, (c)

	ld (hl), a			; store colour value

	ld a, e

	inc a				; next colour
	inc hl

	cp ULA_PLUS_PALETTE_SIZE
	jr nz, _init_ula_copy

	ld hl, _c64_ula_palette
	call _apply_palette

	ret


include "plugin_keyboard.asm"


_image_y_offset:

	defw 0

_image_y_colour_offset:

	defw 0

_image_x_offset:

	defb 0

_image_x_colour_offset:

	defb 0

_c64_ula_palette:

	; ULAPlus palette extracted from
	;
	; https://sites.google.com/site/ulaplus/home/palettes/c64.tap?attredirects=0
	;
	defb $00, $ff, $30, $af, $52, $ad, $26, $d9	; INK 0 -7
	defb $00, $ff, $30, $af, $52, $ad, $26, $d9	; PAPER 0 -7

	defb $50, $48, $75, $49, $92, $f6, $6f, $b6	; INK 8 - 15
	defb $50, $48, $75, $49, $92, $f6, $6f, $b6	; PAPER 8 - 15

	;defb $50, $48, $75, $24, $92, $f6, $6f, $b6	; INK 8 -15
	;defb $50, $48, $75, $24, $92, $f6, $6f, $b6	; PAPER 8 -15
	;;                   ^^^
	;;                   Tweaked R,G.B as dark grey was coming out blue
	;;		    was 2,2,1, now 1, 1, 0
	;;
	defb $00, $ff, $30, $af, $52, $ad, $26, $d9	; INK 0 -7
	defb $50, $48, $75, $49, $92, $f6, $6f, $b6	; PAPER 8 -15

	defb $50, $48, $75, $49, $92, $f6, $6f, $b6	; INK 8 -15
	defb $00, $ff, $30, $af, $52, $ad, $26, $d9	; PAPER 0 -7

_colour_lookup:

	defb 0			; 000 INK 0 : PAPER 0
	defb 0 + 8		; 001 INK 0 : PAPER 1
	defb 0 + 16		; 002 INK 0 : PAPER 2
	defb 0 + 24		; 003 INK 0 : PAPER 3
	defb 0 + 32		; 004 INK 0 : PAPER 4
	defb 0 + 40		; 005 INK 0 : PAPER 5
	defb 0 + 48		; 006 INK 0 : PAPER 6 
	defb 0 + 56		; 007 INK 0 : PAPER 7
	defb 0 + 0 + 128	; 008 INK 0 : PAPER 8
	defb 0 + 8 + 128	; 009 INK 0 : PAPER 9
	defb 0 + 16 + 128 	; 010 INK 0 : PAPER 10
	defb 0 + 24 + 128	; 011 INK 0 : PAPER 11
	defb 0 + 32 + 128	; 012 INK 0 : PAPER 12
	defb 0 + 40 + 128	; 013 INK 0 : PAPER 13
	defb 0 + 48 + 128	; 014 INK 0 : PAPER 14
	defb 0 + 56 + 128	; 015 INK 0 : PAPER 15

	defb 1			; 016 INK 1 : PAPER 0
	defb 1 + 8		; 017 INK 1 : PAPER 1
	defb 1 + 16		; 018 INK 1 : PAPER 2
	defb 1 + 24		; 019 INK 1 : PAPER 3
	defb 1 + 32 		; 020 INK 1 : PAPER 4 
	defb 1 + 40		; 021 INK 1 : PAPER 5 
	defb 1 + 48		; 022 INK 1 : PAPER 6 
	defb 1 + 56		; 023 INK 1 : PAPER 7
	defb 1 + 0 + 128	; 024 INK 1 : PAPER 8
	defb 1 + 8 + 128	; 025 INK 1 : PAPER 9
	defb 1 + 16 + 128	; 026 INK 1 : PAPER 10
	defb 1 + 24 + 128	; 027 INK 1 : PAPER 11
	defb 1 + 32 + 128	; 028 INK 1 : PAPER 12
	defb 1 + 40 + 128	; 029 INK 1 : PAPER 13
	defb 1 + 48 + 128	; 030 INK 1 : PAPER 14
	defb 1 + 56 + 128	; 031 INK 1 : PAPER 15

	defb 2			; 032 INK 2 : PAPER 0
	defb 2 + 8		; 033 INK 2 : PAPER 1
	defb 2 + 16		; 034 INK 2 : PAPER 2
	defb 2 + 24		; 035 INK 2 : PAPER 3
	defb 2 + 32		; 036 INK 2 : PAPER 4
	defb 2 + 40		; 037 INK 2 : PAPER 5
	defb 2 + 48		; 038 INK 2 : PAPER 6
	defb 2 + 56		; 039 INK 2 : PAPER 7
	defb 2 + 0 + 128	; 040 INK 2 : PAPER 8
	defb 2 + 8 + 128	; 041 INK 2 : PAPER 9
	defb 2 + 16 + 128	; 042 INK 2 : PAPER 10
	defb 2 + 24 + 128	; 043 INK 2 : PAPER 11
	defb 2 + 32 + 128	; 044 INK 2 : PAPER 12
	defb 2 + 40 + 128	; 045 INK 2 : PAPER 13
	defb 2 + 48 + 128	; 046 INK 2 : PAPER 14
	defb 2 + 56 + 128	; 047 INK 2 : PAPER 15

	defb 3 			; 048 INK 3 : PAPER 0
	defb 3 + 8 		; 049 INK 3 : PAPER 1
	defb 3 + 16		; 050 INK 3 : PAPER 2
	defb 3 + 24		; 051 INK 3 : PAPER 3
	defb 3 + 32		; 052 INK 3 : PAPER 4
	defb 3 + 40		; 053 INK 3 : PAPER 5
	defb 3 + 48		; 054 INK 3 : PAPER 6
	defb 3 + 56		; 055 INK 3 : PAPER 7
	defb 3 + 0 + 128	; 056 INK 3 : PAPER 8
	defb 3 + 8 + 128	; 057 INK 3 : PAPER 9
	defb 3 + 16 + 128	; 058 INK 3 : PAPER 10
	defb 3 + 24 + 128	; 059 INK 3 : PAPER 11
	defb 3 + 32 + 128	; 060 INK 3 : PAPER 12
	defb 3 + 40 + 128	; 061 INK 3 : PAPER 13
	defb 3 + 48 + 128	; 062 INK 3 : PAPER 14
	defb 3 + 56 + 128	; 063 INK 3 : PAPER 15

	defb 4			; 064 INK 4 : PAPER 0
	defb 4 + 8		; 065 INK 4 : PAPER 1
	defb 4 + 16		; 066 INK 4 : PAPER 2
	defb 4 + 24		; 067 INK 4 : PAPER 3
	defb 4 + 32		; 068 INK 4 : PAPER 4
	defb 4 + 40		; 069 INK 4 : PAPER 5
	defb 4 + 48		; 070 INK 4 : PAPER 6
	defb 4 + 56		; 071 INK 4 : PAPER 7
	defb 4 + 0 + 128	; 072 INK 4 : PAPER 8
	defb 4 + 8 + 128	; 073 INK 4 : PAPER 9
	defb 4 + 16 + 128	; 074 INK 4 : PAPER 10
	defb 4 + 24 + 128	; 075 INK 4 : PAPER 11
	defb 4 + 32 + 128	; 076 INK 4 : PAPER 12
	defb 4 + 40 + 128	; 077 INK 4 : PAPER 13
	defb 4 + 48 + 128	; 078 INK 4 : PAPER 14
	defb 4 + 56 + 128	; 079 INK 4 : PAPER 15

	defb 5			; 080 INK 5 : PAPER 0
	defb 5 + 8		; 081 INK 5 : PAPER 1
	defb 5 + 16		; 082 INK 5 : PAPER 2
	defb 5 + 24		; 083 INK 5 : PAPER 3
	defb 5 + 32		; 084 INK 5 : PAPER 4
	defb 5 + 40		; 085 INK 5 : PAPER 5
	defb 5 + 48		; 086 INK 5 : PAPER 6
	defb 5 + 56		; 087 INK 5 : PAPER 7
	defb 5 + 0 + 128	; 088 INK 5 : PAPER 8
	defb 5 + 8 + 128	; 089 INK 5 : PAPER 9
	defb 5 + 16 + 128	; 090 INK 5 : PAPER 10
	defb 5 + 24 + 128	; 091 INK 5 : PAPER 11
	defb 5 + 32 + 128	; 092 INK 5 : PAPER 12
	defb 5 + 40 + 128	; 093 INK 5 : PAPER 13
	defb 5 + 48 + 128	; 094 INK 5 : PAPER 14
	defb 5 + 56 + 128	; 095 INK 5 : PAPER 15

	defb 6			; 096 INK 6 : PAPER 0
	defb 6 + 8		; 097 INK 6 : PAPER 1
	defb 6 + 16		; 098 INK 6 : PAPER 2
	defb 6 + 24		; 099 INK 6 : PAPER 3
	defb 6 + 32		; 100 INK 6 : PAPER 4
	defb 6 + 40		; 101 INK 6 : PAPER 5
	defb 6 + 48		; 102 INK 6 : PAPER 6
	defb 6 + 56		; 103 INK 6 : PAPER 7
	defb 6 + 0 + 128	; 104 INK 6 : PAPER 8
	defb 6 + 8 + 128	; 105 INK 6 : PAPER 9
	defb 6 + 16 + 128	; 106 INK 6 : PAPER 10
	defb 6 + 24 + 128	; 107 INK 6 : PAPER 11
	defb 6 + 32 + 128	; 108 INK 6 : PAPER 12
	defb 6 + 40 + 128	; 109 INK 6 : PAPER 13
	defb 6 + 48 + 128	; 110 INK 6 : PAPER 14
	defb 6 + 56 + 128	; 111 INK 6 : PAPER 15

	defb 7			; 112 INK 7 : PAPER 0
	defb 7 + 8		; 113 INK 7 : PAPER 1
	defb 7 + 16		; 114 INK 7 : PAPER 2
	defb 7 + 24		; 115 INK 7 : PAPER 3
	defb 7 + 32		; 116 INK 7 : PAPER 4
	defb 7 + 40		; 117 INK 7 : PAPER 5
	defb 7 + 48		; 118 INK 7 : PAPER 6
	defb 7 + 56		; 119 INK 7 : PAPER 7
	defb 7 + 0 + 128	; 120 INK 7 : PAPER 8
	defb 7 + 8 + 128	; 121 INK 7 : PAPER 9
	defb 7 + 16 + 128	; 122 INK 7 : PAPER 10
	defb 7 + 24 + 128	; 123 INK 7 : PAPER 11
	defb 7 + 32 + 128	; 124 INK 7 : PAPER 12
	defb 7 + 40 + 128	; 125 INK 7 : PAPER 13
	defb 7 + 48 + 128	; 126 INK 7 : PAPER 14
	defb 7 + 56 + 128	; 127 INK 7 : PAPER 15

	defb 0 + 0 + 128 + 64	; 128 INK 8 : PAPER 0
	defb 0 + 8 + 128 + 64	; 129 INK 8 : PAPER 1
	defb 0 + 16 + 128 + 64	; 130 INK 8 : PAPER 2
	defb 0 + 24 + 128 + 64	; 131 INK 8 : PAPER 3
	defb 0 + 32 + 128 + 64	; 132 INK 8 : PAPER 4
	defb 0 + 40 + 128 + 64	; 133 INK 8 : PAPER 5
	defb 0 + 48 + 128 + 64	; 134 INK 8 : PAPER 6
	defb 0 + 56 + 128 + 64	; 135 INK 8 : PAPER 7
	defb 0 + 24 + 128 + 64	; 136 INK 8 : PAPER 8
	defb 0 + 8 + 64		; 137 INK 8 : PAPER 9
	defb 0 + 16 + 64	; 138 INK 8 : PAPER 10
	defb 0 + 24 + 64	; 139 INK 8 : PAPER 11
	defb 0 + 32 + 64	; 140 INK 8 : PAPER 12
	defb 0 + 40 + 64	; 141 INK 8 : PAPER 13
	defb 0 + 48 + 64	; 142 INK 8 : PAPER 14
	defb 0 + 56 + 64	; 143 INK 8 : PAPER 15

	defb 1 + 0 + 128 + 64	; 144 INK 9 : PAPER 0
	defb 1 + 8 + 128 + 64	; 145 INK 9 : PAPER 1
	defb 1 + 16 + 128 + 64	; 146 INK 9 : PAPER 2
	defb 1 + 24 + 128 + 64	; 147 INK 9 : PAPER 3
	defb 1 + 32 + 128 + 64	; 148 INK 9 : PAPER 4
	defb 1 + 40 + 128 + 64	; 149 INK 9 : PAPER 5
	defb 1 + 48 + 128 + 64	; 150 INK 9 : PAPER 6
	defb 1 + 56 + 128 + 64	; 151 INK 9 : PAPER 7
	defb 1 + 0 + 64		; 152 INK 9 : PAPER 8
	defb 1 + 8 + 64		; 153 INK 9 : PAPER 9
	defb 1 + 16 + 64	; 154 INK 9 : PAPER 10
	defb 1 + 24 + 64	; 155 INK 9 : PAPER 11
	defb 1 + 32 + 64	; 156 INK 9 : PAPER 12
	defb 1 + 40 + 64	; 157 INK 9 : PAPER 13
	defb 1 + 48 + 64	; 158 INK 9 : PAPER 14
	defb 1 + 56 + 64	; 159 INK 9 : PAPER 15

	defb 2 + 0 + 128 + 64	; 160 INK 10 : PAPER 0
	defb 2 + 8 + 128 + 64	; 161 INK 10 : PAPER 1
	defb 2 + 16 + 128 + 64	; 162 INK 10 : PAPER 2
	defb 2 + 24 + 128 + 64	; 163 INK 10 : PAPER 3
	defb 2 + 32 + 128 + 64	; 164 INK 10 : PAPER 4
	defb 2 + 40 + 128 + 64	; 165 INK 10 : PAPER 5
	defb 2 + 48 + 128 + 64	; 166 INK 10 : PAPER 6
	defb 2 + 56 + 128 + 64	; 167 INK 10 : PAPER 7
	defb 2 + 0 + 64		; 168 INK 10 : PAPER 8
	defb 2 + 8 + 64		; 169 INK 10 : PAPER 9
	defb 2 + 16 + 64	; 170 INK 10 : PAPER 10
	defb 2 + 24 + 64	; 171 INK 10 : PAPER 11
	defb 2 + 32 + 64	; 172 INK 10 : PAPER 12
	defb 2 + 40 + 64	; 173 INK 10 : PAPER 13
	defb 2 + 48 + 64	; 174 INK 10 : PAPER 14
	defb 2 + 56 + 64	; 175 INK 10 : PAPER 15

	defb 3 + 0 + 128 + 64	; 176 INK 11 : PAPER 0
	defb 3 + 8 + 128 + 64	; 177 INK 11 : PAPER 1
	defb 3 + 16 + 128 + 64	; 178 INK 11 : PAPER 2
	defb 3 + 24 + 128 + 64	; 179 INK 11 : PAPER 3
	defb 3 + 32 + 128 + 64	; 180 INK 11 : PAPER 4
	defb 3 + 40 + 128 + 64	; 181 INK 11 : PAPER 5
	defb 3 + 48 + 128 + 64	; 182 INK 11 : PAPER 6
	defb 3 + 56 + 128 + 64	; 183 INK 11 : PAPER 7
	defb 3 + 0 + 64		; 184 INK 11 : PAPER 8
	defb 3 + 8 + 64		; 185 INK 11 : PAPER 9
	defb 3 + 16 + 64	; 186 INK 11 : PAPER 10
	defb 3 + 24 + 64	; 187 INK 11 : PAPER 11
	defb 3 + 32 + 64	; 188 INK 11 : PAPER 12
	defb 3 + 40 + 64	; 189 INK 11 : PAPER 13
	defb 3 + 48 + 64	; 190 INK 11 : PAPER 14
	defb 3 + 56 + 64	; 191 INK 11 : PAPER 15

	defb 4 + 0 + 128 + 64	; 192 INK 12 : PAPER 0
	defb 4 + 8 + 128 + 64	; 193 INK 12 : PAPER 1
	defb 4 + 16 + 128 + 64	; 194 INK 12 : PAPER 2
	defb 4 + 24 + 128 + 64	; 195 INK 12 : PAPER 3
	defb 4 + 32 + 128 + 64	; 196 INK 12 : PAPER 4
	defb 4 + 40 + 128 + 64	; 197 INK 12 : PAPER 5
	defb 4 + 48 + 128 + 64	; 198 INK 12 : PAPER 6
	defb 4 + 56 + 128 + 64	; 199 INK 12 : PAPER 7
	defb 4 + 0 + 64		; 200 INK 12 : PAPER 8
	defb 4 + 8 + 64		; 201 INK 12 : PAPER 9
	defb 4 + 16 + 64	; 202 INK 12 : PAPER 10
	defb 4 + 24 + 64	; 203 INK 12 : PAPER 11
	defb 4 + 32 + 64	; 204 INK 12 : PAPER 12
	defb 4 + 40 + 64	; 205 INK 12 : PAPER 13
	defb 4 + 48 + 64	; 206 INK 12 : PAPER 14
	defb 4 + 56 + 64	; 207 INK 12 : PAPER 15

	defb 5 + 0 + 128 + 64	; 208 INK 13 : PAPER 0
	defb 5 + 8 + 128 + 64	; 209 INK 13 : PAPER 1
	defb 5 + 16 + 128 + 64	; 210 INK 13 : PAPER 2
	defb 5 + 24 + 128 + 64	; 211 INK 13 : PAPER 3
	defb 5 + 32 + 128 + 64	; 212 INK 13 : PAPER 4
	defb 5 + 40 + 128 + 64	; 213 INK 13 : PAPER 5
	defb 5 + 48 + 128 + 64	; 214 INK 13 : PAPER 6
	defb 5 + 56 + 128 + 64	; 215 INK 13 : PAPER 7
	defb 5 + 0 + 64		; 216 INK 13 : PAPER 8
	defb 5 + 8 + 64		; 217 INK 13 : PAPER 9
	defb 5 + 16 + 64	; 218 INK 13 : PAPER 10
	defb 5 + 24 + 64	; 219 INK 13 : PAPER 11
	defb 5 + 32 + 64	; 220 INK 13 : PAPER 12
	defb 5 + 40 + 64	; 221 INK 13 : PAPER 13
	defb 5 + 48 + 64	; 222 INK 13 : PAPER 14
	defb 5 + 56 + 64	; 223 INK 13 : PAPER 15

	defb 6 + 0 + 128 + 64	; 224 INK 14 : PAPER 0
	defb 6 + 8 + 128 + 64	; 225 INK 14 : PAPER 1
	defb 6 + 16 + 128 + 64	; 226 INK 14 : PAPER 2
	defb 6 + 24 + 128 + 64	; 227 INK 14 : PAPER 3
	defb 6 + 32 + 128 + 64	; 228 INK 14 : PAPER 4
	defb 6 + 40 + 128 + 64	; 229 INK 14 : PAPER 5
	defb 6 + 48 + 128 + 64	; 230 INK 14 : PAPER 6
	defb 6 + 56 + 128 + 64	; 231 INK 14 : PAPER 7
	defb 6 + 0 + 64		; 232 INK 14 : PAPER 8
	defb 6 + 8 + 64		; 233 INK 14 : PAPER 9
	defb 6 + 16 + 64	; 234 INK 14 : PAPER 10
	defb 6 + 24 + 64	; 235 INK 14 : PAPER 11
	defb 6 + 32 + 64	; 236 INK 14 : PAPER 12
	defb 6 + 40 + 64	; 237 INK 14 : PAPER 13
	defb 6 + 48 + 64	; 238 INK 14 : PAPER 14
	defb 6 + 56 + 64	; 239 INK 14 : PAPER 15

	defb 7 + 0 + 128 + 64	; 240 INK 15 : PAPER 0	
	defb 7 + 8 + 128 + 64	; 241 INK 15 : PAPER 1
	defb 7 + 16 + 128 + 64	; 242 INK 15 : PAPER 2
	defb 7 + 24 + 128 + 64	; 243 INK 15 : PAPER 3
	defb 7 + 32 + 128 + 64	; 244 INK 15 : PAPER 4
	defb 7 + 40 + 128 + 64	; 245 INK 15 : PAPER 5
	defb 7 + 48 + 128 + 64	; 246 INK 15 : PAPER 6
	defb 7 + 56 + 128 + 64	; 247 INK 15 : PAPER 7
	defb 7 + 0 + 64		; 248 INK 15 : PAPER 8
	defb 7 + 8 + 64		; 249 INK 15 : PAPER 9
	defb 7 + 16 + 64	; 250 INK 15 : PAPER 10	
	defb 7 + 24 + 64	; 251 INK 15 : PAPER 11
	defb 7 + 32 + 64	; 252 INK 15 : PAPER 12
	defb 7 + 40 + 64	; 253 INK 15 : PAPER 13
	defb 7 + 48 + 64	; 254 INK 15 : PAPER 14
	defb 7 + 56 + 64	; 255 INK 15 : PAPER 15

_ula_plus_palette_copy:

	defs(ULA_PLUS_PALETTE_SIZE)

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

_err_unknown:

	defb "Unsupported format!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

