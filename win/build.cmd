@setlocal
@if exist lwasm.exe cd .. || goto Error
@if not exist build mkdir build || goto Error
@if exist display.dsk del display.dsk || goto Error

win\lwasm -9bl -s -p cd --output=build/display.bin --list=build/display.lst src/display.asm || goto Error
win\lwasm -9bl -s -p cd --output=build/display2.bin --list=build/display2.lst src/display2.asm || goto Error
win\lwasm -9bl -s -p cd --output=build/display3.bin --list=build/display3.lst src/display3.asm || goto Error
win\lwasm -9bl -s -p cd --output=build/listing2.bin --list=build/listing2.lst doc/listing2.asm || goto Error

win\decb dskini display.dsk || goto Error

win\decb copy -r -l -0 -b -t src/display.bas display.dsk,DISPLAY.BAS || goto Error
win\decb copy -r -2 -b build/display.bin display.dsk,DISPLAY.BIN || goto Error
win\decb copy -r -3 -a -l src/display.asm display.dsk,DISPLAY.ASM || goto Error

win\decb copy -r -l -0 -b -t src/display2.bas display.dsk,DISPLAY2.BAS || goto Error
win\decb copy -r -2 -b build/display2.bin display.dsk,DISPLAY2.BIN || goto Error
win\decb copy -r -3 -a -l src/display2.asm display.dsk,DISPLAY2.ASM || goto Error

win\decb copy -r -l -0 -b -t src/display3.bas display.dsk,DISPLAY3.BAS || goto Error
win\decb copy -r -2 -b build/display3.bin display.dsk,DISPLAY3.BIN || goto Error
win\decb copy -r -3 -a -l src/display3.asm display.dsk,DISPLAY3.ASM || goto Error

win\decb copy -r -2 -b 3d/diamond.3d display.dsk,DIAMOND.3D || goto Error
win\decb copy -r -2 -b 3d/cube.3d display.dsk,CUBE.3D || goto Error
win\decb copy -r -2 -b 3d/word.3d display.dsk,WORD.3D || goto Error

win\decb dir display.dsk || goto Error

@if not exist \mame0221 exit /b
@set flop1=%cd%\display.dsk

cd \mame0221
mame64.exe coco3h -window -skip_gameinfo -flop1 %flop1%
@exit /b

:Error
@ECHO Build failed
@exit /b 1

