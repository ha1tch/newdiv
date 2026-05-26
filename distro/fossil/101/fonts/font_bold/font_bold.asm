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
;******************************************************************************

	org 32768

	; ' '
	defb 4		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '!'
	defb 3		; width
	defb %11000000
	defb %11000000
	defb %11000000
	defb %11000000
	defb %00000000
	defb %11000000
	defb %00000000

	; '"'
	defb 0		; width
	defb %11011000
	defb %11011000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '#'
	defb 0		; width
	defb %01111000
	defb %11111100
	defb %01111000
	defb %01111000
	defb %11111100
	defb %01111000
	defb %00000000

	; '$'
	defb 0		; width
	defb %00110000
	defb %11111100
	defb %11110000
	defb %11111100
	defb %00111100
	defb %11111100
	defb %00110000

	; '%'
	defb 0		; width
	defb %00000000
	defb %11101100
	defb %11111000
	defb %00110000
	defb %01111100
	defb %11011100
	defb %00000000

	; '&'
	defb 0		; width
	defb %00110000
	defb %01111000
	defb %00110000
	defb %01111100
	defb %11011000
	defb %01111100
	defb %00000000

	; '''
	defb 5		; width
	defb %00110000
	defb %01100000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '('
	defb 5		; width
	defb %00110000
	defb %01100000
	defb %01100000
	defb %01100000
	defb %01100000
	defb %00110000
	defb %00000000

	; ')'
	defb 5		; width
	defb %01100000
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00110000
	defb %01100000
	defb %00000000

	; '*'
	defb 0		; width
	defb %00000000
	defb %00110000
	defb %11111100
	defb %01111000
	defb %11111100
	defb %00110000
	defb %00000000

	; '+'
	defb 0		; width
	defb %00000000
	defb %00110000
	defb %00110000
	defb %11111100
	defb %00110000
	defb %00110000
	defb %00000000

	; ','
	defb 5		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00110000
	defb %00110000
	defb %01100000

	; '-'
	defb 0		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %11111100
	defb %00000000
	defb %00000000
	defb %00000000

	; '.'
	defb 5		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %01110000
	defb %01110000
	defb %00000000

	; '/'
	defb 0		; width
	defb %00000000
	defb %00001100
	defb %00011000
	defb %00110000
	defb %01100000
	defb %11000000
	defb %00000000

	; '0'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %11011100
	defb %11111100
	defb %11101100
	defb %01111000
	defb %00000000

	; '1'
	defb 0		; width
	defb %00110000
	defb %01110000
	defb %11110000
	defb %00110000
	defb %00110000
	defb %11111100
	defb %00000000

	; '2'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %00001100
	defb %01111000
	defb %11000000
	defb %11111100
	defb %00000000

	; '3'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %00111000
	defb %00001100
	defb %11001100
	defb %01111000
	defb %00000000

	; '4'
	defb 0		; width
	defb %00011000
	defb %00111000
	defb %01111000
	defb %11011000
	defb %11111100
	defb %00011000
	defb %00000000

	; '5'
	defb 0		; width
	defb %11111100
	defb %11000000
	defb %11111000
	defb %00001100
	defb %11001100
	defb %01111000
	defb %00000000

	; '6'
	defb 0		; width
	defb %01111000
	defb %11000000
	defb %11111000
	defb %11001100
	defb %11001100
	defb %01111000
	defb %00000000

	; '7'
	defb 0		; width
	defb %11111100
	defb %00001100
	defb %00011000
	defb %00110000
	defb %01100000
	defb %01100000
	defb %00000000

	; '8'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %01111000
	defb %11001100
	defb %11001100
	defb %01111000
	defb %00000000

	; '9'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %11001100
	defb %01111100
	defb %00001100
	defb %01111000
	defb %00000000

	; ':'
	defb 5		; width
	defb %00000000
	defb %00000000
	defb %00110000
	defb %00000000
	defb %00000000
	defb %00110000
	defb %00000000

	; ';'
	defb 5		; width
	defb %00000000
	defb %00110000
	defb %00000000
	defb %00000000
	defb %00110000
	defb %00110000
	defb %01100000

	; '<'
	defb 0		; width
	defb %00000000
	defb %00011000
	defb %00110000
	defb %01100000
	defb %00110000
	defb %00011000
	defb %00000000

	; '='
	defb 0		; width
	defb %00000000
	defb %00000000
	defb %01111100
	defb %00000000
	defb %01111100
	defb %00000000
	defb %00000000

	; '>'
	defb 5		; width
	defb %00000000
	defb %01100000
	defb %00110000
	defb %00011000
	defb %00110000
	defb %01100000
	defb %00000000

	; '?'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %00011000
	defb %00110000
	defb %00000000
	defb %00110000
	defb %00000000

	; '@'
	defb 0		; width
	defb %01111000
	defb %11111100
	defb %11011100
	defb %11111100
	defb %11000000
	defb %01111000
	defb %00000000

	; 'A'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %11001100
	defb %11111100
	defb %11001100
	defb %11001100
	defb %00000000

	; 'B'
	defb 0		; width
	defb %11111000
	defb %11001100
	defb %11111000
	defb %11001100
	defb %11001100
	defb %11111000
	defb %00000000

	; 'C'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %11000000
	defb %11000000
	defb %11001100
	defb %01111000
	defb %00000000

	; 'D'
	defb 0		; width
	defb %11110000
	defb %11011000
	defb %11001100
	defb %11001100
	defb %11011000
	defb %11110000
	defb %00000000

	; 'E'
	defb 0		; width
	defb %11111100
	defb %11000000
	defb %11111000
	defb %11000000
	defb %11000000
	defb %11111100
	defb %00000000

	; 'F'
	defb 0		; width
	defb %11111100
	defb %11000000
	defb %11111000
	defb %11000000
	defb %11000000
	defb %11000000
	defb %00000000

	; 'G'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %11000000
	defb %11011100
	defb %11001100
	defb %01111000
	defb %00000000

	; 'H'
	defb 0		; width
	defb %11001100
	defb %11001100
	defb %11111100
	defb %11001100
	defb %11001100
	defb %11001100
	defb %00000000

	; 'I'
	defb 0		; width
	defb %11111100
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00110000
	defb %11111100
	defb %00000000

	; 'J'
	defb 0		; width
	defb %00001100
	defb %00001100
	defb %00001100
	defb %11001100
	defb %11001100
	defb %01111000
	defb %00000000

	; 'K'
	defb 0		; width
	defb %11011000
	defb %11110000
	defb %11100000
	defb %11110000
	defb %11011000
	defb %11001100
	defb %00000000

	; 'L'
	defb 0		; width
	defb %11000000
	defb %11000000
	defb %11000000
	defb %11000000
	defb %11000000
	defb %11111100
	defb %00000000

	; 'M'
	defb 0		; width
	defb %11001100
	defb %11111100
	defb %11111100
	defb %11001100
	defb %11001100
	defb %11001100
	defb %00000000

	; 'N'
	defb 0		; width
	defb %11001100
	defb %11101100
	defb %11111100
	defb %11011100
	defb %11001100
	defb %11001100
	defb %00000000

	; 'O'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %11001100
	defb %11001100
	defb %11001100
	defb %01111000
	defb %00000000

	; 'P'
	defb 0		; width
	defb %11111000
	defb %11001100
	defb %11001100
	defb %11111000
	defb %11000000
	defb %11000000
	defb %00000000

	; 'Q'
	defb 0		; width
	defb %01111000
	defb %11001100
	defb %11001100
	defb %11111100
	defb %11011100
	defb %01111100
	defb %00000000

	; 'R'
	defb 0		; width
	defb %11111000
	defb %11001100
	defb %11001100
	defb %11111000
	defb %11001100
	defb %11001100
	defb %00000000

	; 'S'
	defb 0		; width
	defb %01111000
	defb %11000000
	defb %01111000
	defb %00001100
	defb %11001100
	defb %01111000
	defb %00000000

	; 'T'
	defb 0		; width
	defb %11111100
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00000000

	; 'U'
	defb 0		; width
	defb %11001100
	defb %11001100
	defb %11001100
	defb %11001100
	defb %11001100
	defb %01111000
	defb %00000000

	; 'V'
	defb 0		; width
	defb %11001100
	defb %11001100
	defb %11001100
	defb %11001100
	defb %01111000
	defb %00110000
	defb %00000000

	; 'W'
	defb 0		; width
	defb %11001100
	defb %11001100
	defb %11001100
	defb %11001100
	defb %11111100
	defb %01111000
	defb %00000000

	; 'X'
	defb 0		; width
	defb %11001100
	defb %01111000
	defb %00110000
	defb %00110000
	defb %01111000
	defb %11001100
	defb %00000000

	; 'Y'
	defb 0		; width
	defb %11001100
	defb %11001100
	defb %01111000
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00000000

	; 'Z'
	defb 0		; width
	defb %11111100
	defb %00001100
	defb %00011000
	defb %00110000
	defb %01100000
	defb %11111100
	defb %00000000

	; '['
	defb 0		; width
	defb %01111000
	defb %01100000
	defb %01100000
	defb %01100000
	defb %01100000
	defb %01111000
	defb %00000000

	; '\'
	defb 0		; width
	defb %00000000
	defb %11000000
	defb %01100000
	defb %00110000
	defb %00011000
	defb %00001100
	defb %00000000

	; ']'
	defb 0		; width
	defb %01111000
	defb %00011000
	defb %00011000
	defb %00011000
	defb %00011000
	defb %01111000
	defb %00000000

	; '^'
	defb 0		; width
	defb %00110000
	defb %01111000
	defb %11111100
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00000000

	; '_'
	defb 0		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %11111100

	; '`'
	defb 0		; width
	defb %00111000
	defb %01101100
	defb %11110000
	defb %01100000
	defb %01100000
	defb %11111100
	defb %00000000

	; 'a'
	defb 0		; width
	defb %00000000
	defb %01111000
	defb %00001100
	defb %01111100
	defb %11001100
	defb %01111100
	defb %00000000

	; 'b'
	defb 0		; width
	defb %11000000
	defb %11000000
	defb %11111000
	defb %11001100
	defb %11001100
	defb %11111000
	defb %00000000

	; 'c'
	defb 0		; width
	defb %00000000
	defb %01111000
	defb %11001100
	defb %11000000
	defb %11001100
	defb %01111000
	defb %00000000

	; 'd'
	defb 0		; width
	defb %00001100
	defb %00001100
	defb %01111100
	defb %11001100
	defb %11001100
	defb %01111100
	defb %00000000

	; 'e'
	defb 0		; width
	defb %00000000
	defb %01111000
	defb %11001100
	defb %11111000
	defb %11000000
	defb %01111100
	defb %00000000

	; 'f'
	defb 0		; width
	defb %00011100
	defb %00110000
	defb %01111100
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00000000

	; 'g'
	defb 0		; width
	defb %00000000
	defb %01111100
	defb %11001100
	defb %11001100
	defb %01111100
	defb %00001100
	defb %00111000

	; 'h'
	defb 0		; width
	defb %11000000
	defb %11000000
	defb %11111000
	defb %11001100
	defb %11001100
	defb %11001100
	defb %00000000

	; 'i'
	defb 0		; width
	defb %00110000
	defb %00000000
	defb %01110000
	defb %00110000
	defb %00110000
	defb %01111000
	defb %00000000

	; 'j'
	defb 0		; width
	defb %00001100
	defb %00000000
	defb %00001100
	defb %00001100
	defb %00001100
	defb %01101100
	defb %00111000

	; 'k'
	defb 0		; width
	defb %11000000
	defb %11110000
	defb %11100000
	defb %11100000
	defb %11110000
	defb %11011000
	defb %00000000

	; 'l'
	defb 0		; width
	defb %01100000
	defb %01100000
	defb %01100000
	defb %01100000
	defb %01100000
	defb %00111000
	defb %00000000

	; 'm'
	defb 0		; width
	defb %00000000
	defb %11111000
	defb %11111100
	defb %11111100
	defb %11111100
	defb %11001100
	defb %00000000

	; 'n'
	defb 0		; width
	defb %00000000
	defb %11111000
	defb %11001100
	defb %11001100
	defb %11001100
	defb %11001100
	defb %00000000

	; 'o'
	defb 0		; width
	defb %00000000
	defb %01111000
	defb %11001100
	defb %11001100
	defb %11001100
	defb %01111000
	defb %00000000

	; 'p'
	defb 0		; width
	defb %00000000
	defb %11111000
	defb %11001100
	defb %11001100
	defb %11111000
	defb %11000000
	defb %11000000

	; 'q'
	defb 0		; width
	defb %00000000
	defb %01111000
	defb %11011000
	defb %11011000
	defb %01111000
	defb %00011000
	defb %00011100

	; 'r'
	defb 0		; width
	defb %00000000
	defb %01111000
	defb %11000000
	defb %11000000
	defb %11000000
	defb %11000000
	defb %00000000

	; 's'
	defb 0		; width
	defb %00000000
	defb %01111000
	defb %11000000
	defb %01111000
	defb %00001100
	defb %11111000
	defb %00000000

	; 't'
	defb 0		; width
	defb %00110000
	defb %01111000
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00011100
	defb %00000000

	; 'u'
	defb 0		; width
	defb %00000000
	defb %11001100
	defb %11001100
	defb %11001100
	defb %11001100
	defb %01111000
	defb %00000000

	; 'v'
	defb 0		; width
	defb %00000000
	defb %11001100
	defb %11001100
	defb %01111000
	defb %01111000
	defb %00110000
	defb %00000000

	; 'w'
	defb 0		; width
	defb %00000000
	defb %11001100
	defb %11111100
	defb %11111100
	defb %11111100
	defb %01111000
	defb %00000000

	; 'x'
	defb 0		; width
	defb %00000000
	defb %11001100
	defb %01111000
	defb %00110000
	defb %01111000
	defb %11001100
	defb %00000000

	; 'y'
	defb 0		; width
	defb %00000000
	defb %11001100
	defb %11001100
	defb %11001100
	defb %01111100
	defb %00001100
	defb %01111000

	; 'z'
	defb 0		; width
	defb %00000000
	defb %11111100
	defb %00011000
	defb %00110000
	defb %01100000
	defb %11111100
	defb %00000000

	; '{'
	defb 0		; width
	defb %00111100
	defb %00110000
	defb %01110000
	defb %00110000
	defb %00110000
	defb %00111100
	defb %00000000

	; '|'
	defb 5		; width
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00110000
	defb %00000000

	; '}'
	defb 0		; width
	defb %01111000
	defb %00011000
	defb %00011100
	defb %00011000
	defb %00011000
	defb %01111000
	defb %00000000

	; '~'
	defb 0		; width
	defb %01111000
	defb %11110000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '(c)'
	defb 0		; width
	defb %01111000
	defb %11111100
	defb %11101100
	defb %11101100
	defb %11111100
	defb %01111000
	defb %00000000

	; '...'
	defb 0		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %11011000
	defb %11011000
	defb %00000000
