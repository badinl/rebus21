/*
BADIN LUCA 1242060
COMPILATORI - PROGETTO FINALE
"REBUS" - TYPE DEFINITION HEADER
*/

/* TYPEDEFS */

typedef struct st_entry {
	char * identifier;
	char * type;
	int address;
	struct st_entry *next;
} st_entry;

typedef struct ia_node {
	char * instruction;
	struct ia_node *next;
} ia_node;

typedef struct bp_node {
	int line;
	struct bp_node *next;
} bp_node;

typedef struct backpatch {
	bp_node * truelist;
	bp_node * falselist;
	bp_node * nextlist;
} bp_payload;

typedef struct decl_ass {
	char * identifier;
	char * temp_label;
} decl_ass_payload;


/* YYSTYPE */
union YYSTYPE {
	//for backpatching lists
	bp_payload backpatch; 
	
	//for marker
	int marker;

	//not backpatching, just different terminals
	//keeping them separate so they make more sense
	char * identifier;
	char * number;
	char * rel_op;
	char * type;
	//
	char * address;
	//payload for declaration with assignment
	decl_ass_payload assign;
};