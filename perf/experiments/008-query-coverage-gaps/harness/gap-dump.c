// gap-dump.c — attribute a language's UNCAPTURED non-whitespace bytes to the
// deepest named node type that covers them, using dog's ACTUAL .scm query.
//
// Replicates dog's ParsingTests.tokenCoverage metric exactly:
//   * covered = union of [start_byte, end_byte) of every query capture node
//   * non-whitespace = bytes not in {0x20 space, 0x09 tab, 0x0A LF, 0x0D CR}
//   * coverage% = coveredNonWS / nonWS * 100
// Every non-ws byte that is NOT covered is a "gap" byte. Each contiguous run of
// gap bytes is attributed to the deepest NAMED node returned by
// ts_node_named_descendant_for_byte_range() at that run — i.e. what node type
// the uncaptured text actually is. Per node-type we accumulate total gap bytes,
// occurrence (run) count, and keep up to a few sample source snippets.
//
// This measures the SAME single-grammar/single-query pipeline dog uses (no
// injection): markdown here is BLOCK-only, exactly like dog.
//
// Build (LANG_FN via -D; add scanner.c per grammar; add second parser.c only
// where a grammar has no scanner — all three here have scanner.c):
//
//   TS=/Users/eddenamber/Projects/dog/.build/checkouts/tree-sitter
//   CSS=/Users/eddenamber/Projects/dog/LocalPackages/tree-sitter-css/src
//   cc -O2 -DLANG_FN=tree_sitter_css -o /tmp/gap-css gap-dump.c \
//      $TS/lib/src/lib.c -I$TS/lib/include -I$TS/lib/src \
//      $CSS/parser.c $CSS/scanner.c -I$CSS
//
//   HTML=/Users/eddenamber/Projects/dog/LocalPackages/tree-sitter-html/src
//   cc -O2 -DLANG_FN=tree_sitter_html -o /tmp/gap-html gap-dump.c \
//      $TS/lib/src/lib.c -I$TS/lib/include -I$TS/lib/src \
//      $HTML/parser.c $HTML/scanner.c -I$HTML
//
//   MDB=/Users/eddenamber/Projects/dog/.build/checkouts/tree-sitter-markdown/tree-sitter-markdown/src
//   cc -O2 -DLANG_FN=tree_sitter_markdown -o /tmp/gap-md gap-dump.c \
//      $TS/lib/src/lib.c -I$TS/lib/include -I$TS/lib/src \
//      $MDB/parser.c $MDB/scanner.c -I$MDB
//
// Run:  ./gap-dump <query.scm> <source-file> [source-file ...]
//   Aggregates across all given source files (like the test combines fixtures).

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tree_sitter/api.h>

#ifndef LANG_FN
#error "define LANG_FN, e.g. -DLANG_FN=tree_sitter_css"
#endif
const TSLanguage *LANG_FN(void);

#define MAX_TYPES 512
#define MAX_SAMPLES 3

struct type_stat {
    char name[64];
    unsigned long gap_bytes;   // total uncaptured non-ws bytes attributed here
    unsigned long runs;        // number of contiguous gap runs
    char samples[MAX_SAMPLES][80];
    int sample_count;
};

static struct type_stat stats[MAX_TYPES];
static int type_count = 0;

static unsigned long total_nonws = 0;
static unsigned long total_covered_nonws = 0;

static int is_ws(unsigned char c) {
    return c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;
}

static struct type_stat *find_type(const char *name) {
    for (int i = 0; i < type_count; i++)
        if (strcmp(stats[i].name, name) == 0) return &stats[i];
    if (type_count >= MAX_TYPES) return &stats[type_count - 1];
    struct type_stat *s = &stats[type_count++];
    memset(s, 0, sizeof(*s));
    strncpy(s->name, name, sizeof(s->name) - 1);
    return s;
}

static char *read_file(const char *path, uint32_t *length_out) {
    FILE *h = fopen(path, "rb");
    if (!h) { perror(path); exit(2); }
    fseek(h, 0, SEEK_END);
    long n = ftell(h);
    fseek(h, 0, SEEK_SET);
    char *buf = malloc((size_t)n + 1);
    if (fread(buf, 1, (size_t)n, h) != (size_t)n) { perror("fread"); exit(2); }
    buf[n] = '\0';
    fclose(h);
    *length_out = (uint32_t)n;
    return buf;
}

static void add_sample(struct type_stat *s, const char *src, uint32_t a, uint32_t b) {
    if (s->sample_count >= MAX_SAMPLES) return;
    // skip if run is pure whitespace snippet
    uint32_t len = b - a;
    if (len > 60) len = 60;
    char *dst = s->samples[s->sample_count];
    int j = 0;
    for (uint32_t i = 0; i < len && j < 76; i++) {
        char c = src[a + i];
        if (c == '\n') { dst[j++] = '\\'; dst[j++] = 'n'; }
        else if (c == '\t') { dst[j++] = '\\'; dst[j++] = 't'; }
        else dst[j++] = c;
    }
    dst[j] = '\0';
    s->sample_count++;
}

static void process_file(TSQuery *query, const char *path) {
    uint32_t src_len = 0;
    char *src = read_file(path, &src_len);

    TSParser *parser = ts_parser_new();
    ts_parser_set_language(parser, LANG_FN());
    TSTree *tree = ts_parser_parse_string(parser, NULL, src, src_len);
    TSNode root = ts_tree_root_node(tree);

    // 1. covered[] bitmap of bytes inside any capture node range
    unsigned char *covered = calloc(src_len, 1);
    TSQueryCursor *cursor = ts_query_cursor_new();
    ts_query_cursor_exec(cursor, query, root);
    TSQueryMatch match;
    while (ts_query_cursor_next_match(cursor, &match)) {
        for (uint16_t i = 0; i < match.capture_count; i++) {
            TSNode node = match.captures[i].node;
            uint32_t a = ts_node_start_byte(node);
            uint32_t b = ts_node_end_byte(node);
            if (b > src_len) b = src_len;
            for (uint32_t p = a; p < b; p++) covered[p] = 1;
        }
    }
    ts_query_cursor_delete(cursor);

    // 2. tally non-ws + covered non-ws (test metric)
    for (uint32_t p = 0; p < src_len; p++) {
        if (!is_ws((unsigned char)src[p])) {
            total_nonws++;
            if (covered[p]) total_covered_nonws++;
        }
    }

    // 3. contiguous runs of uncaptured non-ws bytes -> attribute to deepest
    //    named node covering the run. Whitespace bytes break runs (they are
    //    excluded from the metric anyway).
    uint32_t p = 0;
    while (p < src_len) {
        if (covered[p] || is_ws((unsigned char)src[p])) { p++; continue; }
        uint32_t a = p;
        while (p < src_len && !covered[p] && !is_ws((unsigned char)src[p])) p++;
        uint32_t b = p; // [a,b) uncaptured non-ws run
        TSNode n = ts_node_named_descendant_for_byte_range(root, a, b > a ? b - 1 : a);
        const char *tn = ts_node_is_null(n) ? "(none)" : ts_node_type(n);
        struct type_stat *s = find_type(tn);
        s->gap_bytes += (b - a);
        s->runs++;
        add_sample(s, src, a, b);
    }

    free(covered);
    free(src);
    ts_tree_delete(tree);
    ts_parser_delete(parser);
}

static int cmp_stat(const void *x, const void *y) {
    const struct type_stat *a = x, *b = y;
    if (a->gap_bytes < b->gap_bytes) return 1;
    if (a->gap_bytes > b->gap_bytes) return -1;
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s <query.scm> <source-file> [more...]\n", argv[0]);
        return 2;
    }
    uint32_t qlen = 0;
    char *qsrc = read_file(argv[1], &qlen);
    uint32_t eo = 0;
    TSQueryError et = TSQueryErrorNone;
    TSQuery *query = ts_query_new(LANG_FN(), qsrc, qlen, &eo, &et);
    if (!query) {
        printf("QUERY-ERROR type=%d offset=%u\n", et, eo);
        return 1;
    }

    for (int i = 2; i < argc; i++) process_file(query, argv[i]);

    qsort(stats, type_count, sizeof(struct type_stat), cmp_stat);

    double cov = total_nonws ? (double)total_covered_nonws / total_nonws * 100.0 : 100.0;
    unsigned long total_gap = total_nonws - total_covered_nonws;
    printf("=== coverage: %.1f%%  (nonWS=%lu covered=%lu gap=%lu) ===\n",
           cov, total_nonws, total_covered_nonws, total_gap);
    printf("%-34s %10s %8s %7s\n", "node_type", "gap_bytes", "runs", "%ofgap");
    for (int i = 0; i < type_count; i++) {
        struct type_stat *s = &stats[i];
        double pct = total_gap ? (double)s->gap_bytes / total_gap * 100.0 : 0.0;
        printf("%-34s %10lu %8lu %6.1f%%\n", s->name, s->gap_bytes, s->runs, pct);
        for (int j = 0; j < s->sample_count; j++)
            printf("      | %s\n", s->samples[j]);
    }
    return 0;
}
