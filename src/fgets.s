;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "errno.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import fpIn
.import linenum

; From debug
.import PrintHexByte

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export fgets
.export buffer_reset

;.export linenum

.export fpos_text

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
e1 = $e1

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		unsigned short address

.popseg

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		; Numéro de ligne du fichier
		; unsigned char linenum[2]

		unsigned char max_line_size

		unsigned long fpos_text

.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	AY: Adresse du tampon
;	X : Taille du tampon
;
; Sortie:
;	A  : 0 ou code erreur
;	X  : Modifié
;	Y  : 0
;	C=0: Ok
;	C=1: Erreur
;
; Variables:
;       Modifiées:
;               address
;		max_line_size
;       Utilisées:
;               -
; Sous-routines:
;       fgetc
;----------------------------------------------------------------------
.proc fgets
		sta	address
		sty	address+1
		stx	max_line_size

		; Incrémeente le numéro de ligne
		;php
		sed
		clc
		lda	linenum
		adc	#$01
		sta	linenum
		lda	linenum+1
		adc	#$00
		sta	linenum+1
		cld
		;plp

	loop:
		; fread	(address), #1, 1, fp
		; cmp	#$01
		; bne	eof
		jsr	fgetc
		bcs	eof

		; En principe on ne peut pas avoir de caractère $00 dans un fichier texte
		ldy	#$00
		lda	(address),y
		beq	end

		; <CR>? il faut lire un autre caractère (msdos: <CR><LF>)
		cmp	#$0d
		beq	loop

		; <LF>?
		cmp	#$0a
		beq	end

		dec	max_line_size
		beq	errMemFull

		inc	address
		bne	loop
		inc	address+1
		bne	loop

	errMemFull:
		prints	"Line too long "
		lda	linenum+1
		jsr	PrintHexByte
		lda	linenum
		jsr	PrintHexByte
		crlf
		lda	#e1
		bne	error

	end:
		; Y=0 => place un caractère nul à la place du <CR>
		tya
		sta	(address),y

		; Si ECHO ON
		; print	(address)
		; crlf

		ldx	max_line_size
		clc
		rts

	eof:
		; print	eof_msg
		lda	#$e4

	error:
		sec
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
;
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc fgetc
		ldx	buffer_pos
		cpx	buffer_size
		bcc	getc

		jsr	fill_buffer
		cpx	buffer_size
		beq	eof

	getc:
		ldy	#$00
		lda	buffer,x
		sta	(address),y
		inc	buffer_pos

		; Incrémente le pointeur du fichier pour Goto
		inc	fpos_text
		bne	end
		inc	fpos_text+1
		bne	end
		inc	fpos_text+2
		bne	end
		inc	fpos_text+3
		; beq	overFlow
	end:
	eof:
		rts

	fill_buffer:
		; Le ch376 ne peut lire que 254 octets en une seule fois
		fread	buffer, #$fe, 1, fpIn
		; cmp	#$fe
		; bne	eof

		sta	buffer_size

		ldx	#$00
		stx	buffer_pos

		; clc
		rts

	; eof:
		; rts

	buffer_pos: .byte	$00
	buffer_size: .byte	$00
	buffer: .res	256;0

.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
;
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc buffer_reset
		lda	#$00
		sta	fgetc::buffer_pos
		sta	fgetc::buffer_size
		rts
.endproc


