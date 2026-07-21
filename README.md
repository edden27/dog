# 🐶 dog

> Like bat, but powered by tree-sitter.

![Animated terminal demo of dog highlighting a Swift file, cycling through themes — default UtilityDark, Catppuccin Frappé, Nord Dark, Tokyo Night, then --light](assets/hero.gif)

A `cat` alternative for macOS and Linux that prints files to your terminal with syntax highlighting. Auto-pages with `less`. Built to be piped into previewers like `fzf`, `tv`, and `yazi`.

```sh
dog Sources/Dog/main.swift
dog --light src/lib.rs
echo 'struct Point { let x, y: Int }' | dog -l swift
fzf --preview 'dog --color=always {}'
```

A [yazi plugin](https://github.com/edden27/dog.yazi) wraps `dog` as a previewer with caching and theme config.

## Why dog

- **800+ Zed themes** — drop a JSON file in, or point `--theme-dir` at your existing `~/.config/zed/themes` and use what you already have. Backgrounds, line numbers, and gutter are all theme-controlled. Two zero-cost built-ins ship too — dark is the default, `--light` flips to the bright one.
- **Up to 14.6× faster than bat on large files** — 54k lines of TypeScript in 0.4s vs 5.8s. 100% syntax coverage across all 17 supported languages.
- **~5ms startup, every language** — precompiled highlight queries mean there's no per-language warmup. In fzf or yazi, that's the latency on every keystroke.
- **Single binary, no runtime deps** — 17 grammars statically compiled in. Copy it anywhere, it runs.
- **Built on tree-sitter** — full AST parse, not regex. Highlight queries from [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter).
- **Written in Swift** — direct tree-sitter C API. Custom ANSI renderer, custom JSON and TOML parsers (sub-millisecond).

## Install

::: warning
The install script, Homebrew tap, and release URLs all go live when 0.1 ships — placeholders until then.
:::

**Install script** — figures out your OS and arch, installs the binary, and sets up shell completions:

```sh
curl -fsSL https://sh.dog/install | sh
```

**Homebrew**:

```sh
brew tap edden27/dog
brew install dog
```

**Binary** — four builds: `dog-macos-arm64`, `dog-macos-x86_64`, `dog-linux-x86_64`, `dog-linux-arm64`. Grab yours:

```sh
curl -L <REPO_URL>/releases/latest/download/dog-macos-arm64.tar.gz | tar xz
sudo mv dog /usr/local/bin/
```

**From source** — needs Swift 6.3 or newer (Xcode 26 on macOS):

```sh
git clone <REPO_URL>
cd dog
make build && make install
```

`make install` copies the binary into `/usr/local/bin`, asking for sudo only when it has to; `make install PREFIX=~/.local` avoids sudo entirely.

Requires macOS 14+ or Linux with the Swift runtime (bundled in the Linux binary).

**Tab completions** — dog generates its own completion script for bash, zsh, and fish (`dog --generate-completion-script zsh`); the [docs](https://sh.dog/how-to-integrate-dog#shell-completions) walk through the one-time install for your shell.


## How does it compare to bat?

![Side-by-side comparison of dog and bat rendering a 260,000-line C file — dog finishes in about a second while bat takes several](assets/xlarge-sidebyside.gif)

|                                             | dog                      | bat            |
| ------------------------------------------- | ------------------------ | -------------- |
| Engine                                      | tree-sitter, full AST    | regex per line |
| Themes                                      | Zed JSON, 800+ available | TextMate XML   |
| Bold & italic fonts                         | Theme-controlled         | No             |
| Line background, gutter, line-number colors | Theme-controlled         | Fixed          |
| Languages                                   | 17                       | 200+           |
| Tiny-file speed (~25 lines)                 | **2.8× faster**          | baseline       |
| Small-file speed (~200 lines)               | **3.5× faster**          | baseline       |
| Medium-file speed (~2k lines)               | **6.0× faster**          | baseline       |
| Large-file speed (16k lines avg)            | **7.4× faster**          | baseline       |
| Extreme-file speed (55k–260k lines)         | **8.0× faster**          | baseline       |
| Syntax coverage (avg)                       | **100%**                 | 77%            |
| Multi-file, git gutter, Windows             | Not yet                  | Yes            |
| Binary size                                 | ~20 MB (macOS)           | ~6 MB          |


Full benchmarks and methodology in the [docs](https://sh.dog/benchmarks).

## Documentation

- **[Getting started](https://sh.dog/getting-started)** — install, first highlight, theme, fzf
- **[Configuration](https://sh.dog/configuration)** — every flag, env var, exit code
- **[How to integrate dog](https://sh.dog/how-to-integrate-dog)** — fzf, tv, pager, shell pipes
- **[How to set themes](https://sh.dog/how-to-use-themes)** — pick, install, author + Zed schema
- **[Benchmarks](https://sh.dog/benchmarks)** — full speed and coverage matrix
- **[How is dog different?](https://sh.dog/how-is-dog-different)** — what changes vs bat

## Status

`0.1.0` — first public release. Known limitations:

- Single file at a time (multi-file planned)
- No git-diff gutter
- No Windows
- `--list-languages` and `--range` are stubs
- `$PAGER` not honored (pager is hardcoded to `less -R`)

Test suite: 197 Swift unit tests across 29 suites + 49 integration assertions across 9 suites + 13 bat-compatibility scenarios.

## Acknowledgements

- Highlight queries from [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) (Apache 2.0)
- Tree-sitter grammars from the upstream tree-sitter community
- Theme format from [Zed](https://zed.dev)

## License

MIT — see [LICENSE](LICENSE).

---

::: info 🐕 Dog Fact
Dogs love dark mode. They have superior night vision and motion detection, which was more important evolutionarily than color vision for their survival as hunters.
:::