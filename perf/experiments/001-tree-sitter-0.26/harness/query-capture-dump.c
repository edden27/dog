// Parses a python source file, runs a query, and dumps every capture as
// "pattern_index capture_name node_type [start_byte..end_byte]" — one per
// line, for diffing capture behavior across runtimes/query variants.
//
// Build: same as query-compile-check.c but with this file.
// Run:   ./query-capture-dump <query.scm> <source.py>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tree_sitter/api.h>

const TSLanguage *tree_sitter_python(void);

static char *read_file(const char *path, uint32_t *length_out) {
    FILE *handle = fopen(path, "rb");
    if (!handle) { perror(path); exit(2); }
    fseek(handle, 0, SEEK_END);
    long length = ftell(handle);
    fseek(handle, 0, SEEK_SET);
    char *buffer = malloc((size_t)length + 1);
    fread(buffer, 1, (size_t)length, handle);
    buffer[length] = '\0';
    fclose(handle);
    *length_out = (uint32_t)length;
    return buffer;
}

int main(int argument_count, char **arguments) {
    if (argument_count < 3) {
        fprintf(stderr, "usage: %s <query.scm> <source.py>\n", arguments[0]);
        return 2;
    }
    uint32_t query_length = 0, source_length = 0;
    char *query_source = read_file(arguments[1], &query_length);
    char *source = read_file(arguments[2], &source_length);

    uint32_t error_offset = 0;
    TSQueryError error_type = TSQueryErrorNone;
    TSQuery *query = ts_query_new(tree_sitter_python(), query_source,
                                  query_length, &error_offset, &error_type);
    if (!query) {
        printf("QUERY-ERROR offset=%u\n", error_offset);
        return 1;
    }

    TSParser *parser = ts_parser_new();
    ts_parser_set_language(parser, tree_sitter_python());
    TSTree *tree = ts_parser_parse_string(parser, NULL, source, source_length);

    TSQueryCursor *cursor = ts_query_cursor_new();
    ts_query_cursor_exec(cursor, query, ts_tree_root_node(tree));

    TSQueryMatch match;
    while (ts_query_cursor_next_match(cursor, &match)) {
        for (uint16_t capture_index = 0; capture_index < match.capture_count; capture_index++) {
            TSQueryCapture capture = match.captures[capture_index];
            uint32_t name_length = 0;
            const char *capture_name = ts_query_capture_name_for_id(
                query, capture.index, &name_length);
            printf("p%u %.*s %s [%u..%u]\n", match.pattern_index, (int)name_length,
                   capture_name, ts_node_type(capture.node),
                   ts_node_start_byte(capture.node), ts_node_end_byte(capture.node));
        }
    }
    return 0;
}
