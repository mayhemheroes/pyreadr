#!/usr/bin/env bash
#
# mayhem/build.sh — build pyreadr's fuzz harness (read-fuzz, over the bundled librdata C
# library) AND the project's own Python test suite so mayhem/test.sh only RUNS it.
#
# Runs inside the commit image (mayhem/Dockerfile) as `mayhem` in /mayhem. The base image
# exports the build contract (CC, CXX, LIB_FUZZING_ENGINE, SANITIZER_FLAGS, DEBUG_FLAGS,
# STANDALONE_FUZZ_MAIN, SRC). Cython/pandas/numpy/xarray + libbz2/liblzma/zlib dev headers
# are pre-installed by the Dockerfile so this stays offline-reproducible.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

LIBRDATA_SRC="$SRC/pyreadr/libs/librdata/src"
RDATA_SOURCES=( "$LIBRDATA_SRC"/*.c )
# librdata's read path uses zlib/bzip2/xz decompression (pyreadr enables all three on Linux).
RDATA_DEFS=(-DHAVE_ZLIB -DHAVE_BZIP2 -DHAVE_LZMA)
RDATA_LIBS=(-lz -lbz2 -llzma -lm)

# ---------------------------------------------------------------------------
# 1) Fuzz harness: read-fuzz — in-process libFuzzer over librdata's rdata_parse()
#    (the same code path pyreadr.read_r() drives). The librdata C sources are
#    compiled WITH $SANITIZER_FLAGS + $DEBUG_FLAGS so the fuzzed library — not just
#    the harness — is instrumented under ASan+UBSan and carries DWARF<4 symbols.
# ---------------------------------------------------------------------------
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    -I"$LIBRDATA_SRC" "${RDATA_DEFS[@]}" \
    "$SRC/mayhem/read-fuzz.c" "${RDATA_SOURCES[@]}" "${RDATA_LIBS[@]}" \
    -o /mayhem/read-fuzz

# Standalone (non-fuzzer) run-once reproducer for the same harness.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS "$STANDALONE_FUZZ_MAIN" \
    -I"$LIBRDATA_SRC" "${RDATA_DEFS[@]}" \
    "$SRC/mayhem/read-fuzz.c" "${RDATA_SOURCES[@]}" "${RDATA_LIBS[@]}" \
    -o /mayhem/read-fuzz-standalone

# ---------------------------------------------------------------------------
# 2) Build the project's own Python extension IN PLACE with its NORMAL flags
#    (a clean, unsanitized build) so mayhem/test.sh can run pyreadr's real
#    functional suite. Cython + build deps are pre-installed in the image, so
#    this resolves entirely offline.
# ---------------------------------------------------------------------------
python3 setup.py build_ext --inplace

# ---------------------------------------------------------------------------
# 3) Build read-kat — a native known-answer test over librdata (NORMAL flags), run by
#    mayhem/test.sh. It is a project-owned (non-system) executable, so verify-repo's
#    sabotage neuter (_exit(0) on project binaries) and any real librdata no-op patch
#    both make it emit the wrong / no output — proving the oracle is behavioral even
#    though pyreadr's own suite runs inside the (system) python3 interpreter.
# ---------------------------------------------------------------------------
$CC -O2 $COVERAGE_FLAGS -I"$LIBRDATA_SRC" "${RDATA_DEFS[@]}" \
    "$SRC/mayhem/read-kat.c" "${RDATA_SOURCES[@]}" "${RDATA_LIBS[@]}" \
    -o /mayhem/read-kat

echo "build.sh: OK"
