/*
BADIN LUCA 1242060
COMPILATORI - PROGETTO FINALE
"REBUS" - LEXER
*/

/*regular definitions*/
%option noyywrap
%{
	#include <math.h>
	#include "parser.h"
	#include "parser.tab.h"
	extern YYSTYPE yylval;
%}

DELIM		[ \t\n\r]
WS			{DELIM}+
ENDSTMT		[;]

LETTER		[A-Za-z]
DIGIT		[0-9]
ID			{LETTER}({LETTER}|{DIGIT})*

%%
"if"	{	/* flow control keywords */
			//fprintf(stderr,"<IF>");
			return IF;
		}
"else"	{
			//fprintf(stderr,"<ELSE>");
			return ELSE;
		}
"while" {
			//fprintf(stderr,"<WHILE>");
			return WHILE;
		}

"int"	{	 /* type keywords */
			//fprintf(stderr,"<INT>"); 
			yylval.type = (char*) malloc(sizeof(char) * 4);
			strcpy(yylval.type, "int");
			return TYPE;
		}

"print" { return PRINT;} /* print to screen instruction */

"&&"	{
			//fprintf(stderr,"<AND>");
			return AND;
		}
"||"	{
			//fprintf(stderr,"<OR>");
			return OR;
		}
"!"		{
			//fprintf(stderr,"<NOT>");
			return NOT;
		} /* logical operators */

"<"		{
			//fprintf(stderr,"%s",yytext);
			yylval.rel_op = (char*) malloc(sizeof(char) * 3);
			strcpy(yylval.rel_op, "<");
			return REL;
		}
"<="	{	
			//fprintf(stderr,"%s",yytext);
			yylval.rel_op = (char*) malloc(sizeof(char) * 3);
			strcpy(yylval.rel_op, "<=");
			return REL;
		}
">="	{	
			//fprintf(stderr,"%s",yytext);
			yylval.rel_op = (char*) malloc(sizeof(char) * 3);
			strcpy(yylval.rel_op, ">=");
			return REL;
		}
">"		{	
			//fprintf(stderr,"%s",yytext);
			yylval.rel_op = (char*) malloc(sizeof(char) * 3);
			strcpy(yylval.rel_op, ">");
			return REL;
		}
"=="	{	
			//fprintf(stderr,"%s",yytext);
			yylval.rel_op = (char*) malloc(sizeof(char) * 3);
			strcpy(yylval.rel_op, "==");
			return REL;
		}
"!="	{	
			//fprintf(stderr,"%s",yytext);
			yylval.rel_op = (char*) malloc(sizeof(char) * 3);
			strcpy(yylval.rel_op, "!=");
			return REL;
		} /* relational operators */

"+"|"-"|"*"|"/" {
			//fprintf(stderr,"%c",yytext[0]);
			return yytext[0];
		} /* arithmetic operators */

{DIGIT}+|"+"{DIGIT}+|"-"{DIGIT}+ {
	//fprintf(stderr,"<%s>",yytext);
	yylval.number = strdup(yytext);
	return NUMBER;
} /* numeric constants */

{ID}+ {
	//fprintf(stderr,"<%s>",yytext);
	yylval.identifier = strdup(yytext);
	return IDENTIFIER;
} /* identifiers */

{WS} { } /*remove whitespace*/

{ENDSTMT}|. {
	//fprintf(stderr,"\n");
	return yytext[0];
}

%%