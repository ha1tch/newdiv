;******************************************************************************
;*
;* Copyright(c) 2020-21 Bob Fossil. All rights reserved.
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

DEFC SCR_SIZE=6912
DEFC SCR_SIZE_MONO=6144
DEFC SCR_SUZE_ULA_PLUS=6976
DEFC SCR_ADDRESS=16384
DEFC SCR_ADDRESS_ATTRIBUTES=22528
DEFC ATTRIBUTES_SIZE=768

DEFC ULA_PLUS_REGISTER_PORT=48955
DEFC ULA_PLUS_REGISTER_DATA=65339
DEFC ULA_PLUS_PALETTE_SIZE=64
DEFC ULA_PLUS_REGISTER_GROUP_MODE=64

DEFC SETTING_ENABLE_SLIDESHOW=1

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

	defb ".SCR screen plugin - bob_fossil", $0

_plugin_start:

	; hl is the filename
	; de is the address of the settings buffer or 0

	ld a, d				; check for settings buffer
	or e
	jr z, _plugin_no_cfg

	ld (_plugin_cfg), a		; store we have a cfg file

	ld a, (de)
	ld (_plugin_cfg_flags), a

_plugin_no_cfg:

	ld a, (_plugin_cfg_flags)
	and SETTING_ENABLE_SLIDESHOW
	jr z, _plugin_open

	inc de
	ld a, (de)
;	ld (_plugin_cfg_slideshow_delay), a
	
	push hl
	ld hl, 0
	
	ld d, 0
	ld e, a
	ld b, 50
	
_plugin_halt_multiply_loop:

	add hl, de
	djnz _plugin_halt_multiply_loop
	
	ld (_plugin_slideshow_halts), hl
	pop hl

_plugin_open:

	xor a
	ld (_plugin_file_handle), a

	ld a, ESXDOS_CURRENT_DRIVE	; *

	ld b, ESXDOS_MODE_READ

	rst ESXDOS_SYS_CALL		; open file for reading
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
	jp _plugin_error

_plugin_size:

	ld hl, (_plugin_file_stat + 7)	; put 16 bit file size into hl
	ld bc, SCR_SIZE_MONO		; check if filesize HL == 6144
	or a
	sbc hl, bc
	jr c, _plugin_size_error	; c cleared if hl >= bc

	ld a, h				; hl should be 0 if size is 6144
	or l
	jr z, _plugin_mono_attr

	ld bc, ATTRIBUTES_SIZE		; if 6912 bytes, we should have 768 left iover
	or a
	sbc hl, bc

	ld bc, SCR_SIZE
	ld a, h				; hl should be 0 if remainder was 768
	or l
	jr z, _plugin_read

	ld a, h
	or l
	ld l, a
	ld a, ULA_PLUS_PALETTE_SIZE	; hl should be 64 if ULA plus screen (6976)
	cp l
	jr nz, _plugin_size_error

	ld a, 1
	ld (_plugin_ula_plus), a
	jr _plugin_read

_plugin_size_error:

	ld bc, _err_size
	jp _plugin_error

_plugin_mono_attr:

	ld a, 56 + 64			; ; PAPER 7 : INK 0 : BRIGHT 1
	call _set_attributes

	ld a, 1
	ld (_plugin_monochrome), a
	ld bc, SCR_SIZE_MONO

_plugin_read:

	ld a, (_plugin_file_handle)

	ld hl, SCR_ADDRESS

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_wait

	ld bc, _err_io
	jp _plugin_error
	

_plugin_wait:

	ei

	ld a, (_plugin_ula_plus)
	and a
	call nz, _init_ula_plus

	call _plugin_wait_for_no_keys

_plugin_main:

	call _plugin_in_inkey		; get scancode into l

	ld a, (_plugin_cfg_flags)
	and SETTING_ENABLE_SLIDESHOW
	jr z, _plugin_keys

_plugin_slideshow:

	ld c, l

	halt
	ld hl, (_plugin_slideshow_halts)
	dec hl
	ld (_plugin_slideshow_halts), hl

	ld a, h
	or l
	
	ld l, c
	
	jr nz, _plugin_keys
	
	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_NEXT
	jr _plugin_done	
	
	jr _plugin_main

_plugin_keys:

					; check key up
	ld de, _plugin_user_data + PLUGIN_SETTING_OFFSET_KEY_UP
	ld a, (de)
	cp l
	jr nz, _plugin_key_down

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_FIRST
	jr _plugin_done

_plugin_key_down:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_left

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_LAST
	jr _plugin_done

_plugin_key_left:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_right

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_PREVIOUS
	jr _plugin_done

_plugin_key_right:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_attr

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_NEXT
	jr _plugin_done

_plugin_key_attr:

	ld a, $41			; Shift + A
	cp l
	jr nz, _plugin_key_break

	call _toggle_attr

	jr z, _plugin_wait

_plugin_key_break:

	ld a, $20			; Space
	cp l
	jr nz, _plugin_main

	call _plugin_shift_pressed
	ld a, l
	and SHIFT_CAPS			; shift + space, so return

	jr z, _plugin_main

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN

_plugin_done:

	di

	ld (_plugin_ok_ret + 1), a

	push bc

	ld a, (_plugin_ula_plus)
	and a
	call nz, _ula_plus_off

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop bc

_plugin_ok_ret:

	ld a, 0
	ret

_plugin_error:

	push bc

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop bc

	ld a, PLUGIN_ERROR
	ret


_toggle_attr:

	ld a, (_plugin_monochrome)	; do nothing for mono .scr files
	and a
	ret nz

	ld a, (_plugin_hide_attributes)
	and a

	jr z, _toggle_attr_off

	xor a				; restore attributes
	ld (_plugin_hide_attributes), a

	ld hl, _plugin_attr_buffer	; restiore attributes to screen
	ld de, SCR_ADDRESS_ATTRIBUTES
	ld bc, ATTRIBUTES_SIZE
	ldir

	jr _toggle_attr_shift

_toggle_attr_off:

	inc a				; remove attributes
	ld (_plugin_hide_attributes), a

	ld hl, SCR_ADDRESS_ATTRIBUTES	; copy current attributes to buffer
	ld de, _plugin_attr_buffer
	ld bc, ATTRIBUTES_SIZE
	ldir

	ld a, 56			; PAPER 7 : INK 0
	call _set_attributes

_toggle_attr_shift:

	ld bc, $fefe
	in a, (c)
	and %00000001			; shift pressed?
	jr z, _toggle_attr_shift	; loop until shift released

	ret

_set_attributes:

	ld hl, SCR_ADDRESS_ATTRIBUTES	; a = attribute to set
	ld (hl), a
	ld de, SCR_ADDRESS_ATTRIBUTES + 1
	ld bc, 767
	ldir

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

	ld a, (_plugin_file_handle)
	ld hl, _ula_plus_palette
	ld bc, ULA_PLUS_PALETTE_SIZE

	rst ESXDOS_SYS_CALL		; read palette
	defb ESXDOS_SYS_F_READ

	ret c

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

	ld hl, _ula_plus_palette
	call _apply_palette

	ret

include "plugin_keyboard.asm"

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

_err_size:

	defb "Invalid .SCR file!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0


_plugin_cfg:

	defb $0

_plugin_cfg_flags:

	defb $0
	
;_plugin_cfg_slideshow_delay:
;
;	defb 0
	
_plugin_slideshow_halts:

	defw 0

_plugin_monochrome:

	defb 0

_plugin_hide_attributes:

	defb 0

_plugin_ula_plus:

	defb 0

_ula_plus_palette:

	defs(ULA_PLUS_PALETTE_SIZE)

_ula_plus_palette_copy:

	defs(ULA_PLUS_PALETTE_SIZE)


_plugin_attr_buffer:
