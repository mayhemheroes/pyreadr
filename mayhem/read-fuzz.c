/*
 * read-fuzz — in-process libFuzzer harness for librdata (the C library bundled in
 * pyreadr/libs/librdata) driving the same code path pyreadr.read_r() exercises:
 * rdata_parse() on an RData / Rds byte stream.
 *
 * The upstream fork's original `read-fuzz` target drove the same rdata_parse() path
 * through the Python/atheris wrapper; this is the native in-process equivalent so the
 * fuzzed C code (librdata's parser + its bzip2/gzip/xz decompression front-ends) is
 * directly instrumented under ASan+UBSan.
 */
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "rdata.h"

/* Disable LeakSanitizer only (keep ASan + UBSan). LSan is useless for fuzzing (short
 * iterations leak by design) and, more importantly, it aborts under Mayhem's ptrace-based
 * coverage collection before any edges are recorded (0-edge "Run Failed"). Baking it in as a
 * weak default holds regardless of the runtime env, which Mayhem otherwise owns. librdata also
 * leaks on essentially every parse (as the original pyreadr harness noted), so this is required
 * to fuzz the memory-corruption / UB surface at all. */
__attribute__((weak)) const char *__asan_default_options(void) { return "detect_leaks=0"; }

static int handle_table(const char *name, void *ctx) {
    (void)name; (void)ctx; return RDATA_OK;
}
static int handle_column(const char *name, rdata_type_t type, void *data,
                         long count, void *ctx) {
    (void)name; (void)type; (void)data; (void)count; (void)ctx; return RDATA_OK;
}
static int handle_text(const char *value, int index, void *ctx) {
    (void)value; (void)index; (void)ctx; return RDATA_OK;
}
static int handle_name(const char *value, int index, void *ctx) {
    (void)value; (void)index; (void)ctx; return RDATA_OK;
}
static void handle_error(const char *error_message, void *ctx) {
    (void)error_message; (void)ctx;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    /* Scratch MUST go under /dev/shm — the whole image (incl. /tmp) is read-only during
     * Mayhem coverage collection; /dev/shm is the only writable tmpfs. */
    char path[] = "/dev/shm/rdata_fuzz_XXXXXX";
    int fd = mkstemp(path);
    if (fd < 0)
        return 0;
    if (size > 0) {
        ssize_t off = 0;
        while (off < (ssize_t)size) {
            ssize_t n = write(fd, data + off, size - (size_t)off);
            if (n <= 0) { close(fd); unlink(path); return 0; }
            off += n;
        }
    }
    close(fd);

    rdata_parser_t *parser = rdata_parser_init();
    if (parser) {
        rdata_set_table_handler(parser, handle_table);
        rdata_set_column_handler(parser, handle_column);
        rdata_set_column_name_handler(parser, handle_name);
        rdata_set_row_name_handler(parser, handle_name);
        rdata_set_text_value_handler(parser, handle_text);
        rdata_set_value_label_handler(parser, handle_text);
        rdata_set_dim_handler(parser, handle_column);
        rdata_set_dim_name_handler(parser, handle_text);
        rdata_set_error_handler(parser, handle_error);
        rdata_parse(parser, path, NULL);
        rdata_parser_free(parser);
    }

    unlink(path);
    return 0;
}
