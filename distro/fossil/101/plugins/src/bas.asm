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

	org PLUGIN_ORG

	jr _plugin_start

_plugin_info:

	defb "BP"			; id
	defb 0				; spare
	defb 0				; spare
	defb 0				; flags
	defb 0				; flags2
	defb ".BAS file plugin - bob_fossil", $0

_plugin_start:

	xor a				; page esxdos back in - which will kick out
	out (MMC_MEMORY_PORT), a	; our .dot command, which is why we're running
					; in the screen memory

	ld de, _plugin_filename

_plugin_bas_copy:

	ld a, (hl)			; append filename
	ld (de), a
	inc hl
	inc de
	and a
	jr nz, _plugin_bas_copy

					; NMI.SYS bas code is at ~ $33d8
	ld a, ESXDOS_CURRENT_DRIVE	; * - select current drive
	ld hl, _plugin_filename		; put filename into hl

	rst ESXDOS_SYS_CALL
	defb $90			; call AUTOLOAD

_plugin_error:

	ld a, PLUGIN_ERROR
	ret


_plugin_filename:

	defs(14)
