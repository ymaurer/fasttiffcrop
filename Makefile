CFLAGS = -O -Wall
CC = /usr/bin/gcc
LINKER = /usr/bin/gcc
LIBS = -I/usr/include/

all: fasttiffcrop tiff2jpg
	echo "done."

tiff2jpg.o: tiff2jpg.cpp blockcutter.h blockcutter.cpp
	gcc $(CFLAGS) -c tiff2jpg.cpp -o tiff2jpg.o

tiff2jpg: tiff2jpg.o blockcutter.o
	gcc blockcutter.o tiff2jpg.o -lstdc++ -ljpeg -ltiff -o tiff2jpg

fasttiffcrop.o: fasttiffcrop.cpp blockcutter.h blockcutter.cpp
	${CC} $(CFLAGS) ${LIBS} ${RPATH} -c fasttiffcrop.cpp -o fasttiffcrop.o

fasttiffcrop: fasttiffcrop.o blockcutter.o
	${LINKER} ${LDFLAG} blockcutter.o fasttiffcrop.o -lstdc++ -ljpeg -ltiff -o fasttiffcrop

blockcutter.o: blockcutter.cpp blockcutter.h 
	${CC} $(CFLAGS) ${LIBS} ${RPATH} -c blockcutter.cpp

clean:
	rm -f *.o
	rm -f *.exe
	rm -f fasttiffcrop
	rm -f tiff2jpeg
