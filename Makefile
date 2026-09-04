CC = gcc
CFLAGS = -Wall -Wextra

all: compilper

compilper: y.tab.c lex.yy.c tree.c iburg.c symtab.h tree.h
	$(CC) $(CFLAGS) y.tab.c lex.yy.c tree.c iburg.c -o compilper

compilper.brg: compilper.bfe tree.h
	bfe compilper.bfe > compilper.brg

iburg.c: compilper.brg tree.h
	iburg compilper.brg > iburg.c

oxout.y oxout.l: parser.y scanner.l symtab.h tree.h
	ox parser.y scanner.l

y.tab.c y.tab.h: oxout.y symtab.h tree.h
	bison -y -d oxout.y

lex.yy.c: oxout.l y.tab.h symtab.h
	flex oxout.l

clean:
	rm -f compilper y.tab.c y.tab.h lex.yy.c oxout.y oxout.l compilper.brg iburg.c
