bison -d "$2.y"
flex "$1.l"
gcc "$2.tab.c" lex.yy.c