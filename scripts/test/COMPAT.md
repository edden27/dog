# Compatibility scenarios

Plain-English companion to [`compat.sh`](./compat.sh). The script exercises thirteen behaviors that `dog` must match for it to drop into any workflow where `bat` is currently used — shell pipelines, editor integrations, CI scripts, and interactive terminals. Run it after any change that touches argument parsing, I/O, color decisions, or error paths. A "pass" means every scenario produced the expected output, exit code, and color state. The suite is also summarized in the public [Compatibility section](../../../vitepress-test/docs/benchmarks.md#compatibility) of the benchmarks page.

## Scenarios

1. **Pipe strips color.** Running `dog --woof | cat` emits no ANSI escape sequences. Matches `bat`'s default auto-detection of a non-TTY destination, so piping into `grep`, `less`, or a file stays plain text.

2. **`--color=always` forces color in a pipe.** Explicit `--color=always` overrides pipe auto-detection and emits escapes. Needed by anything that captures colored output for downstream rendering (e.g. `less -R`, shell prompts, rich log viewers). See [env vars](../../../vitepress-test/docs/configuration.md#env-vars).

3. **`NO_COLOR` strips color.** Setting `NO_COLOR=1` suppresses escapes even when output is a TTY. Matches the [NO\_COLOR informal standard](https://no-color.org) that `bat` honors. See [env vars](../../../vitepress-test/docs/configuration.md#env-vars).

4. **`FORCE_COLOR` overrides `NO_COLOR`.** When both variables are set, `FORCE_COLOR=1` wins and escapes are emitted. Required for CI systems that set `NO_COLOR` globally but want colorized logs from specific steps. See [env vars](../../../vitepress-test/docs/configuration.md#env-vars).

5. **Missing file exits `1`.** `dog nonexistent.swift` returns exit code `1`. Scripts that gate on `dog "$f" || handle_missing` rely on this exact code, which is `bat`'s convention.

6. **Bad language flag exits non-zero.** `dog -l fakeLang file` returns a non-zero status rather than silently falling back. Prevents silent miscategorization in automation that passes user-supplied language names.

7. **Stdin with `-l` highlights.** `echo 'let x = 1' | dog -l swift` produces highlighted output. Editors and REPL integrations commonly pipe a selection through `bat -l <lang>` to render it — `dog` must accept the same invocation.

8. **Stdin without a language passes through.** `echo 'let x = 1' | dog` emits the input unchanged. `bat` degrades to plain passthrough when it cannot detect a language from stdin; anything else would corrupt binary-safe pipelines.

9. **Binary file produces a clear message.** `dog /bin/ls` prints a legible "binary" or "not UTF-8" message instead of dumping control bytes or crashing. Matches `bat`'s refusal to render non-text files.

10. **Empty file exits `0` with no output.** An empty input produces no bytes and exit code `0`. Required so that loops over globs don't abort on zero-length files.

11. **Large file piped to `head` emits no broken-pipe error.** `dog big_file | head -5` writes cleanly without a `SIGPIPE` message on stderr. Common interactive pattern for previewing long files; any stderr noise would break scripts that capture stderr.

12. **`--plain` runs without error.** `dog -p file` produces output and exits cleanly. `bat -p` is the standard way to strip decorations while keeping highlighting; users aliasing `cat=bat -p` need the same from `dog`.

13. **`--list-languages` produces output.** `dog --list-languages` writes something to stdout. Tooling that introspects supported grammars (completion scripts, wrappers) depends on this flag returning non-empty output.

## How to run

```sh
bash tests/scripts/compat.sh
```

Runtime is roughly one second. Override the binary under test with `DOG_BIN=/path/to/dog`; otherwise the script uses `cli/.build/debug/dog`.

## Exit code and counts file

The script exits `0` when all thirteen scenarios pass and `1` when any scenario fails. Failed scenario names are listed beneath the summary line.

When `COUNTS_FILE` is set in the environment, the script appends two lines to that file on completion:

```
pass=<number of passing scenarios>
fail=<number of failing scenarios>
```
