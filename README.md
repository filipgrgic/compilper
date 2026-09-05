# compilper

`compilper` is a small compiler project targeting **AMD64 (x86-64)**. The name is a combination of *compiler* and **pilp**, my nickname. I originally started the project as part of a compiler construction course at university, but did not finish the final stage at the time. I later returned to the project and completed the missing parts, including full function-call support and additional testing.

The compiler implements a small custom programming language and translates valid source programs into **AMD64 assembly using the System V AMD64 calling convention**.

## Features

The compiler currently supports:

* Functions and function parameters
* Local variables
* Variable assignments
* Function calls
* Nested function calls
* Recursive functions
* Calls to externally defined functions
* Integer constants

  * Decimal
  * Hexadecimal
  * `_` separators
* Arithmetic operators

  * `+`
  * `-`
  * `*`
* Bitwise operators

  * `and`
  * `not`
* Comparisons

  * `>`
  * `=`
* Array reads and writes
* Conditional control flow using `cond`
* Guarded statements
* `continue`
* `break`
* Named `cond` labels
* Static variable and label scope checking
* AMD64 register-based expression evaluation
* Stack-safe function calls
* Recursive and nested call support
* Automatic regression tests

The compiler differentiates between:

| Exit code | Meaning                          |
| --------: | -------------------------------- |
|       `0` | Successful compilation           |
|       `1` | Lexical error                    |
|       `2` | Syntax error                     |
|       `3` | Static analysis / semantic error |

---

# Target Architecture

The compiler generates **64-bit AMD64/x86-64 assembly**.

It follows the **System V AMD64 ABI**, including the standard integer argument registers:

```text
%rdi
%rsi
%rdx
%rcx
%r8
%r9
```

Function return values are placed in:

```text
%rax
```

Function parameters are copied into stack-frame locations at the beginning of each generated function.

The compiler is therefore primarily intended for **64-bit Linux systems using the System V ABI**.

Generated assembly can be assembled and linked with GCC.

---

# The Language

The implemented language is a small imperative language designed for compiler-construction exercises.

There is only one data representation: a **64-bit word**.

A word may represent:

* a signed integer
* an array address

There is no static or runtime type system distinguishing these two uses.

## Example

```text
inc(x)
    return x + 1;
end;

sum(a,b)
    return a + b;
end;

worker(a,n)
    var i := 0;
    var acc := 0;

    loop:
    cond
        i = n ->
            break loop;

        ->
            acc := acc + (a[i]);
            i := inc(i);
            continue loop;
    end;

    return acc;
end;
```

---

# Language Syntax

A program consists of zero or more function definitions:

```text
function(parameters)
    statements
end;
```

Example:

```text
add(a,b)
    return a + b;
end;
```

## Keywords

The language contains the following keywords:

```text
end
return
var
cond
continue
break
and
not
```

Keywords are **case-sensitive**.

For example:

```text
end
```

is a keyword, while:

```text
End
```

is a valid identifier.

---

## Identifiers

Identifiers:

* must begin with a letter
* may contain letters, digits and `_`

Examples:

```text
foo
myVariable
array_1
x123
```

---

## Numbers

Decimal and hexadecimal integer constants are supported.

Examples:

```text
123
000123
1_000
0xFF
0xCAFE
```

Underscores are ignored when converting the number.

Therefore:

```text
1_000
```

represents:

```text
1000
```

and:

```text
0xFF
```

represents:

```text
255
```

---

## Variables

Variables are introduced using `var`:

```text
var x := 10;
```

A variable is visible only **after** its definition.

Therefore this is valid:

```text
var x := 10;
return x;
```

while this is invalid:

```text
var x := x;
```

Parameters are visible throughout the entire function.

---

## Assignment

Variables can be reassigned:

```text
x := 42;
```

Array elements can also be assigned:

```text
a[i] := 42;
```

---

## Arrays

Arrays are represented simply by addresses.

Reading an array element:

```text
a[i]
```

corresponds to accessing:

```text
address(a) + 8 * i
```

because every element is one 64-bit word.

Writing an array element:

```text
a[i] := value;
```

No bounds checking or runtime type checking is performed.

---

## Functions

Functions are defined as:

```text
add(a,b)
    return a + b;
end;
```

and called as:

```text
add(10,20)
```

Calls may be nested:

```text
inc(inc(5))
```

or used inside expressions:

```text
10 + inc(5)
```

Recursive calls are supported:

```text
fact(n)
    cond
        n = 0 ->
            return 1;
            break;

        ->
            return n * fact(n - 1);
            break;
    end;
end;
```

Functions referenced by a call do not have to be defined in the same source program. This makes it possible to link generated code with external functions implemented elsewhere, for example in C.

---

# Expressions

Supported operations include:

```text
+
-
*
and
not
>
=
```

Examples:

```text
a + b
a * b
a - b
a and b
not a
a > b
a = b
```

`and` and `not` are **bitwise** operations.

Comparisons return:

```text
1
```

for true and:

```text
0
```

for false.

Parentheses may be used to create nested expressions:

```text
1 + (2 + (3 + 4))
```

---

# Control Flow

Control flow is implemented using `cond`.

Example:

```text
cond
    x = 0 ->
        return 10;
        break;

    ->
        return 20;
        break;
end;
```

A guard without an expression:

```text
->
```

is unconditional.

A guard expression is considered true when its result is **odd**.

---

## `break`

`break` exits the surrounding `cond`:

```text
cond
    condition ->
        break;
end;
```

---

## `continue`

`continue` jumps back to the beginning of the surrounding `cond`:

```text
loop:
cond
    x = 10 ->
        break loop;

    ->
        x := x + 1;
        continue loop;
end;
```

---

## Labels

A `cond` may have a label:

```text
outer:
cond
    ->
        break outer;
end;
```

Labels have their own scope and are statically checked.

Variables and labels may not have overlapping visibility using the same name.

---

# Compiler Structure

The project uses several classic compiler-construction tools:

```text
Source program
      │
      ▼
   flex scanner
      │
      ▼
  bison parser
      │
      ▼
 ox attributed grammar
      │
      ▼
   AST / static analysis
      │
      ▼
 iburg instruction selection
      │
      ▼
 AMD64 assembly
```

---

# Repository Structure

## `scanner.l`

The **flex scanner**.

It is responsible for lexical analysis and recognizes:

* identifiers
* decimal numbers
* hexadecimal numbers
* keywords
* operators
* punctuation
* comments
* whitespace

It also converts numeric literals into their numeric representation.

Lexical errors terminate compilation with exit code `1`.

---

## `parser.y`

Contains the grammar and the **ox attributed grammar rules**.

Its responsibilities include:

* parsing the language
* building the abstract syntax tree
* variable scope analysis
* label scope analysis
* checking variable uses
* checking label uses
* detecting conflicting definitions
* preparing function parameters for code generation

Syntax errors terminate compilation with exit code `2`.

Static-analysis errors terminate compilation with exit code `3`.

---

## `symtab.h`

Defines the data structures used by the symbol table.

It distinguishes between:

```c
TYPE_VAR
TYPE_LABEL
```

and represents nested scopes using linked symbol tables.

---

## `tree.h`

Defines the abstract syntax tree representation.

AST node types include nodes for:

* constants
* variables
* arithmetic expressions
* comparisons
* arrays
* assignments
* variable definitions
* functions
* function calls
* argument lists
* `cond`
* guarded statements
* `continue`
* `break`

It also contains the interface used by `iburg`.

---

## `tree.c`

Implements creation of AST nodes.

For example:

```text
create_num
create_var
create_plus
create_array
create_call
create_args
create_return
create_conds
```

The parser uses these functions to construct the internal program representation.

---

## `compilper.bfe`

Contains most of the **AMD64 code generation logic**.

It includes:

* iburg tree-pattern rules
* register-based expression evaluation
* variable stack offsets
* function stack-frame generation
* function parameter handling
* function calls
* nested calls
* temporary stack management
* stack alignment
* array access
* assignments
* `cond`
* `break`
* `continue`
* generated labels

For expressions without function calls, `iburg` performs instruction selection using several AMD64 registers.

Expressions containing calls use a stack-safe evaluation strategy so that nested calls cannot destroy intermediate results stored in caller-saved registers.

---

## `Makefile`

Controls the complete compiler build.

The build pipeline generates intermediate files using:

```text
ox
bison
flex
bfe
iburg
gcc
```

Running:

```bash
make
```

produces:

```text
./compilper
```

Running:

```bash
make clean
```

removes all generated files and the compiler executable.

---

## `test_compiler.sh`

Automated regression-test suite.

It:

* rebuilds the compiler
* checks compiler exit codes
* tests lexical analysis
* tests static analysis
* generates assembly
* links generated assembly with C test programs
* executes the resulting programs
* verifies their output

It includes tests for:

* numbers
* arithmetic
* variables
* arrays
* function calls
* nested calls
* six arguments
* recursion
* external functions
* calls inside expressions
* calls inside array operations
* `cond`
* `continue`
* `break`
* labels
* full integration

---

# Generated Files

The build process creates several intermediate files.

These should normally **not be edited manually**.

Examples include:

```text
oxout.y
oxout.l
y.tab.c
y.tab.h
lex.yy.c
compilper.brg
iburg.c
```

They can all be removed using:

```bash
make clean
```

and regenerated using:

```bash
make
```

---

# Requirements

The compiler is intended to be built on Linux.

The following tools are required:

* GCC
* GNU Make
* flex
* bison
* ox
* bfe
* iburg

The standard tools can normally be installed through the system package manager.

## Arch Linux

```bash
sudo pacman -S base-devel flex bison
```

This installs, among other tools:

```text
gcc
make
flex
bison
```

## Debian / Ubuntu

```bash
sudo apt update
sudo apt install build-essential flex bison
```

## `ox`, `bfe` and `iburg`

The project additionally depends on:

```text
ox
bfe
iburg
```

These are compiler-construction tools used by the original university environment and must be installed separately if they are not already available on the system.

Verify that all required tools can be found:

```bash
command -v gcc
command -v make
command -v flex
command -v bison
command -v ox
command -v bfe
command -v iburg
```

Each command should print the path to the corresponding executable.

---

# Building

Clone the repository:

```bash
git clone <repository-url>
cd compilper
```

Build everything from scratch:

```bash
make clean
make
```

A successful build creates:

```text
compilper
```

Verify:

```bash
./compilper
```

The compiler reads source code from **standard input** and writes generated AMD64 assembly to **standard output**.

---

# Usage

Compile a source program directly:

```bash
echo 'test() return 42; end;' | ./compilper
```

Or compile a file:

```bash
./compilper < program.src
```

Save the generated assembly:

```bash
./compilper < program.src > program.s
```

The resulting assembly can then be assembled and linked using GCC.

Example:

```bash
./compilper < program.src > program.s
gcc program.s test.c -o test
./test
```

---

# Testing

The repository contains an automated regression-test suite.

First make it executable if necessary:

```bash
chmod +x test_compiler.sh
```

Run all tests:

```bash
./test_compiler.sh
```

The script automatically:

1. runs `make clean`
2. rebuilds the compiler
3. executes compiler tests
4. generates AMD64 assembly
5. compiles generated assembly with GCC
6. runs the generated programs
7. verifies their output

A successful run ends with output similar to:

```text
========================================
Test summary
========================================
Passed: 35
Failed: 0
========================================
ALL TESTS PASSED
```

The exact number of tests may change as the test suite is extended.

---

# Quick Start

For a system where all dependencies are already installed:

```bash
git clone <repository-url>
cd compilper

make clean
make

./test_compiler.sh
```

Compile your own program:

```bash
./compilper < input.src > output.s
```

---

# Example: Calling Generated Code from C

Compiler input:

```text
add(a,b)
    return a + b;
end;
```

Generate assembly:

```bash
./compilper < add.src > add.s
```

Create:

```c
#include <stdio.h>

long add(long a, long b);

int main(void) {
    printf("%ld\n", add(10, 20));
    return 0;
}
```

Compile and run:

```bash
gcc add.s main.c -o example
./example
```

Output:

```text
30
```

This demonstrates that functions generated by `compilper` can be called directly from C code using the System V AMD64 calling convention.

---

# Notes

This is an educational compiler rather than a production compiler.

The language intentionally keeps several aspects simple:

* only one 64-bit data representation
* no type checking
* no array bounds checking
* no memory management
* no runtime system
* direct AMD64 code generation
* simple static name and scope analysis

The project focuses on the core stages of compiler construction:

* lexical analysis
* parsing
* attributed grammars
* static analysis
* abstract syntax trees
* instruction selection
* register usage
* stack frames
* calling conventions
* control-flow generation
* AMD64 assembly generation
