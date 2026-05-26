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

DEFC SETTING_REALTIME_TAPE_LOADING=%00000001
DEFC SETTING_REALTIME_TAPE_PAUSES=%00000010

	org PLUGIN_ORG

	jr _plugin_start

_plugin_info:

	defb "BP"				; id
	defb 0					; spare
	defb 0					; spare
	defb PLUGIN_FLAGS1_COPY_SETTINGS	; flags
	defb 0					; flags2

	defb ".TAP file plugin - bob_fossil/mcleod_ideafix", $0

_plugin_start:

	ld a, d				; check for settings buffer
	or e
	jr z, _plugin_no_cfg

	ld (_plugin_cfg), a		; store we have a cfg file

	ld a, (de)
	ld (_plugin_cfg_flags), a

	and SETTING_REALTIME_TAPE_LOADING
	jr z, _plugin_no_cfg

IFNDEF _DEBUG
	call _plugin_uno_ok
	jr c, _plugin_not_uno
ENDIF

	call _realtime_tap_uno
	ret

_plugin_not_uno:

	ld bc, _err_uno
	jr _plugin_error

_plugin_no_cfg:

	; hl is the filename

	push hl

	ld b, ESXDOS_TAPEIN_CLOSE	; close any existing .tap file
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

	pop hl

	jr c, _plugin_error

	ld a, ESXDOS_CURRENT_DRIVE
	ld b, ESXDOS_TAPEIN_OPEN

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

	jr c, _plugin_error

	ld bc, $fefe
	in a, (c)
	and %00000001			; shift pressed?
	jr nz, _plugin_autostart	; no, so autostart it

					; tap is opened so we're done
	ld a, PLUGIN_OK|PLUGIN_STATUS_MESSAGE
	ld bc, _status_attached
	ret

_plugin_autostart:

	xor a				; 0 = tape
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_AUTOLOAD	; auto load the tap

_plugin_attach:

	; .tap file should auto load, otherwise, fall through to error

_plugin_error:

	ld a, PLUGIN_ERROR
	ret

include "tap_uno.asm"

_plugin_cfg:

	defb $0

_plugin_cfg_flags:

	defb $0

_status_attached:

	defb ".TAP file opened", $0

