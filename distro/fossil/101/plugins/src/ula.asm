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

DEFC ULA_PLUS_REGISTER_PORT=48955
DEFC ULA_PLUS_REGISTER_DATA=65339
DEFC ULA_PLUS_PALETTE_SIZE=64
DEFC ULA_PLUS_TAP_SIZE=176
DEFC ULA_PLUS_TAP_PALETTE_OFFSET=$6e
DEFC ULA_PLUS_REGISTER_GROUP_MODE=64

;ULA!
;PALETTE=COMMANDO.TAP
;GAME=COMMANDO.ULA


	org PLUGIN_ORG

	jr _plugin_start

_plugin_info:

	defb "BP"				; id
	defb 0					; spare
	defb 0					; spare
	defb 0					; flags
	defb 0					; flags2
	defb "ULAplus palette file plugin - bob_fossil", $0


_plugin_start:

					; filename in hl
					; parameter block in bc

	inc bc				; check if we're the NMI
	ld a, (bc)			; are we running from NMI?
	ld (_plugin_nmi), a

	call _read_file_to_buffer
	cp PLUGIN_ERROR
	ret z

	xor a
	ld (hl), a			; after reading, hl is the address after
					; the last byte
					; zero terminate the buffer
	inc hl
	ld (_plugin_container_buffer + 1), hl

	ld hl, _ula_buffer
	ld de, _ula_header_string
	ld b, 4
	call _strncmp

	jr nz, _plugin_not_container

	push hl

_plugin_container_buffer:

	ld hl, 0
	ld (_ula_buffer_pointer), hl

	pop hl

	call _handle_container
	cp PLUGIN_ERROR
	ret z

_plugin_not_container:

	ld hl, (_plugin_file_stat + 7)	; put 16 bit file size into hl
	ld a, h
	or l
	cp ULA_PLUS_TAP_SIZE
	jr z, _plugin_ula_tap

	cp ULA_PLUS_PALETTE_SIZE
	jr z, _plugin_ula_raw

	ld bc, _err_unknown
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_ula_tap:

IFDEF _DEBUG
	ld a, 3
	out (254), a
ENDIF

	ld hl, (_ula_buffer_pointer)
	ld de, ULA_PLUS_TAP_PALETTE_OFFSET
	add hl, de
	jr _plugin_got_palette

_plugin_ula_raw:


IFDEF _DEBUG
	ld a, 4
	out (254), a
ENDIF

	ld hl, (_ula_buffer_pointer)

_plugin_got_palette:


	ld (_ula_buffer_pointer), hl

	ld a, (_plugin_nmi)
	and a
	call nz, _handle_nmi

	call _init_ula_plus

	ld a, (_ula_autostart)
	and a
	jr z, _plugin_no_autostart

	xor a				; 0 = tape
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_AUTOLOAD	; auto load the tap


_plugin_no_autostart:

	ld a, PLUGIN_OK|PLUGIN_STATUS_MESSAGE
	ld bc, _txt_palette_loaded

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


_handle_nmi:

IFDEF _DEBUG
	ld a, 4
	out (254), a
ENDIF

	rst ESXDOS_SYS_CALL		; get esxdos version
	defb ESXDOS_SYS_M_DOSVERSION
					; 0.87 returns hl: $0873
					; 0.88 returns hl: $0880
					; 0.89 returns hl: $0890

	or a
	ld b, h
	ld c, l
	ld hl, $0879			; version to check for > 0.87
	sbc hl, bc

	ret nc				; not > 0.87 so do nothing

IFDEF _DEBUG
	ld a, 4
	out (254), a
ENDIF

					; esxdos NMI code restores the prior ULAPlus
					; state which may have been OFF on exiting our
					; NMI.SYS, so set it ON.

					; esxdos 0.88 / 0.89
					;
					; 219f ld bc, $bf3b		; 48955
					; 2142 ld a, $40		; 64
					; 21a4 out (c), a
					; 21a6 ld b, $ff		; bc = $ff3b 65339
					; 21a8 in a,(c)
					; 21aa ld (220a), a
					;
					; ...
					;
					; 2209 ld a, 0

	ld a, 1
	ld ($220a), a

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


;_ula_plus_off:
;
;	ld hl, _ula_plus_palette_copy
;	call _apply_palette
;
;	ld bc, ULA_PLUS_REGISTER_PORT	; disable 64 colour ULA plus mode
;	ld a, 64
;	out (c), a
;
;	xor a
;	ld bc, ULA_PLUS_REGISTER_DATA
;	out (c), a
;	ret


_init_ula_plus:

	ld bc, ULA_PLUS_REGISTER_PORT
	ld a, ULA_PLUS_REGISTER_GROUP_MODE
	out (c), a

	ld a, 1
	ld bc, ULA_PLUS_REGISTER_DATA
	out (c), a			; enable 64 colour ULAPlus mode

;	xor a
;	ld hl, _ula_plus_palette_copy	; make a copy of the existing palette
;
;_init_ula_copy:
;
;	ld bc, ULA_PLUS_REGISTER_PORT
;	out (c), a
;
;	ld e, a				; save a in e
;
;	ld bc, ULA_PLUS_REGISTER_DATA	; select colour
;
;	nop
;
;	in a, (c)
;
;	ld (hl), a			; store colour value
;
;	ld a, e
;
;	inc a				; next colour
;	inc hl
;
;	cp ULA_PLUS_PALETTE_SIZE
;	jr nz, _init_ula_copy

	ld hl, (_ula_buffer_pointer)
	call _apply_palette

	ret


_read_file_to_buffer:

	xor a
	ld (_plugin_file_handle), a

					; filename in hl
					
	ld a, ESXDOS_CURRENT_DRIVE	; *
	ld b, ESXDOS_MODE_READ

	rst ESXDOS_SYS_CALL		; open file
	defb ESXDOS_SYS_F_OPEN

	jr nc, _read_file_to_buffer_stat

	ld bc, _err_file
	ld a, PLUGIN_ERROR
	ret

_read_file_to_buffer_stat:

	ld (_plugin_file_handle), a
	ld hl, _plugin_file_stat
	rst ESXDOS_SYS_CALL		; get file information
	defb ESXDOS_SYS_F_FSTAT

	jr nc, _read_file_to_buffer_read

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ld bc, _err_io
	ld a, PLUGIN_ERROR
	ret

_read_file_to_buffer_read:

	ld bc, (_plugin_file_stat + 7)	; put 16 bit file size into hl
	
	ld hl, (_ula_buffer_pointer)	; read the file in
	ld a, (_plugin_file_handle)

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _read_file_to_buffer_ok

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ld bc, _err_io
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	ret

_read_file_to_buffer_ok:

	push hl

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop hl

	xor a
	ret


_handle_container:

IFDEF _DEBUG
	ld a, 6
	out (254), a
ENDIF

	ld a, (hl)
	cp $d
	jr nz, _handle_container_skip_id_end

	inc hl

_handle_container_skip_id_end:

	inc hl				; hl should now be on the palette line

	ld de, _ula_palette_string
	ld b, 8
	call _strncmp

	jr z, _handle_container_skip_id_ok

	ld a, PLUGIN_ERROR
	ld bc, _err_container
	ret

					; hl should now be on the palette path

_handle_container_skip_id_ok:

	push hl

_handle_container_palette_loop:

	ld a, (hl)
	cp $d
	jr z, _handle_container_palette_end
	cp $a
	jr z, _handle_container_palette_end

	inc hl
	jr _handle_container_palette_loop

_handle_container_palette_end:

	xor a				; zero terminate palette path
	ld (hl), a
	ld (_handle_container_game + 1), hl
	pop hl

	call _read_file_to_buffer

_handle_container_game:

	ld hl, 0			; end of the palette line
	inc hl
	ld a, (hl)
	cp $a
	jr nz, _handle_container_game_skip_inc
	inc hl

_handle_container_game_skip_inc:

	ld de, _ula_game_string
	ld b, 5
	call _strncmp

	jr z, _handle_container_game_id_ok

	ld a, PLUGIN_ERROR
	ld bc, _err_container
	ret

_handle_container_game_id_ok:

	push hl

_handle_container_game_loop:

	ld a, (hl)
	cp $d
	jr z, _handle_container_game_end
	cp $a
	jr z, _handle_container_game_end

	inc hl
	jr _handle_container_game_loop

_handle_container_game_end:

	xor a				; zero terminate game path
	ld (hl), a

	ld b, ESXDOS_TAPEIN_CLOSE	; close any existing .tap file
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

	pop hl


	;jr c, _plugin_error

	ld a, ESXDOS_CURRENT_DRIVE
	ld b, ESXDOS_TAPEIN_OPEN

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

	;jr c, _plugin_error

	ld a, 1
	ld (_ula_autostart), a

	xor a

	ret


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


_plugin_nmi:

	defb 0

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

_err_container:

	defb "Error in container!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

_txt_palette_loaded:

	defb "Loaded ULAplus colour scheme.", $0

_ula_header_string:

	defb "ULA!"

_ula_game_string:

	defb "GAME="

_ula_palette_string:

	defb "PALETTE="

_ula_autostart:

	defb 0

_ula_buffer_pointer:

	defw _ula_buffer

_ula_buffer:
