
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

DEFC ZXUNOADDR=$fc
DEFC ZXUNODATA=$fd
DEFC ZXIBASEPORT=$3b
DEFC DMACTRL=$a0
DEFC DMASRC=$a1
DEFC DMADST=$a2
DEFC DMAPRE=$a3
DEFC DMALEN=$a4
DEFC DMAPROB=$a5
DEFC DMASTAT=$a6

DEFC SPECDRUM=$ffdf
DEFC LBUFFER=2048
DEFC PREESCALER=223			; la cuenta va de 0 a 223, es decir, 224 ciclos
DEFC WAV_HEADER_SIZE=44

DEFC ZX_UNO_OUT_PORT=64571
DEFC ZX_UNO_IN_PORT=64827
DEFC COREID_REGISTER=$ff

DEFC BORDCR=23624

DEFC SCR_COPY=40960

DEFC SETTING_DISPLAY_WAVEFORM=%00000001

;ZXUNOADDR*256+ZXIBASEPORT	64512 + 0x3b = 64571

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

	defb ".WAV plugin - mcleod_ideafix/bob_fossil", $0

_plugin_start:

	; hl is the filename
	; de is the address of the settings buffer or 0

	inc bc
	ld a, (bc)			; are we running from NMI?
	and a

	ld a, 2

	jr z, _plugin_not_nmi
	xor a

_plugin_not_nmi:

	ld (_plugin_esxdos_page_restore + 1), a
	ld (_plugin_esxdos_page_restore2 + 1), a


	ld a, d				; check for settings buffer
	or e
	jr z, _plugin_no_cfg

	ld (_plugin_cfg), a		; store we have a cfg file

	ld a, (de)
	ld (_plugin_cfg_flags), a

_plugin_no_cfg:

	ld a, (_plugin_cfg_flags)
	and SETTING_DISPLAY_WAVEFORM
	jr nz, _plugin_check

					; disable waveform display
	ld a, $c9			;
	ld (PlotWave), a		; disable PlotWave functionality

_plugin_check:

	xor a
	ld (_plugin_file_handle), a

IFNDEF _DEBUG
	call _zx_uno_test
	jr nc, _plugin_uno_ok

	ld bc, _err_uno
	jr _plugin_error
ENDIF

_plugin_uno_ok:

	ld a, ESXDOS_CURRENT_DRIVE	; *

	ld b, ESXDOS_MODE_READ

	rst ESXDOS_SYS_CALL		; open file for reading
	defb ESXDOS_SYS_F_OPEN

	jr nc, _plugin_file_opened

	ld bc, _err_file
	jr _plugin_error

_plugin_file_opened:

	ld (_plugin_file_handle), a

	ld l, ESXDOS_SEEK_SET
	ld bc, 0
	ld de, WAV_HEADER_SIZE		; skip 44 bytes from start (WAV header)

	rst ESXDOS_SYS_CALL		; seek to start
	defb ESXDOS_SYS_F_SEEK

	jr nc, _plugin_header_seek

	ld bc, _err_io
	jr _plugin_error

_plugin_header_seek:

	call _play

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

IFDEF _DEBUG
					; restore border colour
	ld a, (_plugin_user_data + PLUGIN_SETTING_OFFSET_BORDER)
	out (254), a

	; multiply border by 8 and store in BORDCR system variable
	; otherwise subsequent calls to BEEPER zaps the border colour.
	rlca
	rlca
	rlca
	ld (BORDCR), a
ENDIF

_plugin_ok_nav:

	ld bc, 00000

_plugin_ok_ret:

	ld a, 0

	ret

_plugin_error:

	push bc

	ld a, (_plugin_file_handle)
	and a
	jr z, _plugin_error_skip

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

_plugin_error_skip:

	pop bc

	ld a, PLUGIN_ERROR
	ret

_play:



	ld hl, _plugin_status_playing
	call _set_status_icon

	ld a, (_plugin_cfg_flags)
	and SETTING_DISPLAY_WAVEFORM
	jr z, _play_skip_copy

					; want to use 40960 as screen backup
	ld a, MMC_MEMORY_PLUGIN_PAGE2 + 128
	out (MMC_MEMORY_PORT), a

	ld hl, SCR_COPY			; backup existing memory at 40960
	ld de, 8192
	ld bc, DIV_MMC_BANK_SIZE
	ldir

	ld hl, 16384			; copy screen to buffer
	ld de, SCR_COPY
	ld bc, 6144
	ldir

_plugin_esxdos_page_restore:

	ld a, 0
	add a, 128
	out (MMC_MEMORY_PORT), a

_play_skip_copy:

	di

	ld hl, _wav_buffer		; begin of circular play buffer
	ld bc, ZXUNOADDR*256+ZXIBASEPORT
	ld a, DMASRC
	out (c), a
	inc b
	out (c), l
	out (c), h
	dec b

	ld a, DMADST
	out (c), a
	inc b
	ld hl, SPECDRUM
	out (c), l
	out (c), h
	dec b

	ld a, DMAPRE
	out (c), a
	inc b
	ld hl, PREESCALER
	out (c), l
	out (c), h
	dec b

	ld a, DMALEN
	out (c),a
	inc b
	ld hl, LBUFFER
	out (c), l
	out (c), h
	dec b

	ld a, DMAPROB
	out (c), a
	inc b
	ld hl, _wav_buffer
	out (c), l
	out (c), h
	dec b

	ld a, DMACTRL
	out (c), a
	inc b
					; mem to I/O, redisparable, timed, se comprueba direccion fuente
	ld a, %00000111
	out (c), a
	dec b

IFDEF _DEBUG
	ld a, 7
	out (254), a
ENDIF

	call _plugin_wait_for_no_keys

_play_loop:

;	ld bc, $7ffe			; SPACE halfrow
;	in a, (c)
;	and 1
;	jp z, _play_exit


	call _plugin_in_inkey		; get scancode into l

					; check key up
	ld de, _plugin_user_data + PLUGIN_SETTING_OFFSET_KEY_UP
	ld a, (de)
	cp l
	jr nz, _plugin_key_down

	ld a, PLUGIN_OK|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_FIRST
	ld hl, _plugin_status_seek_previous
	jp _play_exit

_plugin_key_down:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_left

	ld a, PLUGIN_OK|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_LAST
	ld hl, _plugin_status_seek_next
	jp _play_exit

_plugin_key_left:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_right

	ld a, PLUGIN_OK|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_PREVIOUS
	ld hl, _plugin_status_seek_previous
	jp _play_exit

_plugin_key_right:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_break

	ld a, PLUGIN_OK|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_NEXT
	ld hl, _plugin_status_seek_next
	jp _play_exit

_plugin_key_break:

	ld a, $20			; Space
	cp l
	jr nz, _play_ok

	call _plugin_shift_pressed
	ld a, l
	and SHIFT_CAPS			; shift + space, so return

	jr z, _play_ok

	call _plugin_wait_for_no_keys
	ld a, PLUGIN_OK
	ld hl, 0
	jr _play_exit

_play_ok:

	ld bc, ZXUNOADDR * 256 + ZXIBASEPORT
	ld a, DMASTAT
	out (c), a
	inc b

StillInSecondHalf:

	in a,(c)
	bit 7, a
	jr z, StillInSecondHalf

	dec b
	ld a, DMAPROB
	out (c), a
	inc b
	ld hl, _wav_buffer + LBUFFER / 2
	out (c), l
	out (c), h
	dec b
	ld a, DMASTAT
	out (c), a
	inc b
	in a,(c)

					;fill second half of buffer with audio data
	ld hl, _wav_buffer + LBUFFER / 2
	ld bc, LBUFFER/2
	ld a, (_plugin_file_handle)

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jp c, _play_exit		;si error, fin de lectura
	ld a, b
	or c
	jp z, _play_exit		;si no hay más que leer, fin de lectura

	ld hl, _wav_buffer + LBUFFER/2
	call PlotWave

	ld bc, ZXUNOADDR*256+ZXIBASEPORT
	ld a, DMASTAT
	out (c), a
	inc b

StillInFirstHalf:

	in a,(c)
	bit 7, a
	jr z, StillInFirstHalf

	dec b
	ld a, DMAPROB
	out (c), a
	inc b
	ld hl, _wav_buffer
	out (c), l
	out (c), h
	dec b
	ld a,DMASTAT
	out (c),a
	inc b
	in a,(c)

					;fill first half of buffer with audio data
	ld hl, _wav_buffer
	ld bc, LBUFFER/2
	ld a, (_plugin_file_handle)

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jp c, _play_exit		;si error, fin de lectura
	ld a,b
	or c
	jp z, _play_exit		;si no hay más que leer, fin de lectura

	ld hl, _wav_buffer
	call PlotWave

	jp _play_loop

_play_exit:

	ld (_plugin_ok_nav + 1), bc
	ld (_plugin_ok_ret + 1), a

	call _set_status_icon

	ld e, a				; store a

	ld a, (_plugin_cfg)		; do we have a config file?
	and a
	jr z, _play_exit_skip_restore

	ld a, (_plugin_cfg_flags)
	and SETTING_DISPLAY_WAVEFORM
	jr z, _play_exit_skip_restore

					; restore the screen
	ld hl, SCR_COPY
	ld de, 16384
	ld bc, 6144
	ldir

	ld a, MMC_MEMORY_PLUGIN_PAGE2 + 128
	out (MMC_MEMORY_PORT), a

	ld de, SCR_COPY
	ld bc, DIV_MMC_BANK_SIZE
	ld hl, 8192
	ldir

_plugin_esxdos_page_restore2:

	ld a, 0				; 0 -nmi, 2 - .dot
	add a, 128
	out (MMC_MEMORY_PORT), a

_play_exit_skip_restore:

	ld bc, ZXUNOADDR * 256 + ZXIBASEPORT
	ld a, DMACTRL
	out (c), a
	inc b
	xor a
	out (c), a
	dec b

	ret


PlotWave:

	ld de,BufferBorrado
	ld c, 0

LoopWave:

	ld a, (de)
	ld b, a
	call Plot
	ld a, (hl)
	srl a
	add a, 24
	ld b, a
	call Plot
	ld a, b
	ld (de), a
	inc hl
	inc de
	inc c
	jp nz, LoopWave

	ret

Plot:
					; B=y, C=x
	push bc
	push de
	push hl
	ld e, b
	ld d, 0				; DE=y
	sla e
	rl d				; DE=DE*2
	ld hl, _screen_lookup
	add hl, de			; HL=puntero a la direccion del primer pixel de Y.
	ld e, (hl)
	inc hl
	ld d,(hl)
	ex de, hl			; HL=dir primer pixel fila Y
	ld d, c				; Guardo coordenada X en D
	ld a, c
	srl a
	srl a
	srl a
	ld c, a
	ld b, 0
	add hl, bc			; HL contiene la direccion a pintar del pixel
	ld a, d				; Recupero coordenada X
	and 7
	ld de, DirBits
	add a, e
	ld e, a
	ld a, d
	adc a, 0
	ld d, a
	ld a,(de)
	xor (hl)
	ld (hl), a
	pop hl
	pop de
	pop bc

	ret

DirBits:

	defb %10000000
	defb %01000000
	defb %00100000
	defb %00010000
	defb %00001000
	defb %00000100
	defb %00000010
	defb %00000001


_set_status_icon:

	ld a, h
	or l
	ret z

					; hl points to status graphic
	ld de, PLUGIN_STATUS_SCREEN_ADDR
	ld b, 8

_set_status_icon_loop:

	ld a, (hl)
	ld (de), a
	inc hl
	inc d
	djnz _set_status_icon_loop
	ret


_plugin_status_playing:

	defb %00000000
	defb %00100000
	defb %00110000
	defb %00111000
	defb %00110000
	defb %00100000
	defb %00000000
	defb %00000000

_plugin_status_seek_next:

	defb %00000000
	defb %01000100
	defb %01100110
	defb %01110111
	defb %01100110
	defb %01000100
	defb %00000000
	defb %00000000

_plugin_status_seek_previous:

	defb %00000000
	defb %00100010
	defb %01100110
	defb %11101110
	defb %01100110
	defb %00100010
	defb %00000000
	defb %00000000


_zx_uno_test:

	ld bc, ZX_UNO_OUT_PORT
	ld a, COREID_REGISTER
	out (c), a

	ld e, 0

_zx_uno_test_get_char:

	ld bc, ZX_UNO_IN_PORT
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


_plugin_file_handle:

 	defb $0

_plugin_cfg:

	defb $0

_plugin_cfg_flags:

	defb $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

_err_uno:

	defb "This plugin requires a ZX-UNO!", $0


include "plugin_keyboard.asm"

_screen_lookup:

	defw $4000
	defw $4100
	defw $4200
	defw $4300
	defw $4400
	defw $4500
	defw $4600
	defw $4700
	defw $4020
	defw $4120
	defw $4220
	defw $4320
	defw $4420
	defw $4520
	defw $4620
	defw $4720
	defw $4040
	defw $4140
	defw $4240
	defw $4340
	defw $4440
	defw $4540
	defw $4640
	defw $4740
	defw $4060
	defw $4160
	defw $4260
	defw $4360
	defw $4460
	defw $4560
	defw $4660
	defw $4760
	defw $4080
	defw $4180
	defw $4280
	defw $4380
	defw $4480
	defw $4580
	defw $4680
	defw $4780
	defw $40a0
	defw $41a0
	defw $42a0
	defw $43a0
	defw $44a0
	defw $45a0
	defw $46a0
	defw $47a0
	defw $40c0
	defw $41c0
	defw $42c0
	defw $43c0
	defw $44c0
	defw $45c0
	defw $46c0
	defw $47c0
	defw $40e0
	defw $41e0
	defw $42e0
	defw $43e0
	defw $44e0
	defw $45e0
	defw $46e0
	defw $47e0
	defw $4800
	defw $4900
	defw $4a00
	defw $4b00
	defw $4c00
	defw $4d00
	defw $4e00
	defw $4f00
	defw $4820
	defw $4920
	defw $4a20
	defw $4b20
	defw $4c20
	defw $4d20
	defw $4e20
	defw $4f20
	defw $4840
	defw $4940
	defw $4a40
	defw $4b40
	defw $4c40
	defw $4d40
	defw $4e40
	defw $4f40
	defw $4860
	defw $4960
	defw $4a60
	defw $4b60
	defw $4c60
	defw $4d60
	defw $4e60
	defw $4f60
	defw $4880
	defw $4980
	defw $4a80
	defw $4b80
	defw $4c80
	defw $4d80
	defw $4e80
	defw $4f80
	defw $48a0
	defw $49a0
	defw $4aa0
	defw $4ba0
	defw $4ca0
	defw $4da0
	defw $4ea0
	defw $4fa0
	defw $48c0
	defw $49c0
	defw $4ac0
	defw $4bc0
	defw $4cc0
	defw $4dc0
	defw $4ec0
	defw $4fc0
	defw $48e0
	defw $49e0
	defw $4ae0
	defw $4be0
	defw $4ce0
	defw $4de0
	defw $4ee0
	defw $4fe0
	defw $5000
	defw $5100
	defw $5200
	defw $5300
	defw $5400
	defw $5500
	defw $5600
	defw $5700
	defw $5020
	defw $5120
	defw $5220
	defw $5320
	defw $5420
	defw $5520
	defw $5620
	defw $5720
	defw $5040
	defw $5140
	defw $5240
	defw $5340
	defw $5440
	defw $5540
	defw $5640
	defw $5740
	defw $5060
	defw $5160
	defw $5260
	defw $5360
	defw $5460
	defw $5560
	defw $5660
	defw $5760
	defw $5080
	defw $5180
	defw $5280
	defw $5380
	defw $5480
	defw $5580
	defw $5680
	defw $5780
	defw $50a0
	defw $51a0
	defw $52a0
	defw $53a0
	defw $54a0
	defw $55a0
	defw $56a0
	defw $57a0
	defw $50c0
	defw $51c0
	defw $52c0
	defw $53c0
	defw $54c0
	defw $55c0
	defw $56c0
	defw $57c0
	defw $50e0
	defw $51e0
	defw $52e0
	defw $53e0
	defw $54e0
	defw $55e0
	defw $56e0
	defw $57e0

BufferBorrado:

	defs(256)

_wav_buffer:

	defs (LBUFFER)


