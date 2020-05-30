100 REM PROGRAM DISPLAY
110 REM COPYRIGHT DAVID MEREDITH 1983
120 REM BASIC PROGRAM PERMITS INPUT OF A 3-D PICTURE AS POINTS AND LINE SEGMENTS. MACHINE LANGUAGE COMPONENT DISPLAYS THE PICTURE
130 REM AND ALLOWS PANNING, SCALING, AND ROTATING
135 CLEAR 300,&H3FFF
140 CLS:PRINT@73,"D I S P L A Y":PRINT@135,"BY DAVID MEREDITH":PRINT@201,"COPYRIGHT 1983"
145 PRINT@416,"READING MACHINE LANGUAGE PART..."
150 LOADM"DISPLAY2"
160 PO=&H7000:LI=PO+9*26:MA=LI+121:REM ADDRESSES OF POINTS BUFFER, LINES BUFFER, AND MAIN DISPLAY ROUTINE
165 DIM CH(25)
170 GOSUB 1000:REM NEW PICTURE
175 CS$="HELPNEWDISPLAY":LD$="LOAD":SV$="SAVE":AA=ASC("A"):QU$=CHR$(34)
180 CLS:PRINT"ENTER help ANYTIME FOR GUIDANCE"
190 LINEINPUT A$:REM GET NEW POINT, LINE, OR COMMAND
200 I=INSTR(A$," "):IF I<>0 THEN A$=LEFT$(A$,I-1)+RIGHT$(A$,LEN(A$)-I):GOTO 200:REM ELIMINATE BLANKS
210 IF LEN(A$) >2 THEN I=INSTR(CS$,A$):IF I=0 THEN 215 ELSE IF I=1 THEN GOSUB 1600:GOTO 190 ELSE IF I=5 THEN GOSUB 1000:GOTO 190 ELSE IF I=8 THEN GOSUB 1800:GOTO 190
215 IF INSTR(A$,LD$)=1 THEN GOSUB 1200:GOTO 190 ELSE IF INSTR(A$,SV$)=1 THEN GOSUB 1400:GOTO 190
220 IF INSTR(A$,"=")=2 THEN GOSUB 2000:GOTO 190:REM DEFINE A POINT
230 IF INSTR(A$,"??")=1 THEN GOSUB 2200:GOTO 190:REM PRINT LINE SEGMENTS
240 IF INSTR(A$,"?")=1 THEN GOSUB 2400:GOTO 190:REM PRINT POINTS
250 REM	AT THIS POINT A$ EITHER DEFINES LINES OR IS INCORRECT
260 L=LEN(A$):IF L<2 THEN GOSUB 2600:GOTO 190:REM IF LEN(A$) <2 THEN LINE INCORRECT
270 IF L<2 THEN 190 ELSE A1=ASC(LEFT$(A$,1))-AA:A2=ASC(MID$(A$,2,1))-AA:IF A1<0 OR A1>25 OR A2<0 OR A2>25 THEN GOSUB 2600:GOTO 190 ELSE L=L-2:A$=RIGHT$(A$,L)
274 IF A1=A2 THENPRINT:PRINT"ENDPOINTS MUST BE DISTINCT":PRINT:GOTO190
275 IF INSTR(A$,"#")=1 THEN L=L-1:A$=RIGHT$(A$,L):GOTO 400:REM DELETE A POINT
280 I=LI:A1=9*A1:A2=9*A2
290 P=PEEK(I):Q=PEEK(I+1):IF P <> 255 THEN IF (P=A1 AND Q=A2) OR (P=A2 AND Q=A1)THEN PRINT:PRINT"LINE ";CHR$(AA+A1/9);CHR$(AA+A2/9);" ALREADY DEFINED":PRINT:GOTO 190 ELSE I=I+2:GOTO 290:REM FIND NEXT OPEN SPACE IN LINES BUFFERCHECKING FOR DUPLICATION
300 IF I=MA-1 THEN PRINT:PRINT"NO ROOM FOR ANOTHER LINE":PRINT:GOTO190
310 IF PEEK(PO+A1)=128 THEN PRINT:PRINT"POINT ";CHR$(A1/9+AA);" NOT DEFINED":PRINT:GOTO 270
320 IF PEEK(PO+A2)=128 THEN PRINT:PRINT"POINT ";CHR$(A2/9+AA);" NOT DEFINED":PRINT:GOTO 270
330 POKE I,A1:POKE I+1,A2:POKE I+2,255:IF L>0 THEN 270 ELSE 190:REM PUT LINE SEGMENT IN LINE BUFFER AND GET NEXT SEGMENT IF ANY
400 REM	DELETE A LINE SEGMENT A1,A2
410 I=LI:A1=9*A1:A2=9*A2
420 IF PEEK(I)=255 THEN PRINT:PRINT"LINE SEGMENT ";CHR$(A1/9+AA);CHR$(A2/9+AA);" NOT DEFINED":PRINT:GOTO 270
430 P=PEEK(I):Q=PEEK(I+1):IF (P<>A1 OR Q<>A2) AND (P<>A2 OR Q<>A1)THEN I=I+2:GOTO 420
440 P=PEEK(I+2):POKE I,P:IF P=255 THEN 270 ELSE I=I+1:GOTO 440:REM DELETE THE POINT BY MOVING DATA DOWN THE BUFFER
1000 REM MAKE A BLANK PICTURE
1010 FOR I=PO TO PO+9*25 STEP 9:POKE I,128:NEXT:REM MARK ALL POINTS AS UNDEFINED
1020 POKE LI,255:REM CLEAR LINE BUFFER
1030 RETURN
1200 REM LOAD A PICTURE FROM DISK
1210 I=INSTR(A$,QU$):IFI<>0THENJ=INSTR(I+1,A$,QU$):IFJ<>0THENNA$=MID$(A$,I,J-I+1)ELSENA$=RIGHT$(A$,LEN(A$)-I)ELSENA$=""
1220 IFLEN(NA$)>8THENNA$=LEFT$(NA$,8)
1230 LOADM NA$+".3D"
1240 GOTO 1800:REM DISPLAY PICTURE AFTER LOADING
1400 REM SAVE CURRENT PICTURE ON DISK
1410 I=INSTR(A$,QU$):IFI<>0THENJ=INSTR(I+1,A$,QU$):IFJ<>0THENNA$=MID$(A$,I,J-I+1)ELSENA$=RIGHT$(A$,LEN(A$)-I)ELSENA$=""
1420 IFLEN(NA$)>8THENNA$=LEFT$(NA$,8)
1430 SAVEM NA$+".3D",PO,MA-1,PO:RETURN
1600 REM HELP ROUTINE
1610 CLS:PRINT"DISPLAY PICTURE:  display"
1615 PRINT"...PRESS x,y,z,s,b AND @ TO EXIT":POKE &H400+55,0
1620 PRINT"ERASE PICTURE:  new"
1630 PRINT"SAVE PIX ON DISK:  save";QU$;"NAME";QU$
1640 PRINT"READ PIX FROM DISK:  load";QU$;"NAME";QU$
1650 PRINT"ENTER POINT P:  P = X,Y,Z"
1660 PRINT"ENTER LINE SEGMENT AB:  AB"
1670 PRINT"DELETE LINE SEGMENT CD:  CD#"
1680 PRINT"PRINT POINTS A TO H:  ?A-H"
1690 PRINT"PRINT LINE SEGMENTS:  ??"
1700 PRINT:RETURN
1800 REM DISPLAY THE PICTURE
1810 REM FIRST DECLARE ALL UNUSED POINTS AS UNDEFINED
1820 FORI=0TO25:CH(I)=0:NEXT
1830 I=LI
1840 P=PEEK(I):IFP<>255THENCH(P/9)=1:I=I+1:GOTO1840:REM MARK ALL POINT NAMES USED
1850 FORI=0TO25:IFCH(I)=0THENPOKEPO+9*I,128:NEXT:REM MARK UNUSED POINTS AS UNDEFINED
1860 POKE 282,0:EXEC MA:POKE282,255:PRINT:RETURN
2000 REM INPUT A POINT
2010 A=ASC(LEFT$(A$,1))-AA:IF A<0 OR A>25 THEN GOSUB 2600:RETURN
2020 AD=PO+9*A
2030 A$=RIGHT$(A$,LEN(A$)-2)
2040 IF A$="" THEN GOSUB 2600:RETURN
2050 VA=VAL(A$):IF ABS(VA) > 80 THEN PRINT:PRINT"COORDINATES MUST BE BETWEEN -80 AND 80":PRINT:RETURN ELSE B=LEN(A$)-LEN(STR$(VA)):IF VA <0 THEN B=B-1
2055 IF B<3 THEN GOSUB 2600:GOTO 190 ELSE A$=RIGHT$(A$,B):IF VA>=0 THEN V1=0:V2=VA ELSE V1=255:V2=256+VA
2060 POKE AD,V1:POKE AD+1,V2:POKE AD+2,0:AD=AD+3
2070 IF A$="" THEN GOSUB 2600:RETURN
2080 VA=VAL(A$):IF ABS(VA) > 80 THEN PRINT:PRINT"COORDINATES MUST BE BETWEEN -80 AND 80":PRINT:RETURN ELSE B=LEN(A$)-LEN(STR$(VA)):IF VA <0 THEN B=B-1
2085 IF B<1 THEN GOSUB 2600:GOTO190 ELSE A$=RIGHT$(A$,B):IF VA>=0 THEN V1=0:V2=VA ELSE V1=255:V2=256+VA
2090 POKE AD,V1:POKE AD+1,V2:POKE AD+2,0:AD=AD+3
2140 VA=VAL(A$):IFABS(VA)>80 THEN PRINT:PRINT"COORDINATES MUST BE BETWEEN -80 AND 80":PRINT:RETURN
2145 IFVA>=0THENV1=0:V2=VA ELSEV1=255:V2=256+VA
2150 POKE AD,V1:POKEAD+1,V2:POKEAD+2,0:RETURN
2200 REM PRINT LINES
2210 I=LI
2220 P=PEEK(I):IF P=255 THEN PRINT:RETURN
2230 PRINTCHR$(P/9+AA);CHR$(PEEK(I+1)/9+AA);" ";:I=I+2:GOTO2220
2400 REM PRINT POINTS
2410 A1=0:A2=25:I=INSTR(A$,"-"):IFI=3THENA1=ASC(MID$(A$,2,1))-AA:IFA1<0ORA1>25THENA1=0:GOTO2030
2420 IFI<LEN(A$)ANDI<=3THENA2=ASC(MID$(A$,I+1,1))-AA:IFA2<0ORA2>25THENA2=25
2430 FORI=A1 TO A2:AD=PO+9*I:IFPEEK(AD)=128THENNEXT:RETURN
2440 PRINTCHR$(I+AA);" = ";:FORJ=0TO6STEP3
2450 VA=PEEK(AD+J)*256+PEEK(AD+J+1)+PEEK(AD+J+2)/256:IFVA>32767THENVA=VA-65536
2460 V$=STR$(VA):PRINTV$;:IFJ<>6THENPRINT",";
2465 NEXT:PRINT:NEXT:RETURN
2600 PRINT:PRINT"UNRECOGNIZED COMMAND":PRINT:RETURN