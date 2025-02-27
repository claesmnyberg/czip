#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
SHELL    = /bin/sh
NASM     = nasm
NASMFLGS = -f elf -w+number-overflow -w+orphan-labels 
LINKER   = ld
LNKFLAGS = -s 
OBJS     = main.o bitio.o lzw_compress.o lzw_decompress.o 
PROG     = czip
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

none: 
	@echo
	@echo "Usage: make <freebsd | linux | clean>"
	@echo

clean:
	rm -f *.o 

freebsd: 
	${NASM} ${NASMFLGS} -DFREEBSD main.asm
	${NASM} ${NASMFLGS} -DFREEBSD bitio.asm
	${NASM} ${NASMFLGS} -DFREEBSD lzw_compress.asm
	${NASM} ${NASMFLGS} -DFREEBSD lzw_decompress.asm
	${LINKER} ${LNKFLAGS} -o ${PROG} ${OBJS}

linux: 
	${NASM} ${NASMFLGS} -DLINUX main.asm
	${NASM} ${NASMFLGS} -DLINUX bitio.asm
	${NASM} ${NASMFLGS} -DLINUX lzw_compress.asm
	${NASM} ${NASMFLGS} -DLINUX lzw_decompress.asm
	${LINKER} ${LNKFLAGS} -o ${PROG} ${OBJS}
