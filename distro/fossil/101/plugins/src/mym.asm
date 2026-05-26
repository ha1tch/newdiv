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
include "mym_player_inc.asm"


	org PLUGIN_ORG

	jr _plugin_start

_plugin_info:

	defb "BP"				; id
	defb 0					; spare
	defb 0					; spare
						; flags
	defb PLUGIN_FLAGS1_COPY_SETTINGS|PLUGIN_FLAGS1_MMC_ONLY
	defb 0					; flags2

_plugin_user_data:

	defs(PLUGIN_SETTING_MAX)		; reserve space for settings copy

_plugin_id_string:

	defb ".MYM file plugin - Lieves!Tuore/Zack/bob_fossil", $0

_plugin_start:

	; filename in hl
	; bc is the parameter block

	push bc
	push hl

	ld de, MYM_PLAYER_ORG		; copy 'mym_player.bin' player to higher memory
	ld hl, _bin_start
	ld bc, _bin_end - _bin_start
	ldir

	ld hl, _plugin_user_data	; copy settings into 'mym_player_bin'.
	ld de, MYM_PLAYER_ORG
	ld bc, PLUGIN_SETTING_MAX
	ldir

	pop hl				; restore filename and param block
	pop bc

					; jump to start of relocated player
	jp MYM_PLAYER_ORG + PLUGIN_SETTING_MAX

_bin_start:

	; mym_player.asm assembled to MYM_PLAYER_ORG
	BINARY "mym_player.bin"

_bin_end:
