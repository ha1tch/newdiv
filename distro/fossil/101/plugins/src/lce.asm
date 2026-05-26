;******************************************************************************
;*
;* Copyright(c) 2020 Bob Fossil. All rights reserved.
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

DEFC LCE_SIZE=13824

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

	defb ".LCE/IMG screen plugin - velesoft/bob_fossil", $0

_plugin_start:

	; hl is the filename
	; bc is the parameter block

	ld (_plugin_param_block), bc

	call _check_128
	jr nz, _plugin_got_128

	ld bc, _err_128
	ld a, PLUGIN_ERROR
	ret

_plugin_got_128:

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
	ld bc, LCE_SIZE			; check if filesize HL == 13824
	or a
	sbc hl, bc
	jr c, _plugin_size_error	; c cleared if hl >= bc

	ld a, h				; hl should be 0 if size is 13824
	or l
	jr z, _plugin_read

_plugin_size_error:

	ld bc, _err_size
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_read:

	ld a, (_plugin_file_handle)

	ld bc, LCE_SIZE / 2
	ld hl, 16384

	rst ESXDOS_SYS_CALL		; read first screen
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_read2

	ld bc, _err_io
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_read2:

	ld a, 7				; switch to bank 7
	ld bc, $7ffd
	out (c), a

	ld hl, 49152			; copy original memory from bank to our buffer
	ld de, _plugin_scr_copy
	ld bc, LCE_SIZE / 2
	ldir

	ld bc, LCE_SIZE / 2
	ld hl, 49152
	ld a, (_plugin_file_handle)

	rst ESXDOS_SYS_CALL		; read second screen
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_init

	ld bc, _err_io
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_init:

	ld hl, (_plugin_param_block)	; ensure we switch back to the previous bank
	ld a, (hl)
	ld (_plugin_bank_restore + 1), a

	ei

_plugin_wait:

	call _plugin_wait_for_no_keys

_plugin_main:

	ld bc, $7ffd

	halt				; switch screens
	ld a, $18
	out (c), a
	halt
	ld a, $10
	out (c), a

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

;	ld bc, $fefe
;	in a, (c)
;	and %00000001			; shift pressed?
;	jr nz, _plugin_loop
;
;	ld b, $f7
;	in a, (c)
;	and %00010000			; check for shift + 5
;	jr nz, _plugin_skip_prev
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
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
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_NEXT
;	jr _plugin_done
;
;_plugin_skip_next:
;
;	ld a, b
;	and %00001000			; check for shift + 7
;	jr nz, _plugin_skip_last
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_FIRST
;	jr _plugin_done
;
;_plugin_skip_last:
;
;	ld a, b
;	and %00010000			; check for shift + 6
;	jr nz, _plugin_skip_first
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_LAST
;	jr _plugin_done
;
;_plugin_skip_first:
;
;	ld b, $7f
;	in a, (c)
;	and %00000001			; check for shift + space
;
;	jr nz, _plugin_loop

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN

_plugin_done:

	push bc
	ld (_plugin_ok_ret + 1), a

	di

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ld a, 7
	ld bc, $7ffd
	out (c), a

	ld de, 49152
	ld hl, _plugin_scr_copy
	ld bc, LCE_SIZE / 2
	ldir

_plugin_bank_restore:

	ld a, 0
	ld bc, $7ffd
	out (c), a

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

_plugin_error_ret:

	ld a, 0

	ret

_check_128:

	ld a, 16
	call _bank_switch

	ld a, (49152)
	ld d, a				; store bank 16 byte
	ld a, 48			; put 48 into bank 16
	ld (49152), a

	ld a, 17
	call _bank_switch

	ld a, (49152)
	ld e, a				; store bank 17 byte
	ld a, 128			; put 128 into bank 17
	ld (49152), a

	ld a, 16			; switch back to bank 16
	call _bank_switch

	ld a, (49152)
	cp 48				; will be 128 if 48k
	jr nz, _check_not_128

	ld a, d				; restore bank 16 byte
	ld (49152), a

	ld a, 17			; switch to bank 17
	call _bank_switch

	ld a, e				; restore bank 17 byte
	ld (49152), a

	ld a, 16			; switch back to bank 16
	call _bank_switch
	or a
	ret

_check_not_128:

	ld a, d				; restore 48k ram byte
	ld (49152), a
	ld a, 0
	and 1
	ret

_bank_switch:

	ld bc, 0x7ffd
	out (c), a
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

	defb "Invalid filetype!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

_err_128:

	defb "This plugin requires 128k hardware!", $0

_plugin_param_block:

	defw 0

_plugin_scr_copy:


