#include "tree.h"
#include <stdlib.h>
#include <string.h>

static treenode_t* create_node(enum treenode_type type) {
    treenode_t *n = malloc(sizeof(treenode_t));

    n->type = type;
    n->name = NULL;
    n->num = 0;

    n->left = NULL;
    n->right = NULL;
    n->third = NULL;

    n->state = NULL;

    return n;
}

treenode_t* create_num(long a) {
    treenode_t *n = create_node(NUM_N);
    n->num = a;
    return n;
}

treenode_t* create_var(char *name) {
    treenode_t *n = create_node(VAR_N);
    n->name = strdup(name);
    return n;
}

treenode_t* create_return(treenode_t *expr) {
    treenode_t *n = create_node(RETURN_N);
    n->left = expr;
    return n;
}

treenode_t* create_func(char *name, treenode_t *stats) {
    treenode_t *n = create_node(FUNC_N);
    n->name = strdup(name);
    n->left = stats;
    return n;
}

treenode_t* create_not(treenode_t *t) {
    treenode_t *n = create_node(NOT_N);
    n->left = t;
    return n;
}

treenode_t* create_array(treenode_t *var, treenode_t *index) {
    treenode_t *n = create_node(ARRAY_N);
    n->left = var;
    n->right = index;
    return n;
}

treenode_t* create_plus(treenode_t *t1, treenode_t *t2) {
    treenode_t *n = create_node(PLUS_N);
    n->left = t1;
    n->right = t2;
    return n;
}

treenode_t* create_mult(treenode_t *t1, treenode_t *t2) {
    treenode_t *n = create_node(MULT_N);
    n->left = t1;
    n->right = t2;
    return n;
}

treenode_t* create_and(treenode_t *t1, treenode_t *t2) {
    treenode_t *n = create_node(AND_N);
    n->left = t1;
    n->right = t2;
    return n;
}

treenode_t* create_grEqMin(int op, treenode_t *t1, treenode_t *t2) {
    treenode_t *n;

    switch (op) {
        case 0:
            n = create_node(EQUALS_N);
            break;

        case 1:
            n = create_node(GREAT_N);
            break;

        case 2:
            n = create_node(MIN_N);
            break;

        default:
            n = create_node(MIN_N);
            break;
    }

    n->left = t1;
    n->right = t2;
    return n;
}

treenode_t* create_stats(treenode_t *first, treenode_t *second) {
    if (first == NULL) return second;
    if (second == NULL) return first;

    treenode_t *n = create_node(STATS_N);
    n->left = first;
    n->right = second;
    return n;
}

treenode_t* create_vardef(char *name, treenode_t *expr) {
    treenode_t *n = create_node(VARDEF_N);
    n->name = strdup(name);
    n->left = expr;
    return n;
}

treenode_t* create_assign(char *name, treenode_t *expr) {
    treenode_t *n = create_node(ASSIGN_N);
    n->name = strdup(name);
    n->left = expr;
    return n;
}

treenode_t* create_array_assign(treenode_t *array, treenode_t *index, treenode_t *expr) {
    treenode_t *n = create_node(ARRAY_ASSIGN_N);
    n->left = array;
    n->right = index;
    n->third = expr;
    return n;
}

treenode_t* create_termstat(treenode_t *term) {
    treenode_t *n = create_node(TERMSTAT_N);
    n->left = term;
    return n;
}

treenode_t* create_conds(char *label, treenode_t *guarded_list) {
    treenode_t *n = create_node(CONDS_N);

    if (label != NULL) {
        n->name = strdup(label);
    }

    n->left = guarded_list;
    return n;
}

treenode_t* create_guarded(treenode_t *condition, treenode_t *stats, treenode_t *contbreak) {
    treenode_t *n = create_node(GUARDED_N);
    n->left = condition;
    n->right = stats;
    n->third = contbreak;
    return n;
}

treenode_t* create_continue(char *label) {
    treenode_t *n = create_node(CONTINUE_N);

    if (label != NULL) {
        n->name = strdup(label);
    }

    return n;
}

treenode_t* create_break(char *label) {
    treenode_t *n = create_node(BREAK_N);

    if (label != NULL) {
        n->name = strdup(label);
    }

    return n;
}
