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

DEFC MG4_SIZE=15616

	org PLUGIN_ORG

	jr _plugin_start

_plugin_info:

	defb "BP"			; id
	defb 0				; spare
	defb 0				; spare
					; flags
	defb PLUGIN_FLAGS1_MMC_ONLY
	defb 0				; flags2
	defb ".MG4 screen plugin - pulsar/bob_fossil", $0

_plugin_start:

	; hl is the filename
	; bc is the parameter block
	ld a, (bc)			; get current ram bank
	ld (_plugin_reloc_start + 6), a
	inc bc

	ld a, (bc)			; are we running from NMI?
	and a

	ld a, 2
	jr z, _plugin_not_nmi
	xor a

_plugin_not_nmi:

	ld (_plugin_esxdos_page_restore + 1), a
	ld (_plugin_reloc_start + 1), a

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
	ld bc, MG4_SIZE			; check if filesize HL == 13824
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

	ld hl, 49152			; real file to 49152 for the time being
	ld bc, MG4_SIZE

	ld a, (_plugin_file_handle)

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_init

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_init:

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

					; back up the memory we need to use
	ld a, MMC_MEMORY_PLUGIN_PAGE2 + 128
	out (MMC_MEMORY_PORT), a

	ld hl, 24576
	ld bc, DIV_MMC_BANK_SIZE
	ld de, 8192

	ldir

	ld a, MMC_MEMORY_PLUGIN_PAGE3 + 128
	out (MMC_MEMORY_PORT), a

	ld hl, 40960
	ld bc, DIV_MMC_BANK_SIZE
	ld de, 8192

	ldir

_plugin_esxdos_page_restore:

	ld a, 0
	add a, 128
	out (MMC_MEMORY_PORT), a

	ld hl, _plugin_reloc_start
	ld de, 24576
	ld bc, _plugin_reloc_end - _plugin_reloc_start
	ldir
	jp 24576

_plugin_reloc_start:

	; mg4_viewer.asm needs to be built at origin $6000
	; so we assemble it there and include it as a binary block
	BINARY "mg4_viewer.bin"

_plugin_reloc_end:

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

_plugin_param_bank:

	defb 0

_plugin_param_nmi:

	defb 0

_err_size:

	defb "Invalid filetype!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

_err_128:

	defb "This plugin requires 128k hardware!", $0
