*
* PROGRAM <<DISPLAY>>
* PAN, SCALE, AND ROTATE CONTENTS OF *POINTS* THEN DISPLAY THE CONTENTS OF *LINES*
*

PAGE1	equ	$4000	; graphics page 1
PAGE2	equ	$5800	; graphics page 2

	org	$f3	; 13 bytes free

Is6309	rmb	1
X1	rmb	1	2-BYTE COORDINATES FOR TWO POINTS
X1P	rmb	1
Y1	rmb	1
Y1P	rmb	1
X2	rmb	1
X2P	rmb	1
Y2	rmb	1
Y2P	rmb	1
SLOPE	rmb	1
TL	fdb	PAGE1	CONTAINS THE ADDRESS OF THE FIRST BYTE OF THE PRESENTLY UNSEEN GRAPHICS SCREEN--PRE-INITIALIZED
DIRTY	rmb	1	

	org	$7000

*
* BASIC DATA STRUCTURES--THE POINTS AND LINES TO BE DRAWN. POINTS MAINTAINS THE COORDINATES OF THE POINTS
*
POINTS	rmb	9*26	STORE THREE COORDS OF THREE BYTES EACH LABELED A..Z FOR THE USER
* UNUSED POINTS HAVE $80 IN THE FIRST BYTE OF EACH COORDINATE
LINES	rmb	121	UP TO 30 PAIRS OF POINTS, LAST PAIR FOLLOWED BY -1, POINT L REPRESENTED BY 9*(ASC(L)-ASC(A))

*
* INTRODUCTORY HOUSEKEEPING TO DISABLE BASIC INTERRUPTS AND CREATE NEW STACK THEN RESTORE ENVIRONMENT FOR RETURN TO BASIC
*

	opt	6309
	pshs	cc
	orcc	#$50		DISABLE REGULAR INTERRUPT
	clr	$ff40		TURN OFF DRIVE MOTOR
	sta	$ffd7		HIGH SPEED
	ldb	#$ff 
	clrd			executes as a $10 (ignored) $4f (clra) on a 6809
a@	stb	<Is6309
	bne	b@
	ldmd	#1		enable 6309 native mode
b@	leau	,S
	lds	#$8000		USE HIGH MEMORY FOR HARDWARE STACK
	pshs	U
	jsr	MAIN
	puls	U
	leas	,U		RESTORE HARDWARE STACK
	sta	$ffd6
	tst	<Is6309
	bne	c@
	ldmd	#0
c@	puls	cc,pc
	rts
	opt	6809 

*
* MAIN DISPLAY LOOP--LOOKS FOR A KEY COMMANDING ROTATION, PANNING, OR SCALING AND ORDERS SAME. INCLUDES AUTO REPEAT
*

MAIN	sta	$FFC0		SET VDG = 110
	sta	$FFC3
	sta	$FFC5
	lda	$FF22		SET HI BITS CONTROL REGISTER = $F0
	anda	#7
	ora	#$F0
	sta	$FF22
	lda	#1
	sta	<DIRTY

a@	tst	<DIRTY
	beq	b@
	clr	<DIRTY
	jsr	DISPLA		DISPLAY THE PICTURE
b@	ldx	#CommandTable
c@	lda	,x
	sta	$ff02
	lda	$ff00
	coma
	pshs	a
	lda	1,x
	ora	#%01000000	PRESERVE SHIFT
	anda	,s+
	cmpa	1,x
	beq	e@
d@	leax	4,x
	tst	,x
	bne	c@
	bra	a@
e@	pshs	x
	jsr	[2,x]
	puls	x
	inc	<DIRTY
	bra	d@

CommandTable:
	fdb	%0111111000001000,ROTX		X
	fdb	%0111111001001000,ROTMX		SHIFT X
	fdb	%0111110100001000,ROTY		Y
	fdb	%0111110101001000,ROTMY		SHIFT Y
	fdb	%0111101100001000,ROTZ		Z
	fdb	%0111101101001000,ROTMZ		SHIFT Z
	fdb	%1111011100001000,PANU		UP ARROW
	fdb	%1110111100001000,PAND		DOWN ARROW
	fdb	%1101111100001000,PANL		LEFT ARROW
	fdb	%1011111100001000,PANR		RIGHT ARROW
	fdb	%1111101100000001,BIGGER	B
	fdb	%1111011100000100,SMALLR	S
	fdb	%1111111000000001,EXIT		@
	fcb	0				END OF TABLE

EXIT	leas	4,s
	rts

*
* CREATE A PICTURE USING CURRENT POINTS AND LINES ON THE UNSEEN GRAPHICS SCREEN THEN DISPLAY THAT SCREEN
*

*
* PLOT THE CURRENT LINES ON THE UNSEEN GRAPHICS SCREEN THEN DISPLAY THE SCREEN
*

DISPLA  tst	<Is6309
	bne	a@
	opt	6309
	ldx	<TL
	ldy	#zero@
	ldw	#6144
	tfm	y,x+
	bra	z@
zero@   fcb     0
	opt	6809
a@	ldd	#0		BLANK SCREEN
	ldx	<TL
	leay	6144,x
	sty	c@+1
	ldd	#0
b@	std	,x++
	std	,x++
	std	,x++
	std	,x++
c@	cmpx	#0
	bne	b@
z@

*
* PLOT EACH LINE
*
	ldu	#LINES
DISP3	ldb	,U+
	cmpb	#$FF
	beq	DISP2		LAST POINT?
	clra
P1300
	addd	#POINTS
	tfr	D,Y		ADDRESS OF FIRST POINT
	ldx	,Y
	stx	<X1
	leay	3,Y
	ldx	,Y
	stx	<Y1
	ldb	,U+
	clra
	addd	#POINTS
	tfr	D,Y		ADDRESS OF SECOND POINT
	ldx	,Y
	stx	<X2
	leay	3,Y
	ldx	,Y
	stx	<Y2
	pshs	U
	jsr	LINE
	puls	U
	bra	DISP3
*
* SWITCH SCREENS TO SHOW NEW PICTURE
*

DISP2	lda	$ff03
	bpl	DISP2		VSYNC
	ldx	<TL
	cmpx	#PAGE1
	beq	DISP4
	sta	$FFD4
	sta	$FFC6		VIDEO OFFSET = $5800/$200=0010 1100
	sta	$FFC8
	sta	$FFCA+1
	sta	$FFCC+1
	sta	$FFCE
	sta	$FFD0+1
	sta	$FFD2
	ldx	#PAGE1
	stx	<TL		SET TL = FIRST BYTE OF UNUSED SCREEN
	rts
DISP4
	sta	$FFC6		VIDEO OFFSET=$4000/$200=0010 0000
	sta	$FFC8
	sta	$FFCA
	sta	$FFCC
	sta	$FFCE
	sta	$FFD0+1
	sta	$FFD2
	ldx	#PAGE2
	stx	<TL		FIRST BYTE OF UNSEEN VIDEO SCREEN
	rts
*
* ROUTINES TO MOVE POINTS
*
*
* PAN LEFT
*
LASTPT	set	POINTS+$9*$19
PANL	ldx	#POINTS
PANL2	lda	,X
	cmpa	#$80
	beq	PANL1
	ldd	,X		GET X COORDINATE AND SUBTRACT 2
	subd	#2
	std	,X
	cmpa	#-$80
	ble	PANL4		POINT OUT OF BOUNDS
PANL1	leax	9,X
	cmpx	#LASTPT
	bls	PANL2
	rts
PANL4	lda	,X		SINCE ONE POINT OUT OF BOUNDS, RESTORE ALL POINTS TO ORIGINAL VALUES
	cmpa	#$80
	beq	PANL5
	lda	1,X
	adda	#2
	sta	1,X
	lda	,X
	adca	#0
	sta	,X
PANL5	leax	-9,X
	cmpx	#POINTS
	bhs	PANL4
	rts
*
* PAN RIGHT
*
PANR	ldx	#POINTS
PANR2	lda	,X
	cmpa	#$80
	beq	PANR1		IF POINT UNDEFINED
	ldd	,X		ADD 2 TO X COORDINATE
	addd	#2
	std	,X
	cmpa	#$10
	bge	PANR4		POINT OUT OF BOUNDS
PANR1	leax	9,X
	cmpx	#LASTPT
	bls	PANR2
	rts
PANR4	lda	,X		SINCE ONE POINT OUT OF BOUNDS, RESTORE ALL POINTS TO  ORIGINAL VALUES
	cmpa	#$80
	beq	PANR5
	lda	1,X
	suba	#2
	sta	1,X
	lda	,X
	sbca	#0
	sta	,X
PANR5	leax	-9,X
	cmpx	#POINTS
	bhs	PANR4
	rts
*
* PAN DOWN
*
PAND	ldx	#POINTS
PAND2	lda	,X
	cmpa	#$80
	beq	PAND1		IF POINT UNDEFINED
	ldd	3,X		SUBTRACT 2 FROM Y COORDINATE
	subd	#2
	std	3,X
	cmpa	#-$10
	ble	PAND4		IF POINT OUT OF BOUNDS
PAND1	leax	9,X
	cmpx	#LASTPT
	bls	PAND2
	rts
PAND4	lda	,X		SINCE ONE POINT OUT OF BOUNDS, RESTORE ALL POINTS  TO ORIGINAL VALUES
	cmpa	#$80
	beq	PAND5
	lda	4,X
	adda	#2
	sta	4,X
	lda	3,X
	adca	#0
	sta	3,X
PAND5	leax	-9,X
	cmpx	#POINTS
	bhs	PAND4
	rts
*
* PAN UP
* 
PANU	ldx	#POINTS
PANU2	lda	,X
	cmpa	#$80
	beq	PANU1	IF POINT UNDEFINED
	ldd	3,X	ADD 2 TO Y COORDINATE
	addd	#2
	std	3,X
	cmpa	#$10
	bge	PANU4	POINT OUT OF BOUNDS
PANU1	leax	9,X
	cmpx	#LASTPT
	bls	PANU2
	rts
PANU4	lda	,X	SINCE ONE POINT OUT OF BOUNDS, RESTORE ALL POINTS  TO ORIGINAL VALUES
	cmpa	#$80
	beq	PANU5
	lda	4,X
	suba	#2
	sta	4,X
	lda	3,X
	sbca	#0
	sta	3,X
PANU5	leax	-9,X
	cmpx	#POINTS
	bhs	PANU4
	rts
*
* ROTATE POSITIVELY ABOUT X AXIS
*
ROTX	ldx	#POINTS
ROTX1	lda	,X
	cmpa	#$80	CHECK FOR UNDEFINED POINT
	beq	ROTX2
	pshs	X
	leax	3,X	ADDRESS OF Y-COORDINATE OF CURRENT POINT
	leay	3,X	ADDRESS OF Z-COORDINATE OF CURRENT POINT
	jsr	ROTATE
	puls	X
	lda	3,X
	cmpa	#$10
	bge	ROTX3
	cmpa	#-$10
	ble	ROTX3	POINT TOO BIG
	lda	6,X
	cmpa	#$10
	bge	ROTX3
	cmpa	#-$10
	ble	ROTX3
ROTX2	leax	9,X	GET NEXT POINT
	cmpx	#LASTPT
	ble	ROTX1
	rts
ROTX3	pshs	X	UNDO ROTATIONS AS  ONE POINT TOO LARGE
	lda	,X
	cmpa	#$80
	beq	RX
	leay	3,X
	leax	6,X
	jsr	ROTATE
RX	puls	X
	leax	-9,X
	cmpx	#POINTS
	bhs	ROTX3
	rts
*
* ROTATE NEGATIVELY ABOUT X AXIS
*
ROTMX	ldx	#POINTS
ROTMX1	lda	,X
	cmpa	#$80	CHECK FOR UNDEFINED POINT
	beq	ROTMX2
	pshs	X
	leay	3,X	ADDRESS OF Y-COORDINATE OF CURRENT POINT
	leax	6,X	ADDRESS OF Z-COORDINATE OF CURRENT POINT
	jsr	ROTATE
	puls	X
	lda	3,X
	cmpa	#$10
	bge	ROTMX3
	cmpa	#-$10
	ble	ROTMX3	POINT TOO BIG
	lda	6,X
	cmpa	#$10
	bge	ROTMX3
	cmpa	#-$10
	ble	ROTMX3
ROTMX2	leax	9,X	GET NEXT POINT
	cmpx	#LASTPT
	ble	ROTMX1
	rts
ROTMX3	pshs	X	UNDO ROTATIONS AS  ONE POINT TOO LARGE
	lda	,X
	cmpa	#$80
	beq	RMX
	leax	3,X
	leay	3,X
	jsr	ROTATE
RMX	puls	X
	leax	-9,X
	cmpx	#POINTS
	bhs	ROTMX3
	rts
*
* ROTATE POSITIVELY ABOUT Y AXIS
*
ROTY	ldx	#POINTS
ROTY1	lda	,X
	cmpa	#$80	CHECK FOR UNDEFINED POINT
	beq	ROTY2
	pshs	X
	leay	,X	ADDRESS OF X-COORDINATE OF CURRENT POINT
	leax	6,X	ADDRESS OF Z-COORDINATE OF CURRENT POINT
	jsr	ROTATE
	puls	X
	lda	,X
	cmpa	#$10
	bge	ROTY3
	cmpa	#-$10
	ble	ROTY3	POINT TOO BIG
	lda	6,X
	cmpa	#$10
	bge	ROTY3
	cmpa	#-$10
	ble	ROTY3
ROTY2	leax	9,X	GET NEXT POINT
	cmpx	#LASTPT
	ble	ROTY1
	rts
ROTY3	pshs	X	UNDO ROTATIONS AS  ONE POINT TOO LARGE
	lda	,X
	cmpa	#$80
	beq	RY
	leay	6,X
	jsr	ROTATE
RY	puls	X
	leax	-9,X
	cmpx	#POINTS
	bhs	ROTY3
	rts
*
* ROTATE NEGATIVELY ABOUT Y AXIS
*
ROTMY	ldx	#POINTS
ROTMY1	lda	,X
	cmpa	#$80	CHECK FOR UNDEFINED POINT
	beq	ROTMY2
	pshs	X
	leay	6,X	ADDRESS OF Z-COORDINATE OF CURRENT POINT--X CONTAINS X-COORD
	jsr	ROTATE
	puls	X
	lda	,X
	cmpa	#$10
	bge	ROTMY3
	cmpa	#-$10
	ble	ROTMY3	POINT TOO BIG
	lda	6,X
	cmpa	#$10
	bge	ROTMY3
	cmpa	#-$10
	ble	ROTMY3
ROTMY2	leax	9,X	GET NEXT POINT
	cmpx	#LASTPT
	ble	ROTMY1
	rts
ROTMY3	pshs	X	UNDO ROTATIONS AS  ONE POINT TOO LARGE
	lda	,X
	cmpa	#$80
	beq	RMY
	leay	,X
	leax	6,X
	jsr	ROTATE
RMY	puls	X
	leax	-9,X
	cmpx	#POINTS
	bhs	ROTMY3
	rts
*
* ROTATE POSITIVELY ABOUT Z AXIS
*
ROTZ	ldx	#POINTS
ROTZ1	lda	,X
	cmpa	#$80	CHECK FOR UNDEFINED POINT
	beq	ROTZ2
	pshs	X
	leay	3,X	ADDRESS OF Y-COORDINATE OF CURRENT POINT--X HAS X-COORDINATE
	jsr	ROTATE
	puls	X
	lda	,X
	cmpa	#$10
	bge	ROTZ3
	cmpa	#-$10
	ble	ROTZ3	POINT TOO BIG
	lda	3,X
	cmpa	#$10
	bge	ROTZ3
	cmpa	#-$10
	ble	ROTZ3
ROTZ2	leax	9,X	GET NEXT POINT
	cmpx	#LASTPT
	ble	ROTZ1
	rts
ROTZ3	pshs	X	UNDO ROTATIONS AS  ONE POINT TOO LARGE
	lda	,X
	cmpa	#$80
	beq	RZ
	leay	,X
	leax	3,X
	jsr	ROTATE
RZ	puls	X
	leax	-9,X
	cmpx	#POINTS
	bhs	ROTZ3
	rts
* 
* ROTATE NEGATIVELY ABOUT Z AXIS
*
ROTMZ	ldx	#POINTS
ROTMZ1	lda	,X
	cmpa	#$80	CHECK FOR UNDEFINED POINT
	beq	ROTMZ2
	pshs	X
	leay	,X	ADDRESS OF X-COORDINATE OF CURRENT POINT
	leax	3,X	ADDRESS OF Y-COORDINATE OF CURRENT POINT
	jsr	ROTATE
	puls	X
	lda	,X
	cmpa	#$10
	bge	ROTMZ3
	cmpa	#-$10
	ble	ROTMZ3	POINT TOO BIG
	lda	3,X
	cmpa	#$10
	bge	ROTMZ3
	cmpa	#-$10
	ble	ROTMZ3
ROTMZ2	leax	9,X	GET NEXT POINT
	cmpx	#LASTPT
	ble	ROTMZ1
	rts
ROTMZ3	pshs	X	UNDO ROTATIONS AS  ONE POINT TOO LARGE
	lda	,X
	cmpa	#$80
	beq	RMZ
	leay	3,X
	jsr	ROTATE
	puls	X
RMZ	leax	-9,X
	cmpx	#POINTS
	bhs	ROTMZ3
	rts
*
* ROTATE AROUND SOME AXIS AS FOLLOWS:  X = COORD POINTED AT BY X-REG, Y=COORD POINTED AT BY Y-REG
* X,Y=(127/128)X-(1/8)Y,(1/8)X+127/128)Y
*
ROTATE	leau	-6,S
	ldd	,X
	std	,U
	std	3,U
	lda	2,X
	sta	2,U
	sta	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	lda	2,U
	suba	5,U
	sta	2,U
	lda	1,U
	sbca	4,U
	sta	1,U
	lda	,U
	sbca	3,U
	sta	,U
	ldd	,Y
	std	3,U
	lda	2,Y
	sta	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	lda	2,U
	suba	5,U
	sta	2,U
	lda	1,U
	sbca	4,U
	sta	1,U
	lda	,U
	sbca	3,U
	sta	,U
	ldd	,U
	std	,X
	lda	2,U
	sta	2,X
	ldd	,Y
	std	3,U
	lda	2,Y
	sta	5,U
	asr	,U
	ror	1,U
	ror	2,U
	asr	,U
	ror	1,U
	ror	2,U
	asr	,U
	ror	1,U
	ror	2,U
	ldd	1,U
	addd	4,U
	std	1,U
	lda	,U
	adca	3,U
	sta	,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	asr	3,U
	ror	4,U
	ror	5,U
	ldd	1,U
	addd	4,U
	std	1,U
	lda	,U
	adca	3,U
	sta	,U
	ldd	,U
	std	,Y
	lda	2,U
	sta	2,Y
	rts
*
* MAKE THE FIGURE 1/32 BIGGER
*
BIGGER	ldx	#POINTS
BIG1	lda	,X	CHECK IF POINT IS DEFINED
	cmpa	#$80
	beq	BIG2
	bsr	GETBIG	INCREASE ALL THREE COORDINATES
	leax	3,X
	bsr	GETBIG
	leax	3,X
	bsr	GETBIG
	leax	-6,X
	leay	,X	CHEC IF ANY OF 3 COORDS TOO BIG
	bsr	TOOBIG
	bge	BIG3
	leay	3,Y
	bsr	TOOBIG
	bge	BIG3
	leay	3,Y
	bsr	TOOBIG
	bge	BIG3
BIG2	leax	9,X	GET NEXT POINT
	cmpx	#LASTPT
	ble	BIG1
	rts
BIG3	lda	,X	RESTORE POINTS IF ONE MADE OUT OF BOUNDS
	cmpa	#$80
	bne	BIG8
	leax	-9,X
	bra	BIG9
BIG8	jsr	GETSML
	leax	3,X
	jsr	GETSML
	leax	3,X
	jsr	GETSML
	leax	-$F,X
BIG9	cmpx	#POINTS
	bhs	BIG3
	rts
GETBIG	leau	-3,S	MAKE ONE COORDINATE 1/32 BIGGER
	ldd	,X
	std	,U
	lda	2,X
	sta	2,U
	asr	,U
	ror	1,U
	ror	2,U
	asr	,U
	ror	1,U
	ror	2,U
	asr	,U
	ror	1,U
	ror	2,U
	asr	,U
	ror	1,U
	ror	2,U
	asr	,U
	ror	1,U
	ror	2,U
	ldd	1,X
	addd	1,U
	std	1,X
	lda	,X
	adca	,U
	sta	,X
	rts
TOOBIG	lda	,Y	CHECK IF A COORDINATE TOO BIG--IF FIRST BYTE >= $80 OR <= -$80
	cmpa	#$10
	bge	TB1
	nega
	cmpa	#$10
TB1	rts		BGE WILL GO IF NUMBER LOADED INTO A WAS >=$10 OR <=-$10
*
* MAKE THE FIGURE 1/32 SMALLER
*
SMALLR	ldx	#POINTS
SML1	lda	,X	CHECK IF POINT IS DEFINED
	cmpa	#$80
	beq	SML2
	bsr	GETSML
	leax	3,X
	bsr	GETSML
	leax	3,X
	bsr	GETSML
	leax	3,X
	bra	SMLR1
SML2	leax	9,X	GET NEXT POINT
SMLR1	cmpx	#LASTPT
	ble	SML1
* CHECK FOR LINE SEGMENT LENGTH < 1 -- IF ONE FOUND, RESTORE POINTS TO ORIGINAL VALUES
	ldu	#LINES
SMLR6	clra
	ldb	,U+
	cmpb	#$FF
	beq	SMLR5	LAST LINE SEGMENT TESTED
	addd	#POINTS
	tfr	D,X	ADDRESS OF FIRST POINT
	clra
	ldb	,U+
	addd	#POINTS
	tfr	D,Y	ADDRESS OF SECOND POINT
	ldd	,X
	cmpd	,Y	TEST FIRST COORD
	bne	SMLR6	INTEGER PARTS NOT EQUAL
	ldd	3,X
	cmpd	3,Y
	bne	SMLR6	INTEGER PARTS OF SECOND COORD NOT EQUAL
	ldd	6,X
	cmpd	6,Y
	bne	SMLR6	INTEGER PARTS OF THIRD COORD NOT EQUAL
* ALL COMPONENTS OF LINE SEGMENT HAVE EQUAL INTEGER PARTS, SO UNDO SMALLER AND RTS FROM BIGGER
	lbra	BIGGER
SMLR5	rts		ALL LINE SEGMENTS CHECKED AND LONG ENOUGH
GETSML	leau	-3,S
	ldd	,X
	std	,U
	lda	2,X
	sta	2,U
	asr	,U
	ror	1,U
	ror	2,U
	asr	,U
	ror	1,U
	ror	2,U
	asr	,U
	ror	1,U
	ror	2,U
	asr	,U
	ror	1,U
	ror	2,U
	asr	,U
	ror	1,U
	ror	2,U
	ldd	1,X
	subd	1,U
	std	1,X
	lda	,X
	sbca	,U
	sta	,X
	rts

*
* DRAW A LINE.  X1,X2 TO Y1,Y2 - COORDINATES ARE SIGNED 16 BIT INTEGERS, VISIBLE SCREEN IS -128 TO 127, -95 TO 95 ON USUAL
* X,Y GRAPH
*
BITS	fcb	$80	FOR SETTING POINTS ON GRAPHICS SCREEN
	fcb	$40
	fcb	$20
	fcb	$10
	fcb	$8
	fcb	$4
	fcb	$2
LASTBT	fcb	$1
TOP	equ	$5F	LIMITS OF VIRTUAL SCREEN
BOTTOM	equ	-$60
LEFT	equ	-$80
RIGHT	equ	$7F

*
* BEGIN LINE DRAWING ALGORITHM
*
* MAKE SURE X1<X2 OR REVERSE COORDINATES
*
LINE	ldd	<X2
	cmpd	<X1
	bge	LN1
	ldx	<X1
	std	<X1
	stx	<X2
	ldx	<Y1
	ldy	<Y2
	stx	<Y2
	sty	<Y1
*
* CHECK FOR SIGN OF SLOPE
*
LN1	ldd	<Y2
	cmpd	<Y1
	lblt	SELINE
*
* BEGIN DRAWING LINE WITH POSITIVE SLOPE
*
* CHECK FOR NO VISIBLE LINE
*
	ldd	<X1
	cmpd	#RIGHT
	lbge	LNDONE
	ldd	<Y1
	cmpd	#TOP
	lbge	LNDONE
	ldd	<X2
	cmpd	#LEFT
	lble	LNDONE
	ldd	<Y2
	cmpd	#BOTTOM
	lble	LNDONE
*
* CHECK IF MUST CLIP LEFT END OF LINE
*
	ldd	<X1
	cmpd	#LEFT
	blt	LN2
	ldd	<Y1
	cmpd	#BOTTOM
	bge	LN3
*
* CLIP LEFT END OF LINE
*
LN2	ldx	<X2
	ldy	<Y2
	pshs	X,Y
LN4	ldd	<X1	X=(X1+X2)/2
	addd	<X2
	asra
	rorb
	tfr	D,X
	ldd	<Y1	Y=(Y1+Y2)/2
	addd	<Y2
	asra
	rorb
	tfr	D,Y
	cmpx	#LEFT
	bgt	LN5
	cmpy	#TOP
	lbge	LNDON1	NO VISIBLE LINE
LN5	cmpx	#RIGHT
	blt	LN6
	cmpy	#BOTTOM
	lble	LNDON1	NO VISIBLE LINE
LN6	cmpx	#LEFT
	blt	LN7
	cmpy	#BOTTOM
	bge	LN8
LN7	stx	<X1	REPLACE LEFT POINT BY MIDPOINT AND REPEAT
	sty	<Y1
	bra	LN4
LN8	cmpx	#LEFT
	ble	LN9
	cmpy	#BOTTOM
	ble	LN9
	stx	<X2	REPLACE RIGHT POINT BY MIDPOINT
	sty	<Y2
	bra	LN4
LN9	stx	<X1	X1,Y1 NOW ON LEFT OR BOTTOM BOUNDARY
	sty	<Y1
	puls	X,Y	RECOVER ORIGINAL RIGHT POINT
	stx	<X2
	sty	<Y2
* CHECK IF MUST CLIP RIGHT END OF LINE
*
LN3	ldd	<X2
	cmpd	#RIGHT
	bgt	LN10
	ldd	<Y2
	cmpd	#TOP
	ble	LN18
*
* CLIP RIGHT END OF LINE
*
LN10	ldx	<X1
	ldy	<Y1
	pshs	X,Y
LN11	ldd	<X1	X=(X1+X2)/2
	addd	<X2
	asra
	rorb
	tfr	D,X
	ldd	<Y1	Y=(Y1+Y2)/2
	addd	<Y2
	asra
	rorb
	tfr	D,Y
	cmpx	#RIGHT
	bgt	LN12
	cmpy	#TOP
	ble	LN13
LN12	stx	<X2	MOVE RIGHT POINT TO MIDPOINT AND REPEAT
	sty	<Y2
	bra	LN11
LN13	cmpx	#RIGHT
	bge	LN14
	cmpy	#TOP
	bge	LN14
	stx	<X1	MOVE LEFT POINT TO MIDPOINT AND REPEAT
	sty	<Y1
	bra	LN11
LN14	stx	<X2	MOVE X2,Y2 TO TOP OR RIGHT BOUNDARY, RECOVER X1,Y1
	sty	<Y2
	puls	X,Y
	stx	<X1
	sty	<Y1
*
* DECIDE IF SLOPE > 1
*
LN18	lda	<X2P	X1P, ETC HOLD CORRECT ONE-BYTE SIGNED VALUES FOR THE COORDINATES, WHICH ARE NOW ON THE VIRTUAL SCREEN
	suba	<X1P
	pshs	A
	ldb	<Y2P
	subb	<Y1P
	cmpb	,S+
	blo	ENELN
*
* DRAW A LINE WITH POSITIVE SLOPE
*
	pshs	B	SAVE NUMBER OF POINTS ON LINE - 1
	jsr	GETSLP	SLOPE = DX/DY, AN 8-BIT FRACTION
	jsr	FRSTBT	SET X,U TO POINT TO BYTE AND BIT ON GRAPHICS SCREEN CORRESP. TO X1,Y1
	puls	B
	clra
	tfr	D,Y
	leay	1,Y	Y=#POINTS ON LINE
	clrb
LN15	lda	,X	SET THE POINTS ON THE GRAPHICS SCREEN FOR THE LINE
	ora	,U	GET THE BYTE AND OR IN THE BIT
	sta	,X
	leay	-1,Y	REDUCE POINT COUNT
	lbeq	LNDONE
	leax	-$20,X	INCREASE Y-COORDINATE BY 1
	addb	<SLOPE	INCREASE X-COORDINATE BY SLOPE (A FRACTION)
	bcc	LN15	B=X MOD 1
	leau	1,U	INCREASE X-COORDINATE BY 1
	cmpu	#LASTBT	TRY TO MOVE RIGHT ONE BIT
	bls	LN15
	ldu	#BITS	ELSE USE NEXT BYTE AND LEFT BIT
	leax	1,X
	bra	LN15
*
* DRAW LINE WITH POSITIVE SLOPE <1
*
ENELN	pshs	A	SAVE # OF POINTS ON LINE - 1
	exg	A,B
	jsr	GETSLP	SLOPE = DY/DX
	jsr	FRSTBT	X,U ARE BYTE AND BIT CORRESP. TO X1,Y1
	puls	B
	clra
	tfr	D,Y
	leay	1,Y	Y=#POINTS ON LINE
	clrb
LN16	lda	,X	DRAW THE LINE
	ora	,U	GET THE BYTE, OR IN  THE BIT
	sta	,X
	leay	-1,Y	REDUCE THE POINT COUNT
	lbeq	LNDONE
	leau	1,U	MOVE ONE BIT TO RIGHT
	cmpu	#LASTBT	IF POSSIBLE
	bls	LN17
	leax	1,X	ELSE MOVE TO NEXT BYTE AND FIRST BIT
	ldu	#BITS
LN17	addb	<SLOPE
	bcc	LN16	NO OVERFLO TO NEXT INTEGER WHEN ADDING SLOPE TO Y
	leax	-$20,X	ELSE ADD 1 TO Y-COORDINATE
	BRA	LN16
*
* BEGIN DRAWING LINE WITH NEGATIVE SLOPE
*
* CHECK FOR NO VISIBLE LINE
*
SELINE	ldd	<X1
	cmpd	#RIGHT
	lbge	LNDONE
	ldd	<Y1
	cmpd	#BOTTOM
	lble	LNDONE
	ldd	<X2
	cmpd	#LEFT
	lble	LNDONE
	ldd	<Y2
	cmpd	#TOP
	lbge	LNDONE
*
* CHECK IF MUST CLIP LEFT END OF LINE
*
	ldd	<X1
	cmpd	#LEFT
	blt	LN2A
	ldd	<Y1
	cmpd	#TOP
	ble	LN3A
*
* CLIP LEFT END OF LINE FT END OF LI
*
LN2A	ldx	<X2
	ldy	<Y2
	pshs	X,Y
LN4A	ldd	X1	X=(X1+X2)/2
	addd	<X2
	asra
	rorb
	tfr	D,X
	ldd	Y1	Y=(Y1+Y2)/2
	addd	<Y2
	asra
	rorb
	tfr	D,Y
	cmpx	#LEFT
	bgt	LN5A
	cmpy	#BOTTOM
	lble	LNDON1	NO VISIBLE LINE
LN5A	cmpx	#RIGHT
	blt	LN6A
	cmpy	#TOP
	lbge	LNDON1	NO VISIBLE LINE
LN6A	cmpx	#LEFT
	blt	LN7A
	cmpy	#TOP
	ble	LN8A
LN7A	stx	<X1	REPLACE LEFT POINT BY MIDPOINT AND REPEAT
	sty	<Y1
	bra	LN4A
LN8A	cmpx	#LEFT
	ble	LN9A
	cmpy	#TOP
	bge	LN9A
	stx	<X2	REPLACE RIGHT POINT BY MIDPOINT
	sty	<Y2
	bra	LN4A
LN9A	stx	<X1	X1,Y1 NOW ON LEFT OR BOTTOM BOUNDARY
	sty	<Y1
	puls	X,Y	RECOVER ORIGINAL RIGHT POINT
	stx	<X2
	sty	<Y2
* CHECK IF MUST CLIP RIGHT END OF LINE
*
LN3A	ldd	<X2
	cmpd	#RIGHT
	bgt	LN10A
	ldd	<Y2
	cmpd	#BOTTOM
	bge	LN18A
*
* CLIP RIGHT END OF LINE
*
LN10A	ldx	<X1
	ldy	<Y1
	pshs	X,Y
LN11A	ldd	<X1	X=(X1+X2)/2
	addd	<X2
	asra
	rorb
	tfr	D,X
	ldd	<Y1	Y=(Y1+Y2)/2
	addd	<Y2
	asra
	rorb
	tfr	D,Y
	cmpx	#RIGHT
	bgt	LN12A
	cmpy	#BOTTOM
	bge	LN13A
LN12A	stx	<X2	MOVE RIGHT POINT TO MIDPOINT AND REPEAT
	sty	<Y2
	bra	LN11A
LN13A	cmpx	#RIGHT
	bge	LN14A
	cmpy	#BOTTOM
	ble	LN14A
	stx	<X1	MOVE LEFT POINT TO MIDPOINT AND REPEAT
	sty	<Y1
	bra	LN11A
LN14A	stx	<X2	MOVE X2,Y2 TO TOP OR RIGHT BOUNDARY, RECOVER X1,Y1
	sty	<Y2	
	puls	X,Y
	stx	<X1
	sty	<Y1
*
* DECIDE IF SLOPE > 1
*
LN18A	lda	<X2P	X1P, ETC HOLD CORRECT ONE-BYTE SIGNED VALUES FOR THE COORDINATES, WHICH ARE NOW ON THE VIRTUAL SCREEN
	suba	<X1P
	pshs	A
	ldb	<Y1P
	subb	<Y2P
	cmpb	,S+
	blo	ESELN
*
* DRAW A LINE WITH NEGATIVE SLOPE <= -1
*
	pshs	B	SAVE NUMBER OF POINTS ON LINE - 1
	jsr	GETSLP	SLOPE = -DX/DY, AN 8-BIT FRACTION
	jsr	FRSTBT	SET X,U TO POINT TO BYTE AND BIT ON GRAPHICS SCREEN CORRESP. TO X1,Y1
	puls	B
	clra
	tfr	D,Y
	leay	1,Y	Y=#POINTS ON LINE
	clrb
LN15A	lda	,X	SET THE POINTS ON THE GRAPHICS SCREEN FOR THE LINE
	ora	,U	GET THE BYTE AND OR IN THE BIT
	sta	,X
	leay	-1,Y	REDUCE POINT COUNT
	lbeq	LNDONE
	leax	$20,X	DECREASE Y-COORDINATE BY 1
	addb	<SLOPE	INCREASE X-COORDINATE BY SLOPE (A FRACTION)
	bcc	LN15A	B=X MOD 1
	leau	1,U	INCREASE X-COORDINATE BY 1
	cmpu	#LASTBT	TRY TO MOVE RIGHT ONE BIT
	bls	LN15A
	ldu	#BITS	ELSE USE NEXT BYTE AND LEFT BIT
	leax	1,X
	bra	LN15A
*
* DRAW LINE WITH NEGATIVE SLOPE > -1
*
ESELN	pshs	A	SAVE # POINTS ON LINE - 1
	exg	A,B
	jsr	GETSLP	SLOPE = -DY/DX
	jsr	FRSTBT	X,U ARE BYTE AND BIT CORRESP. TO X1,Y1
	puls	B
	clra
	tfr	D,Y
	leay	1,Y	Y=#POINTS ON LINE
	clrb
LN16A	lda	,X	DRAW THE LINE
	ora	,U	GET THE BYTE, OR IN  THE BIT
	sta	,X
	leay	-1,Y	REDUCE THE POINT COUNT
	lbeq	LNDONE
	leau	1,U	MOVE ONE BIT TO THE RIGHT
	cmpu	#LASTBT	IF POSSIBLE
	bls	LN17A
	leax	1,X	ELSE MOVE TO NEXT BYTE AND FIRST BIT
	ldu	#BITS
LN17A	addb	<SLOPE
	bcc	LN16A	NO OVERFLO TO NEXT INTEGER WHEN ADDING SLOPE TO Y
	leax	$20,X	ELSE SUBTRACT 1 FROM Y-COORDINATE
	bra	LN16A
LNDON1	puls	X,Y
LNDONE	rts
*
* ASSUME A<B CONTAIN UNSIGNED INTEGERS, PUT A/B INTO SLOPE
*
GETSLP	pshs	B
	clrb
	ldx	#8
GET5	aslb
	asla
	bcs	GET1
	cmpa	,S
	blo	GET4
GET1	suba	,S
	incb
GET4	leax	-1,X
	bne	GET5
	leas	1,S
	stb	<SLOPE
	rts
*
* FIND BYTE X AND BIT (U) ON GRAPHICS SCREEN CORRESPONDING TO X1,Y1
* X=$600+Y1*32+X1DIV8 AND U=#BITS+X1MOD8
* WE USE $600+Y1*(256/8)+X1DIV8 FOR X, AND AS WE DIVIDE X1 BY THREE SUCCESSIVE 2'S, WE PICK UP THE BITS FOR MODIFYING U.
*
FRSTBT	ldx	<TL
	lda	#95
	suba	<Y1P
	ldb	<X1P
	addb	#$80
	ldu	#BITS
	andcc	#$FE
	rora
	rorb
	bcc	FRST1
	leau	1,U
FRST1	asra
	rorb
	bcc	FRST2
	leau	2,U
FRST2	asra
	rorb
	bcc	FRST3
	leau	4,U
FRST3	leax	D,X
	rts
	end
