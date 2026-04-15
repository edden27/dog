# 🐶 dog

> Like bat, but powered by tree-sitter.

A `cat` alternative for macOS and Linux that prints files to your terminal with syntax highlighting. Auto-pages with `less`. Built to be piped into previewers like `fzf`, `tv`, and `yazi`.

```sh
dog Sources/Dog/main.swift
dog --light src/lib.rs
echo 'struct Point { let x, y: Int }' | dog -l swift
fzf --preview 'dog --color=always {}'
```

A [yazi plugin](https://github.com/edden27/dog-yazi) wraps `dog` as a previewer with caching and theme config.

## Why dog

- **800+ Zed themes** — drop a JSON file in, or point `--theme-dir` at your existing `~/.config/zed/themes` and use what you already have. Backgrounds, line numbers, and gutter are all theme-controlled. Two zero-cost built-ins ship too — dark is the default, `--light` flips to the bright one.
- **Up to 8.4× faster than bat on large files** — 55k lines of JS in 307ms vs 2.6s. 100% syntax coverage across all 17 supported languages.
- **Single binary, no runtime deps** — 17 grammars statically compiled in. Copy it anywhere, it runs.
- **Built on tree-sitter** — full AST parse, not regex. Highlight queries from [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter).
- **Written in Swift** — direct tree-sitter C API. Custom ANSI renderer, custom JSON and TOML parsers (sub-millisecond).

## Install

::: warning
Release URLs are placeholders until 0.1 ships.
:::

**macOS** (Homebrew planned):

```sh
curl -L <REPO_URL>/releases/latest/download/dog-macos-arm64.tar.gz | tar xz
sudo mv dog /usr/local/bin/
```

**Linux**:

```sh
curl -L <REPO_URL>/releases/latest/download/dog-linux-x86_64.tar.gz | tar xz
sudo mv dog /usr/local/bin/
```

**From source**:

```sh
git clone <REPO_URL>
cd dog/cli
swift build -c release
cp .build/release/dog /usr/local/bin/
```

Requires macOS 14+ or Linux with the Swift runtime (bundled in the Linux binary).

## How does it compare to bat?


|                                             | dog                      | bat            |
| ------------------------------------------- | ------------------------ | -------------- |
| Engine                                      | tree-sitter, full AST    | regex per line |
| Themes                                      | Zed JSON, 800+ available | TextMate XML   |
| Line background, gutter, line-number colors | Theme-controlled         | Fixed          |
| Languages                                   | 17                       | 200+           |
| Tiny-file speed (~25 lines)                 | tied                     | baseline       |
| Small-file speed (~200 lines)               | 1.2× faster              | baseline       |
| Medium-file speed (~2k lines)               | **3× faster**            | baseline       |
| Large-file speed (16k lines avg)            | **5.1× faster**          | baseline       |
| Extreme-file speed (55k–260k lines)         | **7× faster**            | baseline       |
| Syntax coverage (avg)                       | **100%**                 | 77%            |
| Multi-file, git gutter, Windows             | Not yet                  | Yes            |
| Binary size                                 | ~20 MB (macOS)           | ~6 MB          |


Full benchmarks and methodology in the [docs](https://dog.dev/benchmarks).

## Documentation

- **[Getting started](https://dog.dev/getting-started)** — install, first highlight, theme, fzf
- **[Configuration](https://dog.dev/configuration)** — every flag, env var, exit code
- **[How to integrate dog](https://dog.dev/how-to-integrate-dog)** — fzf, tv, pager, shell pipes
- **[How to set themes](https://dog.dev/how-to-use-themes)** — pick, install, author + Zed schema
- **[Benchmarks](https://dog.dev/benchmarks)** — full speed and coverage matrix
- **[How is dog different?](https://dog.dev/how-is-dog-different)** — what changes vs bat

## Status

`0.1.0` — first public release. Known limitations:

- Single file at a time (multi-file planned)
- No git-diff gutter
- No Windows
- `--list-languages` and `--range` are stubs
- `$PAGER` not honored (pager is hardcoded to `less -R`)

Test suite: 194 Swift unit tests across 12 suites + 49 integration assertions across 9 suites + 13 bat-compatibility scenarios.

## Acknowledgements

- Highlight queries from [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) (Apache 2.0)
- Tree-sitter grammars from the upstream tree-sitter community
- Theme format from [Zed](https://zed.dev)

## License

TBD — pending 0.1 release.

---

::: info 🐕 Dog Fact
Dogs love dark mode. They have superior night vision and motion detection, which was more important evolutionarily than color vision for their survival as hunters.
:::