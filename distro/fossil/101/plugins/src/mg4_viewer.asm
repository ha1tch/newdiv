
include "plugin.asm"
include "../esxdos.asm"

; 24576 - 32767 - plugin scratch #1
; 32768 - 40959 - 8k plugin page
; 40960 - 41951 - plugin scratch #2
; 41952 - 65535 - file restore


;multiArtistView by pulsar 07.11.10..09.04.11//process
;viewer.a80 by pulsar 10.09.09..09.04.11//process

DEFC image=$6700		; 26368

DEFC progsp=$C000

DEFC rutina1=$8000
DEFC rutina2=rutina1+$1F00

;паузы до начала экрана в тактах/24
DEFC pclassic=$23F
DEFC ppentagon=$2D3

DEFC atr1=image
DEFC atrl=32*96
DEFC atr2=atr1+atrl
DEFC atrp=atr2+atrl

DEFC fix=0 ;fix version=1, fix key 8,9
DEFC fixc=1 ;color of fix border
DEFC interlace=1 ;черездвухстрочник "on"
DEFC classic=1 ;classic=0 for no slow memory and 224t/line (pentagon)


	org $6000		; 24576

;picker_classic.a80 by pulsar 07.11.10..09.04.11//final
;classic (tap) версия

	ld a, 0
	ld (_plugin_esxdos_page_restore + 1), a
	ld a, 0
	ld (_plugin_esxdos_bank_restore + 1), a

	ei
	halt
	di

	ld hl, 49152			; move image data from 49152 to where
	ld de, image			; the viewing code expects it
	ld bc, 15616
	ldir
	
	ld (_ix_restore + 2), ix
	ld (_sp_restore + 1), sp
			
	jp _start

					;;;подпрограмки
_pause:
					;;;;пауза до начала экрана
IFNDEF classic
pau_x:
	LD BC,ppentagon;#2d4;23f;23b;2D0 
ELSE
pau_x:
	LD BC, pclassic;#23f 
ENDIF

pau_l:
	dec bc
	ld a, b
	or c
	jp nz, pau_l ;//24
	
	ld a, e
	out (254), a
	ret			


_fix:
;      IF fix
;	LD BC,(pau_x+1)
;	LD A,#EF: IN A,(-2)
;	RRCA: RRCA: JR C,fix1
;	DEC BC
;fix1	RRCA: JR C,fix2
;	INC BC
;fix2	LD (pau_x+1),BC
;	LD A,E: OUT (-2),A
;      ENDIF
	ret





_grut:
					;;;;рутинагенерилка
					;;;;in: de - адрес атриков, hl - adrrutina, bc - адрес возврата из рутины, hl' - экран
	push bc 
	exx
	ld bc, 32
	ld e, 5
	exx
	ld ixl, 96
	
grut2:
	ld bc, 31
	ex de, hl
	add hl, bc
	ex de, hl
	ld (hl), 49
	inc hl ;ld sp,0
	exx
	dec e
	jr nz, grut3
	ld e, 4
	add hl, bc
	
grut3:
	push hl
	ld a, h
	xor 128
	ld h, a
	exx
	pop bc
	ld (hl), c
	inc hl
	ld (hl), b
	inc hl ;����� ������� ���������� � ����
	ld b, 16
	
grut1:
	ld (hl), 33
	inc hl
	inc hl
	ld a, (de)
	dec de
	ld (hl), a
	dec hl	;|
	ld a, (de)
	dec de
	ld (hl), a
	inc hl
	inc hl
	ld (hl), 229
	inc hl 					;push hl
	djnz grut1

IFNDEF classic ;for clones with 224t per line and no slow memory
;	DUP 6: LD (HL),9: INC HL: EDUP 
;	LD (HL),#23: INC HL: LD (HL),0: INC HL
;	LD (HL),#23: INC HL: LD (HL),0: INC HL
ELSE ;classic
	; DUP 3: LD (HL),#00: INC HL: EDUP
	ld (hl), 35
	inc hl
ENDIF

	ld (hl), 171
	inc hl ;xor e
	ld (hl), 237
	inc hl
	ld (hl), 121
	inc hl ;out (c),a
	ld bc, 33
	ex de, hl
	add hl, bc
	ex de, hl
	dec ixl
	jp nz, grut2
	pop de
	ld (hl), 195
	inc hl
	ld (hl), e
	inc hl
	ld (hl), d ;jp {de}
	ret

_fatr:
	ld b,a
	rla			; .3
	rla
	rla
	or b
	ld d, h
	ld e, l
	ld bc, 767
	ld (hl), a
	inc de
	ldir
	ret

_mov:
	ld a, 48
lo1:
	ld bc, 32
	ldir
	ld bc, 32
	ex de, hl
	add hl,bc
	ex de, hl
	add hl, bc
	dec a
	jr nz, lo1
	ret
	
_mimg:
	ld ixl, 12
	
mimg1:
	ld bc, 512
	ldir
IFNDEF interlace ;=0
	LD A,D
	XOR $80
	LD D,A
ENDIF
	dec ixl
	jp nz, mimg1
	ret
	
;подготовка, установка прерываний
_start:
	ld sp, progsp
	di
	
	ld a, i
	ld (_i_restore + 1), a
	
	ld hl, $be00
	ld a, h
	ld i, a
	ld b, 0
	ld a, 191
_start_loop:
	ld (hl), a
	inc hl
	djnz _start_loop

	ld (hl), a
	im 2
	ld h, a
	ld l, h
	ld (hl), 201

	ld bc, 32765
	ld a, 23
	out (c), a

;For MG1,MG2,MG4,MG8 file have HEADER 256 bytes length (one sector on tr-dos disk):
;[3] - MGx_FILE_ID - Identifier for MG files = "MGH" (Milti Gigascreen ZX File Header)
;[1] - MGx_FILE_VER - MG zx file format Version
;[1] + MGS_CharSize - Size of Char[1=8x1, 2=8x2, 4=8x4, 8=8x8]
;[1]*+ ZX Color1 Border
;[1]*+ ZX Color2 Border	
;set: border, paper, ink
	ei
	halt
	ld ix, image
	ld a, (ix + 5)
	ld (b1 + 1), a
	ld hl, 22528
	out (254), a
	call _fatr
	ld a, (ix + 6)
	ld (b2 + 1), a
	ld a, (ix + 4)
	srl a
	ld ixh, a

;перекидываем данные картинки (с учетом interlace)	
	ld hl, image + $100
	ld de, 16384
	call _mimg
	ld de, 49152
	call _mimg
	
;in: hx=4,2,1 (mg8,mg4,mg2)
	ld a, 5
	sub ixh
	ld b, 48
test1:
	srl a
	jp z, teste
	rlc b
	jp test1
teste:	ld a, b
	ld de, atrp
patr2:	ld ixl, ixh
	ld (mo1+1), hl
patr1:	ld bc, 32
	ldir
	dec ixl
	jp z, patr3
mo1:	ld hl, 0
	jp patr1
patr3:	dec a
	jp nz, patr2	

IFNDEF interlace ;=0
	LD HL, atrp
	LD DE, atr1
	LD BC, atrl
	LDIR
	LD DE, atr2
	LD BC,atrl
	LDIR
ELSE ;=1	
	ld hl, atrp
	ld de, atr1
	push hl
	call _mov
	push hl
	call _mov
	pop hl
	ld de, atr1
	ld bc, 32
	ex de, hl
	add hl, bc
	ex de, hl
	add hl, bc
	call _mov
	pop hl
	ld bc, 32
	add hl,bc
	call _mov
ENDIF

	ld hl, rutina1
	ld de, atr1
	ld bc, ssp1
	exx
	ld hl, 22560
	exx
	call _grut
	ld hl, rutina2
	ld de, atr2
	ld bc, ssp2
	exx
	ld hl, 55328
	exx
	call _grut

mloop:
	ei
	halt
b1:	ld a, 0
	out (254), a
;      IF fix
;	LD E,fixc
 ;     ELSE
        ld e, a
;      ENDIF
	call _pause
	ld a, 31
	ld e, 8
	ld bc, 32765
	out (c), a
	ld (ssp1 + 1), sp
	jp rutina1
ssp1:	ld sp, 0	
	ld a, (b1 + 1)
	ld e, a
	call _fix
	ei
	halt
b2:	ld a, 0
	out (254),a
;      IF fix
;	LD E,fixc
 ;     ELSE
        ld e,a
;      ENDIF
	call _pause
	ld a, 23
	ld e, 8
	ld bc, 32765
	out (c), a
	ld (ssp2 + 1), sp
	jp rutina2
ssp2:
	ld sp, 0	
	ld a, (b2 + 1)
	ld e, a
	call _fix
	
	xor a
	in a, (254)
	cpl
	and $1f
	jr z, mloop
	
;	jp mloop

	ld hl, _reloc_exit_start
	ld de, 16384
	ld bc, _reloc_exit_end - _reloc_exit_start
	ldir
	
	jp 16384

_reloc_exit_start:
					; exit routine
	di

_i_restore:

	ld a, 0				; restore interrupts
	ld i, a
	im 1

					; 24576 - 32767 - plugin scratch #1
					; 40960 - 41951 - plugin scratch #2

	ld a, MMC_MEMORY_PLUGIN_PAGE2 + 128
	out (MMC_MEMORY_PORT), a

	ld de, 24576
	ld bc, DIV_MMC_BANK_SIZE
	ld hl, 8192

	ldir

	ld a, MMC_MEMORY_PLUGIN_PAGE3 + 128
	out (MMC_MEMORY_PORT), a

	ld de, 40960
	ld bc, DIV_MMC_BANK_SIZE
	ld hl, 8192

	ldir

_plugin_esxdos_page_restore:

	ld a, 0				; 0 -nmi, 2 - .dot
	add a, 128
	out (MMC_MEMORY_PORT), a

				; we've copied back the original stack so jump back


_plugin_esxdos_bank_restore:

	ld a, $10			; page bank 16 in
	ld bc, $7ffd
	out (c), a

	ld a, PLUGIN_OK|PLUGIN_RESTORE_SCREEN|PLUGIN_RESTORE_BUFFERS
	ld bc, 0

_sp_restore:

	ld sp, 0			; restore stack pointer

_ix_restore:

	ld ix, 0

	ret

_reloc_exit_end:
