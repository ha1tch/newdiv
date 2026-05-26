;******************************************************************************
;*
;* Copyright(c) 2022 Bob Fossil. All rights reserved.
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
;******************************************************************************


	; CP/M style 5 pixel character font

	; ' '
	defb 5			; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '!'
	defb 5			; width
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00000000
	defb %00100000
	defb %00000000

	; '"'
	defb 5			; width
	defb %01001000
	defb %01001000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '#'
	defb 5			; width
	defb %01010000
	defb %11111000
	defb %01010000
	defb %01010000
	defb %11111000
	defb %01010000
	defb %00000000

	; '$'
	defb 5			; width
	defb %00100000
	defb %01111000
	defb %10100000
	defb %01110000
	defb %00101000
	defb %11110000
	defb %00100000

	; '%'
	defb 5			; width
	defb %00000000
	defb %10001000
	defb %10010000
	defb %00100000
	defb %01001000
	defb %10001000
	defb %00000000

	; '&'
	defb 5			; width
	defb %00100000
	defb %01010000
	defb %00100000
	defb %01011000
	defb %10010000
	defb %01101000
	defb %00000000

	; '''
	defb 5			; width
	defb %00100000
	defb %00100000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '('
	defb 5			; width
	defb %00010000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00010000
	defb %00000000

	; ')'
	defb 5			; width
	defb %00100000
	defb %00010000
	defb %00010000
	defb %00010000
	defb %00010000
	defb %00100000
	defb %00000000

	; '*'
	defb 5			; width
	defb %01010000
	defb %00100000
	defb %11111000
	defb %00100000
	defb %01010000
	defb %00000000
	defb %00000000

	; '+'
	defb 5			; width
	defb %00000000
	defb %00100000
	defb %00100000
	defb %11111000
	defb %00100000
	defb %00100000
	defb %00000000

	; ','
	defb 5			; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00100000
	defb %00100000
	defb %01000000

	; '-'
	defb 5			; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %11110000
	defb %00000000
	defb %00000000
	defb %00000000

	; '.'
	defb 5			; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00100000
	defb %00100000
	defb %00000000

	; '/'
	defb 5			; width
	defb %00000000
	defb %00001000
	defb %00010000
	defb %00100000
	defb %01000000
	defb %10000000
	defb %00000000

	; '0'
	defb 5			; width
	defb %01100000
	defb %10010000
	defb %10110000
	defb %11010000
	defb %10010000
	defb %01100000
	defb %00000000

	; '1'
	defb 5			; width
	defb %00100000
	defb %01100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %01110000
	defb %00000000

	; '2'
	defb 5		; width
	defb %01100000
	defb %10010000
	defb %00010000
	defb %01100000
	defb %10000000
	defb %11110000
	defb %00000000

	; '3'
	defb 5			; width
	defb %01100000
	defb %10010000
	defb %00100000
	defb %00010000
	defb %10010000
	defb %01100000
	defb %00000000

	; '4'
	defb 5			; width
	defb %00010000
	defb %00110000
	defb %01010000
	defb %10010000
	defb %11111000
	defb %00010000
	defb %00000000

	; '5'
	defb 5			; width
	defb %11110000
	defb %10000000
	defb %11100000
	defb %00001000
	defb %10001000
	defb %01110000
	defb %00000000

	; '6'
	defb 5			; width
	defb %01110000
	defb %10000000
	defb %11100000
	defb %10010000
	defb %10010000
	defb %01100000
	defb %00000000

	; '7'
	defb 5			; width
	defb %11110000
	defb %00010000
	defb %00100000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %00000000

	; '8'
	defb 5			; width
	defb %01100000
	defb %10010000
	defb %01100000
	defb %10010000
	defb %10010000
	defb %01100000
	defb %00000000

	; '9'
	defb 5			; width
	defb %01100000
	defb %10010000
	defb %10010000
	defb %01110000
	defb %00010000
	defb %11100000
	defb %00000000

	; ':'
	defb 5			; width
	defb %00000000
	defb %00100000
	defb %00100000
	defb %00000000
	defb %00100000
	defb %00100000
	defb %00000000

	; ';'
	defb 5			; width
	defb %00000000
	defb %00100000
	defb %00100000
	defb %00000000
	defb %00100000
	defb %00100000
	defb %01000000

	; '<'
	defb 5			; width
	defb %00000000
	defb %00010000
	defb %00100000
	defb %01000000
	defb %00100000
	defb %00010000
	defb %00000000

	; '='
	defb 5			; width
	defb %00000000
	defb %00000000
	defb %01111000
	defb %00000000
	defb %01111000
	defb %00000000
	defb %00000000

	; '>'
	defb 5			; width
	defb %00000000
	defb %01000000
	defb %00100000
	defb %00010000
	defb %00100000
	defb %01000000
	defb %00000000

	; ?
	defb 5			; width
	defb %01100000
	defb %10010000
	defb %00100000
	defb %01000000
	defb %00000000
	defb %01000000
	defb %00000000

	; @
	defb 5			; width
	defb %01110000
	defb %10001000
	defb %10101000
	defb %10111000
	defb %10000000
	defb %01110000
	defb %00000000

	; 'A'
	defb 5			; width
	defb %01100000
	defb %10010000
	defb %10010000
	defb %11110000
	defb %10010000
	defb %10010000
	defb %00000000

	; 'B'
	defb 5			; width
	defb %11100000
	defb %10010000
	defb %11100000
	defb %10010000
	defb %10010000
	defb %11100000
	defb %00000000

	; 'C'
	defb 5			; width
	defb %01100000
	defb %10010000
	defb %10000000
	defb %10000000
	defb %10010000
	defb %01100000
	defb %00000000

	; 'D'
	defb 5			; width
	defb %11000000
	defb %10100000
	defb %10010000
	defb %10010000
	defb %10100000
	defb %11000000
	defb %00000000

	; 'E'
	defb 5			; width
	defb %11110000
	defb %10000000
	defb %11100000
	defb %10000000
	defb %10000000
	defb %11110000
	defb %00000000

	; 'F'
	defb 5			; width
	defb %11110000
	defb %10000000
	defb %11100000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %00000000

	; 'G'
	defb 5			; width
	defb %01100000
	defb %10010000
	defb %10000000
	defb %10110000
	defb %10010000
	defb %01100000
	defb %00000000

	; 'H'
	defb 5			; width
	defb %10010000
	defb %10010000
	defb %11110000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %00000000

	; 'I'
	defb 5			; width
	defb %01110000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %01110000
	defb %00000000

	; 'J'
	defb 5			; width
	defb %01110000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %10100000
	defb %01000000
	defb %00000000

	; 'K'
	defb 5			; width
	defb %10010000
	defb %10100000
	defb %11000000
	defb %11000000
	defb %10100000
	defb %10010000
	defb %00000000

	; 'L'
	defb 5			; width
	defb %10000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %11110000
	defb %00000000

	; 'M'
	defb 5			; width
	defb %10001000
	defb %11011000
	defb %10101000
	defb %10001000
	defb %10001000
	defb %10001000
	defb %00000000

	; 'N'
	defb 5			; width
	defb %10010000
	defb %10010000
	defb %11010000
	defb %10110000
	defb %10010000
	defb %10010000
	defb %00000000

	; 'O'
	defb 5			; width
	defb %01100000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %01100000
	defb %00000000

	; 'P'
	defb 5			; width
	defb %11100000
	defb %10010000
	defb %10010000
	defb %11100000
	defb %10000000
	defb %10000000
	defb %00000000

	; 'Q'
	defb 5			; width
	defb %01100000
	defb %10010000
	defb %10010000
	defb %10110000
	defb %10010000
	defb %01101000
	defb %00000000

	; 'R'
	defb 5			; width
	defb %11100000
	defb %10010000
	defb %10010000
	defb %11100000
	defb %10100000
	defb %10010000
	defb %00000000

	; 'S'
	defb 5			; width
	defb %01110000
	defb %10000000
	defb %01100000
	defb %00010000
	defb %00010000
	defb %11100000
	defb %00000000

	; 'T'
	defb 5			; width
	defb %11111000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00000000

	; 'U'
	defb 5			; width
	defb %10010000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %01100000
	defb %00000000

	; 'V'
	defb 5			; width
	defb %10001000
	defb %10001000
	defb %10001000
	defb %10001000
	defb %01010000
	defb %00100000
	defb %00000000

	; 'W'
	defb 5			; width
	defb %10001000
	defb %10001000
	defb %10001000
	defb %10001000
	defb %10101000
	defb %01010000
	defb %00000000

	; 'X'
	defb 5			; width
	defb %10001000
	defb %01010000
	defb %00100000
	defb %01010000
	defb %10001000
	defb %10001000
	defb %00000000

	; 'Y'
	defb 5			; width
	defb %10001000
	defb %01010000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00000000

	; 'Z'
	defb 5			; width
	defb %11110000
	defb %00010000
	defb %00100000
	defb %01000000
	defb %10000000
	defb %11110000
	defb %00000000

	; '['
	defb 5			; width
	defb %01110000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %01110000
	defb %00000000

	; '\'
	defb 5			; width
	defb %00000000
	defb %10000000
	defb %01000000
	defb %00100000
	defb %00010000
	defb %00001000
	defb %00000000

	; ']'
	defb 5			; width
	defb %01110000
	defb %00010000
	defb %00010000
	defb %00010000
	defb %00010000
	defb %01110000
	defb %00000000

	; '^'
	defb 5			; width
	defb %00100000
	defb %01110000
	defb %10101000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00000000

	; '_'
	defb 5			; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %11111000

	; '£'
	defb 5			; width
	defb %00100000
	defb %01010000
	defb %01000000
	defb %11100000
	defb %01000000
	defb %11110000
	defb %00000000

	; 'a'
	defb 5			; width
	defb %00000000
	defb %01100000
	defb %00010000
	defb %01110000
	defb %10010000
	defb %01110000
	defb %00000000

	; 'b'
	defb 5			; width
	defb %10000000
	defb %10000000
	defb %11100000
	defb %10010000
	defb %10010000
	defb %11100000
	defb %00000000

	; 'c'
	defb 5			; width
	defb %00000000
	defb %01110000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %01110000
	defb %00000000

	; 'd'
	defb 5			; width
	defb %00010000
	defb %00010000
	defb %01110000
	defb %10010000
	defb %10010000
	defb %01110000
	defb %00000000

	; 'e'
	defb 5			; width
	defb %00000000
	defb %01100000
	defb %10010000
	defb %11100000
	defb %10000000
	defb %01110000
	defb %00000000

	; 'f'
	defb 5			; width
	defb %00110000
	defb %01000000
	defb %11100000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %00000000

	; 'g'
	defb 5			; width
	defb %00000000
	defb %01110000
	defb %10010000
	defb %10010000
	defb %01110000
	defb %00010000
	defb %01100000

	; 'h'
	defb 5			; width
	defb %10000000
	defb %10000000
	defb %11100000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %00000000

	; 'i'
	defb 5			; width
	defb %00100000
	defb %00000000
	defb %01100000
	defb %00100000
	defb %00100000
	defb %01110000
	defb %00000000

	; 'j'
	defb 5			; width
	defb %00010000
	defb %00000000
	defb %00110000
	defb %00010000
	defb %00010000
	defb %10010000
	defb %01100000

	; 'k'
	defb 5			; width
	defb %10000000
	defb %10010000
	defb %10100000
	defb %11000000
	defb %10100000
	defb %10010000
	defb %00000000

	; 'l'
	defb 5			; width
	defb %01100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %01110000
	defb %00000000

	; 'm'
	defb 5			; width
	defb %00000000
	defb %11010000
	defb %10101000
	defb %10101000
	defb %10101000
	defb %10101000
	defb %00000000

	; 'n'
	defb 5			; width
	defb %00000000
	defb %11100000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %00000000

	; 'o'
	defb 5			; width
	defb %00000000
	defb %01100000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %01100000
	defb %00000000

	; 'p'
	defb 5			; width
	defb %00000000
	defb %11100000
	defb %10010000
	defb %10010000
	defb %11100000
	defb %10000000
	defb %10000000

	; 'q'
	defb 5			; width
	defb %00000000
	defb %01110000
	defb %10010000
	defb %10010000
	defb %01110000
	defb %00010000
	defb %00010000

	; 'r'
	defb 5			; width
	defb %00000000
	defb %11100000
	defb %10010000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %00000000

	; 's'
	defb 5			; width
	defb %00000000
	defb %01110000
	defb %10000000
	defb %01100000
	defb %00010000
	defb %11100000
	defb %00000000

	; 't'
	defb 5			; width
	defb %01000000
	defb %11100000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %00110000
	defb %00000000

	; 'u'
	defb 5			; width
	defb %00000000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %01110000
	defb %00000000

	; 'v'
	defb 5			; width
	defb %00000000
	defb %10001000
	defb %10001000
	defb %01010000
	defb %01010000
	defb %00100000
	defb %00000000

	; 'w'
	defb 5			; width
	defb %00000000
	defb %10001000
	defb %10101000
	defb %10101000
	defb %10101000
	defb %01010000
	defb %00000000

	; 'x'
	defb 5			; width
	defb %00000000
	defb %10001000
	defb %01010000
	defb %00100000
	defb %01010000
	defb %10001000
	defb %00000000

	; 'y'
	defb 5			; width
	defb %00000000
	defb %10010000
	defb %10010000
	defb %10010000
	defb %01110000
	defb %00010000
	defb %11100000

	; 'z'
	defb 5			; width
	defb %00000000
	defb %11110000
	defb %00100000
	defb %01000000
	defb %10000000
	defb %11110000
	defb %00000000

	; '{'
	defb 5			; width
	defb %00111000
	defb %01000000
	defb %01000000
	defb %10000000
	defb %01000000
	defb %00111000
	defb %00000000

	; '|'
	defb 5			; width
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00000000

	; '}'
	defb 5			; width
	defb %11000000
	defb %00100000
	defb %00010000
	defb %00100000
	defb %00100000
	defb %11000000
	defb %00000000

	; '~'
	defb 5			; width
	defb %01010000
	defb %10100000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; (c)
	defb 5			; width
	defb %01110000
	defb %10001000
	defb %10111000
	defb %11001000
	defb %10111000
	defb %10001000
	defb %01110000

	; '...'
	defb 5			; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %10101000
	defb %10101000
	defb %00000000
