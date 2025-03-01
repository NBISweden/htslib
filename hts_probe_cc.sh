#!/bin/sh

# Check compiler options for non-configure builds and create Makefile fragment
#
#    Copyright (C) 2022 Genome Research Ltd.
#
#    Author: Rob Davies <rmd@sanger.ac.uk>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# Arguments are:
# 1. C compiler command
# 2. Initial CFLAGS
# 3. LDFLAGS

CC=$1
CFLAGS=$2
LDFLAGS=$3

# Try running the compiler.  Uses the same contest.* names as
# configure for temporary files.
run_compiler ()
{
    "$CC" $CFLAGS $1 $LDFLAGS -o conftest conftest.c 2> conftest.err
    retval=$?
    rm -f conftest.err conftest
    return $retval
}

# Run a test.  $1 is the flag to try, $2 is the Makefile variable to set
# with the flag probe result, $3 is a Makefile variable which will be
# set to 1 if the code was built successfully.  The code to test should
# be passed in via fd 0.
# First try compiling conftest.c without the flag.  If that fails, try
# again with it to see if the flag is needed.
run_test ()
{
    rm -f conftest conftest.err conftest.c
    cat - > conftest.c
    if run_compiler ; then
        echo "$2 ="
        echo "$3 = 1"
    elif run_compiler "$1" ; then
        echo "$2 = $1"
        echo "$3 = 1"
    else
        echo "$3 ="
    fi
}

echo "# Compiler probe results, generated by $0"

# Check for ssse3
run_test "-mssse3" HTS_CFLAGS_SSSE3 HTS_BUILD_SSSE3 <<'EOF'
#ifdef __x86_64__
#include "x86intrin.h"
int main(int argc, char **argv) {
    __m128i a = _mm_set_epi32(1, 2, 3, 4), b = _mm_set_epi32(4, 3, 2, 1);
    __m128i c = _mm_shuffle_epi8(a, b);
    return *((char *) &c);
}
#else
int main(int argc, char **argv) { return 0; }
#endif
EOF

# Check for popcnt
run_test "-mpopcnt" HTS_CFLAGS_POPCNT HTS_BUILD_POPCNT <<'EOF'
#ifdef __x86_64__
#include "x86intrin.h"
int main(int argc, char **argv) {
    unsigned int i = _mm_popcnt_u32(1);
    return i != 1;
}
#else
int main(int argc, char **argv) { return 0; }
#endif
EOF

# Check for sse4.1 etc. support
run_test "-msse4.1" HTS_CFLAGS_SSE4_1 HTS_BUILD_SSE4_1 <<'EOF'
#ifdef __x86_64__
#include "x86intrin.h"
int main(int argc, char **argv) {
    __m128i a = _mm_set_epi32(1, 2, 3, 4), b = _mm_set_epi32(4, 3, 2, 1);
    __m128i c = _mm_max_epu32(a, b);
    return *((char *) &c);
}
#else
int main(int argc, char **argv) { return 0; }
#endif
EOF

echo 'HTS_CFLAGS_SSE4 = $(HTS_CFLAGS_SSSE3) $(HTS_CFLAGS_POPCNT) $(HTS_CFLAGS_SSE4_1)'

# Check for avx2

run_test -mavx2 HTS_CFLAGS_AVX2 HTS_BUILD_AVX2 <<'EOF'
#ifdef __x86_64__
#include "x86intrin.h"
int main(int argc, char **argv) {
    __m256i a = _mm256_set_epi32(1, 2, 3, 4, 5, 6, 7, 8);
    __m256i b = _mm256_add_epi32(a, a);
    long long c = _mm256_extract_epi64(b, 0);
    return (int) c;
}
#else
int main(int argc, char **argv) { return 0; }
#endif
EOF

# Check for avx512

run_test -mavx512f HTS_CFLAGS_AVX512 HTS_BUILD_AVX512 <<'EOF'
#ifdef __x86_64__
#include "x86intrin.h"
int main(int argc, char **argv) {
    __m512i a = _mm512_set1_epi32(1);
    __m512i b = _mm512_add_epi32(a, a);
    return *((char *) &b);
}
#else
int main(int argc, char **argv) { return 0; }
#endif
EOF

rm -f conftest.c
