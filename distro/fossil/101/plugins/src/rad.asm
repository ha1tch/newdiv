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

include "plugin.asm"
include "../esxdos.asm"

DEFC BMP_SIZE=6262
DEFC RAW_PALETTE_SIZE=16
DEFC RAW_SIZE=6160

DEFC ZX_UNO_REGISTER_PORT=64571
DEFC ZX_UNO_DATA_PORT=64827
DEFC COREID_REGISTER=$ff

DEFC RADASCTRL=$40
DEFC RADISTAN_ON=3
DEFC RADISTAN_OFF=0
DEFC RADISTAN_PALETTE_INDEX=$bf3b
DEFC RADISTAN_PALETTE_VALUE=$ff3b

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

	defb ".RAD Radistan bitmap plugin - ???/bob_fossil", $0

_plugin_start:

	; hl is the filename

	call _zx_uno_test
	jr nc, _plugin_uno_ok

	ld bc, _err_uno
	ld a, PLUGIN_ERROR
	ret

_plugin_uno_ok:

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
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_size:

	ld hl, (_plugin_file_stat + 7)	; put 16 bit file size into hl
	ld bc, BMP_SIZE			; check if filesize HL == 6262
	or a
	sbc hl, bc
	jr c, _plugin_size_raw		; c cleared if hl >= bc

	ld a, h				; hl should be 0 if size is 13824
	or l
	jr z, _plugin_read

_plugin_size_raw:

	ld hl, (_plugin_file_stat + 7)	; put 16 bit file size into hl
	ld bc, RAW_SIZE			; check if filesize HL == 6160
	or a
	sbc hl, bc
	jr c, _plugin_size_error	; c cleared if hl >= bc

	ld a, h				; hl should be 0 if size is 13824
	or l
	jr z, _plugin_read_raw

_plugin_size_error:

	ld bc, _err_not_bmp
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_read_raw:

	ld a, 1
	ld ( _plugin_file_type), a
	call _plugin_cls

	ld a, (_plugin_file_handle)
	ld bc, RAW_SIZE - RAW_PALETTE_SIZE
	ld hl, 16384

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

	jr c, _plugin_raw_read_error

	ld a, (_plugin_file_handle)	; load palette to buffer
	ld bc, RAW_PALETTE_SIZE
	ld hl, _buffer

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

	jr c, _plugin_raw_read_error

	ld hl, _buffer
	xor a
	ld c, $3b			; Radistan port low byte in c

_plugin_raw_palette:

	ld b, $bf
	out (c), a

	ld d, a
	ld a, (hl)

	ld b, $ff
	out (c), a

	ld a, d
	inc a
	inc hl

	cp RAW_PALETTE_SIZE

	jr nz, _plugin_raw_palette

					; Enter Radastan mode.
	ld a, RADISTAN_ON
	call _set_radastan_mode
	jr _plugin_wait

_plugin_raw_read_error:

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_SCREEN
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_read:

	ld a, (_plugin_file_handle)
	ld bc, BMP_SIZE
	ld hl, _buffer

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_show

	ld bc, _err_io
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_show:

	call _plugin_cls
	call _display

_plugin_wait:

	call _plugin_wait_for_no_keys

_plugin_main:

	call _plugin_in_inkey		; get scancode into l

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
	jr nz, _plugin_key_break

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_NEXT
	jr _plugin_done

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

	push af
	push bc

					; Exit Radastan mode.
	ld a, RADISTAN_OFF
	call _set_radastan_mode

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop bc
	pop af

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


_plugin_cls:

					; set attributes to hidden to hide the
					; Radistan data before display

	ld a, (_plugin_user_data + PLUGIN_SETTING_OFFSET_FILE)
	ld b, a
	and a, %00111000		; mask PAPER
	srl b				; divide PAPER by 8 to get INK
	srl b
	srl b
	or b				; or INK

	ld hl, 22528
	ld (hl), a
	ld de, 22529
	ld bc, 767
	ldir
	ret


_set_radastan_mode:

	ld e, a				; a is either RADISTAN_ON or RADISTAN_OFF

	ld bc, ZX_UNO_REGISTER_PORT
	ld a, RADASCTRL
	out (c), a

	ld bc, ZX_UNO_DATA_PORT
	ld a, e
	out (c), a

	ret


;

_display:

					; Convert BMP palette to ULAplus palette entry
	ld hl, _buffer + $36		; BMP palette offset. Format is BGRA
	ld bc, RADISTAN_PALETTE_INDEX
	ld e, 0

BucPaleta:

	out (c), e
	ld b, $ff
	ld a, (hl)			 ; blue
	sra a
	sra a
	sra a
	sra a
	sra a
	sra a
	and 3
	ld d, a
	inc hl
	ld a, (hl)			 ; green
	and %11100000
	or d
	ld d, a
	inc hl
	ld a, (hl)			; red
	sra a
	sra a
	sra a
	and %00011100
	or d
	out (c), a
	inc hl
	inc hl				; skip the alpha byte
	ld b, $bf
	inc e
	ld a, e
	cp 16
	jr nz, BucPaleta

					; Enter Radastan mode.
	ld a, RADISTAN_ON
	call _set_radastan_mode

	ld hl, _buffer + $76 + 95 * 64	; offset to the last BMP stored scanline (the first we see on screen)
	ld de, 16384			; offset to the Spectrum screen buffer
	ld b, 96

BucPintaScans:

	push bc
	ld bc, 64
	ldir
	ld bc, -128
	add hl, bc
	pop bc
	djnz BucPintaScans

	ret


_zx_uno_test:

	ld bc, ZX_UNO_REGISTER_PORT
	ld a, COREID_REGISTER
	out (c), a

	ld e, 0

_zx_uno_test_get_char:

	ld bc, ZX_UNO_DATA_PORT
	in a, (c)			; a is now COREID

	and a				; test for 0
	jr z, _zx_uno_test_end

	cp 32
	jr c, _zx_uno_test_end		; < 32
	cp 128
	jr nc, _zx_uno_test_end		; >= 128

	inc e
	jr _zx_uno_test_get_char

_zx_uno_test_end:

	ld a, e				; ZX-UNO returns version string, e.g.
					; 'EXP27-300320'
	cp 2				; 'a' will be 1 if TR_DOS is paged in, so test
					; for at least 2 characters.
	ret


include "plugin_keyboard.asm"

_plugin_file_handle:

	defb 0

_plugin_file_type:

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

_err_not_bmp:

	defb "Invalid file type!", $0

_err_io:

	defb "IO error!", $0

_err_uno:

	defb "This plugin requires a ZX-UNO!", $0

_err_file:

	defb "Couldn't open file!", $0

_buffer:

