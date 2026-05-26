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

DEFC SCL_ID_LEN=8
DEFC SCL_CAT_ENTRY_SIZE=14
DEFC TRD_CAT_ENTRY_SIZE=16
DEFC SECTOR_BYTES=256
DEFC BORDCR=23624

	org PLUGIN_ORG

	jr _plugin_start

_plugin_info:

	defb "BP"			; id
	defb 0				; spare
	defb 0				; spare
	defb 0				; flags
	defb 0				; flags2
	defb ".SCL file plugin - nihirash/bob_fossil", $0

_plugin_start:

	ld (_plugin_filename), hl

	ld bc, $fefe
	in a, (c)
	and %00000001			; shift pressed?
	jr nz, _plugin_no_shift		; no, so we want the .trd to autostart

	ld (_plugin_autostart), a

_plugin_no_shift:
					; filename in hl
	ex de, hl

	rst ESXDOS_SYS_CALL		; get esxdos version
	defb ESXDOS_SYS_M_DOSVERSION
					; 0.87 returns hl: $0873
					; 0.88 returns hl: $0880
					; 0.89 returns hl: $0890

	or a
	ld b, h
	ld c, l
	ld hl, $0889			; version to check for > 0.88
	sbc hl, bc

	ex de, hl

	jr nc, _plugin_esxdos_088

					; esxDOS 0.89+ lets us natively use SCL files
					; via vdisk

	xor a
					; hl - filename, a - unit

	push hl				; call to eject virtual disk trashes HL which
					; holds the filename.

	ld a, $60
	rst ESXDOS_SYS_CALL
	defb $85			; eject the current image (add a,l)

	pop hl				; restore filename

	ld a, $60			; unit
	ld b, 0
	ld c, ESXDOS_CURRENT_DRIVE	; *
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_DISK_STATUS	; mount the image (add a, b)
					; This overwrites the address pointed to by DE
					; with 'Virtual Disk', $0

	jr nc, _plugin_scl_mounted

	ld bc, _err_mount
	ld a, PLUGIN_ERROR
	ret

_plugin_scl_mounted:

	ld a, (_plugin_autostart)
	and a
	jr z, _plugin_scl_auto_tap

	call _plugin_autostart_first

					; if _plugin_autostart_first returns
					; we use normal autostart below

	cp PLUGIN_ERROR
	ret z

	ld a, $fd			; FD = TR-DOS
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_AUTOLOAD	; M_AUTOLOAD

	ld bc, _err_autostart
	ld a, PLUGIN_ERROR
	ret

_plugin_scl_auto_tap:

					; start .trd in TRDOS instead
	ld b, ESXDOS_TAPEIN_CLOSE	; close any existing .tap file
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

	ld a, ESXDOS_SYSTEM_DRIVE	; open TRD.TAP file
	ld b, ESXDOS_TAPEIN_OPEN
	ld hl, _plugin_scl_tap

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

	jr c, _plugin_scl_auto_tap_error

	xor a				; 0 = tape
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_AUTOLOAD	; auto load the tap

_plugin_scl_auto_tap_error:

	ld bc, _err_tap
	ld a, PLUGIN_ERROR
	ret


_plugin_esxdos_088:

	push hl

	ld de, _plugin_filename_copy
	call _strcpy			; take a copy of the filename
	pop hl

	xor a
	ld (_plugin_file_handle), a

	ld a, ESXDOS_CURRENT_DRIVE	; *
	ld b, ESXDOS_MODE_READ

	rst ESXDOS_SYS_CALL		; open file
	defb ESXDOS_SYS_F_OPEN

	jr nc, _plugin_header

	ld bc, _err_file
	ld a, PLUGIN_ERROR
	ret

_plugin_header:

	ld (_plugin_file_handle), a	; read to sector buffer
	ld hl, _plugin_sector_buffer
	ld bc, SCL_ID_LEN + 1		; get ID + count

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_check

	ld bc, _err_io
	jr _plugin_error

_plugin_check:

	ld hl, _plugin_sector_buffer
	ld de, _scl_id
	ld b, SCL_ID_LEN
	call _strncmp			; check buffer contains 'SINCLAIR'

	jr z, _plugin_check_ok

	ld bc, _err_invalid
	jr _plugin_error

_plugin_check_ok:

	ld hl, _plugin_filename_copy
	ld b, $2e			; .
	call _strchr

	ld a, h				; this shouldn't be NULL
	or l
	and a

	jr z, _plugin_error

					; hl is now at the . character
	ld d, h				; replace .scl with .trd
	ld e, l
	ld hl, _trd_extension
	call _strcpy

	call _convert			; a holds return code

	ld d, a
	and PLUGIN_ERROR
	jr nz, _plugin_error 

	ld a, (_plugin_autostart)
	and a
	jr z, _plugin_no_autostart

	call _autostart_trd

	ld d, a
	and PLUGIN_ERROR
	jr nz, _plugin_error 

_plugin_no_autostart:

	ld a, d
	ld (_plugin_ret_ok + 1), a

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

_plugin_ret_ok:

	ld a, 0
	ld bc, _status_done
	ret

_plugin_error:

	push bc

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop bc

	ld a, PLUGIN_ERROR
	ret


_plugin_autostart_first:

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

	ld bc, 9 + (128 * 14)		; 8 + 1 + (128 * 14) = 2048 bytes for catalogue
	ld hl, _plugin_scl_buff

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

	ld hl, _plugin_scl_buff
	ld de, _scl_id
	ld b, SCL_ID_LEN
	call _strncmp			; check buffer contains 'SINCLAIR'

	jr z, _plugin_autostart_valid

	ld bc, _err_invalid
	jr _plugin_error

_plugin_autostart_valid:

					; hl is now the SCL file count
	ld a, (hl)
	ld b, a				; not used at the moment
	inc hl
	push hl

	ld a, (_plugin_file_handle)	; $80a3
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop hl
	ld bc, 8

_plugin_autostart_find:

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
	cp 20				; remove padding spaces from filename
	jr z, _plugin_autostart_trim

	sbc hl, bc
	ld (_plugin_autostart_filename), hl

	ld c, 8				; skip filename chars
	add hl, bc

_plugin_autostart_find_next:

	add hl, bc			; move another 8 bytes to next entry

	dec hl				; scl data after filename is only 6 bytes
	dec hl

	jr _plugin_autostart_find

_plugin_autostart_done:
					; $80c6
	ld hl, (_plugin_autostart_filename)
	ld a, h
	or l

	ret z				; normal autostart if nothing found




_plugin_autostart_generate:

	;ld a, 2
	;out (254), a

	ld a, ESXDOS_SYSTEM_DRIVE	; $
	ld hl, _tmp_path
	ld b, ESXDOS_MODE_WRITE|ESXDOS_MODE_OPEN_CREATE

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_OPEN
	jr nc, _plugin_autostart_tmp_created

	ld a, PLUGIN_ERROR
	ld bc, _err_tap_create
	ret

_plugin_autostart_tmp_created:

	ld (_plugin_file_handle), a

	ld hl, _scl_header_start
	ld b, _scl_parity1 - _scl_header_start
	call _checksum
	ld (_scl_parity1), a

	; do filename replacement and padding here

	ld hl, (_plugin_autostart_filename)
	ld de, _scl_filename
	ld b, 8				; AAAAAAAA is 8 characters

_plugin_autostart_copy:

	ld a, (hl)
	and a
	jr z, _plugin_autostart_copy_zero
	ld (de), a
	inc hl
	inc de
	dec b
	jr _plugin_autostart_copy

_plugin_autostart_copy_zero:

	ld a, b				; do we need to pad the filename
	and a
	jr z, _plugin_autostart_copy_done

	ld a, 0x22			; add closing "
	ld (de), a
	inc de

	ld a, b				; get padding count
	ld a, 0x20			; ' '

_plugin_autostart_copy_pad:

	ld (de), a			; pad filename with spaces
	inc de
	djnz _plugin_autostart_copy_pad

_plugin_autostart_copy_done:

	ld hl, _scl_basic_start
	ld b, _scl_parity2 - _scl_basic_start
	call _checksum
	ld (_scl_parity2), a

	ld a, (_plugin_file_handle)
	ld hl, _scl_tap_data
	ld bc, _scl_tap_end - _scl_tap_data

	rst ESXDOS_SYS_CALL		; write tap to "/tmp/scl_auto.tap"
	defb ESXDOS_SYS_F_WRITE

	jr nc, _plugin_autostart_written

	ld bc, _err_io
	jr _plugin_autostart_error

_plugin_autostart_written:

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ld a, ESXDOS_SYSTEM_DRIVE	; open the .tap file we just created
	ld hl, _tmp_path
	ld b, ESXDOS_TAPEIN_OPEN

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

	jr nc, _plugin_autostart_tap

	ld bc, _err_tap_auto
	ld a, PLUGIN_ERROR
	ret

_plugin_autostart_tap:

	xor a				; 0 = tape
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_AUTOLOAD	; auto load the tap


	ld a, PLUGIN_ERROR
	ld bc, _err_tap_autostart
	ret

_plugin_autostart_error:

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


_convert:

	ld hl, _plugin_filename_copy
	ld a, ESXDOS_CURRENT_DRIVE	; *
	ld b, ESXDOS_MODE_WRITE|ESXDOS_MODE_OPEN_CREATE

	rst ESXDOS_SYS_CALL		; open .trd for writing
	defb ESXDOS_SYS_F_OPEN

	jr nc, _convert_start

	ld bc, _err_output
	jp _convert_error

_convert_start:

	ld (_plugin_file_output_handle), a

					; get number of files in the .SCL file
	ld a, (_plugin_sector_buffer + SCL_ID_LEN)
	ld (_convert_empty_count + 1), a
	ld b, a

_convert_cat:

	push bc

	ld a, (_plugin_file_handle)	; ESXDOS_fread(&buff, 14, iStream);
	ld hl, _plugin_sector_buffer
	ld bc, SCL_CAT_ENTRY_SIZE	; SCL cat entry

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	ld a, (_plugin_free_tracks)	;        buff[15] = freeTrack;
	ld c, a				; store plugin_free_tracks in c
	ld (_plugin_sector_buffer + SCL_CAT_ENTRY_SIZE + 1), a

	ld a, (_plugin_free_sectors)	;        buff[14] = freeSec;
	ld (_plugin_sector_buffer + SCL_CAT_ENTRY_SIZE), a

	ld b, a				;        freeSec += buff[0xd];
	ld a, (_plugin_sector_buffer + SCL_CAT_ENTRY_SIZE - 1)
	ld e, a				; store buff[0xd] in e

	add b
	ld (_plugin_free_sectors), a

					;        freeTrack += freeSec / 16;

	srl a				; divide _plugin_free_sectors by 16
	srl a
	srl a
	srl a

	add c
	ld (_plugin_free_tracks), a

					;        totalFreeSect -= (int) buff[0xd];
	ld hl, (_plugin_total_free_sectors)
	ld d, 0				; e contains buffer[13]
	sbc hl, de
	ld (_plugin_total_free_sectors), hl

	ld a, (_plugin_free_sectors)	;        freeSec = freeSec % 16;
	ld c, a
	ld d, 16

					; http://z80-heaven.wikidot.com/math C_Div_D
					;
					; Inputs:
					;      C is the numerator
					;      D is the denominator
					; Outputs:
					;      A is the remainder
					;      B is 0
					;      C is the result of C/D
					;      D,E,H,L are not changed
					;
	ld b, 8
	xor a

_convert_div_1:

	sla c
	rla
	cp d
	jr c, _convert_div_2
	inc c
	sub d

_convert_div_2:

	djnz _convert_div_1

	ld (_plugin_free_sectors), a

					;        ESXDOS_fwrite(&buff, 16, oStream);
	ld a, (_plugin_file_output_handle)
	ld hl, _plugin_sector_buffer
	ld bc, TRD_CAT_ENTRY_SIZE

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_WRITE

	pop bc

	djnz _convert_cat

	call _clear_sector_buffer

_convert_empty_count:

	ld a, 0				; write remaining empty entries

_convert_empty:

	cp 128
	jr z, _convert_empty_done

	ccf				; clear carry from cp
	push af

	ld a, (_plugin_file_output_handle)
	ld hl, _plugin_sector_buffer
	ld bc, TRD_CAT_ENTRY_SIZE

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_WRITE

	pop af

	jr nc, _convert_empty_ok

	ld bc, _err_cat
	jp _convert_error

_convert_empty_ok:

	inc a
	jr _convert_empty

					;    buff[0xe3] = 0x16; // IMPORTANT! 80 track double sided
					;    buff[0xe4] = count;
					;    buff[0xe1] = freeSec;
					;    buff[0xe2] = freeTrack;

_convert_empty_done:

	ld a, (_plugin_free_sectors)
	ld (_plugin_sector_buffer + $e1), a
	ld a, (_plugin_free_tracks)
	ld (_plugin_sector_buffer + $e2), a
	ld a, $16
	ld (_plugin_sector_buffer + $e3), a
	ld a, (_convert_empty_count + 1)
	ld (_plugin_sector_buffer + $e4), a

					;    if (isFull) {
					;        buff[0xe6] = totalFreeSect / 256;
					;        buff[0xe5] = totalFreeSect & 255;
					;    }

					;    buff[0xe7] = 0x10;
					;    buff[0xf5] = 's';
					;    buff[0xf6] = 'c';
					;    buff[0xf7] = 'l';
					;    buff[0xf8] = '2';
					;    buff[0xf9] = 't';
					;    buff[0xfa] = 'r';
					;    buff[0xfb] = 'd';
	ld a, $10
	ld (_plugin_sector_buffer + $e7), a
	ld hl, _trd_name
	ld de, _plugin_sector_buffer + $f5
	call _strcpy

					;    esx_f_write(oStream, &buff, 256);
					;    esx_f_write(oStream, 0, 1792);

	ld a, (_plugin_file_output_handle)
	ld hl, _plugin_sector_buffer
	ld bc, SECTOR_BYTES

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_WRITE

	jr nc, _convert_clear

	ld bc, _err_info
	jr _convert_error

_convert_clear:

	call _clear_sector_buffer

	ld b, 7				; 7 * 256 = 1792

_convert_empty2:

	push bc

	ld a, (_plugin_file_output_handle)
	ld hl, _plugin_sector_buffer
	ld bc, SECTOR_BYTES

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_WRITE

	pop bc
	djnz _convert_empty2


;    i = esx_f_read(iStream, &buff, 256);
;    while (i == 256) // Only sectors info 
;    {
;        esx_f_write(oStream, &buff, i);
;        i = esx_f_read(iStream, &buff, 256);
;    }

					; flash border while converting so
					; get the current border colour
	ld a, (BORDCR)
	srl a				; divide BORDCR by 8
	srl a
	srl a

	ld (_convert_end + 1), a
	ld (_convert_progress + 1), a

	xor $7				; create inverse
	ld (_convert_data + 1), a

_convert_data:

	ld a, 0
	out (254), a

	ld a, (_plugin_file_handle)
	ld hl, _plugin_sector_buffer
	ld bc, SECTOR_BYTES

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	ld hl, SECTOR_BYTES
	or a
	sbc hl, bc
	jr c, _convert_end		; c cleared if hl >= bc

	ld a, h				; hl should be 0 if bc is 256
	or l
	jr nz, _convert_end

	ld a, (_plugin_file_output_handle)
	ld hl, _plugin_sector_buffer
	ld bc, SECTOR_BYTES

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_WRITE

	jr nc, _convert_progress

	ld bc, _err_data
	jr _convert_error

_convert_progress:

	ld a, 0
	out (254), a

	jr _convert_data

_convert_end:

	ld a, 0
	out (254), a

	; multiply border by 8 and store in BORDCR system variable
	; otherwise subsequent calls to BEEPER zaps the border colour.
	rlca
	rlca
	rlca
	ld (BORDCR), a

	ld a, (_plugin_file_output_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ld a, PLUGIN_OK|PLUGIN_STATUS_MESSAGE|PLUGIN_RESTORE_BUFFERS|PLUGIN_RESTORE_SCREEN

	ret

_convert_error:

	push bc

	ld a, (_plugin_file_output_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop bc

	ld a, PLUGIN_ERROR

	ret

_autostart_trd:

	ld a, $60
	rst ESXDOS_SYS_CALL
	defb $85			; eject the current image (add a,l)

	ld hl, _plugin_filename_copy

	ld a, $60		; unit
	ld b, 0
	ld c, ESXDOS_CURRENT_DRIVE	; *
	rst ESXDOS_SYS_CALL
	defb $80		; mount the image (add a, b)
				; This overwrites the address pointed to by DE
				; with 'Virtual Disk',

	jr c, _autostart_trd_error

	ld a, $fd		; FD = TR-DOS
	rst ESXDOS_SYS_CALL
	defb $90		; M_AUTOLOAD

_autostart_trd_error:

	ld bc, _err_autostart
	ld a, PLUGIN_ERROR

	ret


_clear_sector_buffer:

	xor a
	ld hl, _plugin_sector_buffer
	ld (hl), a
	ld de, _plugin_sector_buffer + 1
	ld bc, SECTOR_BYTES - 1
	ldir

	ret

;void writeCatalog()
;{
;    uint8_t i;
;    totalFreeSect = 2544;
;    freeTrack = 1;
;    freeSec = 0;
;    count = 0;
;
;    oStream = ESXDOS_fopen(filePath, ESXDOS_FILEMODE_WRITE_CREATE, drive);
;    iferror {
;        showMessage("Can't open output file");
;        return ;
;    }
;
;    ESXDOS_fread(&count, 1, iStream);
;    for (i=0;i<count; i++) {
;        ESXDOS_fread(&buff, 14, iStream);
;        buff[14] = freeSec;
;        buff[15] = freeTrack;
;        freeSec += buff[0xd];
;        freeTrack += freeSec / 16;
;        totalFreeSect -= (int) buff[0xd];
;        freeSec = freeSec % 16;
;        ESXDOS_fwrite(&buff, 16, oStream);
;    }
;    cleanBuffer();
;
;    for (i = count;i<128;i++) ESXDOS_fwrite(&buff, 16, oStream);
;    iferror {
;        showMessage("Issue with writing catalog to TRD-file");
;        return;
;    }
;    textUtils_println(" * Disk catalog written");
;    writeDiskInfo();
;}


	; function to find a character in a zero terminated string
	;
	; b character to find
	; hl source string
	; 
	; return hl pointer to character or NULL

_strchr:
	ld a, (hl)
	
	and a
	jr nz, _strchr_cmp
	
	ld hl, 0
	ret

_strchr_cmp:

	cp b
	ret z

	inc hl
	jr _strchr

	; function to do a basic zero terminated string copy
	;
	; hl source string
	; de dest string
_strcpy:
	ld a, (hl)
	ld (de), a
	and a
	ret z
	
	inc hl
	inc de
	jr _strcpy

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

;

_scl_id:

	defb "SINCLAIR", 0

_trd_extension:

	defb ".TRD", $0
	
_trd_name:

	defb "BRWSTRD", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

_err_output:

	defb "Couldn't create output file!", $0

_err_cat:

	defb "Error writing catalogue!", $0

_err_info:

	defb "Error writing info!", $0

_err_data:

	defb "Error writing data!", $0

_err_invalid:

	defb "Not a valid .SCL file!", $0

_status_done:

	defb "SCL converted to TRD", $0

_plugin_scl_tap:

	defb "/BIN/BPLUGINS/SCL.TAP", $0

_err_mount:

	defb "Failed to mount.SCL file!", $0

_err_autostart:

	defb "Failed to start .SCL file!", $0

_err_tap:

	defb "Failed to open SCL.TAP!", $0

_err_file_read:

	defb "Failed to read from .SCL!", $0

_err_tap_auto:

	defb "Failed to open SCL_AUTO.TAP!", $0

_err_tap_autostart:

	defb "Failed to autostart SCL_AUTO.TAP!", $0

_err_tap_create:

	defb "Couldn't write /TMP/SCL_AUTO.TAP!", $0

_tmp_path:

	defb "/tmp/scl_auto.tap", $0

_trd_boot_bas:

	defb "boot    B", $0

_plugin_free_sectors:

	defb 0

_plugin_free_tracks:

	defb 1

_plugin_total_free_sectors:

	defw 2544

_plugin_file_handle:

	defb 0

_plugin_file_output_handle:

	defb 0
	
_plugin_autostart:

	defb 1

_plugin_filename_copy:

	defs(13)

_plugin_sector_buffer:

	defs(SECTOR_BYTES)

_plugin_filename:

	defw 0

_plugin_autostart_filename:

	defw 0

; /TMP/SCL_AUTO.TAP

_scl_tap_data:

	defw $0013			; header length 17 bytes + flag + checksum
	defb $0				; flag byte (0 for headers, ff for data blocks)

_scl_header_start:

	defb $0				; filetype (Basic) 0
	defb "SCL AUTO  "		; 'Program: '
	defw $001d			; length
	defw $000a			; autostart line
	defw $001d			; variable area

_scl_parity1:

	defb $67			; parity *

	defw $001f			; block_length

_scl_basic_start:

	defb $ff			; Data...
	defw $0a00			; BASIC line number
	defw $0019			; BASIC line length

	defb $f9, $c0, $b0, $22		; RANDOMIZE USR VAL "
					; 15619": REM : RUN "
	defb "15619", $22, $3a, $ea, $3a, $f7, $22

					; Use RUN as LOAD doesn't autostart BASIC

_scl_filename:

	defb "AAAAAAAA", $22, $0d	; AAAAAAAA"

_scl_parity2:

	defb $0				; parity *

_scl_tap_end:


_plugin_scl_buff:
					; this is where the SCL catalogue gets loaded to

