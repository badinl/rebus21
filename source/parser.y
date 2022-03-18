/*
BADIN LUCA 1242060
COMPILATORI - PROGETTO FINALE
"REBUS" - PARSER
*/

%{
	#include <ctype.h>
	#include <stdlib.h>
	#include <stdio.h>
	#include <string.h>
	#include "parser.h"

	int trace = 0; //print trace informations on parser reductions
	int debug = 0; //print debug informations on semantic actions
	int print_line_num = 0; //print line numbers to output file

	int yylex();
	void yyerror(char* s);

	//symbol table
	st_entry* symbol_table = NULL;

	//functions for operations on symbol table
	unsigned int st_count = 0;
	int st_new(char* name, char* type);
	int st_exist(char* name);

	//instruction array for backpatching
	ia_node* instruction_array = NULL;

	//functions for operations on instruction array
	void ia_backpatch(bp_node* backpatch_list, int value);
	void ia_emit(char* instruction);
	int ia_count();
	void ia_generate();
	void ia_print(); //only for debug

	//functions for manipulating backpatching lists
	bp_node* bp_merge(bp_node* list1, bp_node* list2, bp_node* list3);
	bp_node* bp_new(int val);
	int bp_count(bp_node* backpatch_list); //only for debug
	void bp_print(bp_node* backpatch_list); //only for debug

	//temporary name management
	unsigned int temp_count = 0;
	const char* get_temp() {
		if(debug) fprintf(stderr, "Allocating new temp.\n");
		char* new_temp = (char*) malloc(sizeof(char) * 10);
		sprintf(new_temp,"t%i",temp_count++);
		if(debug) fprintf(stderr, "\tAllocated new temp %s\n", new_temp);
		return new_temp;
	}
%}

//import yystype
%define api.value.type {union YYSTYPE}

//tokens
%token	<number>		NUMBER
%token	<identifier>	IDENTIFIER
%token	<rel_op>		REL
%token	<type>			TYPE

%token	IF
%token	ELSE
%token	WHILE

%token	PRINT

//nonterminals
%type	<backpatch>	stmt
%type	<backpatch>	list
%type	<marker>	M
%type	<backpatch>	N

%type	<assign>	decl_ass
%type				assign	//nothing to return
%type				print	//nothing to return
%type				decl	//nothing to return

%type	<backpatch>	bool
%type	<address>	expr	//address- of the variable on the LHS of the expression

//precedence rules on math operators
%left '+' '-'
%left '*' '/'
%right UMINUS

//precedence rules on logical operators
%left OR
%left AND
%right NOT

//definition of relational operators
%nonassoc REL //EQ LT GT LE GE NE

%%

prog:	list										{
														if(trace) fprintf(stderr,"\nX -> L;\n");
														
														ia_backpatch($1.nextlist, ia_count());

														ia_generate();
													};

list:	list M stmt									{
														if(trace) fprintf(stderr,"\nL -> L M S;\n");

														ia_backpatch($1.nextlist, $2);
														$$.nextlist = $3.nextlist;

														if(debug) {
															fprintf(stderr,"nextlist ");
															bp_print($$.nextlist);
														}
													}
		| stmt										{
														if(trace) fprintf(stderr,"\nL -> S;\n");

														$$.nextlist = $1.nextlist;

														if(debug) {
															fprintf(stderr,"nextlist ");
															bp_print($$.nextlist);
														}
													};

stmt:	assign ';'									{
														if(trace) fprintf(stderr,"\nS -> A;\n");

														$$.nextlist = NULL;
													}
		| decl ';'									{
														if(trace) fprintf(stderr,"\nS -> D;\n");

														$$.nextlist = NULL;
													}
		| '{' list '}'								{
														if(trace) fprintf(stderr,"\nS -> {L}\n");

														$$.nextlist = $2.nextlist;

														if(debug) {
															fprintf(stderr,"nextlist ");
															bp_print($$.nextlist);
														}
													}
		| IF '(' bool ')' M stmt					{
														if(trace) fprintf(stderr,"\nS -> IF (B) M S K\n");

														ia_backpatch($3.truelist, $5);
														$$.nextlist = bp_merge($3.falselist, $6.nextlist, NULL);

														if(debug) {
															fprintf(stderr,"nextlist ");
															bp_print($$.nextlist);
														}
													}
		| IF '(' bool ')' M stmt N M stmt			{
														if(trace) fprintf(stderr,"\nS -> IF (B) M S ELSE M S\n");

														ia_backpatch($3.truelist, $5);
														ia_backpatch($3.falselist, $8);

														bp_node* temp = (bp_node*) malloc(sizeof(bp_node));
														temp = bp_merge($6.nextlist, $7.nextlist, $9.nextlist);
														$$.nextlist = temp;

														if(debug) {
															fprintf(stderr,"nextlist ");
															bp_print($$.nextlist);
														}
													}
		| WHILE M '(' bool ')' M stmt				{
														if(trace) fprintf(stderr,"\nS -> WHILE M (B) M S\n");

														ia_backpatch($7.nextlist, $2);
														ia_backpatch($4.truelist, $6);
														$$.nextlist = $4.falselist;

														char* new_goto = (char*) malloc(sizeof(char) * 10);
														sprintf(new_goto, "goto %i", $2);
														ia_emit(new_goto);

														if(debug) {
															fprintf(stderr,"nextlist ");
															bp_print($$.nextlist);
														}
													}
		| print ';'									{
														if(trace) fprintf(stderr,"\nS -> R;\n");

														$$.nextlist = NULL; //controllare
													};

M:		%empty										{
														if(trace) fprintf(stderr,"\nM -> e\n");

														$$ = ia_count();

														if(debug)
															fprintf(stderr,"Marker - saving value of next instruction %i\n", $$);
													};

N:		ELSE										{
														if(trace) fprintf(stderr,"\nN -> ELSE\n");

														$$.nextlist = bp_new(ia_count());
														ia_emit("goto ");

														if(debug) {
															fprintf(stderr,"Else Marker - nextlist");
															bp_print($$.nextlist);
														}
													};

print:	PRINT expr									{
														if(trace) fprintf(stderr,"\nprint -> PRINT E\n");

														char* new_line = (char*) malloc(sizeof(char) * (strlen($2) + 6 + 1));
														sprintf(new_line, "print %s", $2);
														ia_emit(new_line);
														free(new_line);
													};

assign: IDENTIFIER '=' expr							{
														//must exist in ST but we will also need its address
														int address = st_exist($1);

														if(address >= 0) {
															if(trace) fprintf(stderr,"\nA->id = e [ASS]\n");

															char* new_line = (char*) malloc(sizeof(char) * (10 + 3 + strlen($3) + 1));
															sprintf(new_line, "s%i = %s", address, $3);
															ia_emit(new_line);
															free(new_line);
														} else {
															yyerror("Assignment to undeclared variable.");
															YYERROR;												
														}
													};

decl_ass: IDENTIFIER '=' expr						{
														//must not exist in ST
														if(st_exist($1) < 0) {
															if(trace) fprintf(stderr,"\nA->id = e [DEC]\n");

															//DO NOT USE ID yet!
															//use a temp, perform operations on it, and return it
															//parent statement will declare ID and assign temp to it

															const char* temp_label = get_temp();
															char* new_line = (char*) malloc(sizeof(char) * (strlen(temp_label) + strlen($3) + 3 + 1));
															sprintf(new_line, "%s = %s", temp_label, $3);
															ia_emit(new_line);
															free(new_line);

															//payload for assignment
															$$.identifier = $1;
															$$.temp_label = (char*)temp_label; 
														} else {
															yyerror("Redeclaration of existing variable.");	
															YYERROR;
														}
													};

decl:	TYPE label									{
														if(trace) fprintf(stderr,"\nD -> TYPE LL\n");
													};

label:	label ',' IDENTIFIER						{
														if(trace) fprintf(stderr,"\nLL -> LL , id\n");

														if(st_exist($3) < 0) { //check that variable does not exist

															int address = st_new($3,"int");
															
															char* new_line = (char*) malloc(sizeof(char) * (4 + 10 + 1));
															sprintf(new_line, "int s%i", address);
															ia_emit(new_line);
															free(new_line);
														} else {
															yyerror("Redeclaration of existing variable.");
															YYERROR;										
														}
													}
		| label ',' decl_ass						{
														if(trace) fprintf(stderr,"\nLL -> LL , A\n");

														int address = st_new($3.identifier,"int");
														
														char* new_line = (char*) malloc(sizeof(char) * (4 + 10 + 1));
														sprintf(new_line, "int s%i", address);
														ia_emit(new_line);
														free(new_line);
														
														new_line = (char*) malloc(sizeof(char) * (10 + 3 + strlen($3.temp_label) + 1));
														sprintf(new_line, "s%i = %s", address, $3.temp_label);
														ia_emit(new_line);
														free(new_line);
													}
		| IDENTIFIER								{
														if(trace) fprintf(stderr,"\nLL -> id\n");

														if(st_exist($1) < 0) { //check that variable does not exist
															int address = st_new($1,"int");
															
															char* new_line = (char*) malloc(sizeof(char) * (10 + 4 + 1));
															sprintf(new_line, "int s%i", address);
															ia_emit(new_line);
															free(new_line);
														} else {
															yyerror("Redeclaration of existing variable.");
															YYERROR;										
														}
													}
		| decl_ass									{
														if(trace) fprintf(stderr,"\nLL -> A\n");

														int address = st_new($1.identifier,"int");
														
														char* new_line = (char*) malloc(sizeof(char) * (10 + 4 + 1));
														sprintf(new_line, "int s%i", address);
														ia_emit(new_line);
														free(new_line);
														
														new_line = (char*) malloc(sizeof(char) * (10 + 3 + strlen($1.temp_label) + 1));
														sprintf(new_line, "s%i = %s", address, $1.temp_label);
														ia_emit(new_line);
														free(new_line);
													};

bool:	bool OR M bool								{
														if(trace) fprintf(stderr,"\nB -> B OR M B\n");

														ia_backpatch($1.falselist, $3);
														$$.truelist = bp_merge($1.truelist, $4.truelist, NULL);
														$$.falselist = $4.falselist;

														if(debug) {
															fprintf(stderr, "propagating truelist");
															bp_print($$.truelist);
															fprintf(stderr, "propagating falselist");
															bp_print($$.falselist);
														}
													}
		| bool AND M bool							{
														if(trace) fprintf(stderr,"\nB -> B AND M B\n");

														ia_backpatch($1.truelist, $3);
														$$.falselist = bp_merge($1.falselist, $4.falselist, NULL);
														$$.truelist = $4.truelist;

														if(debug) {
															fprintf(stderr, "propagating truelist");
															bp_print($$.truelist);
															fprintf(stderr, "propagating falselist");
															bp_print($$.falselist);
														}
													}
		| NOT bool									{
														if(trace) fprintf(stderr,"\nB -> NOT B\n");

														$$.truelist = $2.falselist;
														$$.falselist = $2.truelist;

														if(debug) {
															fprintf(stderr, "propagating truelist");
															bp_print($$.truelist);
															fprintf(stderr, "propagating falselist");
															bp_print($$.falselist);
														}
													}
		| '(' bool ')'								{
														if(trace) fprintf(stderr,"\nB -> (B)\n");

														$$.truelist = $2.truelist;
														$$.falselist = $2.falselist;

														if(debug) {
															fprintf(stderr, "propagating truelist");
															bp_print($$.truelist);
															fprintf(stderr, "propagating falselist");
															bp_print($$.falselist);
														}
													}
		| expr REL expr								{
														if(trace) fprintf(stderr,"\nB -> E REL E\n");

														$$.truelist = bp_new(ia_count());
														$$.falselist = bp_new(ia_count() + 1);

														char* new_line = (char*) malloc(sizeof(char) * (3 + strlen($1) + 1 + strlen($2) + 1 + strlen($3) + 6 + 1));
														sprintf(new_line, "if %s %s %s goto ", $1, $2, $3);
														ia_emit(new_line);
														ia_emit("goto ");
														free(new_line);

														if(debug) {
															fprintf(stderr, "propagating truelist");
															bp_print($$.truelist);
															fprintf(stderr, "propagating falselist");
															bp_print($$.falselist);
														}
													}
		;

expr:	expr '+' expr								{
														if(trace) fprintf(stderr,"\nE -> E + E\n");

														const char* temp_label = get_temp();
														
														char* new_line = (char*) malloc(sizeof(char) * (strlen(temp_label) + 3 + strlen($1) + 3 + strlen($3) + 1));
														sprintf(new_line, "%s = %s + %s", temp_label, $1, $3);
														ia_emit(new_line); //emit: temp = e1.addr + e2.addr
														free(new_line);
														
														$$ = (char*)temp_label; //propagate synth. label
													}
		| expr '-' expr								{
														if(trace) fprintf(stderr,"\nE -> E - E\n");

														const char* temp_label = get_temp();

														char* new_line = (char*) malloc(sizeof(char) * (strlen(temp_label) + 3 + strlen($1) + 3 + strlen($3) + 1));
														sprintf(new_line, "%s = %s - %s", temp_label, $1, $3);
														ia_emit(new_line);
														free(new_line);

														$$ = (char*)temp_label;
													}
		| expr '*' expr								{
														if(trace) fprintf(stderr,"\nE -> E * E\n");

														const char* temp_label = get_temp();

														char* new_line = (char*) malloc(sizeof(char) * (strlen(temp_label) + 3 + strlen($1) + 3 + strlen($3) + 1));
														sprintf(new_line, "%s = %s * %s", temp_label, $1, $3);
														ia_emit(new_line);
														free(new_line);
														
														$$ = (char*)temp_label;
													}
		| expr '/' expr								{
														if(trace) fprintf(stderr,"\nE -> E // E\n");

														const char* temp_label = get_temp();

														char* new_line = (char*) malloc(sizeof(char) * (strlen(temp_label) + 3 + strlen($1) + 3 + strlen($3) + 1));
														sprintf(new_line, "%s = %s / %s", temp_label, $1, $3);
														ia_emit(new_line);
														free(new_line);
														
														$$ = (char*)temp_label;
													}
		| '(' expr ')'								{
														if(trace) fprintf(stderr,"\nE -> (E)\n");

														const char* temp_label = get_temp();

														char* new_line = (char*) malloc(sizeof(char) * (strlen(temp_label) + 3 + strlen($2) + 1));
														sprintf(new_line, "%s = %s", temp_label, $2);
														ia_emit(new_line);
														free(new_line);
														
														$$ = (char*)temp_label;
													}
		| '-' expr %prec UMINUS						{
														if(trace) fprintf(stderr,"\nE -> -E\n");

														const char* temp_label = get_temp();

														char* new_line = (char*) malloc(sizeof(char) * (strlen(temp_label) + 8 + strlen($2) + 1));
														sprintf(new_line, "%s = minus %s", temp_label, $2);
														ia_emit(new_line);
														free(new_line);
														
														$$ = (char*)temp_label;
													}
		| NUMBER									{
														if(trace) fprintf(stderr,"\nE -> num\n");

														$$ = $1;
													}
		| IDENTIFIER								{
														if(trace) fprintf(stderr,"\nE -> id\n");

														//does this identifier exist?
														int address = st_exist($1);

														if(address>=0) {
															sprintf($$,"s%i",address);
														} else {
															//throw error!!
															yyerror("Undefined identifier.");
															YYERROR;
														}

														$$ = $1;
													}
		;

%%

int main() {
	if (yyparse()  != 0)
		fprintf(stderr,  "Abnormal exit.\n");
	else
		fprintf(stderr,  "Compilation successful.\n");
	return 0;
}

void yyerror(char* s) {
	fprintf(stderr, "Error: %s\n", s);
}

//functions for symbol table
//put new identifier in ST
int st_new(char* name, char* type) {
	if(debug) fprintf(stderr, "Putting new identifier in ST: %s of type %s.\n",name,type);

	//does it exist?
	if(st_exist(name) == -1) {
		//skip to last
		st_entry* current = symbol_table;
		if (current != NULL) { //empty list: don't skip and we'll handle it later
			while (current->next != NULL) current = current->next;
		}

		//create entry
		st_entry* new_entry = (st_entry*)malloc(sizeof(st_entry));
		new_entry->next = NULL;
		new_entry->identifier = strdup(name);
		new_entry->type = strdup(type);
		new_entry->address = st_count++;
		
		//add to ST
		if (current != NULL) current->next = new_entry;
		else symbol_table = new_entry;

		//return its address
		return new_entry->address;
		
	} else { //already exists
		//if(debug) fprintf(stderr, "Warning: identifier %s already exists in ST.", name);
		return -1;
	}
}

//check if identifier exists in ST, returns -1 if not, index if yes
int st_exist(char* name) {
	if(debug) fprintf(stderr, "Checking if exists in ST: %s\n", name);
	
	if(symbol_table == NULL) { //empty ST
		if(debug) fprintf(stderr, "\tST is empty.\n");
		return -1;
	}

	st_entry* current = symbol_table;
	while (current != NULL) {
		if(strcmp(current->identifier, name) == 0) {
			if(debug) fprintf(stderr, "\t%s exists with address %i\n", name, current->address);
			return current->address;
		}
		current = current->next;
	}
	if(debug) fprintf(stderr, "\tDid not exist.\n");
	return -1;
}

//functions for backpatching
//add new instruction to IA
void ia_emit(char* instruction) {
	if(debug) fprintf(stderr, "Emit to IA: %s\n", instruction);

	//skip to last
	ia_node* current = instruction_array;
	if (current != NULL) {
		while (current->next != NULL) current = current->next;
	} //empty list: don't skip and we'll handle it later

	//create entry
	ia_node* new_instruction = (ia_node*)malloc(sizeof(ia_node));
	new_instruction->next = NULL;
	new_instruction->instruction = strdup(instruction);

	if (current != NULL) //add to IA
		current->next = new_instruction;
	else //set as only element of previously empty IA
		instruction_array = new_instruction;
}

//backpatch lines of IA with line value
void ia_backpatch(bp_node* backpatch_list, int value) {
	//visit all lines of IA defined by SLL backpatch_list of bp_nodes
	//they all end with "goto "
	//simply append value to all of them

	//sanity check
	if(instruction_array == NULL) {
		if(debug) fprintf(stderr, "\tThe IA is empty, cannot backpatch.\n");
		return;
	}
	if(backpatch_list == NULL) {
		if(debug) fprintf(stderr, "\tThe backpatch list is empty, cannot backpatch.\n");
		return;
	}
	
	if(debug) {
		fprintf(stderr, "Backpatching list with value: %i\n", value);
		fprintf(stderr, "Backpatch list has %i entries. Contents: ", bp_count(backpatch_list));
		bp_print(backpatch_list);
	}

	int this_line = 0;
	ia_node* current = instruction_array;
	while (current != NULL) {

		//scan the bp list
		bp_node* current_bp = backpatch_list;
		while(current_bp != NULL) {
			//does the bp list contain this line?
			if(current_bp->line == this_line) { //if so, backpatch it
				//fprintf(stderr, "\tBackpatching line %i with value %i.\n", this_line, value);

				//concatenate patch to current->instruction
				char* patch = (char*) malloc(sizeof(char) * 10);
				sprintf(patch, "%i", value);

				char* newBuffer = (char*)malloc(strlen(current->instruction) + strlen(patch) + 1); //allocate new buffer

				//do the copy and concat
				strcpy(newBuffer,current->instruction);
				strcat(newBuffer,patch);

				free(current->instruction); //release old buffer
				current->instruction = newBuffer; //store new pointer
				
				if(debug) fprintf(stderr, "\tLine %i backpatched to read: %s\n", this_line, current->instruction);
			}

			current_bp = current_bp->next;
		}

		current = current->next;
		this_line++;
	}
}

//print all lines in IA to stderr
void ia_print() {
	ia_node* current = instruction_array;
	if(instruction_array == NULL) {
		fprintf(stderr, "<empty IA>");
		return;
	}
	int this_line = 0;
	while (current != NULL) {
		fprintf(stderr, "%i\t%s\n", this_line++, current->instruction);
		current = current->next;
	}
}

//generate final IA to stdout
void ia_generate() {
	ia_node* current = instruction_array;
	int this_line = 0;
	while (current != NULL) {
		if(print_line_num) fprintf(stdout, "%i:\t\t%s\n", this_line, current->instruction);
		else fprintf(stdout, "%s\n", current->instruction);
		current = current->next;
		this_line++;
	}
}

//gets number of current lines in IA
int ia_count() {

	int lines = 0;
	ia_node* current = instruction_array;
	while (current != NULL) {
		lines++;
		current = current->next;
	}

	return lines;
}

//print BP list
void bp_print(bp_node* backpatch_list) {
	bp_node* current = backpatch_list;

	fprintf(stderr, "[ ");

	while (current != NULL) {
		fprintf(stderr, "%i ", current->line);
		current = current->next;
	}

	fprintf(stderr, "]\n");
}

//gets number of entries in BP list
int bp_count(bp_node* backpatch_list) {

	int lines = 0;
	bp_node* current = backpatch_list;
	while (current != NULL) {
		lines++;
		current = current->next;
	}
	
	return lines;
}

//merge backpatch lists
bp_node* bp_merge(bp_node* list1, bp_node* list2, bp_node* list3) {

	if(debug) {
		fprintf(stderr, "Merging BP lists. Lists to be merged\n");
		if(list1 != NULL) bp_print(list1);
		if(list2 != NULL) bp_print(list2);
		if(list3 != NULL) bp_print(list3);
	}

	if (list1 == NULL) { //1 vuota
		if (list2 == NULL) { //1 e 2 vuote: a prescindere result = 3 (anche se null)
			return list3;
		} else { //2 non vuota: result = list2 a prescindere
			if (list3 != NULL) { //list3 non vuota
				//merge 2+3
				bp_node* current = list2;
				while (current->next != NULL) current = current->next;
				current->next = list3;
			} //list3 vuota: non serve fare niente

			return list2;
		}
	} else { //1 non vuota: result = list1 a prescindere
		if (list2 == NULL) { //2 vuota
			if (list3 != NULL) { //3 non vuota
				bp_node* current = list1;
				while (current->next != NULL) current = current->next;
				current->next = list3;
			} //list3 vuota: non serve fare niente
		} else { //2 non vuota
			//merge 1+2
			bp_node* current = list1;
			while (current->next != NULL) current = current->next;
			current->next = list2;

			if (list3 != NULL) { //3 non vuota
				//keep advancing pointer to end of 1+2
				while (current->next != NULL) current = current->next;
				current->next = list3;
			} //list3 vuota: non serve fare niente
		}
		return list1;
	}
}

//create new backpatch list
bp_node* bp_new(int val) {
	if(debug) fprintf(stderr, "Creating new BP list with init line value %i.\n", val);
	bp_node* newlist = (bp_node*) malloc(sizeof(bp_node));
	newlist->line = val;
	newlist->next = NULL;
	return newlist;
}