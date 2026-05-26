; 25600 - $6400

include "../esxdos.asm"
include "plugin.asm"

;=========================================================
	ORG	$6400

buff	EQU	$e000
hdr	EQU	$BD00

	ld a, 0				; esxdos file handle	00 01
	ld (file_handle), a		;			02 03 04
	ld a, 0				; previous ram bank	05 06
	ld (_plugin_esxdos_bank_restore + 1), a		;	07 08 09
	ld a, 0						;	10 11
	ld (_plugin_esxdos_page_restore + 1), a

	ld (_ix_restore + 2), ix
	ld (_sp_restore + 1), sp

;------------------------------------------ задание стека, страниц
	ld	sp, $6400
	ld	bc, $7ffd
	ld	a, $17
	out	(c), a
;------------------------------------------ очистка атрибутов экранов
	ld	hl, $5800
	ld	de, $5801
	ld	bc, 767
	ld	(hl), l
	ldir
	ld	hl, $d800
	ld	de, $d801
	ld	bc, 767
	ld	(hl), l
	ldir
;//------------------------------------------ Подгрузка заголовка


	ld hl, hdr
	ld bc, 256

	ld a, (file_handle)

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

;	LD	HL, HDR
;	LD	DE, (23796)
;	LD	BC, $0105
;	CALL	#3D13

	ld hl, $4000
	ld bc, 6144

	ld a, (file_handle)

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

;//------------------------------------------ Подгрузка экранов
;	LD	HL,#4000	//6144
;	LD	DE,(23796)
;	LD	BC,#1805
;	CALL	#3D13

	ld hl, $c000
	ld bc, 6144

	ld a, (file_handle)

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

;	LD	HL,#C000	//6144
;	LD	DE,(23796)
;	LD	BC,#1805
;	CALL	#3D13

	ld hl, buff
	ld bc, 3072

	ld a, (file_handle)

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

;	LD	HL,BUFF		//3072
;	LD	DE,(23796)
;	LD	BC,#0C05
;	CALL	#3D13

	call calca0


	ld hl, buff
	ld bc, 3072

	ld a, (file_handle)

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

;	LD	HL,BUFF		//3072
;	LD	DE,(23796)
;	LD	BC,#0C05
;	CALL	#3D13

	call calca1


	ld hl, buff
	ld bc, 768

	ld a, (file_handle)

	rst ESXDOS_SYS_CALL		; read file
	defb ESXDOS_SYS_F_READ

;	LD	HL, BUFF
;	LD	DE,(23796)
;	LD	BC,#0305	//768
;	CALL	#3D13

close_file:
	ld a, (file_handle)
	rst ESXDOS_SYS_CALL
	defb ESXDOS_SYS_F_CLOSE

	call out8x8
	ld bc ,$7FFD
	ld a, $17
	out (c), a

;//------------------------ Установка режима прерываний
	di
	
	ld a, i
	ld (_i_restore + 1), a	
	
	ld a, $be
	ld i, a
	im 2
	ld hl, $be00
	ld b, 0
ll1:
	ld (hl), $bf
	inc hl
	djnz ll1
	ld (hl), $bf
	ld hl, $bfbf
	ld (hl), $c9
;//------------------------
mainlp:
	ei
	halt
	ld a, (hdr + 5)
	out ($fe), a
	call pause	;17
	call attr0	;17
	ei
	halt
	ld a, (hdr + 6)
	out ($fe), a
	call pause
	call attr1
	
	xor a
	in a, (254)
	cpl
	and $1f

	jr z, mainlp

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


file_handle:
	defb 0

;//------------------------
pause:
	ld bc, $7ffd	;10
	ld a, $1f		;7
page 	equ $-1		;
	xor %00001000	;7
	ld (page), a	;13 //37
	out (c), a		;12
	;//--------------
	ld bc, 735		;10 //745
pause0:
	dec bc		;6
	ld a,b		;4
	or c		;4
	jp nz,pause0	;10 //24 - 17898+?/24

	;//18
	nop
	nop
	nop
	nop
	nop
	ret			;10

;//------------------------
out8x8:
	ld hl, buff
	ld de, $5800
	ld a,24
	call out1
	ld de, $d800
	ld a, 24
out1:	;//--------------
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ex de, hl
	ld bc, 16
	add hl, bc
	ex de, hl
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	dec a
	jp nz, out1
	ret

;//------------------------
;//	!DUP	8
;//	LD	HL,data		;#21 #00 #00	/10
;//	LD	(scr),HL	;#22 #00 #00	/16 // итого 26 на два знакоместа
;//	!EDUP			// 26*8=208 -> FREE16
;//	NOP
;//	NOP
;//	NOP
;//	NOP

calca0:
	ld hl, attr0
	ld de, $5808
	jp ca2
calca1:
	ld hl, attr1
	ld de, $d808
ca2:
	ld ix, buff
	ld a, 24
ca3:
	ex af, af
	ld c, 8
ca1:
	ld b, 8
	push de
ca0:
	ld (hl), $21
	inc hl
	ld a, (ix)
	ld (hl), a
	inc hl
	inc ix
	ld a, (ix)
	ld (hl), a
	inc hl
	inc ix
	ld (hl), $22
	inc hl
	ld (hl), e
	inc hl
	ld (hl), d
	inc hl
	inc de
	inc de
	djnz ca0
	ld (hl), $00
	inc hl
	ld (hl), $00
	inc hl
	ld (hl), $00
	inc hl
	ld (hl), $00
	inc hl
	pop de
	dec c
	jp nz, ca1
	push hl
	ld hl, 32
	add hl, de
	ex de, hl
	pop hl
	ex af, af
	dec a
	jp nz, ca3
	ld (hl), $c9
	ret


attr0	EQU	$
attr1	EQU	$+9985

