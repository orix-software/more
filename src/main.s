
;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "fcntl.inc"

XMAINARGS = $2C
XGETARGV = $2E

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
; From stop-or-cont.s
.import StopOrCont

; From fgerts.s
.import fgets

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export _main

; Pour fgets
.export fpIn
.export linenum

;----------------------------------------------------------------------
;                       Segments vides
;----------------------------------------------------------------------
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
VERSION = $20232010
.define PROGNAME "more"

LINE_SIZE = 80

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		unsigned char buffer[LINE_SIZE]

		unsigned short _argv
		unsigned char _argc
		unsigned short argn

		unsigned short fpIn
		unsigned short linenum
		unsigned short linenum_start

		unsigned char fpause
		unsigned char ffilename

.popseg

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
		noarg_msg:
			.asciiz "Missing filename\r\n"
.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"



;----------------------------------------------------------------------
;
; Entrée:
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
.proc _main

	get_args:
		initmainargs _argv, _argc
		dec	_argc
		bne	main

		jsr	cmnd_version

		print	noarg_msg

		mfree	(_argv)

		rts

	main:
		getmainarg #1, (_argv), argn

		fopen	(argn), O_RDONLY,,fpIn
		cmp	#$ff
		bne	go
		cpx	#$ff
		beq	error

	go:
		lda	#$ff
		sta	fpause

		jsr	cmnd_more
		crlf

		mfree	(_argv)
		rts


	error:
		prints	"File not found: "
		print	(argn)
		crlf

		mfree	(_argv)
		rts
.endproc


;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;
; Variables:
;	Modifiées:
;		argn
;		ffilename
;		linenum
;		linenum_start
;		buffer
;
;	Utilisées:
;		fpause
;
; Sous-routines:
;	end_of_page
;	fgets
;	StopOrCont
;	strlen
;	print
;	cputc
;	crlf
;----------------------------------------------------------------------
.proc cmnd_more
		; Calcul de la longueur du nom du fichier
		strlen	(argn)
		cpy	#22

		; ffilename: 1-> len(argn)>=22, 0-> len(argn)<22
		lda	#$00
		rol
		sta	ffilename
		beq	set_linenum

		; Tronque le nom du fichier
		; Ajuste argn
		tya
		; Ici C=0
		sbc	#(19-1)
		; Ici C=1
		adc	argn
		sta	argn
		bcc	set_linenum
		inc	argn+1

	set_linenum:
		; On commnence la numérotation des lignes à 1
		lda	#$01
		sta	linenum
		sta	linenum_start
		lda	#$00
		sta	linenum+1
		sta	linenum_start+1

		cputc	$0c

	loop:
		lda	#<buffer
		ldy	#>buffer
		ldx	#LINE_SIZE
		jsr	fgets
		bcs	eof

		print	buffer
		crlf

		; On peut supprimer les 2 instructions suivantes si on force
		; fpause != 0
		jsr	StopOrCont
		bcs	break

		lda	fpause
		beq	loop
		jsr	end_of_page
		bcc	loop

		cmp	#$03
		bne	eof

	break:
		prints	"^C"
	eof:
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	print
;	crlf
;----------------------------------------------------------------------
.proc cmnd_version
		.out   .sprintf("%s version %x.%x - %x.%x", PROGNAME, (::VERSION & $ff0)>>4, (::VERSION & $0f), ::VERSION >> 16, (::VERSION & $f000)>>12)

		prints	.sprintf("%s version %x.%x - %x.%x", PROGNAME, (::VERSION & $ff0)>>4, (::VERSION & $0f), ::VERSION >> 16, (::VERSION & $f000)>>12)
		crlf

		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;
; Variables:
;	Modifiées:
;		linenum
;		linenum_start
;	Utilisées:
;		SCRY
;		ffilename
;		argn
; Sous-routines:
;	print
;	cgetc
;	cputc
;	PrintHexByte
;----------------------------------------------------------------------
.proc end_of_page
		; Fin de page atteinte?
		lda	SCRY
		cmp	#(SCREEN_YSIZE-1)
		bcc	end

		; Paper 7: Ink 0
		prints	"\x1bW\x1b@"

		; Affiche '...' davant le nom du fichier pour insiquer qu'il
		; est tronqué.
		lda	ffilename
		beq	full_fname

		prints	"..."

	full_fname:
		; Affiche le nom du fichier
		print	(argn)

		; Affiche les numéros de ligne de début et de fin de la page
		prints	" lines "

		lda	linenum_start+1
		jsr	PrintHexByte
		lda	linenum_start
		jsr	PrintHexByte

		cputc	'-'

		; Décommenter les deux sta si on n'autorise pas l'avance ligne par ligne
		lda	linenum+1
		; sta	linenum_start+1
		jsr	PrintHexByte
		lda	linenum
		; sta	linenum_start
		jsr	PrintHexByte

		cgetc
		pha

		; Efface la dernière ligne
		; print @0,27;chr(14)
		prints	"\x1f\x5b@\x0e"

		; Touche 'q'?
		pla
		cmp	#'q'
		beq	eof

		; [CTRL]+c?
		cmp	#$03
		beq	break

		; [ Si on autorise l'avance ligne par ligne
		; [RETURN]?
		cmp	#$0d
		bne	cls

		; Incrémente le numéro de ligne (BCD)
		sei
		sed
		; Ici C=1 à cause du cmp #$0d
		lda	linenum_start
		adc	#$00
		sta	linenum_start
		lda	linenum_start+1
		adc	#$00
		sta	linenum_start+1
		cld
		cli

		clc
		rts
		; ]

	cls:
		cputc	$0c
		; [ supprimer si on n'autorise pas l'avance ligne par ligne
		lda	linenum
		sta	linenum_start
		lda	linenum+1
		sta	linenum_start+1
		clc
		; ]

	end:
	break:
	eof:
		rts

.endproc
