
include "plugin.asm"
include "../esxdos.asm"
include "mym_player_inc.asm"

DEFC SONG_BUFFER=40960
DEFC uncomp=24576				; (14 * 3 * 128 = 5376) bytes
DEFC rows=uncomp+(3*FRAG*REGS)			; 29952

; 65024 - 65535 is used for the IM2 table (fd fd fd ...)
; 63750 - player code
; 63678 - 63742 - stack
;
; current file limit is 33726 bytes (63678 - 29952)

	org MYM_PLAYER_ORG

_plugin_user_data:

	defs(PLUGIN_SETTING_MAX)		; reserve space for settings copy


	ld (_plugin_done_sp + 1), sp
	ld (_plugin_error_sp + 1), sp
	ld sp, MYM_PLAYER_SP

	inc bc
	ld a, (bc)			; are we running from NMI?
	and a

	ld a, 2

	jr z, _plugin_not_nmi
	xor a

_plugin_not_nmi:

	ld (_plugin_esxdos_page_restore + 1), a
	ld (_plugin_esxdos_page_restore2 + 1), a

	xor a
	ld (_plugin_file_handle), a

	ld a, ESXDOS_CURRENT_DRIVE	; *
	ld b, ESXDOS_MODE_READ

	rst ESXDOS_SYS_CALL		; open file
	defb ESXDOS_SYS_F_OPEN

	jr nc, _plugin_stat

	ld bc, _err_file
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error_ret

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

	ld hl, MYM_PLAYER_RAMTOP	; work out the free memory available
	ld bc, rows
	or a
	sbc hl, bc
	ld b, h				; put result into bc
	ld c, l

	ld hl, (_plugin_file_stat + 7)	; put 16 bit file size into hl
					; check if filesize HL < 16384
	push hl

	or a
	sbc hl, bc

	pop bc				; pop hl size into bc

	jr c, _plugin_read

	ld bc, _err_memory
	ld a, PLUGIN_ERROR
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_read:

	push bc

					; want to use 40960 as 8k scratch
	ld a, MMC_MEMORY_PLUGIN_PAGE2 + 128
	out (MMC_MEMORY_PORT), a

	ld hl, SONG_BUFFER		; backup existing memory at 40960
	ld bc, DIV_MMC_BANK_SIZE
	ld de, 8192

	ldir

					; want to use 24576 as 8k scratch
	ld a, MMC_MEMORY_PLUGIN_PAGE3 + 128
	out (MMC_MEMORY_PORT), a

	ld hl, uncomp
	ld bc, DIV_MMC_BANK_SIZE
	ld de, 8192

	ldir

_plugin_esxdos_page_restore:

	ld a, 0
	add a, 128
	out (MMC_MEMORY_PORT), a

	pop bc

	ld a, (_plugin_file_handle)	; read file to buffer
	ld hl, rows

	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_READ

	jr nc, _plugin_main

	call _plugin_bank_restore

	ld bc, _err_io
	ld a, PLUGIN_ERROR|PLUGIN_RESTORE_BUFFERS
	ld (_plugin_error_ret + 1), a
	jp _plugin_error

_plugin_main:

	ld hl, _plugin_status_playing
	call _set_status_icon

	push ix
	push iy

	exx				; Starting values for procedure readbits
	ld de, 1
	;ld d, 0
	;ld e, 1
	ld hl, rows + 2
	exx

	ld hl,uncomp + FRAG		; Starting values for the playing variables
	ld (dest1), hl
	ld (dest2), hl
	ld (psource), hl
	ld a, FRAG
	ld (played), a
	ld hl, 0
	ld (prows), hl

	call extract			; Unpack the first fragment

	call setint			; Set up the interrupts

_plugin_loop:

	call extract

_plugin_wait:

	xor a
	in a, (254)
	cpl
	and $1f
	jr nz, _plugin_key_check

_plugin_wait_ret:

	ld a, (played)			; Wait until VBI has played a fragment
	or a
	jr nz, _plugin_wait

	ld (psource), iy
	ld a, FRAG
	ld (played), a

	jr _plugin_loop

;	jr      z, update
;	and 1
;	jr z, waitvb
;
;	call keypress
;	jr nz, _plugin_done
;	jr waitvb



;update:
;	ld      (psource),iy
;        ld      a,FRAG
;        ld      (played),a
;        ;call    keypress
        ;jr      z, _plugin_loop

_plugin_key_check:

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
	jr nz, _plugin_wait_ret

	call _plugin_shift_pressed
	ld a, l
	and SHIFT_CAPS			; shift + space, so return

	jr z, _plugin_wait_ret

	ld a, PLUGIN_OK|PLUGIN_RESTORE_BUFFERS
	ld hl, 0

_plugin_done:

	push bc				; save navigation
	push af				; save return code

	call _set_status_icon

	call shutint
	call shutup

	call _plugin_bank_restore

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop af				; restore return code
	pop bc				; restore navigation

	pop iy
	pop ix

_plugin_done_sp:

	ld sp, 00000

	ret


_plugin_error:

	push bc

	ld a, (_plugin_file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	pop bc


_plugin_error_sp:

	ld sp, 00000

_plugin_error_ret:

	ld a, 0
	ret


_plugin_bank_restore:

					; restore the memory we used for the song
					; buffer 
	ld a, MMC_MEMORY_PLUGIN_PAGE2 + 128
	out (MMC_MEMORY_PORT), a

	ld de, SONG_BUFFER
	ld bc, DIV_MMC_BANK_SIZE
	ld hl, 8192

	ldir

	ld a, MMC_MEMORY_PLUGIN_PAGE3 + 128
	out (MMC_MEMORY_PORT), a

	ld de, uncomp
	ld bc, DIV_MMC_BANK_SIZE
	ld hl, 8192

	ldir

_plugin_esxdos_page_restore2:

	ld a, 0				; 0 -nmi, 2 - .dot
	add a, 128
	out (MMC_MEMORY_PORT), a

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

_err_memory:

	defb "Out of memory!", $0

_err_io:

	defb "IO error!", $0

_err_file:

	defb "Couldn't open file!", $0

;_err_invalid:
;
;	defb "Not a valid .STC file!", $0


; MYMPLAY - Player for MYM-tunes
; MSX-version by Marq/Lieves!Tuore & Fit 30.1.2000
;
; 1.2.2000  - Added the disk loader. Thanks to Yzi & Plaque for examples.
;
; Source suitable for Table-driven assembler (TASM), sorry all
; Devpac freaks v/
;
;
; 2/2/2000 - Zack <dom@jb.man.ac.uk>
;
;       ZX Spectrum + AY Port
;       Converted over to z80asm format cos za80 was being awkward
;
; Notes:
;       ZX Version uses im2 (can't capture unlike on MSX)
;       AY Ports on ZX are $BFFD - port select
;                          $FFFD - data write
;
;       Tune length is limited to ~26350 bytes (Not sure if we'd be 
;       affected by contention if we locate at 24576 - working on emu!)
;       If not affected than can have ~34540 bytes
;
; 7/2/2000 - Zack <dom@jb.man.ac.uk>
;       ZX Port of MSX v0.4


DEFC FRAG = 128     ; Fragment size
DEFC REGS = 14      ; Number of PSG registers
DEFC FBITS = 7       ; Bits needed to store fragment offset
DEFC table = 65024    ; Where we put our im2 int table
DEFC intjp = 65021    ; Ye olde im2 jump
;DEFC rows=49152


; *** Unpack a fragment. Returns IY=new playing position for VBI
extract:
        xor     a
regloop:
        push    af
        ld      c,a
        ld      b,0
        ld      hl,regbits      ; D=Bits in this PSG register
        add     hl,bc
        ld      d,(hl)
        ld      hl,current      ; E=Current value of a PSG register
        add     hl,bc
        ld      e,(hl)

        ld      bc,FRAG*3       ; v0.4
        ld      hl,(dest1)      ; IX=Destination 1
        ld      ix,(dest1)
        add     hl,bc
        ld      (dest1),hl
        ld      hl,(dest2)      ; HL=Destination 2
        push    hl
        add     hl,bc
        ld      (dest2),hl
        pop     hl

        ex      af,af'
        ld      a,FRAG          ; AF'=fragment end counter
        ex      af,af'
        ld      a,1             ; Get fragment bit
        call    readbits
        or      a
        jr      nz,compfrag     ; 1=Compressed fragment, 0=Unchanged

        ld      b,FRAG          ; Unchanged fragment just set all to E
sweep:
	ld      (hl),e
        inc     hl
        ld      (ix+0),e
        inc     ix
        djnz    sweep
        jp      nextreg

compfrag:
				; Compressed fragment
        ld      a,1
        call    readbits
        or      a
        jr      nz,notprev      ; 0=Previous register value, 1=raw/compressed

        ld      (hl),e          ; Unchanged register
        inc     hl
        ld      (ix+0),e
        inc     ix
        ex      af,af'
        dec     a
        ex      af,af'
        jp      nextbit

notprev:
        ld      a,1
        call    readbits
        or      a
        jr      z,packed        ; 0=compressed data  1=raw data

        ld      a,d             ; Raw data, read regbits[i] bits
        call    readbits
        ld      e,a
        ld      (hl),a
        inc     hl
        ld      (ix+0),a
        inc     ix
        ex      af,af'
        dec     a
        ex      af,af'
        jp      nextbit

packed:
	ld      a,FBITS         ; Reference to previous data
        call    readbits        ; Read the offset
        ld      c,a
        ld      a,FBITS         ; Read the number of bytes
        call    readbits
        ld      b,a

        push    hl
        push    bc
        ld      bc,-FRAG
        add     hl,bc
        pop     bc
        ld      a,b
        ld      b,0
        add     hl,bc
        ld      b,a
        push    hl
        pop     iy              ; IY=source address
        pop     hl

        inc     b
copy:
	ld      a,(iy+0)          ; Copy from previous data 
        inc     iy
        ld      e,a             ; Set current value
        ld      (hl),a
        inc     hl
        ld      (ix+0),a
        inc     ix
        ex      af,af'
        dec     a
        ex      af,af'
        djnz    copy

nextbit:
        ex      af,af'          ; If AF'=0 then fragment is done
        ld      c,a
        ex      af,af'
        ld      a,c
        or      a
        jp      nz,compfrag

nextreg:
        pop     af
        ld      b,0             ; Save the current value of PSG reg
        ld      c,a
        push    hl
        ld      hl,current
        add     hl,bc
        ld      (hl),e
        pop     hl

        inc     a               ; Check if all registers are done
        cp      REGS
        jp      nz,regloop

        or      a               ; Check if dest2 must be wrapped
        ld      bc,rows
        sbc     hl,bc
        jr      nz,nowrap

        ld      ix,uncomp+FRAG
        ld      hl,uncomp+FRAG
        ld      iy,uncomp+(2*FRAG)
        jr      endext

nowrap:
	ld      ix,uncomp
        ld      hl,uncomp+(2*FRAG)
        ld      iy,uncomp+FRAG

endext:
	ld      (dest1),ix
        ld      (dest2),hl

        ld      bc,FRAG
        ld      hl,(prows)
        add     hl,bc
        ld      (prows),hl
        ld      bc,(rows)
        or      a
        sbc     hl,bc
        jr      c,noend         ; If rows>played rows then exit
        exx                     ; Otherwise restart
        ld      e,1
        ld      d,0
        ld      hl,rows+2
        exx
        ld      hl,0
        ld      (prows),hl

noend:
	ret

; *** Reads A bits from data, returns bits in A
readbits:
        exx
        ld      b,a
        ld      c,0

onebit:
	sla     c               ; Get one bit at a time
        rrc     e
        jr      nc,nonew        ; Wrap the AND value
        ld      d,(hl)
        inc     hl

nonew:
	ld      a,e
        and     d
        jr      z,zero
        inc     c
zero:
	djnz    onebit

        ld      a,c
        exx
        ret

; *** The interrupt handler. Partially MSX specific
interrupt:
	push    af
        push    bc
        push    de
        push    hl


        ld      hl,(psource)
        ld      de,-1+(3*FRAG)   ; Bytes to skip before next reg-1
        xor     a
        ld      c,253
ploop:
	ld      b,255
        out     (c),a
        ld      b,191
        outi
        inc     a
        add     hl,de
        cp      REGS-1
        jp      nz,ploop

        ld      a,(hl)
        inc     a       ;if reg 13=255 skip
        jr      z,notrig
        ld      a,13
        ld      bc,65533
        out     (c),a
        ld      b,191
        outi

notrig:
	ld      hl,(psource)
        inc     hl
        ld      (psource),hl

        ld      a,(played)
        or      a
        jr      z,endint
        dec     a
        ld      (played),a

endint:
	pop     hl
        pop     de
        pop     bc
        pop     af
        ei
        ret

_i_store:

	defb 0

;
; Sets up the im2 table and switches mode
;
.setint
        di
        ld      hl,table
        ld      de,table+1
        ld      bc,256
        ld      (hl),253
        ldir
	ld a, i
	ld (_i_store), a

        ld      a,195
        ld      (intjp),a
        ld      hl,interrupt
        ld      (intjp+1),hl
        ld      a,254
        ld      i,a
        im      2
        ei
        ret

;
; Turn off the interrupts, go back to im 1 (default for ZX)
; Restore hl' so BASIC stays sane
;

.shutint
        di
        ld      a, (_i_store)
        ld      i,a
        im      1
        ld      hl,10072
        exx
        ret




; *** Returns Z=1 if key pressed. ZX-specific
keypress:
        xor     a
        in      a,(254)
        cpl
        and     31
        ret

; *** Shuts down the audio. ZX-Specifc
shutup:
        ld      e,14
        xor     a
        ld      c,253
        ld      d,0
shloop:
        ld      b,253
        out     (c),a
        inc     a
        ld      b,191
        out     (c),d
        dec     e
        jr      nz,shloop
        ret

; *** Program data
played:
	defb     0       ; VBI counter
dest1:
	defw     0       ; Uncompress destination 1
dest2:
	defw     0       ; - " -                  2
psource:
	defw    0       ; Playing offset for the VB-player
prows:
	defw     0       ; Rows played so far

; Bits per PSG register
regbits:
	defb    8,4,8,4,8,4,5,8,5,5,5,8,8,8
; Current values of PSG registers
current:
	defb    0,0,0,0,0,0,0,0,0,0,0,0,0,0



;; Reserve room for uncompressed data 
;uncomp:
;        defs    (3*FRAG*REGS)
;; Tune is loaded to this address
;rows:


