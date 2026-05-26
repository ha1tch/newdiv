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

DEFC SNAPLOAD_DEST = 23512		; address used by NMI.SYS

	org PLUGIN_ORG

	jr _plugin_start

_plugin_info:

	defb "BP"			; id
	defb 0				; spare
	defb 0				; spare
	defb 0				; flags
	defb 0				; flags2
	defb ".Z80 file plugin - bob_fossil", $0

_plugin_start:

					; filename in hl
	push hl

	ld hl, _snapload_command 	; append 'snapload '
	ld de, SNAPLOAD_DEST
	ld bc, _snapload_command_end - _snapload_command
	ldir

	pop hl

_plugin_snapshot_copy:

	ld a, (hl)			; append filename
	ld (de), a
	inc hl
	inc de
	and a
	jr nz, _plugin_snapshot_copy

	ld hl, SNAPLOAD_DEST		; hl points to command string
	ei
	rst ESXDOS_SYS_CALL		; undocumented hook code to execute a command?
	defb $8f			; adc a, a

_plugin_error:

	ld a, PLUGIN_ERROR
	ret


_snapload_command:
	defb "snapload "

_snapload_command_end:
