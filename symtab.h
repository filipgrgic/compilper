#ifndef SYMTAB_H
#define SYMTAB_H

enum type {
    TYPE_VAR,
    TYPE_LABEL
};

typedef struct node {
    char *name;
    enum type type;
    struct node *next;
} node_t;

typedef struct table {
    node_t *head;
    struct table *outer;
} table_t;

#endif
