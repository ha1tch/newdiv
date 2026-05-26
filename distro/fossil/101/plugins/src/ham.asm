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

; IM2 table 	$c000 49152	256 bytes
; HAM256 file 	$d000 53248	7680 bytes

DEFC IM2_I=$c0
DEFC IM2_TABLE=$c000
DEFC IM2_TABLE_BYTE=$c2
DEFC IM2_TABLE_JUMP=$c2c2

DEFC TIMEX_SCREEN=$6000

DEFC ULA_PLUS_REGISTER_PORT=48955
DEFC ULA_PLUS_REGISTER_DATA=65339
DEFC ULA_PLUS_PALETTE_SIZE=64

DEFC HAM_256_SIZE=7680
DEFC HAM_256_SCREEN_BUFFER=$d000	; 53248
DEFC HAM_256_PALETTE_BUFFER=HAM_256_SCREEN_BUFFER + 6912
DEFC HAM_8X1_SIZE=13056

	org PLUGIN_ORG

	jr _plugin_start

	defb "BP"				; id
	defb 0					; spare
	defb 0					; spare
	defb PLUGIN_FLAGS1_COPY_SETTINGS	; flags
	defb 0					; flags2

_plugin_user_data:

	defs(PLUGIN_SETTING_MAX)		; reserve space for settings copy

_plugin_id_string:

	defb "ULAplus HAM256/9x1 plugin - Andrew Owen/Simon Owen/bob_fossil", $0

_plugin_start:

	; hl is the filename
	; bc is the parameter block

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
	ld bc, HAM_256_SIZE		; check if filesize HL == 7680
	or a
	sbc hl, bc
	jr c, _plugin_size_error	; c cleared if hl >= bc

	ld a, h				; hl should be 0 if size is 7680
	or l
	jr z, _plugin_read_ham_256

_plugin_size_8x1:

	ld hl, (_plugin_file_stat + 7)	; put 16 bit file size into hl
	ld bc, HAM_8X1_SIZE		; check if filesize HL == 13056
	or a
	sbc hl, bc
	jr c, _plugin_size_error	; c cleared if hl >= bc

	ld a, h				; hl should be 0 if size is 13056
	or l
	jr z, _plugin_read_ham_8x1

_plugin_size_error:

	ld bc, _err_size
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_read_ham_8x1:

	ld a, 1
	ld (_ham_8x1), a

	ld a, (_plugin_file_handle)

	ld hl, $4000
	ld bc, 6144

	rst ESXDOS_SYS_CALL		; read first screen
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_read_second

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error


_plugin_read_second:

	; !!!
	ld hl, TIMEX_SCREEN
	ld de, HAM_256_SCREEN_BUFFER
	ld bc, 6144
	ldir

	ld a, (_plugin_file_handle)

	ld hl, TIMEX_SCREEN
	ld bc, 6144

	rst ESXDOS_SYS_CALL		; read first screen
	defb ESXDOS_SYS_F_READ

	ld a, (_plugin_file_handle)

	ld hl, HAM_256_PALETTE_BUFFER
	ld bc, 768

	rst ESXDOS_SYS_CALL		; read attributes
	defb ESXDOS_SYS_F_READ

	jr _plugin_init

_plugin_read_ham_256:

	ld a, (_plugin_file_handle)

	ld bc, HAM_256_SIZE
	ld hl, HAM_256_SCREEN_BUFFER

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_init

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_init:

					; code goes here
	call _setup_ham

_plugin_wait:

	call _plugin_wait_for_no_keys

_plugin_main:

	call _plugin_in_inkey		; get scancode into l

					; check key up
	ld de, _plugin_user_data + PLUGIN_SETTING_OFFSET_KEY_UP
	ld a, (de)
	cp l
	jr nz, _plugin_key_down

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE|PLUGIN_RESTORE_BUFFERS
	ld bc, PLUGIN_NAVIGATE_FIRST
	jr _plugin_done

_plugin_key_down:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_left

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE|PLUGIN_RESTORE_BUFFERS
	ld bc, PLUGIN_NAVIGATE_LAST
	jr _plugin_done

_plugin_key_left:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_right

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE|PLUGIN_RESTORE_BUFFERS
	ld bc, PLUGIN_NAVIGATE_PREVIOUS
	jr _plugin_done

_plugin_key_right:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_break

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_NAVIGATE|PLUGIN_RESTORE_BUFFERS
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

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_RESTORE_BUFFERS
	ld bc, 0

_plugin_done:

	push bc

	ld (_plugin_ok_ret + 1), a

	call _close_ham

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

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


_setup_ham:

;	di				; disable interrupts
;	push af				; save the registers
;	push bc
;	push de
;	push hl

	xor a
	ld hl, _ula_plus_palette_copy	; make a copy of the existing palette

_setup_ham_copy:

					; save any existing ULAplus palette
	ld bc, ULA_PLUS_REGISTER_PORT
	out (c), a

	ld e, a				; save a in e

	ld bc, ULA_PLUS_REGISTER_DATA	; select colour

	nop

	in a, (c)

	ld (hl), a			; store colour value

	ld a, e

	inc a				; next colour
	inc hl

	cp ULA_PLUS_PALETTE_SIZE
	jr nz, _setup_ham_copy

					; ham256 code starts here


	ld de, 0xbfff			; D = register port, E = data port
	ld c, 0x3b			; C = ZXI base port
	xor a				; count starts at zero

_setup_ham_palette_loop:

	ld b, d				; register port
	out (c), a			; palette entry to write
	ld b, e				;
	ex af, af'			; save the count
	xor a				; set the palette to all black
	out (c), a
	ex af, af'			; restore the count
	inc a				; next palette entry
	cp ULA_PLUS_PALETTE_SIZE	; are we nearly there yet?
					; repeat until all 64 have been done
	jr nz, _setup_ham_palette_loop

	ld b, d				; select register port
	out (c), a			; A = 64 (mode group)
	ld a, 1				; RGB mode (2 for HSL)
	ld b, e				; data port
	out (c), a			; enable RGB mode

	ld a, (_ham_8x1)		; skip next bit if we're ham8x1
	and a
	jr z, _setup_ham_skip_8x1


	ld a, 2				; screen mode 2
	out (255), a
	jr _setup_ham_int

;	ld		hl, screen		; bitmap
;	ld		de, 0x4000		; screen address
;	ld		bc, 6144		; bytes
;	ldir					; block copy
;
;	ld		hl, attr		; attributes
;	ld		de, 0x6000		; screen address
;	ld		bc, 6144		; bytes
;	ldir					; block copy

;	ld		a, 0x3b			; use ROM vector table
;	ld		i, a			;
;
;	pop hl				; restore the registers
;	pop de
;	pop bc
;	pop af


_setup_ham_skip_8x1:

	ld hl, HAM_256_SCREEN_BUFFER	; bitmap and attributes
	ld de, 0x4000			; screen address
	ld bc, 6912			; bytes
	ldir				; block copy

_setup_ham_int:

	ld hl, IM2_TABLE
	ld de, IM2_TABLE + 1
	ld bc, 256
	ld (hl), IM2_TABLE_BYTE
	ldir
	ld a, i
	ld (_i_store), a

	ld a, 195			; jp opcode
	ld (IM2_TABLE_JUMP), a
	ld hl, _im2_main
	ld (IM2_TABLE_JUMP + 1), hl
	ld a, IM2_I
	ld i, a
	im 2
	ei
	ret


_close_ham:

	di
	ld a, (_i_store)
	ld i,a
	im 1
	ld hl, 10072
	exx

	ld hl, _ula_plus_empty_palette	; set all black before we turn ULAplus off
	call _apply_palette

	ld hl, 22528
	ld (hl), 0
	ld de, 22529
	ld bc, 767
	ldir

	ld bc, ULA_PLUS_REGISTER_PORT	; disable 64 colour ULA plus mode
	ld a, 64
	out (c), a

	xor a
	ld bc, ULA_PLUS_REGISTER_DATA
	out (c), a

	ld hl, _ula_plus_palette_copy	; restore original ULAplus palette
	call _apply_palette

	ld a, (_ham_8x1)
	and a
	ret z

	xor a				; screen mode 0
	out (255), a

	ld de, TIMEX_SCREEN		; restore memory
	ld hl, HAM_256_SCREEN_BUFFER
	ld bc, 6144
	ldir

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


_im2_main:

	push af				; save registers
	push bc
	push de
	push hl
	ex af, af'
	exx
	push af
	push bc
	push de
	push hl

	ld hl, (0)			; padding
	nop				;

	ld hl, 473			; wait until just before the row

_im2_delay:

	dec hl
	ld a, h
	or l
	jr nz, _im2_delay		; wait until near top of main screen

	ld hl, HAM_256_PALETTE_BUFFER	; colour data

	ld de, 0xbf00			; D = register select, E = data port (+1 due to OUTI)
	ld c, 0x3b			; C = ZXI base port

	xor a				; first CLUT entry is zero

	exx
	ld de, 0x3f0c			; D = counter mask for 2 rows, E = 12 pairs of rows

_im2_loop1:

	ld b, 16			; B=16 (x2 from below) entries to set

_im2_loop2:

	exx

	ld b, d				; register port
	out (c), a			; set CLUT
	ld b, e				; data port
	outi				; set colour
	inc a				; next CLUT entry

	ld b, d				; same again...
	out (c), a
	ld b, e
	outi
	inc a

	exx
	djnz _im2_loop2			; finish row

	and d
	jr nz, _im2_loop1		; finish pair

_im2_pad_val:

	ld b, 8				; timing for 48
	djnz $				; delay before next row

	nop				; 8 t-states
	nop

	dec e
	jr nz, _im2_loop1		; finish screen

	pop hl				; restore registers
	pop de
	pop bc
	pop af
	ex af, af'			;'
	exx
	pop hl
	pop de
	pop bc
	pop af

	ei
	ret


include "plugin_keyboard.asm"

_plugin_file_handle:

	defb 0

_i_store:

	defb 0

_ham_8x1:

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

_ula_plus_palette_copy:

	defs(ULA_PLUS_PALETTE_SIZE)

_ula_plus_empty_palette:

	defs(ULA_PLUS_PALETTE_SIZE)


_err_size:

	defb "Invalid filetype!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

;

; HAM256 viewer v0.3

; HAM256 format devised by Andrew Owen
; Raster code by Simon Owen

;org 57700
;	jr		switch_on
;
;	di						; switch interrupt mode
;	im		1
;	ei
;	ret
;
;	defb	"3"				; minor version number
;
;org 57708					; 56 bytes
;switch_on:
;	di						; disable interrupts
;	push	af				; save the registers
;	push	bc
;	push	de
;	push	hl
;
;	ld		de, 0xbfff		; D = register port, E = data port	
;	ld		c, 0x3b			; C = ZXI base port
;	xor		a				; count starts at zero
;	
;p_loop:
;	ld		b, d			; register port
;	out		(c), a			; palette entry to write
;	ld		b, e			;
;	ex		af, af'			;'save the count
;	xor		a				; set the palette to all black
;	out		(c), a
;	ex		af, af'			;'restore the count
;	inc		a				; next palette entry
;	cp		64				; are we nearly there yet?
;	jr		nz, p_loop		; repeat until all 64 have been done
;
;	ld		b, d			; select register port
;	out		(c), a			; A = 64 (mode group)
;	ld		a, 1			; RGB mode (2 for HSL)
;	ld		b, e			; data port
;	out		(c), a			; enable RGB mode 
;
;	ld		hl, screen		; bitmap and attributes
;	ld		de, 0x4000		; screen address
;	ld		bc, 6912		; bytes
;	ldir					; block copy
;
;	ld		a, 0x3b			; use ROM vector table
;	ld		i, a			;
;
;	pop		hl				; restore the registers
;	pop		de
;	pop		bc
;	pop		af
;
;enable_im2:	
;	im		2				; switch it on
;	ei						; enable interrupts
;	ret						; return to BASIC
;
;org 57764					; 80 bytes of code
;
;im_main:
;	push	af				; save registers
;	push	bc
;	push	de
;	push	hl
;	ex		af, af'			;'
;	exx
;	push	af
;	push	bc
;	push	de
;	push	hl
;
;	ld		hl, (0)			; padding		
;	nop						;
;	
;	ld		hl, 473			; wait until just before the row
;	
;delay:
;	dec		hl
;	ld		a, h
;	or		l
;	jr		nz, delay		; wait until near top of main screen
;
;	ld		hl, palette		; colour data
;	ld		de, 0xbf00		; D = register select, E = data port (+1 due to OUTI)
;	ld		c, 0x3b			; C = ZXI base port
;
;	xor		a				; first CLUT entry is zero
;
;	exx
;	ld		de, 0x3f0c		; D = counter mask for 2 rows, E = 12 pairs of rows
;
;loop1:
;	ld		b, 16			; B=16 (x2 from below) entries to set
;	
;loop2:
;	exx
;
;	ld  	b, d			; register port
;	out 	(c), a			; set CLUT
;	ld  	b, e			; data port
;	outi					; set colour
;	inc		a               ; next CLUT entry
;
;    ld		b, d			; same again...
;	out		(c), a
;	ld		b, e
;	outi
;	inc		a
;
;	exx
;	djnz	loop2          ; finish row
;
;	and		d
;	jr		nz, loop1        ; finish pair
;
;pad_val:
;	ld		b, 8			; timing for 48
;	djnz 	$				; delay before next row
;
;	nop						; 8 t-states
;	nop
;	
;	dec		e
;	jr		nz, loop1        ; finish screen
;
;	pop		hl				; restore registers
;	pop		de
;	pop		bc
;	pop		af
;	ex		af, af'			;'
;	exx
;	pop		hl
;	pop		de
;	pop		bc
;	pop		af
;	
;	jp		0x0038			; jump into ROM interrupt handler
;
;org 57844
;screen:
;	incbin	"ham256.scr"
;
;org 64756
;palette:
;	incbin	"ham256.pal"
;
;org 65524
;vector:
;	jp		im_main			; jump to main interrupt handler
;
;org 65535
;	defb	24				; combined with first ROM byte forms JR vector
;
;
