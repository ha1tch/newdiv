
IFNDEF SHIFT_CAPS
DEFC SHIFT_CAPS=1
ENDIF

IFNDEF SHIFT_SYMBOL
DEFC SHIFT_SYMBOL=2
ENDIF

_plugin_shift_pressed:

	ld hl, 0

					; Test for Caps Shift.
	ld bc, $fefe			; (Caps Shift, Z, X, C, V)	65278
	in a, (c)
	rra

	jr c, _plugin_shift_pressed_sym	; not pressed if carry

	ld hl, SHIFT_CAPS

_plugin_shift_pressed_sym:

					; Test for Sym Shift.
	ld bc, $7ffe			; (Space, Sym Shift, M, N, B)	32766
	in a, (c)
	rra
	rra

	ret c

	ld a, SHIFT_SYMBOL
	or l
	ld l, a

	ret


_plugin_wait_for_no_keys:

	xor a
	in a, (254)

	and $1f				; code taken from z88dk function
					; asm_in_test_key
	cp $1f

	jr nz, _plugin_wait_for_no_keys

	ret


; amalgamation of the keyboard code from:
;
; /z88dk/libsrc/_DEVELOPMENT/input/zx/z80/asm_in_inkey.asm
; /z88dk/libsrc/_DEVELOPMENT/input/zx/z80/in_key_translation_table.asm

; asm_in_inkey.asm

; ===============================================================
; Sep 2005, improved Apr 2014
; ===============================================================
; 
; int in_inkey(void)
;
; Read instantaneous state of the keyboard and return ascii code
; if only one key is pressed.
;
; ===============================================================

;SECTION code_clib
;SECTION code_input
;
;PUBLIC asm_in_inkey
;
;EXTERN in_key_translation_table, error_znc, error_zc
;
;asm_in_inkey:

_plugin_in_inkey:

   ; exit : if one key is pressed
   ;
   ;           hl = ascii code
   ;           carry reset
   ;
   ;         if no keys are pressed
   ;
   ;            hl = 0
   ;            carry reset
   ;
   ;         if more than one key is pressed
   ;
   ;            hl = 0
   ;            carry set
   ;
   ; uses : af, bc, de, hl

   ; locate a key row with key active
   
   ld bc,$fefe                 ; key port, first row selected
   ld de,$0500                 ; e = offset into key translation table
   ld hl,$ffe0                 ; constant used in loop

   ; first row contains CAPS shift
   
   in a,(c)
   or $e1                      ; ignore CAPS shift
   cp h
   jr nz, keyhit_0             ; if key is pressed in this row

   ld e,d
   ld b,$fd
   
row_loop:

   in a,(c)
   or l
   cp h
   jr nz, keyhit_0             ; if key is pressed in this row

   ld a,e
   add a,d
   ld e,a                      ; increase index into key translation table
   
   rlc b
   jp m, row_loop              ; if key row is not the last one

   ; last row contains SYM shift
   
   in a,(c)
   or $e2                      ; ignore SYM shift
   cp h
   ld c,a
   jr nz, keyhit_1             ; if key is pressed in this row

   jp error_znc                ; if no keys pressed

keyhit_0:

   ; at least one key row is active
   ; make sure no others are active
   
   ld c,a
   
   ;  c = key result
   ;  b = key row containing keypress
   ;  e = index into key translation table for row
   ; hl = $ffe0
   ;  d = 5
   
   ld a,b
   cpl
   or $81
   
   in a,($fe)                  ; look at all other rows except CAPS/SYM rows
   or l
   cp h
   jp nz, error_zc             ; if more than one key pressed
   
   ld a,$7f
   in a,($fe)                  ; read SYM shift row
   or $e2                      ; ignore sym shift
   cp h
   jp nz, error_zc             ; if key in sym shift row pressed
   
keyhit_1:

   ; only one key row is active
   ; determine ascii code from translation table
   
   ;  c = key result
   ;  e = index into key translation table for row
   ;  d = 5
   
   ld b,0
   ld hl,rowtable - $e0
   add hl,bc
   
   ld a,(hl)
   cp d
   jp nc, error_zc             ; if more than one key is pressed in row
   
   add a,e
   ld e,a                      ; e = index into key translation table for key
   
   ld hl,in_key_translation_table
   ld d,b
   add hl,de
   
   ; check for shift modifiers

check_caps:

   ld a,$fe
   in a,($fe)
   and $01
   jr nz, check_sym
   
   ld e,40
   add hl,de

check_sym:

   ld a,$7f
   in a,($fe)
   and $02
   jr nz, ascii
   
   ld e,80
   add hl,de

ascii:

   ld l,(hl)
   ld h,b
   
   ret

;  /z88dk/libsrc/_DEVELOPMENT/target/crt_page_zero_z80.inc

error_zc:
   
   ld hl,0
   scf
   ret

error_znc:
   
   ld hl,0
   
   scf
   ccf
   
   ret

rowtable:

   defb 255,255,255,255,255,255,255
   defb 255,255,255,255,255,255,255,255
   defb 4,255,255,255,255,255,255
   defb 255,3,255,255,255,2,255,1
   defb 0,255

in_key_translation_table:

   ; unshifted
   
   defb 255,'z','x','c','v'      ; CAPS SHIFT, Z, X, C, V
   defb 'a','s','d','f','g'      ; A, S, D, F, G
   defb 'q','w','e','r','t'      ; Q, W, E, R, T
   defb '1','2','3','4','5'      ; 1, 2, 3, 4, 5
   defb '0','9','8','7','6'      ; 0, 9, 8, 7, 6
   defb 'p','o','i','u','y'      ; P, O, I, U, Y
   defb 13,'l','k','j','h'       ; ENTER, L, K, J, H
   defb ' ',255,'m','n','b'      ; SPACE, SYM SHIFT, M, N, B

   ; the following are CAPS SHIFTed

   defb 255,'Z','X','C','V'      ; CAPS SHIFT, Z, X, C, V
   defb 'A','S','D','F','G'      ; A, S, D, F, G
   defb 'Q','W','E','R','T'      ; Q, W, E, R, T
   defb 7,6,128,129,8            ; 1, 2, 3, 4, 5
   defb 12,8,9,11,10             ; 0, 9, 8, 7, 6
   defb 'P','O','I','U','Y'      ; P, O, I, U, Y
   defb 13,'L','K','J','H'       ; ENTER, L, K, J, H
   defb ' ',255,'M','N','B'      ; SPACE, SYM SHIFT, M, N, B

   ; the following are SYM SHIFTed

   defb 255,':',96,'?','/'       ; CAPS SHIFT, Z, X, C, V
   defb '~','|',92,'{','}'       ; A, S, D, F, G
   defb 131,132,133,'<','>'      ; Q, W, E, R, T
   defb '!','@','#','$','%'      ; 1, 2, 3, 4, 5
   defb '_',')','(',39,'&'       ; 0, 9, 8, 7, 6
   defb 34,';',130,']','['       ; P, O, I, U, Y
   defb 13,'=','+','-','^'       ; ENTER, L, K, J, H
   defb ' ',255,'.',',','*'      ; SPACE, SYM SHIFT, M, N, B

   ; the following are CAPS SHIFTed and SYM SHIFTed ("CTRL" key)

   defb 255,26,24,3,22           ; CAPS SHIFT, Z, X, C, V
   defb 1,19,4,6,7               ; A, S, D, F, G
   defb 17,23,5,18,20            ; Q, W, E, R, T
   defb 27,28,29,30,31           ; 1, 2, 3, 4, 5
   defb 127,255,134,'`',135      ; 0, 9, 8, 7, 6
   defb 16,15,9,21,25            ; P, O, I, U, Y
   defb 13,12,11,10,8            ; ENTER, L, K, J, H
   defb ' ',255,13,14,2          ; SPACE, SYM SHIFT, M, N, B

