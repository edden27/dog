// Experiment 003a: can a compiled TSQuery be serialized and reloaded, skipping
// ts_query_new's expensive pattern analysis (10-122ms per language)?
//
// Gains access to tree-sitter internals by compiling the runtime amalgamation
// (lib.c) into this translation unit. TSQuery (query.c:295, runtime 0.25.10)
// holds ONE pointer (language, re-injected at load) + POD arrays:
//   2x SymbolTable (2 flat arrays each), Array(CaptureQuantifiers) (nested),
//   steps/pattern_map/predicate_steps/patterns/step_offsets/negated_fields/
//   string_buffer/repeat_symbols (flat), wildcard_root_pattern_count (scalar).
//
// Flow: compile fresh -> serialize to buffer -> deserialize -> run BOTH
// queries over a fixture -> compare capture streams exactly -> report timings.
//
// Build (per grammar):
//   cc -O2 -DLANG_FN=tree_sitter_cpp -o serialize-bench-cpp serialize-bench.c \
//      -I$TS_SRC/lib/include -I$TS_SRC/lib/src \
//      <grammar>/src/parser.c <grammar>/src/scanner.c -I<grammar>/src
//   ($TS_SRC = .build/checkouts/tree-sitter; do NOT also link lib.c — it is
//    #included below.)
//
// Run:
//   ./serialize-bench-cpp <query.scm> <source-fixture> [iterations]
//
// Caveat by design: the byte format is arch/compiler-specific (bitfields,
// struct layout). That is acceptable for the intended use — queries
// precompiled AT BUILD TIME and embedded in the same binary that loads them.

#include "lib.c"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifndef LANG_FN
#error "define LANG_FN, e.g. -DLANG_FN=tree_sitter_cpp"
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

// ---- serialization buffer ----

typedef struct {
  uint8_t *bytes;
  size_t length;
  size_t capacity;
  size_t read_offset;
} Buffer;

static void buffer_write(Buffer *buffer, const void *data, size_t count) {
  if (buffer->length + count > buffer->capacity) {
    buffer->capacity = (buffer->length + count) * 2;
    buffer->bytes = realloc(buffer->bytes, buffer->capacity);
  }
  memcpy(buffer->bytes + buffer->length, data, count);
  buffer->length += count;
}

static void buffer_read(Buffer *buffer, void *data, size_t count) {
  memcpy(data, buffer->bytes + buffer->read_offset, count);
  buffer->read_offset += count;
}

#define WRITE_ARRAY(buffer, array)                                        \
  do {                                                                    \
    uint32_t element_count = (array).size;                                \
    buffer_write(buffer, &element_count, sizeof element_count);           \
    if (element_count > 0)                                                \
      buffer_write(buffer, (array).contents,                              \
                   element_count * sizeof(*(array).contents));            \
  } while (0)

#define READ_ARRAY(buffer, array)                                         \
  do {                                                                    \
    uint32_t element_count = 0;                                           \
    buffer_read(buffer, &element_count, sizeof element_count);            \
    (array).size = element_count;                                         \
    (array).capacity = element_count;                                     \
    if (element_count > 0) {                                              \
      (array).contents =                                                  \
          ts_malloc(element_count * sizeof(*(array).contents));           \
      buffer_read(buffer, (array).contents,                               \
                  element_count * sizeof(*(array).contents));             \
    } else {                                                              \
      (array).contents = NULL;                                            \
    }                                                                     \
  } while (0)

static void serialize_query(const TSQuery *query, Buffer *buffer) {
  WRITE_ARRAY(buffer, query->captures.characters);
  WRITE_ARRAY(buffer, query->captures.slices);
  WRITE_ARRAY(buffer, query->predicate_values.characters);
  WRITE_ARRAY(buffer, query->predicate_values.slices);
  // nested: array of arrays
  uint32_t quantifier_count = query->capture_quantifiers.size;
  buffer_write(buffer, &quantifier_count, sizeof quantifier_count);
  for (uint32_t index = 0; index < quantifier_count; index++) {
    WRITE_ARRAY(buffer, query->capture_quantifiers.contents[index]);
  }
  WRITE_ARRAY(buffer, query->steps);
  WRITE_ARRAY(buffer, query->pattern_map);
  WRITE_ARRAY(buffer, query->predicate_steps);
  WRITE_ARRAY(buffer, query->patterns);
  WRITE_ARRAY(buffer, query->step_offsets);
  WRITE_ARRAY(buffer, query->negated_fields);
  WRITE_ARRAY(buffer, query->string_buffer);
  WRITE_ARRAY(buffer, query->repeat_symbols_with_rootless_patterns);
  buffer_write(buffer, &query->wildcard_root_pattern_count,
               sizeof query->wildcard_root_pattern_count);
}

static TSQuery *deserialize_query(Buffer *buffer, const TSLanguage *language) {
  TSQuery *query = ts_calloc(1, sizeof(TSQuery));
  READ_ARRAY(buffer, query->captures.characters);
  READ_ARRAY(buffer, query->captures.slices);
  READ_ARRAY(buffer, query->predicate_values.characters);
  READ_ARRAY(buffer, query->predicate_values.slices);
  uint32_t quantifier_count = 0;
  buffer_read(buffer, &quantifier_count, sizeof quantifier_count);
  query->capture_quantifiers.size = quantifier_count;
  query->capture_quantifiers.capacity = quantifier_count;
  query->capture_quantifiers.contents =
      quantifier_count > 0
          ? ts_malloc(quantifier_count * sizeof(CaptureQuantifiers))
          : NULL;
  for (uint32_t index = 0; index < quantifier_count; index++) {
    READ_ARRAY(buffer, query->capture_quantifiers.contents[index]);
  }
  READ_ARRAY(buffer, query->steps);
  READ_ARRAY(buffer, query->pattern_map);
  READ_ARRAY(buffer, query->predicate_steps);
  READ_ARRAY(buffer, query->patterns);
  READ_ARRAY(buffer, query->step_offsets);
  READ_ARRAY(buffer, query->negated_fields);
  READ_ARRAY(buffer, query->string_buffer);
  READ_ARRAY(buffer, query->repeat_symbols_with_rootless_patterns);
  buffer_read(buffer, &query->wildcard_root_pattern_count,
              sizeof query->wildcard_root_pattern_count);
  query->language = language;
  return query;
}

// ---- capture-stream comparison ----

static Buffer dump_captures(const TSQuery *query, TSTree *tree) {
  Buffer dump = {0};
  TSQueryCursor *cursor = ts_query_cursor_new();
  ts_query_cursor_exec(cursor, query, ts_tree_root_node(tree));
  TSQueryMatch match;
  while (ts_query_cursor_next_match(cursor, &match)) {
    buffer_write(&dump, &match.pattern_index, sizeof match.pattern_index);
    for (uint16_t capture_index = 0; capture_index < match.capture_count;
         capture_index++) {
      TSQueryCapture capture = match.captures[capture_index];
      uint32_t record[3] = { capture.index,
                             ts_node_start_byte(capture.node),
                             ts_node_end_byte(capture.node) };
      buffer_write(&dump, record, sizeof record);
    }
  }
  ts_query_cursor_delete(cursor);
  return dump;
}

int main(int argument_count, char **arguments) {
  if (argument_count < 3) {
    fprintf(stderr, "usage: %s <query.scm> <source-fixture> [iterations]\n",
            arguments[0]);
    return 2;
  }
  uint32_t query_length = 0, source_length = 0;
  char *query_source = read_file(arguments[1], &query_length);
  char *source = read_file(arguments[2], &source_length);
  int iterations = argument_count > 3 ? atoi(arguments[3]) : 20;

  // fresh compile (timed)
  double start = now_ms();
  uint32_t error_offset = 0;
  TSQueryError error_type = TSQueryErrorNone;
  TSQuery *fresh_query = ts_query_new(LANG_FN(), query_source, query_length,
                                      &error_offset, &error_type);
  double compile_ms = now_ms() - start;
  if (!fresh_query) {
    fprintf(stderr, "query error at offset %u\n", error_offset);
    return 1;
  }

  // serialize
  Buffer serialized = {0};
  serialize_query(fresh_query, &serialized);

  // deserialize (timed, median over iterations)
  double load_times[iterations];
  TSQuery *loaded_query = NULL;
  for (int iteration = 0; iteration < iterations; iteration++) {
    if (loaded_query) ts_query_delete(loaded_query);
    serialized.read_offset = 0;
    start = now_ms();
    loaded_query = deserialize_query(&serialized, LANG_FN());
    load_times[iteration] = now_ms() - start;
  }
  double load_total = 0;
  double load_min = load_times[0];
  for (int iteration = 0; iteration < iterations; iteration++) {
    load_total += load_times[iteration];
    if (load_times[iteration] < load_min) load_min = load_times[iteration];
  }

  // capture equality on the real fixture
  TSParser *parser = ts_parser_new();
  ts_parser_set_language(parser, LANG_FN());
  TSTree *tree = ts_parser_parse_string(parser, NULL, source, source_length);
  Buffer fresh_captures = dump_captures(fresh_query, tree);
  Buffer loaded_captures = dump_captures(loaded_query, tree);

  int identical = fresh_captures.length == loaded_captures.length
    && memcmp(fresh_captures.bytes, loaded_captures.bytes,
              fresh_captures.length) == 0;

  printf("compile:      %8.2f ms\n", compile_ms);
  printf("blob size:    %8zu bytes\n", serialized.length);
  printf("load mean:    %8.3f ms  (min %.3f, %d iterations)\n",
         load_total / iterations, load_min, iterations);
  printf("captures:     %s (%zu bytes of capture records)\n",
         identical ? "IDENTICAL" : "MISMATCH — DO NOT PROCEED",
         fresh_captures.length);

  // exercise ts_query_delete on the loaded query — allocator consistency
  ts_query_delete(loaded_query);
  ts_query_delete(fresh_query);
  printf("delete:       both queries freed cleanly\n");
  return identical ? 0 : 1;
}
