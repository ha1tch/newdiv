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

	; Tasword 2 style 64 character font

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
	defb 4		; width
	defb %01000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %00000000
	defb %01000000
	defb %00000000

	; '"'
	defb 4		; width
	defb %10100000
	defb %10100000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '#'
	defb 4		; width
	defb %10100000
	defb %11100000
	defb %10100000
	defb %10100000
	defb %11100000
	defb %10100000
	defb %00000000

	; '$'
	defb 4		; width
	defb %01000000
	defb %11100000
	defb %10000000
	defb %11100000
	defb %00100000
	defb %11100000
	defb %01000000

	; '%'
	defb 4		; width
	defb %10000000
	defb %10000000
	defb %00100000
	defb %01000000
	defb %10000000
	defb %00100000
	defb %00100000

	; '&'
	defb 4		; width
	defb %01000000
	defb %10100000
	defb %01000000
	defb %10100000
	defb %11100000
	defb %01100000
	defb %00000000

	; '''
	defb 4		; width
	defb %01000000
	defb %10000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '('
	defb 4		; width
	defb %01000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %01000000
	defb %00000000

	; ')'
	defb 4		; width
	defb %10000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %10000000
	defb %00000000

	; '*'
	defb 4		; width
	defb %00000000
	defb %10100000
	defb %01000000
	defb %11100000
	defb %01000000
	defb %10100000
	defb %00000000

	; '+'
	defb 4		; width
	defb %00000000
	defb %01000000
	defb %01000000
	defb %11100000
	defb %01000000
	defb %01000000
	defb %00000000

	; ','
	defb 4		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %01000000
	defb %01000000
	defb %10000000

	; '-'
	defb 4		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %11100000
	defb %00000000
	defb %00000000
	defb %00000000

	; '.'
	defb 4		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %11000000
	defb %11000000
	defb %00000000

	; '/'
	defb 4		; width
	defb %00100000
	defb %00100000
	defb %01000000
	defb %01000000
	defb %10000000
	defb %10000000
	defb %00000000

	; '0'
	defb 4		; width
	defb %11100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %11100000
	defb %00000000

	; '1'
	defb 4		; width
	defb %01000000
	defb %11000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %11100000
	defb %00000000

	; '2'
	defb 4		; width
	defb %01000000
	defb %10100000
	defb %00100000
	defb %01000000
	defb %10000000
	defb %11100000
	defb %00000000

	; '3'
	defb 4		; width
	defb %11000000
	defb %00100000
	defb %11000000
	defb %00100000
	defb %00100000
	defb %11000000
	defb %00000000

	; '4'
	defb 4		; width
	defb %00100000
	defb %01100000
	defb %10100000
	defb %10100000
	defb %11100000
	defb %00100000
	defb %00000000

	; '5'
	defb 4		; width
	defb %11100000
	defb %10000000
	defb %11000000
	defb %00100000
	defb %00100000
	defb %11000000
	defb %00000000

	; '6'
	defb 4		; width
	defb %01100000
	defb %10000000
	defb %11000000
	defb %10100000
	defb %10100000
	defb %01000000
	defb %00000000

	; '7'
	defb 4		; width
	defb %11100000
	defb %00100000
	defb %01000000
	defb %01000000
	defb %10000000
	defb %10000000
	defb %00000000

	; '8'
	defb 4		; width
	defb %11100000
	defb %10100000
	defb %01000000
	defb %10100000
	defb %10100000
	defb %11100000
	defb %00000000

	; '9'
	defb 4		; width
	defb %01000000
	defb %10100000
	defb %10100000
	defb %01100000
	defb %00100000
	defb %11000000
	defb %00000000

	; ':'
	defb 4		; width
	defb %00000000
	defb %00000000
	defb %01000000
	defb %00000000
	defb %00000000
	defb %01000000
	defb %00000000

	; ';'
	defb 4		; width
	defb %00000000
	defb %01000000
	defb %00000000
	defb %00000000
	defb %01000000
	defb %01000000
	defb %10000000

	; '<'
	defb 4		; width
	defb %00000000
	defb %00100000
	defb %01000000
	defb %10000000
	defb %01000000
	defb %00100000
	defb %00000000

	; '='
	defb 4		; width
	defb %00000000
	defb %00000000
	defb %11100000
	defb %00000000
	defb %11100000
	defb %00000000
	defb %00000000

	; '>'
	defb 4		; width
	defb %00000000
	defb %10000000
	defb %01000000
	defb %00100000
	defb %01000000
	defb %10000000
	defb %00000000

	; '?'
	defb 4		; width
	defb %01000000
	defb %10100000
	defb %00100000
	defb %01000000
	defb %00000000
	defb %01000000
	defb %00000000

	; '@'
	defb 4		; width
	defb %01100000
	defb %11110000
	defb %11010000
	defb %10100000
	defb %10000000
	defb %01110000
	defb %00000000

	; 'A'
	defb 4		; width
	defb %01000000
	defb %10100000
	defb %11100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %00000000

	; 'B'
	defb 4		; width
	defb %11000000
	defb %10100000
	defb %11000000
	defb %10100000
	defb %10100000
	defb %11000000
	defb %00000000

	; 'C'
	defb 4		; width
	defb %01000000
	defb %10100000
	defb %10000000
	defb %10000000
	defb %10100000
	defb %01000000
	defb %00000000

	; 'D'
	defb 4		; width
	defb %11000000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %11000000
	defb %00000000

	; 'E'
	defb 4		; width
	defb %11100000
	defb %10000000
	defb %11000000
	defb %10000000
	defb %10000000
	defb %11100000
	defb %00000000

	; 'F'
	defb 4		; width
	defb %11100000
	defb %10000000
	defb %11100000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %00000000

	; 'G'
	defb 4		; width
	defb %01000000
	defb %10100000
	defb %10000000
	defb %11100000
	defb %10100000
	defb %01000000
	defb %00000000

	; 'H'
	defb 4		; width
	defb %10100000
	defb %10100000
	defb %11100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %00000000

	; 'I'
	defb 4		; width
	defb %11100000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %11100000
	defb %00000000

	; 'J'
	defb 4		; width
	defb %11100000
	defb %00100000
	defb %00100000
	defb %10100000
	defb %10100000
	defb %01000000
	defb %00000000

	; 'K'
	defb 4		; width
	defb %10100000
	defb %10100000
	defb %11000000
	defb %11000000
	defb %10100000
	defb %10100000
	defb %00000000

	; 'L'
	defb 4		; width
	defb %10000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %11100000
	defb %00000000

	; 'M'
	defb 4		; width
	defb %10100000
	defb %11100000
	defb %11100000
	defb %11100000
	defb %10100000
	defb %10100000
	defb %00000000

	; 'N'
	defb 4		; width
	defb %11100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %00000000

	; 'O'
	defb 4		; width
	defb %01000000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %01000000
	defb %00000000

	; 'P'
	defb 4		; width
	defb %11000000
	defb %10100000
	defb %10100000
	defb %11000000
	defb %10000000
	defb %10000000
	defb %00000000

	; 'Q'
	defb 4		; width
	defb %11100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %11100000
	defb %11100000
	defb %00100000

	; 'R'
	defb 4		; width
	defb %11100000
	defb %10100000
	defb %10100000
	defb %11000000
	defb %11000000
	defb %10100000
	defb %00000000

	; 'S'
	defb 4		; width
	defb %01100000
	defb %10000000
	defb %01000000
	defb %00100000
	defb %00100000
	defb %11000000
	defb %00000000

	; 'T'
	defb 4		; width
	defb %11100000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %00000000

	; 'U'
	defb 4		; width
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %11100000
	defb %00000000

	; 'V'
	defb 4		; width
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %01000000
	defb %00000000

	; 'W'
	defb 4		; width
	defb %10100000
	defb %11100000
	defb %11100000
	defb %11100000
	defb %11100000
	defb %01000000
	defb %00000000

	; 'X'
	defb 4		; width
	defb %10100000
	defb %10100000
	defb %01000000
	defb %01000000
	defb %10100000
	defb %10100000
	defb %00000000

	; 'Y'
	defb 4		; width
	defb %10100000
	defb %10100000
	defb %10100000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %00000000

	; 'Z'
	defb 4		; width
	defb %11100000
	defb %00100000
	defb %01000000
	defb %01000000
	defb %10000000
	defb %11100000
	defb %00000000

	; '['
	defb 4		; width
	defb %11100000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %11100000
	defb %00000000

	; '\'
	defb 4		; width
	defb %10000000
	defb %10000000
	defb %00100000
	defb %00100000
	defb %00010000
	defb %00010000
	defb %00000000

	; ']'
	defb 4		; width
	defb %11100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %11100000
	defb %00000000

	; '^'
	defb 4		; width
	defb %01000000
	defb %10100000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '_'
	defb 4		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %11110000

	; '`'
	defb 4		; width
	defb %00100000
	defb %01010000
	defb %01000000
	defb %11110000
	defb %01000000
	defb %11110000
	defb %00000000

	; 'a'
	defb 4		; width
	defb %00000000
	defb %11000000
	defb %00100000
	defb %11100000
	defb %10100000
	defb %11100000
	defb %00000000

	; 'b'
	defb 4		; width
	defb %10000000
	defb %10000000
	defb %11000000
	defb %10100000
	defb %10100000
	defb %11000000
	defb %00000000

	; 'c'
	defb 4		; width
	defb %00000000
	defb %01100000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %01100000
	defb %00000000

	; 'd'
	defb 4		; width
	defb %00100000
	defb %00100000
	defb %01100000
	defb %10100000
	defb %10100000
	defb %11100000
	defb %00000000

	; 'e'
	defb 4		; width
	defb %00000000
	defb %01000000
	defb %10100000
	defb %11000000
	defb %10000000
	defb %01100000
	defb %00000000

	; 'f'
	defb 4		; width
	defb %01100000
	defb %10000000
	defb %11000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %00000000

	; 'g'
	defb 4		; width
	defb %00000000
	defb %01100000
	defb %10100000
	defb %10100000
	defb %01100000
	defb %00100000
	defb %11000000

	; 'h'
	defb 4		; width
	defb %10000000
	defb %10000000
	defb %11000000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %00000000

	; 'i'
	defb 4		; width
	defb %01000000
	defb %00000000
	defb %11000000
	defb %01000000
	defb %01000000
	defb %11100000
	defb %00000000

	; 'j'
	defb 4		; width
	defb %00100000
	defb %00000000
	defb %00100000
	defb %00100000
	defb %00100000
	defb %10100000
	defb %01000000

	; 'k'
	defb 4		; width
	defb %10000000
	defb %10100000
	defb %11000000
	defb %11000000
	defb %10100000
	defb %10100000
	defb %00000000

	; 'l'
	defb 4		; width
	defb %10000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %01100000
	defb %00000000

	; 'm'
	defb 4		; width
	defb %00000000
	defb %10100000
	defb %11100000
	defb %11100000
	defb %11100000
	defb %10100000
	defb %00000000

	; 'n'
	defb 4		; width
	defb %00000000
	defb %11000000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %00000000

	; 'o'
	defb 4		; width
	defb %00000000
	defb %01000000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %01000000
	defb %00000000

	; 'p'
	defb 4		; width
	defb %00000000
	defb %11000000
	defb %10100000
	defb %10100000
	defb %11000000
	defb %10000000
	defb %10000000

	; 'q'
	defb 4		; width
	defb %00000000
	defb %01100000
	defb %10100000
	defb %10100000
	defb %01100000
	defb %00100000
	defb %00100100

	; 'r'
	defb 4		; width
	defb %00000000
	defb %01100000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %10000000
	defb %00000000

	; 's'
	defb 4		; width
	defb %00000000
	defb %01100000
	defb %10000000
	defb %01000000
	defb %00100000
	defb %11000000
	defb %00000000

	; 't'
	defb 4		; width
	defb %01000000
	defb %11100000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %00100000
	defb %00000000

	; 'u'
	defb 4		; width
	defb %00000000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %11100000
	defb %00000000

	; 'v'
	defb 4		; width
	defb %00000000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %01000000
	defb %00000000

	; 'w'
	defb 4		; width
	defb %00000000
	defb %10100000
	defb %11100000
	defb %11100000
	defb %11100000
	defb %01000000
	defb %00000000

	; 'x'
	defb 4		; width
	defb %00000000
	defb %10100000
	defb %10100000
	defb %01000000
	defb %10100000
	defb %10100000
	defb %00000000

	; 'y'
	defb 4		; width
	defb %00000000
	defb %10100000
	defb %10100000
	defb %10100000
	defb %01100000
	defb %00100000
	defb %11000000

	; 'z'
	defb 4		; width
	defb %00000000
	defb %11100000
	defb %00100000
	defb %01000000
	defb %10000000
	defb %11100000
	defb %00000000

	; '{'
	defb 4		; width
	defb %00100000
	defb %01000000
	defb %01000000
	defb %10000000
	defb %01000000
	defb %01000000
	defb %00100000

	; '|'
	defb 4		; width
	defb %01000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %01000000
	defb %00000000

	; '}'
	defb 4		; width
	defb %10000000
	defb %01000000
	defb %01000000
	defb %00100000
	defb %01000000
	defb %01000000
	defb %10000000

	; '~'
	defb 4		; width
	defb %01010000
	defb %10100000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000

	; '(c)'
	defb 4		; width
	defb %11110000
	defb %10110000
	defb %11010000
	defb %11010000
	defb %10110000
	defb %11110000
	defb %00000000

	; '...'
	defb 4		; width
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %00000000
	defb %10100000
	defb %00000000

