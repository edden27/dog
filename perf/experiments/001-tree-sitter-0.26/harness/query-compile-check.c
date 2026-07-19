// Compiles a highlights query against a grammar and reports success or the
// exact error offset/type. Built against whichever tree-sitter runtime the
// build command links — used to diff 0.25 vs 0.26 query validation behavior.
//
// Build (0.26.11 source cloned to $TS_SRC, python grammar from LocalPackages):
//   cc -O2 -o query-compile-check query-compile-check.c \
//      $TS_SRC/lib/src/lib.c -I$TS_SRC/lib/include -I$TS_SRC/lib/src \
//      <grammar>/src/parser.c <grammar>/src/scanner.c -I<grammar>/src
//
// Run:
//   ./query-compile-check <query.scm>
//
// Exit 0 = compiled clean. Exit 1 = error, prints type, byte offset, and the
// query text around the offset.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tree_sitter/api.h>

const TSLanguage *tree_sitter_python(void);

static const char *error_type_name(TSQueryError error_type) {
    switch (error_type) {
        case TSQueryErrorNone: return "None";
        case TSQueryErrorSyntax: return "Syntax";
        case TSQueryErrorNodeType: return "NodeType";
        case TSQueryErrorField: return "Field";
        case TSQueryErrorCapture: return "Capture";
        case TSQueryErrorStructure: return "Structure";
        case TSQueryErrorLanguage: return "Language";
        default: return "Unknown";
    }
}

int main(int argument_count, char **arguments) {
    if (argument_count < 2) {
        fprintf(stderr, "usage: %s <query.scm>\n", arguments[0]);
        return 2;
    }
    FILE *query_file = fopen(arguments[1], "rb");
    if (!query_file) { perror("open"); return 2; }
    fseek(query_file, 0, SEEK_END);
    long query_length = ftell(query_file);
    fseek(query_file, 0, SEEK_SET);
    char *query_source = malloc((size_t)query_length + 1);
    fread(query_source, 1, (size_t)query_length, query_file);
    query_source[query_length] = '\0';
    fclose(query_file);

    uint32_t error_offset = 0;
    TSQueryError error_type = TSQueryErrorNone;
    TSQuery *query = ts_query_new(
        tree_sitter_python(), query_source, (uint32_t)query_length,
        &error_offset, &error_type);

    if (query) {
        printf("OK: compiled, %u patterns\n", ts_query_pattern_count(query));
        ts_query_delete(query);
        free(query_source);
        return 0;
    }

    printf("ERROR type=%s offset=%u\n", error_type_name(error_type), error_offset);
    long context_start = (long)error_offset - 80;
    if (context_start < 0) context_start = 0;
    long context_end = (long)error_offset + 80;
    if (context_end > query_length) context_end = query_length;
    printf("--- query context [%ld..%ld] ---\n%.*s\n", context_start, context_end,
           (int)(context_end - context_start), query_source + context_start);

    unsigned line_number = 1;
    for (long index = 0; index < (long)error_offset; index++) {
        if (query_source[index] == '\n') line_number++;
    }
    printf("--- line %u ---\n", line_number);
    free(query_source);
    return 1;
}
