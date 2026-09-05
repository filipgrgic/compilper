#ifndef TREE_H
#define TREE_H

struct treenode;
struct burm_state;

#define NODEPTR_TYPE struct treenode *
#define OP_LABEL(p) ((p)->type)
#define LEFT_CHILD(p) ((p)->left)
#define RIGHT_CHILD(p) ((p)->right)
#define STATE_LABEL(p) ((p)->state)

enum treenode_type {
    NUM_N,
    VAR_N,
    RETURN_N,
    FUNC_N,
    PLUS_N,
    MULT_N,
    MIN_N,
    AND_N,
    NOT_N,
    GREAT_N,
    EQUALS_N,
    ARRAY_N,
    STATS_N,
    VARDEF_N,
    ASSIGN_N,
    ARRAY_ASSIGN_N,
    TERMSTAT_N,
    CONDS_N,
    GUARDED_N,
    CONTINUE_N,
    BREAK_N,
    CALL_N,
    ARGS_N
};

typedef struct treenode {
    enum treenode_type type;

    char *name;
    long num;

    struct treenode *left;
    struct treenode *right;
    struct treenode *third;

    struct burm_state *state;
} treenode_t;

treenode_t* create_num(long a);

treenode_t* create_var(char *name);

treenode_t* create_return(treenode_t *expr);

treenode_t* create_func(char *name, treenode_t *body);

treenode_t* create_not(treenode_t *t);

treenode_t* create_array(treenode_t *var, treenode_t *index);

treenode_t* create_plus(treenode_t *t1, treenode_t *t2);

treenode_t* create_mult(treenode_t *t1, treenode_t *t2);

treenode_t* create_and(treenode_t *t1, treenode_t *t2);

treenode_t* create_grEqMin(int op, treenode_t *t1, treenode_t *t2);

treenode_t* create_stats(treenode_t *first, treenode_t *second);

treenode_t* create_vardef(char *name, treenode_t *expr);

treenode_t* create_assign(char *name, treenode_t *expr);

treenode_t* create_array_assign(treenode_t *array, treenode_t *index, treenode_t *expr);

treenode_t* create_termstat(treenode_t *term);

treenode_t* create_conds(char *label, treenode_t *guarded_list);

treenode_t* create_guarded(treenode_t *condition, treenode_t *stats, treenode_t *contbreak);

treenode_t* create_continue(char *label);

treenode_t* create_break(char *label);

int reset_params(void);

int add_param(char *name);

int generate_function(treenode_t *func);

treenode_t* create_args(treenode_t *args, treenode_t *expr);

treenode_t* create_call(char *name, treenode_t *args);

#endif
