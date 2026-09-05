#!/usr/bin/env bash

set -u
set -o pipefail

COMPILER="./compilper"

PASSED=0
FAILED=0

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

pass() {
    printf "\033[32m[PASS]\033[0m %s\n" "$1"
    PASSED=$((PASSED + 1))
}

fail() {
    printf "\033[31m[FAIL]\033[0m %s\n" "$1"
    FAILED=$((FAILED + 1))
}

section() {
    printf "\n\033[1m=== %s ===\033[0m\n" "$1"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

section "Build"

if make clean >/dev/null 2>&1 && make >/dev/null 2>&1; then
    pass "make clean && make"
else
    fail "Compiler could not be built"
    echo
    echo "Build output:"
    make clean
    make
    exit 1
fi

if [[ -x "$COMPILER" ]]; then
    pass "compilper executable exists"
else
    fail "compilper executable does not exist"
    exit 1
fi

# ---------------------------------------------------------------------------
# Exit-code tests
# ---------------------------------------------------------------------------

expect_exit_code() {
    local name="$1"
    local expected="$2"
    local source="$3"

    printf '%s\n' "$source" | "$COMPILER" >/dev/null 2>&1
    local actual=$?

    if [[ "$actual" -eq "$expected" ]]; then
        pass "$name (exit $expected)"
    else
        fail "$name: expected exit $expected, got $actual"
    fi
}

section "Error Handling"

expect_exit_code \
    "Lexical error" \
    1 \
    '@'

expect_exit_code \
    "Syntax error" \
    2 \
    'foo( return 1; end;'

expect_exit_code \
    "Undefined variable" \
    3 \
    'foo() return x; end;'

expect_exit_code \
    "Duplicate visible variable" \
    3 \
    'foo(a) var a := 5; return a; end;'

expect_exit_code \
    "Variable used as label" \
    3 \
    'foo(x) cond -> break x; end; end;'

expect_exit_code \
    "Undefined label" \
    3 \
    'foo() cond -> break missing; end; end;'

expect_exit_code \
    "Variable not visible in own definition" \
    3 \
    'foo() var x := x; return 0; end;'

expect_exit_code \
    "Variable outside guarded scope" \
    3 \
    'foo() cond -> var x := 1; break; end; return x; end;'

# ---------------------------------------------------------------------------
# Static-analysis success tests
# ---------------------------------------------------------------------------

expect_success() {
    local name="$1"
    local source="$2"

    printf '%s\n' "$source" | "$COMPILER" >/dev/null 2>&1
    local actual=$?

    if [[ "$actual" -eq 0 ]]; then
        pass "$name"
    else
        fail "$name: compiler returned exit $actual"
    fi
}

section "Static Analysis"

expect_success \
    "Variable visible after definition" \
    'foo() var x := 1; return x; end;'

expect_success \
    "Same variable name in independent guarded scopes" \
    'foo() cond -> var x := 1; break; -> var x := 2; break; end; return 0; end;'

expect_success \
    "Label visible inside cond" \
    'foo() outer: cond -> break outer; end; return 0; end;'

expect_success \
    "Nested cond can access outer label" \
    'foo() outer: cond -> cond -> break outer; end; break; end; return 0; end;'

expect_success \
    "Identifiers are case sensitive" \
    'End() return 1; end;'

# ---------------------------------------------------------------------------
# Runtime-test helper
# ---------------------------------------------------------------------------

runtime_test() {
    local name="$1"
    local expected="$2"
    local source="$3"
    local csource="$4"

    local id
    id=$(printf '%s' "$name" | tr -cd '[:alnum:]')

    local asm="$TMPDIR/${id}.s"
    local cfile="$TMPDIR/${id}.c"
    local binary="$TMPDIR/${id}"

    printf '%s\n' "$source" | "$COMPILER" > "$asm" 2>"$TMPDIR/compiler.err"
    local compiler_status=$?

    if [[ "$compiler_status" -ne 0 ]]; then
        fail "$name: compiler returned exit $compiler_status"
        return
    fi

    printf '%s\n' "$csource" > "$cfile"

    gcc "$asm" "$cfile" -o "$binary" \
        >"$TMPDIR/gcc.out" 2>"$TMPDIR/gcc.err"

    local gcc_status=$?

    if [[ "$gcc_status" -ne 0 ]]; then
        fail "$name: generated assembly could not be linked"
        echo "  GCC error:"
        sed 's/^/    /' "$TMPDIR/gcc.err"
        return
    fi

    local actual
    actual=$("$binary")
    local runtime_status=$?

    if [[ "$runtime_status" -ne 0 ]]; then
        fail "$name: executable exited with status $runtime_status"
        return
    fi

    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name: expected '$expected', got '$actual'"
    fi
}

# ---------------------------------------------------------------------------
# Scanner / constants
# ---------------------------------------------------------------------------

section "Scanner and Numbers"

runtime_test \
    "Leading decimal zeros" \
    "123" \
    'test() return 000123; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Decimal underscores" \
    "1000" \
    'test() return 1_000; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Hexadecimal number" \
    "255" \
    'test() return 0xFF; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

# ---------------------------------------------------------------------------
# Arithmetic
# ---------------------------------------------------------------------------

section "Expressions"

runtime_test \
    "Addition" \
    "30" \
    'test() return 10 + 20; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Multiplication" \
    "42" \
    'test() return 6 * 7; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Subtraction" \
    "7" \
    'test() return 10 - 3; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Greater comparison true" \
    "1" \
    'test() return 10 > 3; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Equality comparison false" \
    "0" \
    'test() return 10 = 3; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Deep expression" \
    "21" \
    'test() return 1 + (2 + (3 + (4 + (5 + 6)))); end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

section "Variables"

runtime_test \
    "Variable definition" \
    "12" \
    'test() var x := 6; return x * 2; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Variable assignment" \
    "99" \
    'test() var x := 1; x := 99; return x; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

# ---------------------------------------------------------------------------
# Arrays
# ---------------------------------------------------------------------------

section "Arrays"

runtime_test \
    "Array read" \
    "30" \
    'get(a,i) return a[i]; end;' \
    '#include <stdio.h>
long get(long *a, long i);
int main(void) {
    long a[] = {10,20,30,40};
    printf("%ld", get(a,2));
    return 0;
}'

runtime_test \
    "Array write" \
    "99 99" \
    'set(a,i,x) a[i] := x; return a[i]; end;' \
    '#include <stdio.h>
long set(long *a, long i, long x);
int main(void) {
    long a[] = {10,20,30,40};
    long result = set(a,1,99);
    printf("%ld %ld", result, a[1]);
    return 0;
}'

# ---------------------------------------------------------------------------
# Function calls
# ---------------------------------------------------------------------------

section "Function Calls"

runtime_test \
    "Simple function call" \
    "6" \
    'inc(a) return a + 1; end; test() return inc(5); end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Nested function calls" \
    "7" \
    'inc(a) return a + 1; end; test() return inc(inc(5)); end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Calls as multiple arguments" \
    "9" \
    'inc(a) return a + 1; end; add(a,b) return a + b; end; test() return add(inc(2),inc(5)); end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Six arguments" \
    "21" \
    'sum6(a,b,c,d,e,f) return a + b + c + d + e + f; end; test() return sum6(1,2,3,4,5,6); end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Call inside expression" \
    "16" \
    'inc(a) return a + 1; end; test() return 10 + inc(5); end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Call in variable definition" \
    "12" \
    'inc(a) return a + 1; end; test() var x := inc(5); return x * 2; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Call in assignment" \
    "6" \
    'inc(a) return a + 1; end; test() var x := 1; x := inc(5); return x; end;' \
    '#include <stdio.h>
long test(void);
int main(void) {
    printf("%ld", test());
    return 0;
}'

# ---------------------------------------------------------------------------
# Recursion
# ---------------------------------------------------------------------------

section "Recursion"

runtime_test \
    "Factorial recursion" \
    "120" \
    'fact(n) cond n = 0 -> return 1; break; -> return n * fact(n - 1); break; end; end;' \
    '#include <stdio.h>
long fact(long);
int main(void) {
    printf("%ld", fact(5));
    return 0;
}'

# ---------------------------------------------------------------------------
# Calls and arrays
# ---------------------------------------------------------------------------

section "Function Calls with Arrays"

runtime_test \
    "Function call as array index" \
    "30" \
    'idx() return 2; end; get(a) return a[idx()]; end;' \
    '#include <stdio.h>
long get(long *);
int main(void) {
    long a[] = {10,20,30,40};
    printf("%ld", get(a));
    return 0;
}'

runtime_test \
    "Function call returns array address" \
    "20" \
    'get(a) return a; end; test(a) return get(a)[1]; end;' \
    '#include <stdio.h>
long test(long *);
int main(void) {
    long a[] = {10,20,30,40};
    printf("%ld", test(a));
    return 0;
}'

runtime_test \
    "Calls in array assignment" \
    "99" \
    'idx() return 1; end; value() return 99; end; test(a) a[idx()] := value(); return a[1]; end;' \
    '#include <stdio.h>
long test(long *);
int main(void) {
    long a[] = {10,20,30,40};
    printf("%ld", test(a));
    return 0;
}'

# ---------------------------------------------------------------------------
# Control flow
# ---------------------------------------------------------------------------

section "Control Flow"

runtime_test \
    "Continue and break" \
    "3" \
    'f() var x := 0; outer: cond x = 3 -> break outer; -> x := x + 1; continue outer; end; return x; end;' \
    '#include <stdio.h>
long f(void);
int main(void) {
    printf("%ld", f());
    return 0;
}'

runtime_test \
    "Break outer cond" \
    "5" \
    'f() var x := 0; outer: cond -> cond -> x := 5; break outer; end; break; end; return x; end;' \
    '#include <stdio.h>
long f(void);
int main(void) {
    printf("%ld", f());
    return 0;
}'

runtime_test \
    "Continue outer cond" \
    "3" \
    'f() var x := 0; outer: cond x = 3 -> break; -> cond -> x := x + 1; continue outer; end; break; end; return x; end;' \
    '#include <stdio.h>
long f(void);
int main(void) {
    printf("%ld", f());
    return 0;
}'

# ---------------------------------------------------------------------------
# External C call
# ---------------------------------------------------------------------------

section "External Functions"

runtime_test \
    "Call external C function" \
    "21" \
    'test() return external(1,2,3,4,5,6); end;' \
    '#include <stdio.h>

long test(void);

long external(long a, long b, long c, long d, long e, long f) {
    return a + b + c + d + e + f;
}

int main(void) {
    printf("%ld", test());
    return 0;
}'

runtime_test \
    "Function call used as statement" \
    "123 42" \
    'test() external(123); return 42; end;' \
    '#include <stdio.h>

long test(void);

long external(long x) {
    printf("%ld ", x);
    return 999;
}

int main(void) {
    printf("%ld", test());
    return 0;
}'

# ---------------------------------------------------------------------------
# Full integration test
# ---------------------------------------------------------------------------

section "Integration Test"

runtime_test \
    "Full compiler integration" \
    "110" \
    'inc(x)
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

test(a)
    var s := worker(a, 4);

    cond
        s > 50 ->
            return sum(s, 10);
            break;

        ->
            return s;
            break;
    end;
end;' \
    '#include <stdio.h>

long test(long *);

int main(void) {
    long a[] = {10,20,30,40};
    printf("%ld", test(a));
    return 0;
}'

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf "\n"
printf "========================================\n"
printf "Test summary\n"
printf "========================================\n"
printf "Passed: %d\n" "$PASSED"
printf "Failed: %d\n" "$FAILED"
printf "========================================\n"

if [[ "$FAILED" -eq 0 ]]; then
    printf "\033[32mALL TESTS PASSED\033[0m\n"
    exit 0
else
    printf "\033[31mSOME TESTS FAILED\033[0m\n"
    exit 1
fi
