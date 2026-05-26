;******************************************************************************
;*
;* Copyright(c) 2020-22 Bob Fossil. All rights reserved.
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

DEFC stc_data=0xc000
DEFC MAX_SIZE=16384
DEFC STC_ID_LEN=18

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

	defb ".STC file plugin - gasman/bob_fossil", $0

_plugin_start:

					; filename in hl
	xor a
	ld (_plugin_file_handle), a

	ld a, ESXDOS_CURRENT_DRIVE	; *
	ld b, ESXDOS_MODE_READ

	rst ESXDOS_SYS_CALL		; open file
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
					; check if filesize HL < 16384
	push hl

	ld bc, MAX_SIZE			; check data is in RAM
	or a
	sbc hl, bc

	pop bc				; pop hl size into bc

	jr c, _plugin_read

	ld bc, _err_memory
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_read:

	ld a, (_plugin_file_handle)	; read file to stc_data address
	ld hl, stc_data

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_check

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_check:

	push hl
	ld hl, stc_data + 7		; offset for 'SONG BY ST COMPILE'
	ld de, _stc_id
	ld b, STC_ID_LEN
	call _strncmp			; check data + 7 is 'SONG BY ST COMPILE'

	pop hl
	jr z, _plugin_init

	ld bc, _err_invalid
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jr _plugin_error

_plugin_init:

	push ix

	ei

	ld hl, stc_data
	call stc_init

	ld hl, _plugin_status_playing
	call _set_status_icon

	call _plugin_wait_for_no_keys

_plugin_playback:

	halt
	call stc_play

	call _plugin_in_inkey		; get scancode into l

					; check key up
	ld de, _plugin_user_data + PLUGIN_SETTING_OFFSET_KEY_UP
	ld a, (de)
	cp l
	jr nz, _plugin_key_down

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_FIRST
	ld hl, _plugin_status_seek_previous
	jr _plugin_done

_plugin_key_down:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_left

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_LAST
	ld hl, _plugin_status_seek_next
	jr _plugin_done

_plugin_key_left:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_right

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_PREVIOUS
	ld hl, _plugin_status_seek_previous
	jr _plugin_done

_plugin_key_right:

	inc de
	ld a, (de)
	cp l
	jr nz, _plugin_key_break

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
	ld bc, PLUGIN_NAVIGATE_NEXT
	ld hl, _plugin_status_seek_next
	jr _plugin_done

_plugin_key_break:

	ld a, $20			; Space
	cp l
	jr nz, _plugin_playback

	call _plugin_shift_pressed
	ld a, l
	and SHIFT_CAPS			; shift + space, so return

	jr z, _plugin_playback

;	ld bc, $fefe
;	in a, (c)
;	and %00000001			; shift pressed?
;	jr nz, _plugin_playback
;
;;	xor a
;;	in a, (254)
;;	cpl
;;	and $1f
;;	jr z, _plugin_playback
;
;	ld b, $f7
;	in a, (c)
;	and %00010000			; check for shift + 5
;	jr nz, _plugin_skip_prev
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_PREVIOUS
;	jr _plugin_done
;
;_plugin_skip_prev:
;
;	ld b, $ef
;	in a, (c)
;	ld b, a
;	and %00000100			; check for shift + 8
;	jr nz, _plugin_skip_next
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_NEXT
;	jr _plugin_done
;
;_plugin_skip_next:
;
;	ld a, b
;	and %00001000			; check for shift + 7
;	jr nz, _plugin_skip_last
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_FIRST
;	jr _plugin_done
;
;_plugin_skip_last:
;
;	ld a, b
;	and %00010000			; check for shift + 6
;	jr nz, _plugin_skip_first
;
;	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS|PLUGIN_NAVIGATE
;	ld bc, PLUGIN_NAVIGATE_LAST
;	jr _plugin_done
;
;_plugin_skip_first:
;
;	ld b, $7f
;	in a, (c)
;	and %00000001			; check for shift + space
;
;;	xor a
;;	in a, (254)
;;	cpl
;;	and $1f
;
;	jr nz, _plugin_playback

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS
	ld hl, 0

_plugin_done:

	push bc				; save navigation
	push af				; save return code

	call _set_status_icon

	call stc_init

	di

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop af				; restore return code
	pop bc				; restore navigation

	pop ix

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


include "plugin_keyboard.asm"

;z80
;zx-spectrum
;assembler

; Disassembly of the file "stcrout.bin"
; 
; CPU Type: Z80
; 
; Created with dZ80 2.0
; 
; on Wednesday, 18 of February 2004 at 10:47 PM
; 

;stc_init_entry:
;        ld      hl,stc_data
;stc_data_addr:	equ $-1
;        jp      stc_init
;stc_play_entry:
;        jp      stc_play
stc_init: 
	di      
        ld      a,(hl)		; read delay value
        ld      (delay),a
        ld      (data_addr),hl	; store address of data start
        inc     hl			; now hl = stc_data+1, start of pointer list
        call    read_convert_ptr	; find absolute address of position map
        ld      a,(de)		; read song length
        inc     de			; de now points to first real entry in position map
        inc     a
        ld      (song_length),a
        ld      (position_map),de
        call    read_convert_ptr
        ld      (l7c36),de
        push    de
        call    read_convert_ptr
        ld      (l7c38),de
        ld      hl,001bh
        call    l7c7e
        ex      de,hl
        ld      (l7c3a),hl
        ld      hl,l7c45
        ld      (l7c3f),hl
        ld      hl,l7c46
        ld      de,l7c46+1
        ld      bc,002ch
        ld      (hl),b
        ldir    
        pop     hl
        ld      bc,0021h
        xor     a
        call    l7c73
        dec     a
        ld      (l7c4f),a
        ld      (l7c59),a
        ld      (l7c63),a
        ld      a,01h
        ld      (delay_count),a
        inc     hl
        ld      (l7c4d),hl
        ld      (l7c57),hl
        ld      (l7c61),hl
        call    l7fe3
        ei      
        ret     

position_map:  defw      0xf177
l7c36:	defw 0xf18f
l7c38:	defw 0xf213
l7c3a:	defw 0xee5e
delay:         defb      0x06
delay_count:   defb      0x01
song_length:   defb      0x0c
l7c3f:	defw 0xe745
l7c41:	defw 0x69b8
l7c43:	defw 0x6a57
l7c45:	defb 0xff
l7c46:	defb 0x00
	defb 0x00
l7c48:	defb 0x00, 0x00, 0x00
l7c4b:	defw 0x0000
l7c4d:	defw 0xf190
l7c4f:	defb 0xff
	defb 0x00, 0x00
l7c52:	defb 0x00, 0x00, 0x00
l7c55:	defb 0x00
	defb 0x00
l7c57:	defb 0x90
	defb 0xf1
l7c59:	defb 0xff, 0x00, 0x00
l7c5c:	defb 0x00, 0x00
	defb 0x00
l7c5f:	defb 0x00, 0x00
l7c61:	defb 0x90, 0xf1
l7c63:	defb 0xff
l7c64:	defb 0x00
l7c65:	defb 0x00
	defb 0x00
l7c67:	defb 0x00, 0x00
l7c69:	defb 0x00, 0x00
l7c6b:	defb 0x00
l7c6c:	defb 0x00
l7c6d:	defb 0x00
l7c6e:	defb 0x00
l7c6f:	defb 0x00
l7c70:	defb 0x00, 0x00
l7c72:	defb 0x00

l7c73:  cp      (hl)
        ret     z
        add     hl,bc
        jp      l7c73
read_convert_ptr:
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ex      de,hl		; ld hl,(hl)
l7c7e:  ld      bc,0ee43h
data_addr equ $-2
        add     hl,bc		; convert an offset from stc_data to an absolute address
        ex      de,hl		; return it in de
        ret     
l7c84:  ld      d,00h
        ld      e,a
        add     a,a
        add     a,e
        ld      e,a
        add     ix,de
        ld      a,(ix+01h)
        bit     7,a
        ld      c,10h
        jp      nz,l7c97
        ld      c,d
l7c97:  bit     6,a
        ld      b,02h
        jp      nz,l7c9f
        ld      b,d
l7c9f:  and     1fh
        ld      h,a
        ld      e,(ix+02h)
        ld      a,(ix+00h)
        push    af
        and     0f0h
        rrca    
        rrca    
        rrca    
        rrca    
        ld      d,a
        pop     af
        and     0fh
        ld      l,a
        bit     5,(ix+01h)
        ret     z
        set     4,d
        ret     
l7cbc:  ld      a,(l7c64)
        ld      c,a
        ld      hl,song_length
        cp      (hl)
        jp      c,l7cc9
        xor     a
        ld      c,a
l7cc9:  inc     a
        ld      (l7c64),a
        ld      l,c
        ld      h,00h
        add     hl,hl
        ld      de,(position_map)
        add     hl,de
        ld      c,(hl)
        inc     hl
        ld      a,(hl)
        ld      (l7f08),a
        ld      a,c
        ld      hl,(l7c38)
        ld      bc,0007h
        call    l7c73
        inc     hl
        call    read_convert_ptr
        ld      (l7c3f),de
        call    read_convert_ptr
        ld      (l7c41),de
        call    read_convert_ptr
        ld      (l7c43),de
        ret     
l7cfd:  dec     (ix+02h)
        ret     p
        ld      a,(ix-01h)
        ld      (ix+02h),a
        ret     
stc_play:  ld      a,(delay_count)
        dec     a
        ld      (delay_count),a
        jp      nz,l7e52
        ld      a,(delay)
        ld      (delay_count),a
        ld      ix,l7c48
        call    l7cfd
        jp      p,l7d33
        ld      hl,(l7c3f)
        ld      a,(hl)
        inc     a
        call    z,l7cbc
        ld      hl,(l7c3f)
        call    l7d5c
        ld      (l7c3f),hl
l7d33:  ld      ix,l7c52
        call    l7cfd
        jp      p,l7d46
        ld      hl,(l7c41)
        call    l7d5c
        ld      (l7c41),hl
l7d46:  ld      ix,l7c5c
        call    l7cfd
        jp      p,l7e52
        ld      hl,(l7c43)
        call    l7d5c
        ld      (l7c43),hl
        jp      l7e52
l7d5c:  ld      a,(hl)
        cp      60h
        jp      c,l7d8a
        cp      70h
        jp      c,l7d97
        cp      80h
        jp      c,l7db8
        jp      z,l7daf
        cp      81h
        jp      z,l7d95
        cp      82h
        jp      z,l7db5
        cp      8fh
        jp      c,l7dd4
        sub     0a1h
        ld      (ix+02h),a
        ld      (ix-01h),a
        inc     hl
        jp      l7d5c
l7d8a:  ld      (ix+01h),a
        ld      (ix+00h),00h
        ld      (ix+07h),20h
l7d95:  inc     hl
        ret     
l7d97:  sub     60h
        push    hl
        ld      bc,0063h
        ld      hl,(l7c3a)
        call    l7c73
        inc     hl
        ld      (ix+03h),l
        ld      (ix+04h),h
        pop     hl
        inc     hl
        jp      l7d5c
l7daf:  inc     hl
l7db0:  ld      (ix+07h),0ffh
        ret     
l7db5:  xor     a
        jr      l7dba
l7db8:  sub     70h
l7dba:  push    hl
        ld      bc,0021h
        ld      hl,(l7c36)
        call    l7c73
        inc     hl
        ld      (ix+05h),l
        ld      (ix+06h),h
        ld      (ix-02h),00h
        pop     hl
        inc     hl
        jp      l7d5c
l7dd4:  sub     80h
        ld      (l7c72),a
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      (l7c70),a
        ld      (ix-02h),01h
        push    hl
        xor     a
        ld      bc,0021h
        ld      hl,(l7c36)
        call    l7c73
        inc     hl
        ld      (ix+05h),l
        ld      (ix+06h),h
        pop     hl
        jp      l7d5c
l7df9:  ld      a,(ix+07h)
        inc     a
        ret     z
        dec     a
        dec     a
        ld      (ix+07h),a
        push    af
        ld      a,(ix+00h)
        ld      c,a
        inc     a
        and     1fh
        ld      (ix+00h),a
        pop     af
        ret     nz
        ld      e,(ix+03h)
        ld      d,(ix+04h)
        ld      hl,0060h
        add     hl,de
        ld      a,(hl)
        dec     a
        jp      m,l7db0
        ld      c,a
        inc     a
        and     1fh
        ld      (ix+00h),a
        inc     hl
        ld      a,(hl)
        inc     a
        ld      (ix+07h),a
        ret     
l7e2d:  ld      a,c
        or      a
        ret     nz
        ld      a,h
        ld      (l7c6b),a
        ret     
l7e35:  ld      a,(ix+07h)
        inc     a
        ret     z
        ld      a,(ix-02h)
        or      a
        ret     z
        cp      02h
        jp      z,l7e4b
        ld      (ix-02h),02h
        jp      l7e4f
l7e4b:  xor     a
        ld      (l7c72),a
l7e4f:  set     4,(hl)
        ret     
l7e52:  ld      ix,l7c48
        call    l7df9
        ld      a,c
        ld      (l7f00),a
        ld      ix,(l7c4b)
        call    l7c84
        ld      a,c
        or      b
        rrca    
        ld      (l7c6c),a
        ld      ix,l7c48
        ld      a,(ix+07h)
        inc     a
        jp      z,l7e7e
        call    l7e2d
        call    l7ef6
        ld      (l7c65),hl
l7e7e:  ld      hl,l7c6d
        ld      (hl),a
        call    l7e35
        ld      ix,l7c52
        call    l7df9
        ld      a,(ix+07h)
        inc     a
        jp      z,l7eb3
        ld      a,c
        ld      (l7f00),a
        ld      ix,(l7c55)
        call    l7c84
        ld      a,(l7c6c)
        or      c
        or      b
        ld      (l7c6c),a
        call    l7e2d
        ld      ix,l7c52
        call    l7ef6
        ld      (l7c67),hl
l7eb3:  ld      hl,l7c6e
        ld      (hl),a
        call    l7e35
        ld      ix,l7c5c
        call    l7df9
        ld      a,(ix+07h)
        inc     a
        jp      z,l7eec
        ld      a,c
        ld      (l7f00),a
        ld      ix,(l7c5f)
        call    l7c84
        ld      a,(l7c6c)
        rlc     c
        rlc     b
        or      b
        or      c
        ld      (l7c6c),a
        call    l7e2d
        ld      ix,l7c5c
        call    l7ef6
        ld      (l7c69),hl
l7eec:  ld      hl,l7c6f
        ld      (hl),a
        call    l7e35
        jp      l7fe3
l7ef6:  ld      a,l
        push    af
        push    de
        ld      l,(ix+05h)
        ld      h,(ix+06h)
        ld      de,000ah
l7f00:	equ $-2
        add     hl,de
        ld      a,(ix+01h)
        add     a,(hl)
        add     a,00h
l7f08:	equ $-1
        add     a,a
        ld      e,a
        ld      d,00h
        ld      hl,tonetable
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        pop     de
        pop     af
        bit     4,d
        jr      z,l7f1f
        res     4,d
        add     hl,de
        ret     
l7f1f:  and     a
        sbc     hl,de
        ret     

tonetable:
	defw 0x0ef8, 0x0e10, 0x0d60, 0x0c80, 0x0bd8, 0x0b28, 0x0a88, 0x09f0
	defw 0x0960, 0x08e0, 0x0858, 0x07e0, 0x077c, 0x0708, 0x06b0, 0x0640
	defw 0x05ec, 0x0594, 0x0544, 0x04f8, 0x04b0, 0x0470, 0x042c, 0x03f0
	defw 0x03be, 0x0384, 0x0358, 0x0320, 0x02f6, 0x02ca, 0x02a2, 0x027c
	defw 0x0258, 0x0238, 0x0216, 0x01f8, 0x01df, 0x01c2, 0x01ac, 0x0190
	defw 0x017b, 0x0165, 0x0151, 0x013e, 0x012c, 0x011c, 0x010b, 0x00fc
	defw 0x00ef, 0x00e1, 0x00d6, 0x00c8, 0x00bd, 0x00b2, 0x00a8, 0x009f
	defw 0x0096, 0x008e, 0x0085, 0x007e, 0x0077, 0x0070, 0x006b, 0x0064
	defw 0x005e, 0x0059, 0x0054, 0x004f, 0x004b, 0x0047, 0x0042, 0x003f
	defw 0x003b, 0x0038, 0x0035, 0x0032, 0x002f, 0x002c, 0x002a, 0x0027
	defw 0x0025, 0x0023, 0x0021, 0x001f, 0x001d, 0x001c, 0x001a, 0x0019
	defw 0x0017, 0x0016, 0x0015, 0x0013, 0x0012, 0x0011, 0x0010, 0x000f

l7fe3:  ld      hl,l7c72
        xor     a
        or      (hl)
        ld      a,0dh
        jr      nz,l7ff1
        sub     03h
        dec     hl
        dec     hl
        dec     hl
l7ff1:  ld      c,0fdh
l7ff3:  ld      b,0ffh
        out     (c),a
        ld      b,0bfh
        outd    
        dec     a
        jp      p,l7ff3
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

;

_stc_id:

	defb "SONG BY ST COMPILE", 0

_err_memory:

	defb "Out of memory!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

_err_invalid:

	defb "Not a valid .STC file!", $0

