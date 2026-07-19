// Experiment 004: can query compilation (ts_query_new) overlap with parsing
// (ts_parser_parse) on a second thread?
//
// Measures, over ITERATIONS runs each:
//   sequential: compile query, then parse, then exec query   (dog today)
//   overlapped: compile on pthread || parse on main, join, then exec
//
// Reports per-phase medians and the wall-clock delta. Both ts_query_new and
// ts_parser_parse only read the static TSLanguage — no shared mutable state.
//
// Build (per grammar; LANG_FN set via -D, scanner optional via extra arg):
//   cc -O2 -DLANG_FN=tree_sitter_typescript -o overlap-ts overlap-bench.c \
//      $TS_SRC/lib/src/lib.c -I$TS_SRC/lib/include -I$TS_SRC/lib/src \
//      <grammar-src>/parser.c <grammar-src>/scanner.c -I<grammar-src> -lpthread
//
// Run:
//   ./overlap-ts <query.scm> <source-file> [iterations]

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <tree_sitter/api.h>

#ifndef LANG_FN
#error "define LANG_FN, e.g. -DLANG_FN=tree_sitter_typescript"
#endif

const TSLanguage *LANG_FN(void);

static double now_ms(void) {
    struct timespec timestamp;
    clock_gettime(CLOCK_MONOTONIC, &timestamp);
    return (double)timestamp.tv_sec * 1000.0 + (double)timestamp.tv_nsec / 1e6;
}

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

struct compile_job {
    const char *query_source;
    uint32_t query_length;
    TSQuery *query;
};

static void *compile_thread_main(void *argument) {
    struct compile_job *job = argument;
    uint32_t error_offset = 0;
    TSQueryError error_type = TSQueryErrorNone;
    job->query = ts_query_new(LANG_FN(), job->query_source, job->query_length,
                              &error_offset, &error_type);
    return NULL;
}

static int compare_double(const void *left, const void *right) {
    double difference = *(const double *)left - *(const double *)right;
    return (difference > 0) - (difference < 0);
}

static double median(double *values, int count) {
    qsort(values, count, sizeof(double), compare_double);
    return values[count / 2];
}

static uint32_t run_exec(TSQuery *query, TSTree *tree) {
    TSQueryCursor *cursor = ts_query_cursor_new();
    ts_query_cursor_exec(cursor, query, ts_tree_root_node(tree));
    TSQueryMatch match;
    uint32_t capture_count = 0;
    while (ts_query_cursor_next_match(cursor, &match)) {
        capture_count += match.capture_count;
    }
    ts_query_cursor_delete(cursor);
    return capture_count;
}

int main(int argument_count, char **arguments) {
    if (argument_count < 3) {
        fprintf(stderr, "usage: %s <query.scm> <source-file> [iterations]\n", arguments[0]);
        return 2;
    }
    uint32_t query_length = 0, source_length = 0;
    char *query_source = read_file(arguments[1], &query_length);
    char *source = read_file(arguments[2], &source_length);
    int iterations = argument_count > 3 ? atoi(arguments[3]) : 15;

    double sequential_totals[iterations], overlapped_totals[iterations];
    double compile_times[iterations], parse_times[iterations];
    uint32_t sequential_captures = 0, overlapped_captures = 0;

    for (int iteration = 0; iteration < iterations; iteration++) {
        // --- sequential ---
        double start = now_ms();
        uint32_t error_offset = 0;
        TSQueryError error_type = TSQueryErrorNone;
        TSQuery *query = ts_query_new(LANG_FN(), query_source, query_length,
                                      &error_offset, &error_type);
        double after_compile = now_ms();
        if (!query) { fprintf(stderr, "query error at %u\n", error_offset); return 1; }
        TSParser *parser = ts_parser_new();
        ts_parser_set_language(parser, LANG_FN());
        TSTree *tree = ts_parser_parse_string(parser, NULL, source, source_length);
        double after_parse = now_ms();
        sequential_captures = run_exec(query, tree);
        double after_exec = now_ms();
        sequential_totals[iteration] = after_exec - start;
        compile_times[iteration] = after_compile - start;
        parse_times[iteration] = after_parse - after_compile;
        ts_tree_delete(tree);
        ts_parser_delete(parser);
        ts_query_delete(query);

        // --- overlapped ---
        start = now_ms();
        struct compile_job job = { query_source, query_length, NULL };
        pthread_t compile_thread;
        pthread_create(&compile_thread, NULL, compile_thread_main, &job);
        TSParser *parser2 = ts_parser_new();
        ts_parser_set_language(parser2, LANG_FN());
        TSTree *tree2 = ts_parser_parse_string(parser2, NULL, source, source_length);
        pthread_join(compile_thread, NULL);
        if (!job.query) { fprintf(stderr, "overlapped query error\n"); return 1; }
        overlapped_captures = run_exec(job.query, tree2);
        overlapped_totals[iteration] = now_ms() - start;
        ts_tree_delete(tree2);
        ts_parser_delete(parser2);
        ts_query_delete(job.query);
    }

    if (sequential_captures != overlapped_captures) {
        fprintf(stderr, "CAPTURE MISMATCH: seq=%u overlap=%u\n",
                sequential_captures, overlapped_captures);
        return 1;
    }

    double sequential_median = median(sequential_totals, iterations);
    double overlapped_median = median(overlapped_totals, iterations);
    printf("compile median: %7.1fms\n", median(compile_times, iterations));
    printf("parse   median: %7.1fms\n", median(parse_times, iterations));
    printf("sequential (compile+parse+exec): %7.1fms\n", sequential_median);
    printf("overlapped (max(c,p)+exec):      %7.1fms\n", overlapped_median);
    printf("saved: %.1fms (%.1f%%)  captures=%u\n",
           sequential_median - overlapped_median,
           (sequential_median - overlapped_median) / sequential_median * 100.0,
           sequential_captures);
    return 0;
}
