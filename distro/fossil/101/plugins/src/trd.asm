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

	org PLUGIN_ORG

	jr _plugin_start

_plugin_info:

	defb "BP"			; id
	defb 0				; spare
	defb 0				; spare
	defb 0				; flags
	defb 0				; flags2
	defb ".TRD file plugin - bob_fossil", $0

_plugin_start:

					; hl - filename, a - unit

	ld (_plugin_filename), hl

	ld a, $60
	rst ESXDOS_SYS_CALL
	defb $85			; eject the current image (add a,l)

	ld hl, (_plugin_filename)	; restore filename

	ld a, $60			; unit
	ld b, 0
	ld c, ESXDOS_CURRENT_DRIVE	; *
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_DISK_STATUS	; mount the image (add a, b)
					; This overwrites the address pointed to by DE
					; with 'Virtual Disk', $0

	jr nc, _plugin_trd_mounted

	ld bc, _err_mount
	ld a, PLUGIN_ERROR
	ret

_plugin_trd_mounted:

	ld bc, $fefe
	in a, (c)
	and %00000001			; shift pressed?
	jr nz, _plugin_autostart	; no, so just autostart the .trd
					; start .trd in TRDOS instead

	ld b, ESXDOS_TAPEIN_CLOSE	; close any existing .tap file
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

	ld a, ESXDOS_SYSTEM_DRIVE	; open TRD.TAP file
	ld b, ESXDOS_TAPEIN_OPEN
	ld hl, _plugin_trd_tap

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

	jr c, _plugin_tap_error

	xor a				; 0 = tape
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_AUTOLOAD	; auto load the tap

_plugin_tap_error:

	ld bc, _err_tap
	ld a, PLUGIN_ERROR
	ret

_plugin_autostart:

	call _plugin_autostart_first

					; if _plugin_autostart_first returns
					; we use normal autostart below

_plugin_autostart_sys:

	cp PLUGIN_ERROR
	ret z

	ld a, $fd			; FD = TR-DOS
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_AUTOLOAD	; M_AUTOLOAD

_plugin_error:

	ld bc, _err_autostart
	ld a, PLUGIN_ERROR
	ret


_plugin_autostart_first:

					; $ 8071
	ld hl, (_plugin_filename)

	xor a
	ld (_plugin_file_handle), a

	ld a, ESXDOS_CURRENT_DRIVE	; *
	ld b, ESXDOS_MODE_READ

	rst ESXDOS_SYS_CALL		; open file for reading
	defb ESXDOS_SYS_F_OPEN

	jr nc, _plugin_autostart_opened

	ld bc, _err_file
	ld a, PLUGIN_ERROR
	ret

_plugin_autostart_opened:

	ld (_plugin_file_handle), a

	ld bc, 128 * 16			; 2048 bytes for catalogue
	ld hl, _plugin_trd_buff

	rst ESXDOS_SYS_CALL		; read catalogue into buffer
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_autostart_read

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ld bc, _err_file_read
	ld a, PLUGIN_ERROR
	ret

_plugin_autostart_read:

	xor a				; 0 terminate buffer
	ld (hl), a

	ld a, (_plugin_file_handle)	; $80a3
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ld hl, _plugin_trd_buff
	ld bc, 8

_plugin_autostart_find:
					; $80ab
	ld a, (hl)
	and a
	jr z, _plugin_autostart_done	; if 0 we're done

	add hl, bc			; move 8 bytes to get to the extension

	cp 1				; is file deleted?
	jr z, _plugin_autostart_find_next

	ld a, (hl)
	cp $42				; is extension B?

	jr nz, _plugin_autostart_find_next


					; is file 'boot    B'?
	push hl
	sbc hl, bc			; go to start of filename

	ld b, 9				; compare 9 characters
	ld de, _trd_boot_bas

_plugin_autostart_boot_check:

	ld a, (de)
	cp (hl)
	jr nz, _plugin_autostart_boot_end

	inc de				; characters match so move on
	inc hl

	djnz _plugin_autostart_boot_check

_plugin_autostart_boot_end:

	pop hl
	ld a, b
	and a				; if b is 0, just return an autostart as
					; the disk has a 'boot.B' file
	ret z

	ld b, 0				; restore bc

					; skip if we've already got a B file
	push hl

	ld hl, (_plugin_autostart_filename)
	ld a, h
	or l

	pop hl

	jr nz, _plugin_autostart_find_next

_plugin_autostart_trim:

	xor a				; $80bc
	ld (hl), a			; overwrite with 0
	dec hl
	dec bc
	ld a, (hl)
	cp $20				; remove padding spaces from filename
	jr z, _plugin_autostart_trim

	sbc hl, bc			; 80d8
	ld (_plugin_autostart_filename), hl

	ld c, 8
	add hl, bc

_plugin_autostart_find_next:

	add hl, bc			; move another 8 bytes to next entry

	jr _plugin_autostart_find

_plugin_autostart_done:
					; $80c6
	ld hl, (_plugin_autostart_filename)
	ld a, h
	or l

	ret z				; normal autostart if nothing found

_plugin_generate:

	;ld a, 2
	;out (254), a

	ld a, ESXDOS_SYSTEM_DRIVE	; $
	ld hl, _tmp_path
	ld b, ESXDOS_MODE_WRITE|ESXDOS_MODE_OPEN_CREATE

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_OPEN
	jr nc, _plugin_tmp_created

	ld a, PLUGIN_ERROR
	ld bc, _err_tap_create
	ret

_plugin_tmp_created:

	ld (_plugin_file_handle), a

	ld hl, _trd_header_start
	ld b, _trd_parity1 - _trd_header_start
	call _checksum
	ld (_trd_parity1), a

	; do filename replacement and padding here

	ld hl, (_plugin_autostart_filename)
	ld de, _trd_filename
	ld b, 8				; AAAAAAAA is 8 characters

_plugin_copy:

	ld a, (hl)
	and a
	jr z, _plugin_copy_zero
	ld (de), a
	inc hl
	inc de
	dec b
	jr _plugin_copy

_plugin_copy_zero:

	ld a, b				; do we need to pad the filename
	and a
	jr z, _plugin_copy_done

	ld a, 0x22			; add closing "
	ld (de), a
	inc de

	ld a, b				; get padding count
	ld a, 0x20			; ' '

_plugin_copy_pad:

	ld (de), a			; pad filename with spaces
	inc de
	djnz _plugin_copy_pad

_plugin_copy_done:

	ld hl, _trd_basic_start
	ld b, _trd_parity2 - _trd_basic_start
	call _checksum
	ld (_trd_parity2), a

	ld a, (_plugin_file_handle)
	ld hl, _trd_tap_data
	ld bc, _trd_tap_end - _trd_tap_data

	rst ESXDOS_SYS_CALL		; write tap to "/tmp/trd_auto.tap"
	defb ESXDOS_SYS_F_WRITE

	jr nc, _plugin_ok

	ld bc, _err_io
	jr _plugin_auto_error

_plugin_ok:

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ld a, ESXDOS_SYSTEM_DRIVE	; open the .tap file we just created
	ld hl, _tmp_path
	ld b, ESXDOS_TAPEIN_OPEN

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

	jr nc, _plugin_auto_tap

	ld bc, _err_tap_auto
	ld a, PLUGIN_ERROR
	ret

_plugin_auto_tap:

	xor a				; 0 = tape
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_AUTOLOAD	; auto load the tap


	ld a, PLUGIN_ERROR
	ld bc, _err_tap_autostart
	ret

_plugin_auto_error:

	push bc

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop bc

	ld a, PLUGIN_ERROR
	ret

	; hl is start address
	; b is length
	; returns parity byte in a

_checksum:

	xor a

_checksum_loop:

	ld c, (hl)
	xor c
	inc hl
	djnz _checksum_loop

	ret


_plugin_filename:

	defw 0

_plugin_autostart_filename:

	defw 0

_plugin_file_handle:

	defb 0

; /TMP/TRD_AUTO.TAP

_trd_tap_data:

	defw $0013			; header length 17 bytes + flag + checksum
	defb $0				; flag byte (0 for headers, ff for data blocks)

_trd_header_start:

	defb $0				; filetype (Basic) 0
	defb "TRD AUTO  "		; 'Program: '
	defw $001d			; length
	defw $000a			; autostart line
	defw $001d			; variable area

_trd_parity1:

	defb $67			; parity *

	defw $001f			; block_length

_trd_basic_start:

	defb $ff			; Data...
	defw $0a00			; BASIC line number
	defw $0019			; BASIC line length

	defb $f9, $c0, $b0, $22		; RANDOMIZE USR VAL "
					; 15619": REM : RUN "
	defb "15619", $22, $3a, $ea, $3a, $f7, $22

					; Use RUN as LOAD doesn't autostart BASIC

_trd_filename:

	defb "AAAAAAAA", $22, $0d	; AAAAAAAA"

_trd_parity2:

	defb $0				; parity *

_trd_tap_end:


; 00000000: 1300 0000 5452 4420 4155 544f 2020 1d00  ....TRD AUTO  ..
; 00000010: 0a00 1d00 671f 00ff 000a 1900 f9c0 b022  ....g.........."
; 00000020: 3135 3631 3922 3aea 3aef 2241 4141 4141  15619":.:."AAAAA
; 00000030: 4141 4122 0d57                           AAA".W


_tmp_dir:

	defb "/tmp", $0

_tmp_path:

	defb "/tmp/trd_auto.tap", $0

_plugin_trd_tap:

	defb "/BIN/BPLUGINS/TRD.TAP", $0

_trd_boot_bas:

	defb "boot    B", $0

_err_mount:

	defb "Failed to mount .TRD file!", $0

_err_autostart:

	defb "Failed to start .TRD file!", $0

_err_tap:

	defb "Failed to open TRD.TAP!", $0

_err_tap_auto:

	defb "Failed to open TRD_AUTO.TAP!", $0

_err_tap_autostart:

	defb "Failed to autostart TRD_AUTO.TAP!", $0

_err_tap_create:

	defb "Couldn't write /TMP/TRD_AUTO.TAP!", $0

_err_file:

	defb "Failed to open TRD!", $0

_err_file_read:

	defb "Failed to read from .TRD!", $0

_err_io:

	defb "IO error!", $0

_plugin_trd_buff:
					; this is where the TRD catalogue gets loaded to

