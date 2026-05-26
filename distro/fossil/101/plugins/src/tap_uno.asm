
DEFC ZX_UNO_REGISTER_PORT=64571
DEFC ZX_UNO_DATA_PORT=64827
DEFC COREID_REGISTER=$ff

DEFC SCANDBLCTRL_REGISTER=$0b
DEFC SRAMADDR=$f0
DEFC SRAMADDRINC=$f1
DEFC SRAMDATA=$f2

DEFC BUFFER_SIZE=2048

_realtime_tap_uno:

					; hl is .tap filename

	ld bc, $fefe
	in a, (c)
	and %00000001			; shift pressed?
	ld (_tap_autostart), a

	ld a, ESXDOS_CURRENT_DRIVE	; *

	ld b, ESXDOS_MODE_READ

	rst ESXDOS_SYS_CALL		; open file for reading
	defb ESXDOS_SYS_F_OPEN

	jr nc, _realtime_tap_uno_read_ok

	ld bc, _err_file
	ld a, PLUGIN_ERROR
	ret

_realtime_tap_uno_read_ok:

	ld (_tap_file_handle), a

	call _realtime_tap_read

	ld a, (_tap_autostart)
	or a
	jr nz, _realtime_tap_uno_read_autostart

	ld bc, _txt_tap_loaded
	ld a, PLUGIN_OK|PLUGIN_STATUS_MESSAGE
	ret
					; software assisted PLAY press

_realtime_tap_uno_read_autostart:

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


_realtime_tap_read:

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

_realtime_tap_read_loop:

					; tam = readword (handle); if (!leido) break;
					; flag = readbyte (handle); if (!leido) break;
					; puts ("P");

	ld hl, _tam
	call _readword

	jp c, _realtime_tap_read_loop_end
	ld a, b
	or c
	jp z, _realtime_tap_read_loop_end

	ld hl, _flag
	call _readbyte

	jp c, _realtime_tap_read_loop_end
	ld a, b
	or c
	jp z, _realtime_tap_read_loop_end

					; if (flag < 128)
					;   copysram (pulsh, sizeof pulsh);
					; else
					;   copysram (pulsd, sizeof pulsd);

	ld a, (_flag)
	cp 128
	jr nc, _realtime_tap_read_copy_pulsd

	ld hl, _pulsh
	ld de, PULSH_LENGTH
	jr _realtime_tap_read_copy

_realtime_tap_read_copy_pulsd:

	ld hl, _pulsd
	ld de, PULSD_LENGTH

_realtime_tap_read_copy:

	call _copysram

					; puts ("D");
					; tam += 16;

	ld hl, (_tam)
	push hl

	ld b, h
	ld c, l

	ld de, 16
	add hl, de

					; //puts("\xd");print16bhex (tam); puts("\xd");
					; data[1] = tam & 0xFF;
					; data[2] = (tam>>8) & 0xFF;

	ld a, l
	ld (_data + 1), a
	ld a, h
	ld (_data + 2), a

;					; tam -= 16;
;					; tamb = tam;

	ld h, b
	ld l, c
	ld de, 0
;					; tamb = tamb * 8;

	ld b, 3

_realtime_tap_read_mult:

	sla e
	sla h
	jr nc, _realtime_tap_read_mult_no_carry_h

	set 0, e

_realtime_tap_read_mult_no_carry_h:

	sla l
	jr nc, _realtime_tap_read_mult_no_carry_l
	set 0, h

_realtime_tap_read_mult_no_carry_l:

	djnz _realtime_tap_read_mult

					; de hl = tamb * 8

					; data[5] = tamb & 0xFF;
					; data[6] = (tamb>>8) & 0xFF;
					; data[7] = (tamb>>16) & 0xFF;
					; data[8] = 0x80 | ((tamb>>24) & 0xFF);
					;
					; copysram (data, sizeof data);

	ld a, l
	ld (_data + 5), a
	ld a, h
	ld (_data + 6), a
	ld a, e
	ld (_data + 7), a
	ld a, d
	or $80
	ld (_data + 8), a

	ld hl, _data
	ld de, DATA_LENGTH
	call _copysram

					; writesram (flag);
					; incaddrsram();
	ld a, (_flag)
	ld l, a
	call _writesram

					; tam--;
					; copyblock (handle, 0, tam); if (!leido) break;

					; restore tam
	pop hl
	dec hl
	ld (_tam), hl

	ld de, 0
	ex de, hl
					; hi = 0, lo = _tam
	call _copyblock

	ld a, (_plugin_cfg_flags)
	and SETTING_REALTIME_TAPE_PAUSES
	jp z, _realtime_tap_read_loop

					;   if (nopausa == 0)
					;   {
					;     puts ("A");
					;     copysram (pausa, sizeof pausa);
					;   }
					; }

	ld hl, _pause
	ld de, PAUSE_LENGTH
	call _copysram

	jp _realtime_tap_read_loop

					; // pequeña pausa de 20ms para evitar errores de carga
					; // a causa de la conmutación brusca de la señal de EAR
					; // del player virtual a la entrada real
					;
					; // Add full stop mark to the tape
					; copysram (fullstop, sizeof fullstop);

_realtime_tap_read_loop_end:

	ld hl, _fullstop
	ld de, FULLSTOP_LENGTH
	call _copysram


	ld bc, ZX_UNO_REGISTER_PORT
	ld a, SCANDBLCTRL_REGISTER
	out (c), a

					; restore _scandblctrl
	ld a, (_scandblctrl)
	ld bc, ZX_UNO_DATA_PORT
	out (c), a

					; close .tap file handle
	ld a, (_tap_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	ret


; ----------------------

_read:

					; hl buffer
					; bc length
	ld a, (_tap_file_handle)

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

					; hl is word buffer
	ld bc, 2
	call _read

	ret


_readbyte:

					; hl is byte buffer
	ld bc, 1
	call _read

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


_copysram:

					; de length
					; hl byte pointer

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


_plugin_uno_ok:

	ld bc, ZX_UNO_REGISTER_PORT
	ld a, COREID_REGISTER
	out (c), a

	ld e, 0

_plugin_uno_ok_get_char:

	ld bc, ZX_UNO_DATA_PORT
	in a, (c)			; a is now COREID

	and a				; test for 0
	jr z, _plugin_uno_ok_end

	cp 32
	jr c, _plugin_uno_ok_end		; < 32
	cp 128
	jr nc, _plugin_uno_ok_end		; >= 128

	inc e
	jr _plugin_uno_ok_get_char

_plugin_uno_ok_end:

	ld a, e				; ZX-UNO returns version string, e.g.
					; 'EXP27-300320'
	cp 2				; 'a' will be 1 if TR_DOS is paged in, so test
					; for at least 2 characters.
	ret

_err_uno:

	defb "This setting requires a ZX-UNO!", $0

_err_file:

	defb "Couldn't open file!", $0

_txt_tap_loaded:

	defb "TAP file loaded.", $0

_scandblctrl:

	defb 0

_tap_file_handle:

	defb 0

_tap_autostart:

	defb 0

_tam:

	defw 0

_flag:

	defb 0

DEFC PULSH_LENGTH = 13
DEFC PULSD_LENGTH = 13
DEFC FULLSTOP_LENGTH = 5
DEFC DATA_LENGTH = 21
DEFC PAUSE_LENGTH = 11

_pulsh:

					; BYTE pulsh[] = {0x02,0x08,0x00,0x00,0x00,0x7f,0x9f,0x78,0x08,0x9b,0x02,0xdf,0x02};

	defb 0x02, 0x08, 0x00, 0x00, 0x00, 0x7f, 0x9f, 0x78, 0x08, 0x9b, 0x02, 0xdf, 0x02

_pulsd:

					; BYTE pulsd[] = {0x02,0x08,0x00,0x00,0x00,0x97,0x8c,0x78,0x08,0x9b,0x02,0xdf,0x02};

	defb 0x02, 0x08, 0x00, 0x00, 0x00, 0x97, 0x8c, 0x78, 0x08, 0x9b, 0x02, 0xdf, 0x02

_data:

					; BYTE data[] = {0x03,0x00,0x00,0x00,0x00,0x98,0x00,0x00,0x80,0xB1,0x03,0x02,0x02, 0x57,0x03,0x57,0x03,0xAE,0x06,0xAE,0x06};

	defb 0x03, 0x00, 0x00, 0x00, 0x00, 0x98, 0x00, 0x00, 0x80, 0xB1, 0x03, 0x02, 0x02, 0x57, 0x03, 0x57, 0x03, 0xAE, 0x06, 0xAE, 0x06

					; BYTE pausa[] = {0x02,0x6,0,0,0,0x1,0x80,0x35,0x80,0xe0,0x67};

_pause:

	defb 0x02, 0x06, 0x00, 0x00, 0x00, 0x01, 0x80, 0x35, 0x80, 0xe0, 0x67

_fullstop:

					; BYTE fullstop[] = {0,0,0,0,0};

	defb 0, 0, 0, 0, 0

_buffer:

	defs(BUFFER_SIZE)


