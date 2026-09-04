%{
#include <stdlib.h>
#include <string.h>
#include "symtab.h"
#include "tree.h"

int yylex(void);
void yyerror(const char *s);

table_t *initTable(table_t *o) {
	table_t *table = malloc(sizeof(table_t));
	table->head = NULL;
	table->outer = o;
	return table;
}

int searchInTable(char *n, table_t *t) {
    if (t == NULL) return -1;
    if (t->head != NULL) {
        node_t *c = t->head;
        while (c != NULL) {
            if (strcmp(n, c->name) == 0) {
                if (c->type == TYPE_VAR) return 0;
                return 1;
            }
            c = c->next;
        }
    }
    return searchInTable(n, t->outer);
}

int checkVar(char *n, table_t *t) {
    if (searchInTable(n, t) != 0) exit(3);
    return 1;
}

int checkLabel(char *n, table_t *t) {
    if (searchInTable(n, t) != 1) exit(3);
    return 1;
}

node_t *copyNode(node_t *n) {
    node_t *copy = malloc(sizeof(node_t));
    copy->name = strdup(n->name);
    copy->type = n->type;
    copy->next = NULL;
    return copy;
}

table_t *copyTable(table_t *t) {
    if (!t) return NULL;

    table_t *copy = malloc(sizeof(table_t));
    if (!t->head) {
        copy->head = NULL;
        copy->outer = t->outer;
        return copy;
    }

    copy->head = copyNode(t->head);
    node_t *current = t->head;
    node_t *currentCopy = copy->head;
    current = current->next;

    while (current != NULL) {
        currentCopy->next = copyNode(current);
        currentCopy = currentCopy->next;
        current = current->next;
    }

    copy->outer = t->outer; // outer wird nicht verändert, deshalb muss es nicht extra kopiert werden.
    return copy;
}

table_t *copyAndExtendTable(char *n, enum type ty, table_t *t) {
    if (searchInTable(n, t) != -1) exit(3);

    node_t *node = malloc(sizeof(node_t));
    node->name = strdup(n);
    node->type = ty;
    node->next = NULL;

    table_t *copy = copyTable(t);

    if (copy->head == NULL) {
        copy->head = node;
    } else {
        node_t *current = copy->head;

        while (current->next != NULL){
            current = current->next;
        }
        current->next = node;
    }

    return copy;
}

treenode_t* make_assignment(char *name, treenode_t *base, treenode_t *index, treenode_t *expr) {
    if (name != NULL) {
        return create_assign(name, expr);
    }

    return create_array_assign(base, index, expr);
}

treenode_t* make_contbreak(int kind, char *label) {
    if (kind == 0) {
        return create_continue(label);
    }

    return create_break(label);
}
%}

%token ID NUM END RETURN VAR COND CONTINUE BREAK AND NOT ASSIGNOP ARROW
%start Program

@attributes { char *name; } ID
@attributes { long value; } NUM
@attributes { table_t *in; table_t *out; char *name; } Label
@attributes { table_t *in; table_t *out; int init; int add; } Pars
@attributes { table_t *in; table_t *out; struct treenode *t; } Stats Stat
@attributes { table_t *in; struct treenode *t; } Conds GuardedList Guarded OptExpr
@attributes { table_t *in; } ExprList
@attributes { table_t *in; struct treenode *t; } Expr NotExpr AddExpr MultExpr AndExpr
@attributes { table_t *in; int ok; char *name; } OptId
@attributes { table_t *in; int ok; char *name; struct treenode *base; struct treenode *index; } Lexpr
@attributes { table_t *in; int ok; struct treenode *t; } Term
@attributes { struct treenode *t; int init; int gen; } Funcdef
@attributes { int op; } GreatEqMinus
@attributes { int kind; } ContBreak
%%

Program :   FunctionList
        ;

FunctionList:   /* empty */
            |   FunctionList Funcdef ';'
            ;

Funcdef :   ID '(' Pars ')' Stats END
                @{
                    @i @Funcdef.init@ = reset_params();
                    @i @Pars.init@ = @Funcdef.init@;
                    @i @Pars.in@ = initTable(NULL);
                    @i @Stats.in@ = @Pars.out@;
                    @i @Funcdef.t@ = create_func(@ID.name@, @Stats.t@);
                    @i @Funcdef.gen@ = @Pars.add@ + generate_function(@Funcdef.t@);		 
		@}
        ;

Pars    :   /* empty */
                @{
                    @i @Pars.out@ = @Pars.in@;
                    @i @Pars.add@ = @Pars.init@;
                @}
        |   ID
                @{
                    @i @Pars.out@ = copyAndExtendTable(@ID.name@, TYPE_VAR, @Pars.in@);
                    @i @Pars.add@ = @Pars.init@ + add_param(@ID.name@);
                @}
        |   ID ',' Pars
                @{
                    @i @Pars.1.init@ = @Pars.0.init@ + add_param(@ID.name@);
                    @i @Pars.1.in@ = copyAndExtendTable(@ID.name@, TYPE_VAR, @Pars.0.in@);
                    @i @Pars.0.out@ = @Pars.1.out@;
                    @i @Pars.0.add@ = @Pars.1.add@;
                @}
        ;

Stats   :   /* empty */
                @{
                    @i @Stats.out@ = @Stats.in@;
                    @i @Stats.t@ = NULL;
                @}
        |   Stats Stat ';'
                @{
                    @i @Stats.1.in@ = @Stats.0.in@;
                    @i @Stat.in@ = @Stats.1.out@;
                    @i @Stats.0.out@ = @Stat.out@;
                    @i @Stats.0.t@ = create_stats(@Stats.1.t@, @Stat.t@);
                @}
        ;

Stat    :   RETURN Expr
                @{
                    @i @Expr.in@ = @Stat.in@;
                    @i @Stat.out@ = @Stat.in@;
                    @i @Stat.t@ = create_return(@Expr.t@);
                @}
        |   Conds
                @{
                    @i @Conds.in@ = @Stat.in@;
                    @i @Stat.out@ = @Stat.in@;
                    @i @Stat.t@ = @Conds.t@;
                @}
        |   VAR ID ASSIGNOP Expr /* Variablendefinition */
                @{
                    @i @Expr.in@ = @Stat.in@;
                    @i @Stat.out@ = copyAndExtendTable(@ID.name@, TYPE_VAR, @Stat.in@);
                    @i @Stat.t@ = create_vardef(@ID.name@, @Expr.t@);
                @}
        |   Lexpr ASSIGNOP Expr /* Zuweisung */
                @{
                    @i @Lexpr.in@ = @Stat.in@;
                    @i @Expr.in@ = @Stat.in@;
                    @i @Stat.out@ = @Stat.in@;
                    @i @Stat.t@ = make_assignment(@Lexpr.name@, @Lexpr.base@, @Lexpr.index@, @Expr.t@);
                @}
        |   Term
                @{
                    @i @Term.in@ = @Stat.in@;
                    @i @Stat.out@ = @Stat.in@;
                    @i @Stat.t@ = create_termstat(@Term.t@);
                @}
        ;

Conds   :   Label COND GuardedList END
                @{
                    @i @Label.in@ = initTable(@Conds.in@);
                    @i @GuardedList.in@ = @Label.out@;
		    @i @Conds.t@ = create_conds(@Label.name@, @GuardedList.t@);
                @}
        ;

Label   :   /* empty */
                @{ 
		    @i @Label.out@ = @Label.in@; 
		    @i @Label.name@ = NULL;
		@}
        |   ID ':'
                @{ 
		    @i @Label.out@ = copyAndExtendTable(@ID.name@, TYPE_LABEL, @Label.in@);
		    @i @Label.name@ = @ID.name@; 
		@}
        ;

GuardedList :   /* empty */
                    @{
                        @i @GuardedList.t@ = NULL;
                    @}
            |   GuardedList Guarded ';'
                    @{
                        @i @GuardedList.1.in@ = @GuardedList.0.in@;
                        @i @Guarded.in@ = @GuardedList.0.in@;
                        @i @GuardedList.0.t@ = create_stats(@GuardedList.1.t@, @Guarded.t@);
                    @}
            ;

Guarded :   OptExpr ARROW Stats ContBreak OptId /* Labelverwendung */
                @{
                    @i @OptExpr.in@ = @Guarded.in@;
                    @i @Stats.in@ = initTable(@Guarded.in@);
                    @i @OptId.in@ = @Guarded.in@;
		    @i @Guarded.t@ = create_guarded(@OptExpr.t@, @Stats.t@, make_contbreak(@ContBreak.kind@, @OptId.name@));
                @}
        ;

OptExpr :   /* empty */
		@{
		    @i @OptExpr.t@ = NULL;
		@}
        |   Expr
                @{ 
		    @i @Expr.in@ = @OptExpr.in@; 
		    @i @OptExpr.t@ = @Expr.t@;
		@}
        ;

OptId   :   /* empty */
                @{ 
		    @i @OptId.ok@ = 1; 
		    @i @OptId.name@ = NULL;
		@}
        |   ID
                @{ 
		    @i @OptId.ok@ = checkLabel(@ID.name@, @OptId.in@); 
		    @i @OptId.name@ = @ID.name@;
		@}
        ;

ContBreak   :   CONTINUE
                    @{
                        @i @ContBreak.kind@ = 0;
                    @}
            |   BREAK
                    @{
                        @i @ContBreak.kind@ = 1;
                    @}
            ;

Lexpr   :   ID
                @{ 
		    @i @Lexpr.ok@ = checkVar(@ID.name@, @Lexpr.in@);
		    @i @Lexpr.name@ = @ID.name@;
		    @i @Lexpr.base@ = NULL;
		    @i @Lexpr.index@ = NULL;
		@}
        |   Term '[' Expr ']'
        	@{
                    @i @Term.in@ = @Lexpr.in@;
                    @i @Expr.in@ = @Lexpr.in@;
                    @i @Lexpr.ok@ = 1;
		    @i @Lexpr.name@ = NULL;
		    @i @Lexpr.base@ = @Term.t@;
		    @i @Lexpr.index@ = @Expr.t@;
                @}
	;

Expr    :   Term
                @{
                    @i @Term.in@ = @Expr.in@;
                    @i @Expr.t@ = @Term.t@;
                @}
        |   NotExpr
                @{ 
		    @i @NotExpr.in@ = @Expr.in@; 
                    @i @Expr.t@ = @NotExpr.t@;
		@}
        |   Term '[' Expr ']'
                @{
                    @i @Term.in@ = @Expr.0.in@;
                    @i @Expr.1.in@ = @Expr.0.in@;
                    @i @Expr.0.t@ = create_array(@Term.t@, @Expr.1.t@);
                @}
        |   AddExpr
                @{
                    @i @AddExpr.in@ = @Expr.in@;
                    @i @Expr.t@ = @AddExpr.t@;
                @}
        |   MultExpr
                @{
                    @i @MultExpr.in@ = @Expr.in@;
                    @i @Expr.t@ = @MultExpr.t@;
                @}
        |   AndExpr
                @{
                    @i @AndExpr.in@ = @Expr.in@;
                    @i @Expr.t@ = @AndExpr.t@;
                @}
        |   Term GreatEqMinus Term
                @{
                    @i  @Term.0.in@ = @Expr.in@;
                    @i @Term.1.in@ = @Expr.in@;
                    @i @Expr.t@ = create_grEqMin(@GreatEqMinus.op@, @Term.0.t@, @Term.1.t@);
                @}
        ;

NotExpr :   NOT Term
                @{ 
		    @i @Term.in@ = @NotExpr.in@;
		    @i @NotExpr.t@ = create_not(@Term.t@);
		@}
        |   NOT NotExpr
                @{ 
		    @i @NotExpr.1.in@ = @NotExpr.0.in@; 
		    @i @NotExpr.0.t@ = create_not(@NotExpr.1.t@);
		@}
        ;

AddExpr:   Term '+' Term
                @{ 
		    @i @Term.0.in@ = @AddExpr.in@; 
		    @i @Term.1.in@ = @AddExpr.in@; 
		    @i @AddExpr.t@ = create_plus(@Term.0.t@, @Term.1.t@);
		@}
        |   AddExpr '+' Term
                @{
                    @i @Term.in@ = @AddExpr.0.in@;
                    @i @AddExpr.1.in@ = @AddExpr.0.in@;
		    @i @AddExpr.0.t@ = create_plus(@AddExpr.1.t@, @Term.t@);
                @}
        ;

MultExpr:   Term '*' Term
                @{ 
		    @i @Term.0.in@ = @MultExpr.in@; 
		    @i @Term.1.in@ = @MultExpr.in@; 
		    @i @MultExpr.t@ = create_mult(@Term.0.t@, @Term.1.t@);
		@}
        |   MultExpr '*' Term
                @{
                    @i @Term.in@ = @MultExpr.0.in@;
                    @i @MultExpr.1.in@ = @MultExpr.0.in@;
		    @i @MultExpr.0.t@ = create_mult(@MultExpr.1.t@, @Term.t@);
                @}
        ;

AndExpr:   Term AND Term
                @{ 
		    @i @Term.0.in@ = @AndExpr.in@; 
		    @i @Term.1.in@ = @AndExpr.in@; 
		    @i @AndExpr.t@ = create_and(@Term.0.t@, @Term.1.t@);
		@}
        |   AndExpr AND Term
                @{
                    @i @Term.in@ = @AndExpr.0.in@;
                    @i @AndExpr.1.in@ = @AndExpr.0.in@;
		    @i @AndExpr.0.t@ = create_and(@AndExpr.1.t@, @Term.t@);
                @}
        ;

GreatEqMinus:   '>'
	    	    @{ @i @GreatEqMinus.op@ = 1; @}	
            |   '='
	    	    @{ @i @GreatEqMinus.op@ = 0; @}	
            |   '-'
	    	    @{ @i @GreatEqMinus.op@ = 2; @}	
            ;

Term    :   '(' Expr ')'
                @{
                    @i @Expr.in@ = @Term.in@;
                    @i @Term.ok@ = 1;
                    @i @Term.t@ = @Expr.t@;
                @}
        |   NUM
                @{
                    @i @Term.ok@ = 1;
                    @i @Term.t@ = create_num(@NUM.value@);
                @}
        |   ID
                @{
                    @i @Term.ok@ = checkVar(@ID.name@, @Term.in@);
                    @i @Term.t@ = create_var(@ID.name@);
                @}
        |   ID '(' ExprList OptExpr ')'
                @{
                    @i @ExprList.in@ = @Term.in@;
                    @i @OptExpr.in@ = @Term.in@;
                    @i @Term.ok@ = 1;
                    @i @Term.t@ = NULL;
                @}
        ;

ExprList:   /* empty */
        |   ExprList Expr ','
                @{
                    @i @Expr.in@ = @ExprList.0.in@;
                    @i @ExprList.1.in@ = @ExprList.0.in@;
                @}
        ;

%%
void yyerror(const char *s) {
	(void)s;
        exit(2);
}

int main(void) {
        yyparse();
        exit(0);
}
