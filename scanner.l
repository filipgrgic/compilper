%option noyywrap noinput nounput

%{
#include "symtab.h"
#include "y.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

long convertToNumber(char *name) {
	char *clean = malloc(strlen(name) + 1);
	int i = 0;
	int j = 0;
	while(name[i] != '\0') {
		if (name[i] != '_') {
			clean[j] = name[i];
			i++;
			j++;
		} else i++;
	}
	clean[j] = '\0';
	long result = strtoll(clean, NULL, 0);
	free(clean);
	return result;
}
%}

%%
end {return END;}
return {return RETURN;}
var {return VAR;}
cond {return COND;}
continue {return CONTINUE;}
break {return BREAK;}
and {return AND;}
not {return NOT;}

0x[0-9A-Fa-f_]+ return NUM; @{
	@NUM.value@ = convertToNumber(yytext);
@}

[A-Za-z][A-Za-z0-9_]* return ID; @{ 
	@ID.name@ = strdup(yytext); 
@}

_*[0-9][0-9_]* return NUM; @{
	@NUM.value@ = convertToNumber(yytext);
@}

[\n\t ]+ {}

--.* {}

":="   { return ASSIGNOP; }
"->"   { return ARROW; }
";"    { return ';'; }
"("    { return '('; }
")"    { return ')'; }
","    { return ','; }
":"    { return ':'; }
">"    { return '>'; }
"="    { return '='; }
"-"    { return '-'; }
"*"    { return '*'; }
"+"    { return '+'; }
"["    { return '['; }
"]"    { return ']'; }

. {exit(1);}
%%
