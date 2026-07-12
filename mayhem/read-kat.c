/*
 * read-kat — a small known-answer test binary for the librdata C library that pyreadr
 * wraps. It parses an R data file with librdata and prints the number of columns and the
 * per-column row count it observed. mayhem/test.sh asserts these against known values, so a
 * no-op / neutered librdata (or the sabotage LD_PRELOAD that _exit(0)s project binaries)
 * produces the wrong output / no output and FAILS the oracle.
 *
 * Usage: read-kat <file.rds|file.RData>
 * Output (on success): "KAT ncols=<n> nrows=<n>"
 */
#include <stdio.h>
#include <stdlib.h>

#include "rdata.h"

static int g_ncols = 0;
static long g_nrows = -1;

static int on_column(const char *name, rdata_type_t type, void *data,
                     long count, void *ctx) {
    (void)name; (void)type; (void)data; (void)ctx;
    g_ncols++;
    if (count > g_nrows)
        g_nrows = count;
    return RDATA_OK;
}
static int on_table(const char *name, void *ctx) { (void)name; (void)ctx; return RDATA_OK; }

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <file>\n", argv[0]);
        return 2;
    }
    rdata_parser_t *parser = rdata_parser_init();
    if (!parser) {
        fprintf(stderr, "KAT init failed\n");
        return 3;
    }
    rdata_set_table_handler(parser, on_table);
    rdata_set_column_handler(parser, on_column);
    rdata_error_t err = rdata_parse(parser, argv[1], NULL);
    rdata_parser_free(parser);
    if (err != RDATA_OK) {
        fprintf(stderr, "KAT parse error: %s\n", rdata_error_message(err));
        return 4;
    }
    printf("KAT ncols=%d nrows=%ld\n", g_ncols, g_nrows);
    return 0;
}
