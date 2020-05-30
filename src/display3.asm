;
; Program <<DISPLAY>>
; Pan, scale, and rotate contents of Points then display the contents of Lines
;

Page1		equ		$3e00			; graphics page 1
Page2		equ		$5700			; graphics page 2

ScreenWidth	equ		256 
ScreenHeight    equ		200 
BytesPerRow	equ		ScreenWidth/8 
ScreenBytes	equ		ScreenHeight*BytesPerRow 

		org		$7f00 
		setdp		*/$100 

DirectPage	equ		* 

Is6309		rmb		1 
X1		rmb		1			; 2-byte coordinates for two points
X1p		rmb		1 
Y1		rmb		1 
Y1p		rmb		1 
X2		rmb		1 
X2p		rmb		1 
Y2		rmb		1 
Y2p		rmb		1 
Slope		rmb		1 
Temp		rmb		1
Screen		fdb		Page1			; contains the address of the first byte of the presently unseen graphics screen--pre-initialized
Dirty		rmb		1 
Erase		rmb		1 

		org		$7000 

Points		rmb		9*26			; store three coords of three bytes each labeled a..z for the user
LastPoint	equ		*-9                     ; unused points have $80 in the first byte of each coordinate
Lines		rmb		121			; up to 30 pairs of points, last pair followed by -1, point l represented by 9*(asc(l)-asc(a))

; introductory housekeeping to disable basic interrupts and create new stack then restore environment for return to basic

Start		pshs		cc 
		orcc		#$50			; disable regular interrupt
		clr		$ff40			; turn off drive motor
		sta		$ffd7			; high speed
		lda		#DirectPage/$100 
		tfr		a,dp 

		ldb		#$ff 
		opt		6309 
		clrd			 	        ; executes as a $10 (ignored) $4f (clra) on a 6809
a@		stb		<Is6309 
		bne		b@ 
		ldmd		#1			; enable 6309 native mode
		opt		6809 
b@		leau		,s 
		lds		#DirectPage		; use high memory for hardware stack
		pshs		u 

		lda		#68 
		sta		$ff90 

		lda		#%10000000 	        ; graphics mode
		sta		$ff98 

		lda		#%00101000 	        ; 256x200x2
		sta		$ff99 

		clra					; black
		sta		$ff9a			; border
		sta		$ffb0			; palette 0
		lda		#63			; white
		sta		$ffb1			; palette 1

		bsr		Main 

		puls		u 
		leas		,u			; restore hardware stack
		sta		$ffd6 
		tst		<Is6309 
		bne		a@ 
		opt		6309 
		ldmd		#0 
		opt		6809 
a@		clra		
		tfr		a,dp 

		jsr		[$e002] 		; restore text mode
		puls		cc,pc 			; exit to BASIC

;
; main display loop. looks for a key commanding rotation, panning, or scaling.
;

Main		lda		#1 
		sta		<Dirty 
		clr		<Erase 

a@		tst		<Dirty 
		beq		b@ 
		clr		<Dirty 
		jsr		Display			; display the picture
b@		ldx		#CommandTable 
c@		lda		,x 
		sta		$ff02 
		lda		$ff00 
		coma		
		pshs		a 
		lda		1,x 
		ora		#%01000000 	        ; preserve shift
		anda		,s+ 
		cmpa		1,x 
		beq		e@ 
d@		leax		4,x 
		tst		,x 
		bne		c@ 
		bra		a@ 
e@		pshs		x 
		jsr		[2,X] 
		puls		x 
		inc		<Dirty 
		bra		d@ 

CommandTable    fdb	%0111111000001000,RotateX       ; x
		fdb	%0111111001001000,RotateXm 	; shift x
		fdb	%0111110100001000,RotateY       ; y
		fdb	%0111110101001000,RotateYm 	; shift y
		fdb	%0111101100001000,RotateZ       ; z
		fdb	%0111101101001000,RotateZm 	; shift z
		fdb	%1111011100001000,PanUp	        ; up arrow
		fdb	%1110111100001000,PanDown       ; down arrow
		fdb	%1101111100001000,PanLeft       ; left arrow
		fdb	%1011111100001000,PanRight      ; right arrow
		fdb	%1111101100000001,Bigger	; b
		fdb	%1111011100000100,Smaller	; s
		fdb	%1111111001000000,Toggle 	; spacebar
		fdb	%1111111000000001,Exit 	        ; @
		fcb		0		        ; end of table

Toggle		ldx		#5000			; debounce
a@		leax		-1,x 
		bne		a@ 
b@		lda		#%11111110 
		sta		$ff02 
		lda		$ff00 
		coma		
		anda		#%01000000 
		bne		b@ 

		com		<Erase 
		bne		a@ 
		jmp		ClearScreen 
a@		ldx		<Screen 
		cmpx		#Page1 
		beq		b@ 
		ldx		#Page1 
		ldd		#($70000+Page1)/8 
		bra		c@ 
b@		ldx		#Page2 
		ldd		#($70000+Page2)/8 
c@		stx		<Screen 
		std		$ff9d 
		rts		

Exit		leas		4,s 
		rts		

ClearScreen     tst		<Erase 
		bne		exit@ 
		tst		<Is6309 
		bne		a@ 
		opt		6309 
		ldx		<Screen 
		ldy		#zero@ 
		ldw		#ScreenBytes 
		tfm		y,X+ 
		opt		6809 
		bra		exit@ 
zero@		fcb		0 
a@		ldd		#0			; blank screen
		ldx		<Screen 
		leay		ScreenBytes,x 
		sty		c@+1 
		ldd		#0 
b@		std		,X++ 
		std		,X++ 
		std		,X++ 
		std		,X++ 
		std		,X++ 
		std		,X++ 
		std		,X++ 
		std		,X++ 
c@		cmpx		#0 
		bne		b@ 
exit@		rts		

;
; plot the current lines on the unseen graphics screen then display the screen
;

Display         bsr		ClearScreen 		
		ldu		#Lines 			; plot each line
a@		ldb		,U+ 
		cmpb		#$ff 
		beq		PageFlip 		; last point?
		clra		
		addd		#Points 
		tfr		d,y			; address of first point
		ldx		,y 
		stx		<X1 
		leay		3,y 
		ldx		,y 
		stx		<Y1 
		ldb		,U+ 
		clra		
		addd		#Points 
		tfr		d,y			; address of second point
		ldx		,y 
		stx		<X2 
		leay		3,y 
		ldx		,y 
		stx		<Y2 
		pshs		u 
		jsr		Line 
		puls		u 
		bra		a@

PageFlip	tst		<Erase 
		bne		skip@ 
		ldx		<Screen 
		cmpx		#Page1 
		beq		a@ 
		ldx		#Page1 
		ldd		#($70000+Page2)/8 
		bra		b@ 
a@		ldx		#Page2 
		ldd		#($70000+Page1)/8 
b@		std		$ff9d 
		stx		<Screen			; first byte of unseen video screen
skip@		rts		

PanLeft		ldx		#Points 
a@		lda		,x 
		cmpa		#$80 
		beq		b@ 
		ldd		,x			; get x coordinate and subtract 2
		subd		#2 
		std		,x 
		cmpa		#-$80 
		ble		c@			; point out of bounds
b@		leax		9,x 
		cmpx		#LastPoint 
		bls		a@ 
		rts		
c@		lda		,x			; since one point out of bounds, restore all points to original values
		cmpa		#$80 
		beq		d@
		lda		1,x 
		adda		#2 
		sta		1,x 
		lda		,x 
		adca		#0 
		sta		,x 
d@		leax		-9,x 
		cmpx		#Points 
		bhs		c@
		rts		

PanRight	ldx		#Points 
a@		lda		,x 
		cmpa		#$80 
		beq		b@			; if point undefined
		ldd		,x			; add 2 to x coordinate
		addd		#2 
		std		,x 
		cmpa		#$10 
		bge		c@			; point out of bounds
b@		leax		9,x 
		cmpx		#LastPoint 
		bls		a@ 
		rts		
c@		lda		,x			; since one point out of bounds, restore all points to  original values
		cmpa		#$80 
		beq		d@ 
		lda		1,x 
		suba		#2 
		sta		1,x 
		lda		,x 
		sbca		#0 
		sta		,x 
d@		leax		-9,x 
		cmpx		#Points 
		bhs		c@ 
		rts		

PanDown		ldx		#Points 
a@		lda		,x 
		cmpa		#$80 
		beq		b@			; if point undefined
		ldd		3,x			; subtract 2 from y coordinate
		subd		#2 
		std		3,x 
		cmpa		#-$10 
		ble		c@			; if point out of bounds
b@		leax		9,x 
		cmpx		#LastPoint 
		bls		a@ 
		rts		
c@		lda		,x			; since one point out of bounds, restore all points  to original values
		cmpa		#$80 
		beq		d@ 
		lda		4,x 
		adda		#2 
		sta		4,x 
		lda		3,x 
		adca		#0 
		sta		3,x 
d@		leax		-9,x 
		cmpx		#Points 
		bhs		c@ 
		rts		

PanUp		ldx		#Points 
a@		lda		,x 
		cmpa		#$80 
		beq		b@			; if point undefined
		ldd		3,x			; add 2 to y coordinate
		addd		#2 
		std		3,x 
		cmpa		#$10 
		bge		c@			; point out of bounds
b@		leax		9,x 
		cmpx		#LastPoint 
		bls		a@ 
		rts		
c@		lda		,x			; since one point out of bounds, restore all points  to original values
		cmpa		#$80 
		beq		d@ 
		lda		4,x 
		suba		#2 
		sta		4,x 
		lda		3,x 
		sbca		#0 
		sta		3,x 
d@		leax		-9,x 
		cmpx		#Points 
		bhs		c@ 
		rts		

RotateX		ldx		#Points 		; rotate positively about x axis
a@		lda		,x 
		cmpa		#$80			; check for undefined point
		beq		b@ 
		pshs		x 
		leax		3,x			; address of y-coordinate of current point
		leay		3,x			; address of z-coordinate of current point
		jsr		Rotate 
		puls		x 
		lda		3,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@			; point too big
		lda		6,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@ 
b@		leax		9,x			; get next point
		cmpx		#LastPoint 
		ble		a@ 
		rts		
c@		pshs		x			; undo rotations as  one point too large
		lda		,x 
		cmpa		#$80 
		beq		d@ 
		leay		3,x 
		leax		6,x 
		jsr		Rotate 
d@		puls		x 
		leax		-9,x 
		cmpx		#Points 
		bhs		c@ 
		rts		

RotateXm	ldx		#Points 		; rotate negatively about x axis
a@		lda		,x 
		cmpa		#$80			; check for undefined point
		beq		b@ 
		pshs		x 
		leay		3,x			; address of y-coordinate of current point
		leax		6,x			; address of z-coordinate of current point
		jsr		Rotate 
		puls		x 
		lda		3,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@			; point too big
		lda		6,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@ 
b@		leax		9,x			; get next point
		cmpx		#LastPoint 
		ble		a@ 
		rts		
c@		pshs		x			; undo rotations as  one point too large
		lda		,x 
		cmpa		#$80 
		beq		d@ 
		leax		3,x 
		leay		3,x 
		jsr		Rotate 
d@		puls		x 
		leax		-9,x 
		cmpx		#Points 
		bhs		c@ 
		rts		

RotateY		ldx		#Points 		; rotate positively about y axis
a@		lda		,x 
		cmpa		#$80			; check for undefined point
		beq		b@ 
		pshs		x 
		leay		,x			; address of x-coordinate of current point
		leax		6,x			; address of z-coordinate of current point
		jsr		Rotate 
		puls		x 
		lda		,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@			; point too big
		lda		6,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@ 
b@		leax		9,x			; get next point
		cmpx		#LastPoint 
		ble		a@ 
		rts		
c@		pshs		x			; undo rotations as  one point too large
		lda		,x 
		cmpa		#$80 
		beq		d@ 
		leay		6,x 
		jsr		Rotate 
d@		puls		x 
		leax		-9,x 
		cmpx		#Points 
		bhs		c@ 
		rts		

RotateYm	ldx		#Points 		; rotate negatively about y axis
a@		lda		,x 
		cmpa		#$80			; check for undefined point
		beq		b@ 
		pshs		x 
		leay		6,x			; address of z-coordinate of current point--x contains x-coord
		jsr		Rotate 
		puls		x 
		lda		,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@			; point too big
		lda		6,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@ 
b@		leax		9,x			; get next point
		cmpx		#LastPoint 
		ble		a@ 
		rts		
c@		pshs		x			; undo rotations as  one point too large
		lda		,x 
		cmpa		#$80 
		beq		d@ 
		leay		,x 
		leax		6,x 
		jsr		Rotate 
d@		puls		x 
		leax		-9,x 
		cmpx		#Points 
		bhs		c@ 
		rts		

RotateZ		ldx		#Points 		; rotate positively about z axis
a@		lda		,x 
		cmpa		#$80			; check for undefined point
		beq		b@ 
		pshs		x 
		leay		3,x			; address of y-coordinate of current point--x has x-coordinate
		jsr		Rotate 
		puls		x 
		lda		,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@			; point too big
		lda		3,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@ 
b@		leax		9,x			; get next point
		cmpx		#LastPoint 
		ble		a@ 
		rts		
c@		pshs		x			; undo rotations as  one point too large
		lda		,x 
		cmpa		#$80 
		beq		d@ 
		leay		,x 
		leax		3,x 
		jsr		Rotate 
d@		puls		x 
		leax		-9,x 
		cmpx		#Points 
		bhs		c@ 
		rts		

RotateZm	ldx		#Points 		; rotate negatively about z axis
a@		lda		,x 
		cmpa		#$80			; check for undefined point
		beq		b@ 
		pshs		x 
		leay		,x			; address of x-coordinate of current point
		leax		3,x			; address of y-coordinate of current point
		jsr		Rotate 
		puls		x 
		lda		,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@			; point too big
		lda		3,x 
		cmpa		#$10 
		bge		c@ 
		cmpa		#-$10 
		ble		c@ 
b@		leax		9,x			; get next point
		cmpx		#LastPoint 
		ble		a@ 
		rts		
c@		pshs		x			; undo rotations as  one point too large
		lda		,x 
		cmpa		#$80 
		beq		d@ 
		leay		3,x 
		jsr		Rotate 
		puls		x 
d@		leax		-9,x 
		cmpx		#Points 
		bhs		c@ 
		rts		

;
; rotate around an axis as follows:  x = coord pointed at by x-reg, y=coord pointed at by y-reg
; x,y=(127/128)x-(1/8)y,(1/8)x+127/128)y
;

Rotate		leau		-6,s 
		ldd		,x 
		std		,u 
		std		3,u 
		lda		2,x 
		sta		2,u 
		sta		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		lda		2,u 
		suba		5,u 
		sta		2,u 
		lda		1,u 
		sbca		4,u 
		sta		1,u 
		lda		,u 
		sbca		3,u 
		sta		,u 
		ldd		,y 
		std		3,u 
		lda		2,y 
		sta		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		lda		2,u 
		suba		5,u 
		sta		2,u 
		lda		1,u 
		sbca		4,u 
		sta		1,u 
		lda		,u 
		sbca		3,u 
		sta		,u 
		ldd		,u 
		std		,x 
		lda		2,u 
		sta		2,x 
		ldd		,y 
		std		3,u 
		lda		2,y 
		sta		5,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		ldd		1,u 
		addd		4,u 
		std		1,u 
		lda		,u 
		adca		3,u 
		sta		,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		asr		3,u 
		ror		4,u 
		ror		5,u 
		ldd		1,u 
		addd		4,u 
		std		1,u 
		lda		,u 
		adca		3,u 
		sta		,u 
		ldd		,u 
		std		,y 
		lda		2,u 
		sta		2,y 
		rts		

;
; make the object 1/32 bigger
;

Bigger		ldx		#Points 
a@		lda		,x			; check if point is defined
		cmpa		#$80 
		beq		b@ 
		bsr		Expand			; increase all three coordinates
		leax		3,x 
		bsr		Expand 
		leax		3,x 
		bsr		Expand 
		leax		-6,x 
		leay		,x			; chec if any of 3 coords too big
		bsr		TooBig 
		bge		c@ 
		leay		3,y 
		bsr		TooBig 
		bge		c@ 
		leay		3,y 
		bsr		TooBig 
		bge		c@ 
b@		leax		9,x			; get next point
		cmpx		#LastPoint 
		ble		a@ 
		rts		
c@		lda		,x			; restore points if one made out of bounds
		cmpa		#$80 
		bne		d@ 
		leax		-9,x 
		bra		e@ 
d@		jsr		Shrink 
		leax		3,x 
		jsr		Shrink 
		leax		3,x 
		jsr		Shrink 
		leax		-$f,x 
e@		cmpx		#Points 
		bhs		c@ 
		rts		

Expand		leau		-3,s			; make one coordinate 1/32 bigger
		ldd		,x 
		std		,u 
		lda		2,x 
		sta		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		ldd		1,x 
		addd		1,u 
		std		1,x 
		lda		,x 
		adca		,u 
		sta		,x 
		rts		

TooBig		lda		,y			; check if a coordinate too big--if first byte >= $80 or <= -$80
		cmpa		#$10 
		bge		a@
		nega		
		cmpa		#$10 
a@		rts					; bge will go if number loaded into a was >=$10 or <=-$10

;
; make the object 1/32 smaller
;

Smaller		ldx		#Points 
a@		lda		,x			; check if point is defined
		cmpa		#$80 
		beq		b@ 
		bsr		Shrink 
		leax		3,x 
		bsr		Shrink 
		leax		3,x 
		bsr		Shrink 
		leax		3,x 
		bra		c@ 
b@		leax		9,x			; get next point
c@		cmpx		#LastPoint 
		ble		a@

; check for line segment length < 1 -- if one found, restore points to original values

		ldu		#Lines 
a@		clra		
		ldb		,U+ 
		cmpb		#$ff 
		beq		exit@			; last line segment tested
		addd		#Points 
		tfr		d,x			; address of first point
		clra		
		ldb		,U+ 
		addd		#Points 
		tfr		d,y			; address of second point
		ldd		,x 
		cmpd		,y			; test first coord
		bne		a@			; integer parts not equal
		ldd		3,x 
		cmpd		3,y 
		bne		a@			; integer parts of second coord not equal
		ldd		6,x 
		cmpd		6,y 
		bne		a@			; integer parts of third coord not equal
		jmp		Bigger 			; all components of line segment have equal integer parts, so undo smaller and rts from bigger
exit@		rts					; all line segments checked and long enough

Shrink		leau		-3,s 
		ldd		,x 
		std		,u 
		lda		2,x 
		sta		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		asr		,u 
		ror		1,u 
		ror		2,u 
		ldd		1,x 
		subd		1,u 
		std		1,x 
		lda		,x 
		sbca		,u 
		sta		,x 
		rts		

Top		equ		$5f			; limits of virtual screen
Bottom		equ		-$60-8 
Left		equ		-$80 
Right		equ		$7f 

LineExit	rts
NoLine		puls		x,y,pc

;
; draw a line. x1,x2 to y1,y2 - coordinates are signed 16 bit integers, visible screen is -128 to 127, -95 to 95 on usual x,y graph
;

Line		ldd		<X2 			; make sure x1<x2 or reverse coordinates
		cmpd		<X1 
		bge		a@ 
		ldx		<X1 
		std		<X1 
		stx		<X2 
		ldx		<Y1 
		ldy		<Y2 
		stx		<Y2 
		sty		<Y1 
a@		ldd		<Y2                     ; check for sign of slope
		cmpd		<Y1 
		lblt		LineNS			; draw line with a negative slope

;
; draw line with a positive slope
;

		ldd		<X1                     ; check for no visible line
		cmpd		#Right 
		bge		LineExit 
		ldd		<Y1 
		cmpd		#Top 
		bge		LineExit 
		ldd		<X2 
		cmpd		#Left 
		ble		LineExit 
		ldd		<Y2 
		cmpd		#Bottom 
		ble		LineExit 

		ldd		<X1 			; check if must clip left end of line
		cmpd		#Left 
		blt		a@
		ldd		<Y1 
		cmpd		#Bottom 
		bge		h@ 
a@		ldx		<X2                     ; clip left end of line
		ldy		<Y2 
		pshs		x,y 
b@		ldd		<X1			; x=(x1+x2)/2
		addd		<X2 
		asra		
		rorb		
		tfr		d,x 
		ldd		<Y1			; y=(y1+y2)/2
		addd		<Y2 
		asra		
		rorb		
		tfr		d,y 
		cmpx		#Left 
		bgt		c@ 
		cmpy		#Top 
		bge		NoLine			; no visible line
c@		cmpx		#Right 
		blt		d@ 
		cmpy		#Bottom 
		ble		NoLine			; no visible line
d@		cmpx		#Left 
		blt		e@ 
		cmpy		#Bottom 
		bge		f@ 
e@		stx		<X1			; replace left point by midpoint and repeat
		sty		<Y1 
		bra		b@ 
f@		cmpx		#Left 
		ble		g@ 
		cmpy		#Bottom 
		ble		g@ 
		stx		<X2			; replace right point by midpoint
		sty		<Y2 
		bra		b@ 
g@		stx		<X1			; x1,y1 now on left or bottom boundary
		sty		<Y1 
		puls		x,y			; recover original right point
		stx		<X2 
		sty		<Y2 
h@		ldd		<X2 			; check if must clip right end of line
		cmpd		#Right 
		bgt		i@ 
		ldd		<Y2 
		cmpd		#Top 
		ble		n@ 
i@		ldx		<X1 			; clip right end of line
		ldy		<Y1 
		pshs		x,y 
j@		ldd		<X1			; x=(x1+x2)/2
		addd		<X2 
		asra		
		rorb		
		tfr		d,x 
		ldd		<Y1			; y=(y1+y2)/2
		addd		<Y2 
		asra		
		rorb		
		tfr		d,y 
		cmpx		#Right 
		bgt		k@
		cmpy		#Top 
		ble		l@
k@		stx		<X2			; move right point to midpoint and repeat
		sty		<Y2 
		bra		j@ 
l@		cmpx		#Right 
		bge		m@
		cmpy		#Top 
		bge		m@ 
		stx		<X1			; move left point to midpoint and repeat
		sty		<Y1 
		bra		j@ 
m@		stx		<X2			; move x2,y2 to top or right boundary, recover x1,y1
		sty		<Y2 
		puls		x,y 
		stx		<X1 
		sty		<Y1 
n@		lda		<X2p			; decide if slope > 1
		suba		<X1p 			; x1p, etc hold correct one-byte signed values for the coordinates, which are now on the virtual screen
		pshs		a 
		ldb		<Y2p 
		subb		<Y1p 
		cmpb		,S+ 
		blo		p@ 
;
; draw a line with positive slope >=1
;
		pshs		b			; save number of points on line - 1
		jsr		GetSlope		; slope = dx/dy, an 8-bit fraction
		jsr		GetScreen		; set x,u to point to byte and bit on graphics screen corresp. to x1,y1
		puls		b 
		clra		
		tfr		d,y 
		leay		1,y			; y=#points on line
		clrb		
o@		lda		,x			; set the points on the graphics screen for the line
		ora		,u			; get the byte and or in the bit
		sta		,x 
		leay		-1,y			; reduce point count
		lbeq		LineExit 
		leax		-BytesPerRow,x 		; increase y-coordinate by 1
		addb		<Slope			; increase x-coordinate by slope (a fraction)
		bcc		o@			; b=x mod 1
		leau		1,u			; increase x-coordinate by 1
		cmpu		#LastBit		; try to move right one bit
		bls		o@ 
		ldu		#BitTable		; else use next byte and left bit
		leax		1,x 
		bra		o@ 
;
; draw line with positive slope <1
;
p@		pshs		a			; save # of points on line - 1
		exg		a,b 
		jsr		GetSlope		; slope = dy/dx
		jsr		GetScreen		; x,u are byte and bit corresp. to x1,y1
		puls		b 
		clra		
		tfr		d,y 
		leay		1,y			; y=#points on line
		clrb		
q@		lda		,x			; draw the line
		ora		,u			; get the byte, or in  the bit
		sta		,x 
		leay		-1,y			; reduce the point count
		beq		LineExit2 
		leau		1,u			; move one bit to right
		cmpu		#LastBit		; if possible
		bls		r@ 
		leax		1,x			; else move to next byte and first bit
		ldu		#BitTable 
r@		addb		<Slope 
		bcc		q@			; no overflo to next integer when adding slope to y
		leax		-BytesPerRow,x 		; else add 1 to y-coordinate
		bra		q@ 

LineExit2	rts
NoLine2		puls		x,y,pc

;
; draw line with negative slope
;

LineNS		ldd		<X1 			; check for no visible line
		cmpd		#Right 
		bge		LineExit2
		ldd		<Y1 
		cmpd		#Bottom 
		ble		LineExit2
		ldd		<X2 
		cmpd		#Left 
		ble		LineExit2
		ldd		<Y2 
		cmpd		#Top 
		bge		LineExit2

		ldd		<X1 			; check if must clip left end of line
		cmpd		#Left 
		blt		a@ 
		ldd		<Y1 
		cmpd		#Top 
		ble		h@ 
a@		ldx		<X2 			; clip left end of line
		ldy		<Y2 
		pshs		x,y 
b@		ldd		X1			; x=(x1+x2)/2
		addd		<X2 
		asra		
		rorb		
		tfr		d,x 
		ldd		Y1			; y=(y1+y2)/2
		addd		<Y2 
		asra		
		rorb		
		tfr		d,y 
		cmpx		#Left 
		bgt		c@ 
		cmpy		#Bottom 
		ble		NoLine2			; no visible line
c@		cmpx		#Right 
		blt		d@ 
		cmpy		#Top 
		bge		NoLine2			; no visible line
d@		cmpx		#Left 
		blt		e@ 
		cmpy		#Top 
		ble		f@ 
e@		stx		<X1			; replace left point by midpoint and repeat
		sty		<Y1 
		bra		b@ 
f@		cmpx		#Left 
		ble		g@ 
		cmpy		#Top 
		bge		g@ 
		stx		<X2			; replace right point by midpoint
		sty		<Y2 
		bra		b@ 
g@		stx		<X1			; x1,y1 now on left or bottom boundary
		sty		<Y1 
		puls		x,y			; recover original right point
		stx		<X2 
		sty		<Y2 
h@		ldd		<X2 			; check if must clip right end of line
		cmpd		#Right 
		bgt		i@ 
		ldd		<Y2 
		cmpd		#Bottom 
		bge		n@ 
i@		ldx		<X1 			; clip right end of line
		ldy		<Y1 
		pshs		x,y 
j@		ldd		<X1			; x=(x1+x2)/2
		addd		<X2 
		asra		
		rorb		
		tfr		d,x 
		ldd		<Y1			; y=(y1+y2)/2
		addd		<Y2 
		asra		
		rorb		
		tfr		d,y 
		cmpx		#Right 
		bgt		k@ 
		cmpy		#Bottom 
		bge		l@ 
k@		stx		<X2			; move right point to midpoint and repeat
		sty		<Y2 
		bra		j@ 
l@		cmpx		#Right 
		bge		m@ 
		cmpy		#Bottom 
		ble		m@ 
		stx		<X1			; move left point to midpoint and repeat
		sty		<Y1 
		bra		j@ 
m@		stx		<X2			; move x2,y2 to top or right boundary, recover x1,y1
		sty		<Y2 
		puls		x,y 
		stx		<X1 
		sty		<Y1 
n@		lda		<X2p			; decide if slope > 1
		suba		<X1p 			; x1p, etc hold correct one-byte signed values for the coordinates, which are now on the virtual screen
		pshs		a 
		ldb		<Y1p 
		subb		<Y2p 
		cmpb		,S+ 
		blo		p@ 
;
; draw a line with negative slope <= -1
;
		pshs		b			; save number of points on line - 1
		jsr		GetSlope		; slope = -dx/dy, an 8-bit fraction
		jsr		GetScreen		; set x,u to point to byte and bit on graphics screen corresp. to x1,y1
		puls		b 
		clra		
		tfr		d,y 
		leay		1,y			; y=#points on line
		clrb		
o@		lda		,x			; set the points on the graphics screen for the line
		ora		,u			; get the byte and or in the bit
		sta		,x 
		leay		-1,y			; reduce point count
		lbeq		LineExit 
		leax		BytesPerRow,x 		; decrease y-coordinate by 1
		addb		<Slope			; increase x-coordinate by slope (a fraction)
		bcc		o@			; b=x mod 1
		leau		1,u			; increase x-coordinate by 1
		cmpu		#LastBit		; try to move right one bit
		bls		o@ 
		ldu		#BitTable		; else use next byte and left bit
		leax		1,x 
		bra		o@ 
;
; draw line with negative slope > -1
;
p@		pshs		a			; save # points on line - 1
		exg		a,b 
		jsr		GetSlope		; slope = -dy/dx
		jsr		GetScreen		; x,u are byte and bit corresp. to x1,y1
		puls		b 
		clra		
		tfr		d,y 
		leay		1,y			; y=#points on line
		clrb		
q@		lda		,x			; draw the line
		ora		,u			; get the byte, or in  the bit
		sta		,x 
		leay		-1,y			; reduce the point count
		beq		s@ 
		leau		1,u			; move one bit to the right
		cmpu		#LastBit		; if possible
		bls		r@ 
		leax		1,x			; else move to next byte and first bit
		ldu		#BitTable 
r@		addb		<Slope 
		bcc		q@			; no overflow to next integer when adding slope to y
		leax		BytesPerRow,x 		; else subtract 1 from y-coordinate
		bra		q@ 
s@		rts

;
; assume a<b contain unsigned integers, put a/b into slope
;

GetSlope	stb		<Temp
		clrb		
		ldx		#8 
a@		aslb		
		asla		
		bcs		b@ 
		cmpa		<Temp
		blo		c@ 
b@		suba		<Temp
		incb		
c@		leax		-1,x 
		bne		a@ 
		stb		<Slope
		rts

;
; find byte x and bit (u) on graphics screen corresponding to x1,y1
; x=<SCREEN+y1*32+x1div8 and u=#bits+x1mod8
; we use <Screen+y1*(256/8)+x1div8 for x, and as we divide x1 by three successive 2's, we pick up the bits for modifying u.
;

GetScreen	ldx		<Screen 
		lda		#95 
		suba		<Y1p 
		ldb		#BytesPerRow 
		mul		
		leax		d,x 
		ldb		<X1p 
		addb		#$80 
		tfr		b,a 
		lsrb		
		lsrb		
		lsrb		
		abx		
		anda		#7 
		ldu		#BitTable
		leau		a,u 
		rts		

BitTable	fcb		$80			; for setting points on graphics screen
		fcb		$40 
		fcb		$20 
		fcb		$10 
		fcb		$8 
		fcb		$4 
		fcb		$2 
LastBit		fcb		$1 

		end		Start
