// Precompiled-query blob generator (perf Item 4 / experiment 003b).
//
// Compiles one highlight query with ts_query_new (paying the expensive
// pattern analysis once, at build time) and writes the serialized blob via
// ts_query_serialize (dog's local tree-sitter patch, LocalPackages/tree-sitter).
//
// Built and invoked per grammar by scripts/generate/query-blobs.sh — see that
// script for the full pipeline. LANG_FN is injected with -D.
//
//   ./gen-query-blob-<lang> <query.scm> <output.blob>

#include <stdio.h>
#include <stdlib.h>
#include <tree_sitter/api.h>

#ifndef LANG_FN
#error "define LANG_FN, e.g. -DLANG_FN=tree_sitter_cpp"
#endif

const TSLanguage *LANG_FN(void);

int main(int argument_count, char **arguments) {
  if (argument_count != 3) {
    fprintf(stderr, "usage: %s <query.scm> <output.blob>\n", arguments[0]);
    return 2;
  }
  FILE *query_file = fopen(arguments[1], "rb");
  if (!query_file) { perror(arguments[1]); return 2; }
  fseek(query_file, 0, SEEK_END);
  long query_length = ftell(query_file);
  fseek(query_file, 0, SEEK_SET);
  char *query_source = malloc((size_t)query_length);
  fread(query_source, 1, (size_t)query_length, query_file);
  fclose(query_file);

  uint32_t error_offset = 0;
  TSQueryError error_type = TSQueryErrorNone;
  TSQuery *query = ts_query_new(LANG_FN(), query_source,
                                (uint32_t)query_length, &error_offset, &error_type);
  if (!query) {
    fprintf(stderr, "query compile error at offset %u (type %d)\n",
            error_offset, (int)error_type);
    return 1;
  }

  uint32_t blob_length = 0;
  uint8_t *blob = ts_query_serialize(query, query_source,
                                     (uint32_t)query_length, &blob_length);

  // round-trip self-check before writing anything
  TSQuery *reloaded = ts_query_deserialize(LANG_FN(), blob, blob_length,
                                           query_source, (uint32_t)query_length);
  if (!reloaded) {
    fprintf(stderr, "self-check failed: blob did not deserialize\n");
    return 1;
  }
  if (ts_query_pattern_count(reloaded) != ts_query_pattern_count(query)
      || ts_query_capture_count(reloaded) != ts_query_capture_count(query)) {
    fprintf(stderr, "self-check failed: pattern/capture counts differ\n");
    return 1;
  }
  ts_query_delete(reloaded);
  ts_query_delete(query);

  FILE *output_file = fopen(arguments[2], "wb");
  if (!output_file) { perror(arguments[2]); return 2; }
  fwrite(blob, 1, blob_length, output_file);
  fclose(output_file);
  printf("%s: %u bytes\n", arguments[2], blob_length);
  free(blob);
  free(query_source);
  return 0;
}
