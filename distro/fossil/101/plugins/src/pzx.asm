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

DEFC ZX_UNO_REGISTER_PORT=64571
DEFC ZX_UNO_DATA_PORT=64827
DEFC COREID_REGISTER=$ff

DEFC SCANDBLCTRL_REGISTER=$0b
DEFC SRAMADDR=$f0
DEFC SRAMADDRINC=$f1
DEFC SRAMDATA=$f2

DEFC BUFFER_SIZE=2048
DEFC PZX_BLOCK_TAG_SIZE=8
DEFC PZX_BLOCK_SIZE=4
DEFC PAUSE_SIZE=10

;DEFINE DEBUG_PZX

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

	defb ".PZX plugin - mcleod_ideafix/bob_fossil", $0

_plugin_start:

	; hl is the filename

	call _zx_uno_test

IFNDEF _DEBUG

	jr nc, _plugin_uno_ok

	ld bc, _err_uno
	ld a, PLUGIN_ERROR
	ret

ENDIF

_plugin_uno_ok:

	ld bc, $fefe
	in a, (c)
	and %00000001			; shift pressed?
	jr nz, _plugin_no_shift		; no, so we want the .pzx to autostart

	ld (_plugin_autostart), a

_plugin_no_shift:

	ld a, ESXDOS_CURRENT_DRIVE	; *

	ld b, ESXDOS_MODE_READ

	rst ESXDOS_SYS_CALL		; open file for reading
	defb ESXDOS_SYS_F_OPEN

	jr nc, _plugin_read

	ld bc, _err_file
	ld a, PLUGIN_ERROR
	ret

_plugin_read:

	ld (_plugin_file_handle), a

	call _read_block_tag

	ld de, _pzx_header_block	; check PZX file header
	call _blockcmp
	jr z, _plugin_pzx_ok

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ld bc, _err_not_pzx
	ld a, PLUGIN_ERROR
	ret

_plugin_pzx_ok:

	ld a, (_buffer + 5)
	ld b, a
	ld a, (_buffer + 4)
	ld c, a

	ld hl, _buffer
	call _read

	call _readpzx

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ld a, (_plugin_user_data + PLUGIN_SETTING_OFFSET_BORDER)
	out (254), a

	ld a, (_plugin_autostart)
	and a
	jr nz, _plugin_load_tape

	ld bc, _txt_pzx_loaded
	ld a, PLUGIN_OK|PLUGIN_STATUS_MESSAGE
	ret

_plugin_load_tape:

					; software assisted PLAY press

	ld a, $f3
	ld bc, ZX_UNO_REGISTER_PORT
	out (c), a

	ld a, $1
	ld bc, ZX_UNO_DATA_PORT
	out (c), a

	xor a
	ld bc, ZX_UNO_DATA_PORT
	out (c), a

	ld b, ESXDOS_TAPEIN_CLOSE	; close any existing .tap file
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_M_TAPEIN

					; esxDOS NMI appears to set i resgister to $3e
					; which causes early Speedlock protected games
					; to crash out after the main BASIC block
	ld a, $3f
	ld i, a

	xor a				; 0 = tape
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_AUTOLOAD

	ld a, PLUGIN_OK
	ret


;void readpzx (BYTE handle)
;{
;    WORD hi,lo,res;
;    BYTE scandblctrl;
;
;    ZXUNOADDR = 0xb;
;    scandblctrl = ZXUNODATA;
;    ZXUNODATA = scandblctrl | 0xc0;
;
;    rewindsram();
;    while(1)
;    {
;        *((BYTE *)(23692)) = 0xff;  // para evitar el mensaje de scroll
;        res = readblocktag (handle);
;        if (!res)
;           break;
;
;        if (buffer[0]=='P' &&
;            buffer[1]=='U' &&
;            buffer[2]=='L' &&
;            buffer[3]=='S')
;        {
;            puts ("P");
;            MAKEWORD(lo,buffer[5],buffer[4]);
;            MAKEWORD(hi,buffer[7],buffer[6]);
;            writesram(0x2);
;            incaddrsram();
;            copysram(&buffer[4],4);
;            copyblock (handle,hi,lo);
;        }
;        else if (buffer[0]=='D' &&
;            buffer[1]=='A' &&
;            buffer[2]=='T' &&
;            buffer[3]=='A')
;        {
;            puts ("D");
;            MAKEWORD(lo,buffer[5],buffer[4]);
;            MAKEWORD(hi,buffer[7],buffer[6]);
;            writesram(0x3);
;            incaddrsram();
;            copysram(&buffer[4],4);
;            copyblock (handle,hi,lo);
;        }
;        else if (buffer[0]=='P' &&
;            buffer[1]=='A' &&
;            buffer[2]=='U' &&
;            buffer[3]=='S')
;        {
;            puts ("A");
;            MAKEWORD(lo,buffer[5],buffer[4]);
;            MAKEWORD(hi,buffer[7],buffer[6]);
;            convertpaus2puls (handle);
;            //writesram(0x4);
;            //incaddrsram();
;            //copysram(&buffer[4],4);
;            //copyblock (handle,hi,lo);
;        }
;        else if (buffer[0]=='S' &&
;            buffer[1]=='T' &&
;            buffer[2]=='O' &&
;            buffer[3]=='P')
;        {
;            puts ("S");
;            res = readword (handle);
;            //MAKEWORD(lo,buffer[5],buffer[4]);
;            //MAKEWORD(hi,buffer[7],buffer[6]);
;            writesram(0x1);
;            incaddrsram();
;            copysram (&res, 2);
;            writesram(0);
;            incaddrsram();
;            writesram(0);
;            incaddrsram();
;            //skipblock(handle,hi,lo);
;        }
;        else if (buffer[0]=='B' &&
;            buffer[1]=='R' &&
;            buffer[2]=='W' &&
;            buffer[3]=='S')
;        {
;            puts ("B");
;            writesram(0x4);
;            incaddrsram();
;            writesram(0);
;            incaddrsram();
;            writesram(0);
;            incaddrsram();
;            writesram(0);
;            incaddrsram();
;            writesram(0);
;            incaddrsram();
;            MAKEWORD(lo,buffer[5],buffer[4]);
;            MAKEWORD(hi,buffer[7],buffer[6]);
;            skipblock(handle,hi,lo);
;        }
;        else  // skip unsupported block
;        {
;            puts ("x");
;            MAKEWORD(lo,buffer[5],buffer[4]);
;            MAKEWORD(hi,buffer[7],buffer[6]);
;            skipblock(handle,hi,lo);
;        }
;    }
;    // pequeña pausa de 20ms para evitar errores de carga
;    // a causa de la conmutación brusca de la señal de EAR
;    // del player virtual a la entrada real
;
;    // Add full stop mark to the tape
;    writesram(0);
;    incaddrsram();
;    writesram(0);
;    incaddrsram();
;    writesram(0);
;    incaddrsram();
;    writesram(0);
;    incaddrsram();
;    writesram(0);
;    incaddrsram();
;
;    ZXUNOADDR = 0xb;
;    ZXUNODATA = scandblctrl;
;}

_readpzx:				; $806c

	ld a, $f3
	ld bc, ZX_UNO_REGISTER_PORT
	out (c), a

	ld a, $2			; flush any existing pzx tape?
	ld bc, ZX_UNO_DATA_PORT
	out (c), a

	xor a
	ld bc, ZX_UNO_DATA_PORT
	out (c), a

	ld bc, ZX_UNO_REGISTER_PORT	; get current turbo value
	ld a, SCANDBLCTRL_REGISTER
	out (c), a

	ld bc, ZX_UNO_DATA_PORT
	in a, (c)			; a is now SCANDBLCTRL

	ld (_scandblctrl), a
	or %11000000			; enable 28Mhz turbo
	ld bc, ZX_UNO_DATA_PORT
	out (c), a

	call _rewindsram

_read_pzx_loop:

	call _read_block_tag		; $8081

	ld a, b
	or c
	and a
	jp z, _read_pzx_loop_end

	ld de, _pzx_pulse_block
	call _blockcmp
	jr nz, _read_pzx_not_pulse

	ld a, 1
	out (254), a

IFDEF DEBUG_PZX
	ld hl, _pulse_count
	inc (hl)
ENDIF

		;puts ("D");
		;MAKEWORD(lo,buffer[5],buffer[4]);
		;MAKEWORD(hi,buffer[7],buffer[6]);
		;writesram(0x2);
		;incaddrsram();
		;copysram(&buffer[4],4);
		;copyblock (handle,hi,lo);

	ld a, (_buffer + 5)
	ld d, a
	ld a, (_buffer + 4)
	ld e, a

	ld a, (_buffer + 7)
	ld h, a
	ld a, (_buffer + 6)
	ld l, a

	push hl
	push de

	ld l, 2
	call _writesram
	;call _incaddrsram

	ld hl, _buffer + 4
	ld bc, 4
	call _copysram

	pop de
	pop hl

	call _copyblock

	jr _read_pzx_loop

_read_pzx_not_pulse:

	ld de, _pzx_data_block
	call _blockcmp
	jr nz, _read_pzx_not_data

	ld a, 2
	out (254), a

IFDEF DEBUG_PZX
	ld hl, _data_count
	inc (hl)
ENDIF


		;puts ("D");
		;MAKEWORD(lo,buffer[5],buffer[4]);
		;MAKEWORD(hi,buffer[7],buffer[6]);
		;writesram(0x3);
		;incaddrsram();
		;copysram(&buffer[4],4);
		;copyblock (handle,hi,lo);

					; $8121
	ld a, (_buffer + 5)
	ld d, a
	ld a, (_buffer + 4)
	ld e, a

	ld a, (_buffer + 7)
	ld h, a
	ld a, (_buffer + 6)
	ld l, a

	push hl
	push de

	ld l, 3
	call _writesram
	;call _incaddrsram

	ld hl, _buffer + 4
	ld bc, 4

	call _copysram

	pop de				; $1385
	pop hl				; $1

	call _copyblock			; $8146

	jp _read_pzx_loop

_read_pzx_not_data:

	ld de, _pzx_pause_block
	call _blockcmp
	jr nz, _read_pzx_not_pause

	ld a, 3
	out (254), a

IFDEF DEBUG_PZX
	ld hl, _pause_count
	inc (hl)
ENDIF


;            puts ("A");
;            MAKEWORD(lo,buffer[5],buffer[4]);
;            MAKEWORD(hi,buffer[7],buffer[6]);
;            convertpaus2puls (handle);
;            //writesram(0x4);
;            //incaddrsram();
;            //copysram(&buffer[4],4);
;            //copyblock (handle,hi,lo);

;	ld a, (_buffer + 5)
;	ld d, a
;	ld a, (_buffer + 4)
;	ld e, a
;
;	ld a, (_buffer + 7)
;	ld h, a
;	ld a, (_buffer + 6)
;	ld l, a
;
;	push hl
;	push de

	call _convertpaus2puls
;	ld l, 4
;	call _writesram
;	call _incaddrsram
;
;;            //copysram(&buffer[4],4);
;;            //copyblock (handle,hi,lo);
;
;	ld hl, _buffer + 4
;	ld bc, 4
;	call _copysram
;
;	pop de
;	pop hl
;	call _copyblock

	jp _read_pzx_loop

_read_pzx_not_pause:

	ld de, _pzx_stop_block
	call _blockcmp
	jr nz, _read_pzx_not_stop

	ld a, 4
	out (254), a

IFDEF DEBUG_PZX
	ld hl, _stop_count
	inc (hl)
ENDIF


;            res = readword (handle);
;            //MAKEWORD(lo,buffer[5],buffer[4]);
;            //MAKEWORD(hi,buffer[7],buffer[6]);
;            writesram(0x1);
;            incaddrsram();
;            copysram (&res, 2);
;            writesram(0);
;            incaddrsram();
;            writesram(0);
;            incaddrsram();
;            //skipblock(handle,hi,lo);

	call _readword
	ld l, 1
	call _writesram
	;call _incaddrsram

	ld hl, _result
	ld bc, 2
	call _copysram

	ld l, 0
	call _writesram
	;call _incaddrsram
	call _writesram
	;call _incaddrsram

	jp _read_pzx_loop

_read_pzx_not_stop:

	ld de, _pzx_browse_block
	call _blockcmp
	jr nz, _read_pzx_not_browse

	ld a, 5
	out (254), a

IFDEF DEBUG_PZX
	ld hl, _browse_count
	inc (hl)
ENDIF


;            writesram(0x4);
;            incaddrsram();
;            writesram(0);
;            incaddrsram();
;            writesram(0);
;            incaddrsram();
;            writesram(0);
;            incaddrsram();
;            writesram(0);
;            incaddrsram();
;            MAKEWORD(lo,buffer[5],buffer[4]);
;            MAKEWORD(hi,buffer[7],buffer[6]);
;            skipblock(handle,hi,lo);

	ld l, 4
	call _writesram
	;call _incaddrsram
	ld l, 0
	ld b, 4

_read_pzx_browse_loop:

	push bc
	call _writesram
	;call _incaddrsram
	pop bc
	djnz _read_pzx_browse_loop

	;jr _read_pzx_loop		; fall through and skip

_read_pzx_not_browse:

					; unsupported block?
					
IFDEF DEBUG_PZX
	ld hl, _other_count
	inc (hl)
ENDIF

	ld a, (_buffer + 5)
	ld d, a
	ld a, (_buffer + 4)
	ld e, a

	ld a, (_buffer + 7)
	ld b, a
	ld a, (_buffer + 6)
	ld c, a

;            MAKEWORD(lo,buffer[5],buffer[4]);
;            MAKEWORD(hi,buffer[7],buffer[6]);
;            skipblock(handle,hi,lo);

					; bc high word offset
					; de low word offset

	call _skip_block

					
					
	jp _read_pzx_loop

_read_pzx_loop_end:

	ld a, 6
	out (254), a

	ld l, 0
					; Add full stop mark to the tape
	ld b, 5

_read_pzx_stop:

	push bc
	call _writesram
	;call _incaddrsram
	pop bc
	djnz _read_pzx_stop

	ld bc, ZX_UNO_REGISTER_PORT
	ld a, SCANDBLCTRL_REGISTER
	out (c), a

	ld a, (_scandblctrl)		; restore _scandblctrl
	ld bc, ZX_UNO_DATA_PORT
	out (c), a

	ret


_blockcmp:

					; hl source string
					; de dest string
					; b length to compare
					;
					; returns z set if all characters matched

	ld hl, _buffer
	ld b, PZX_BLOCK_SIZE

_blockcmp_loop:

	ld a, (de)
	cp (hl)
	jr nz, _blockcmp_done

	inc de
	inc hl

	djnz _blockcmp_loop

_blockcmp_done:

	ld a, b
	and a
	ret



_read_block_tag:

	ld hl, _buffer
	ld bc, PZX_BLOCK_TAG_SIZE
	call _read

	ret

;WORD read (BYTE handle, BYTE *buffer, WORD nbytes)
;{
;    __asm
;    push bc
;    push de
;    ld a,4(ix)  ;File handle in A
;    ld l,5(ix)  ;Buffer address
;    ld h,6(ix)  ;in HL
;    ld c,7(ix)
;    ld b,8(ix)  ;Buffer length in BC
;    rst #8
;    .db #F_READ
;    jr nc,read_ok
;    ld (#_errno),a
;    ld bc,#65535
;read_ok:
;    ld h,b
;    ld l,c
;    pop de
;    pop bc
;    __endasm;
;}
;

_read:

					; hl buffer
					; bc length
	ld a, (_plugin_file_handle)

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

					; bc bytes read
	ret


;WORD readword (BYTE handle)
;{
;    WORD res;
;    read (handle, &res, 2);
;    return res;
;}
;

_readword:

	ld hl, _result
	ld bc, 2
	call _read

	ret

;void skipblock (BYTE handle, WORD hiskip, WORD loskip)
;{
;    seek (handle, hiskip, loskip, SEEK_CUR);
;}
;

;void seek (BYTE handle, WORD hioff, WORD looff, BYTE from)
;{
;    __asm
;    push bc
;    push de
;    ld a,4(ix)  ;File handle in A
;    ld c,5(ix)  ;Hiword of offset in BC
;    ld b,6(ix)
;    ld e,7(ix)  ;Loword of offset in DE
;    ld d,8(ix)
;    ld l,9(ix)  ;From where: 0: start, 1:forward current pos, 2: backwards current pos
;    rst #8
;    .db #F_SEEK
;    pop de
;    pop bc
;    __endasm;
;}
;

_skip_block:

					; bc high word offset
					; de low word offset

	ld l, ESXDOS_SEEK_FWD

	ld a, (_plugin_file_handle)

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_SEEK

	ret

;void copyblock (BYTE handle, WORD hicopy, WORD locopy)
;{
;    //print16bhex(hicopy);
;    //print16bhex(locopy); puts("\xd");
;    while (hicopy!=0 || locopy>=BUFSIZE)
;    {
;        read (handle, buffer, BUFSIZE);
;        copysram (buffer, BUFSIZE);
;        if ((locopy-BUFSIZE)>locopy)
;           hicopy--;
;        locopy -= BUFSIZE;
;        //print16bhex(hicopy);
;        //print16bhex(locopy);  puts("\xd");
;    }
;    if (locopy>0)
;    {
;        //print16bhex(hicopy);
;        //print16bhex(locopy);  puts("\xd");
;        read (handle, buffer, locopy);
;        copysram (buffer, locopy);
;    }
;}

_copyblock:

					; hl high word
					; de low word

_copyblock_loop:

	ld a, h				; $81fc
	or l
	and a

	jr nz, _copyblock_skip_high

	push hl
	or a

	ld bc, BUFFER_SIZE		; check POK file is less than MAX_SIZE
	ld h, d
	ld l, e

	sbc hl, bc

	pop hl
	jr c, _copyblock_low


_copyblock_skip_high:

	push hl
	push de

	ld hl, _buffer
	ld bc, BUFFER_SIZE

	call _read

	ld hl, _buffer
	ld bc, BUFFER_SIZE

	call _copysram

	pop de
	pop hl

	push hl				; $8252
	ld h, d
	ld l, e
	ld bc, BUFFER_SIZE
	or a
	sbc hl, bc			; locopy-BUFSIZE
	ld b, d
	ld c, e
	or a
	sbc hl, bc			; >locopy
	pop hl
	jr c, _copyblock_sub_low

;        if ((locopy-BUFSIZE)>locopy)
;           hicopy--;

	dec hl

_copyblock_sub_low:

	push hl				; locopy -= BUFSIZE;
	ld h, d
	ld l, e
	ld bc, BUFFER_SIZE
	or a
	sbc hl, bc
	ex de, hl
	pop hl

	jr _copyblock_loop

_copyblock_low:

	ld a, d
	or e
	and a
	ret z

	ld hl, _buffer
	ld b, d
	ld c, e

	push hl
	push bc

	call _read

	pop bc
	pop hl

	call _copysram

	ret

;void convertpaus2puls (BYTE handle)
;{
;    BYTE pausa[10] = {0x6,0,0,0,0x1,0x80,0,0,0,0};
;
;    writesram(0x2);
;    incaddrsram();
;    read (handle, buffer, 4);
;    pausa[6] = buffer[2];
;    pausa[7] = buffer[3] | 0x80;
;    pausa[8] = buffer[0];
;    pausa[9] = buffer[1];
;    copysram (pausa,10);
;}

_convertpaus2puls:

	ld l, 2
	call _writesram
	;call _incaddrsram

	ld hl, _buffer
	ld bc, 4
	call _read

	ld hl, _buffer
	ld a, (hl)
	ld (_pause + 8), a
	inc hl

	ld a, (hl)
	ld (_pause + 9), a
	inc hl

	ld a, (hl)
	ld (_pause + 6), a
	inc hl

	ld a, (hl)
	or $80
	ld (_pause + 7), a

	ld hl, _pause
	ld bc, PAUSE_SIZE

	call _copysram

	ret


;void rewindsram (void)
;{
;    ZXUNOADDR = SRAMADDR;
;    ZXUNODATA = 0;
;    ZXUNODATA = 0;
;    ZXUNODATA = 0;
;}

_rewindsram:

	ld a, SRAMADDR
	ld bc, ZX_UNO_REGISTER_PORT
	out (c), a

	xor a
	ld bc, ZX_UNO_DATA_PORT
	out (c), a

	ld bc, ZX_UNO_DATA_PORT
	out (c), a

	ld bc, ZX_UNO_DATA_PORT
	out (c), a

	ret

;void writesram (BYTE v)
;{
;    ZXUNOADDR = SRAMDATA;
;    ZXUNODATA = v;
;}

_writesram:

					; l is byte to write

	ld a, SRAMDATA
	ld bc, ZX_UNO_REGISTER_PORT
	out (c), a

	ld a, l 
	ld bc, ZX_UNO_DATA_PORT
	out (c), a

;	ret

;void incaddrsram (void)
;{
;    ZXUNOADDR = SRAMADDRINC;
;    ZXUNODATA = 0;
;}

;_incaddrsram:

	ld a, SRAMADDRINC
	ld bc, ZX_UNO_REGISTER_PORT
	out (c), a

	xor a
	ld bc, ZX_UNO_DATA_PORT
	out (c), a

	ret

;void copysram (BYTE *p, WORD l)
;{
;    while (l--)
;    {
;        ZXUNOADDR = SRAMDATA;
;        ZXUNODATA = *p++;
;        ZXUNOADDR = SRAMADDRINC;
;        ZXUNODATA = 0;
;    }
;}

_copysram:

					; bc length
					; hl byte pointer

	ld d, b
	ld e, c

_copysram_loop:

	ld a, d
	or e
	and a
	ret z

	;push bc

					; ZXUNOADDR = SRAMDATA;
	ld a, SRAMDATA
	ld bc, ZX_UNO_REGISTER_PORT
	out (c), a
					; ZXUNODATA = *p++;
	ld a, (hl)

;IFDEF DEBUG_PZX
;	push hl
;	ld hl, (_screen_buffer)
;	ld (hl), a
;	inc hl
;	ld (_screen_buffer), hl
;	pop hl
;ENDIF

	ld bc, ZX_UNO_DATA_PORT
	out (c), a
	inc hl
	
	and 7
	out (254), a

					; ZXUNOADDR = SRAMADDRINC;
					; ZXUNODATA = 0;
	ld a, SRAMADDRINC
	ld bc, ZX_UNO_REGISTER_PORT
	out (c), a

	xor a
	ld bc, ZX_UNO_DATA_PORT
	out (c), a


	;pop bc

	dec de
	jr _copysram_loop


_zx_uno_test:

	ld bc, ZX_UNO_REGISTER_PORT
	ld a, COREID_REGISTER
	out (c), a

	ld e, 0

_zx_uno_test_get_char:

	ld bc, ZX_UNO_DATA_PORT
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


IFDEF DEBUG_PZX

_hl_high:

	defw 0

_de_low:

	defw 0

_pulse_count:

	defb 0

_data_count:

	defb 0

_pause_count:

	defb 0

_stop_count:

	defb 0

_browse_count:

	defb 0

_other_count:

	defb 0

_screen_buffer:

	defw 0

ENDIF

_scandblctrl:

	defb 0

_plugin_file_handle:

	defb 0

_plugin_autostart:

	defb 1

_result:

	defw 0

_pause:

	defb $6
	defb $0
	defb $0
	defb $0
	defb $1
	defb $80
	defb $0
	defb $0
	defb $0
	defb $0

_pzx_header_block:

	defb "PZXT"

_pzx_pulse_block:

	defb "PULS"

_pzx_data_block:

	defb "DATA"

_pzx_pause_block:

	defb "PAUS"

_pzx_stop_block:

	defb "STOP"

_pzx_browse_block:

	defb "BRWS"

_txt_pzx_loaded:

	defb "PZX file loaded.", $0

_err_not_pzx:

	defb "Invalid file type!", $0

_err_io:

	defb "IO error!", $0

_err_uno:

	defb "This plugin requires a ZX-UNO!", $0

_err_file:

	defb "Couldn't open file!", $0

_buffer:

	defs(BUFFER_SIZE)
