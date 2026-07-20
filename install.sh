#!/bin/sh
#
# dog installer — downloads the right release binary for this machine and
# sets up shell completions. Served at https://sh.dog/install.
#
# Usage:
#   curl -fsSL https://sh.dog/install | sh
#   curl -fsSL https://sh.dog/install | sh -s -- --prefix ~/.local --completions fish
#
# Options:
#   --prefix DIR         install to DIR/bin (default: /usr/local/bin if
#                        writable, else ~/.local/bin)
#   --completions SHELL  bash | zsh | fish | none (default: detect from $SHELL)
#
# Completions are written only into directories the shell already auto-loads;
# this script never edits shell config files — when no such directory exists
# it prints the lines to add instead.
#
# DOG_INSTALL_URL overrides the download URL (testing only).

set -eu

REPO="edden27/dog"
PREFIX=""
COMP="auto"

say()  { printf 'dog install: %s\n' "$*"; }
fail() { printf 'dog install: error: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)      PREFIX="${2:?--prefix needs a directory}"; shift 2 ;;
    --completions) COMP="${2:?--completions needs bash|zsh|fish|none}"; shift 2 ;;
    *) fail "unknown option: $1" ;;
  esac
done

# ── platform ─────────────────────────────────────────────────────────────────
case "$(uname -s)" in
  Darwin) OS=macos ;;
  Linux)  OS=linux ;;
  *) fail "unsupported OS: $(uname -s) — dog runs on macOS and Linux" ;;
esac
case "$(uname -m)" in
  arm64 | aarch64) ARCH=arm64 ;;
  x86_64 | amd64)  ARCH=x86_64 ;;
  *) fail "unsupported architecture: $(uname -m)" ;;
esac

TARBALL="dog-$OS-$ARCH.tar.gz"
URL="${DOG_INSTALL_URL:-https://github.com/$REPO/releases/latest/download/$TARBALL}"

# ── download ─────────────────────────────────────────────────────────────────
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "downloading $URL"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" -o "$TMP/$TARBALL"
elif command -v wget >/dev/null 2>&1; then
  wget -q "$URL" -O "$TMP/$TARBALL"
else
  fail "need curl or wget"
fi

tar -xzf "$TMP/$TARBALL" -C "$TMP"
[ -f "$TMP/dog" ] || fail "tarball did not contain a dog binary"

# ── install binary ───────────────────────────────────────────────────────────
if [ -n "$PREFIX" ]; then
  BINDIR="$PREFIX/bin"
elif [ -w /usr/local/bin ]; then
  BINDIR=/usr/local/bin
else
  BINDIR="$HOME/.local/bin"
fi

mkdir -p "$BINDIR"
install -m 755 "$TMP/dog" "$BINDIR/dog"
VERSION="$("$BINDIR/dog" --version)" || fail "installed binary failed to run"
say "installed $BINDIR/dog ($VERSION)"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) say "note: $BINDIR is not in your PATH — add: export PATH=\"$BINDIR:\$PATH\"" ;;
esac

# ── completions ──────────────────────────────────────────────────────────────
COMP_SHELL="$COMP"
[ "$COMP_SHELL" = auto ] && COMP_SHELL="$(basename "${SHELL:-unknown}")"

gen() { "$BINDIR/dog" --generate-completion-script "$1"; }

case "$COMP_SHELL" in
  zsh)
    DIR=""
    if [ -d "$HOME/.oh-my-zsh" ]; then
      DIR="$HOME/.oh-my-zsh/completions"
      mkdir -p "$DIR"
    else
      for d in /opt/homebrew/share/zsh/site-functions /usr/local/share/zsh/site-functions; do
        if [ -d "$d" ] && [ -w "$d" ]; then DIR="$d"; break; fi
      done
    fi
    if [ -n "$DIR" ]; then
      gen zsh > "$DIR/_dog"
      say "zsh completions → $DIR/_dog"
    else
      mkdir -p "$HOME/.zsh/completion"
      gen zsh > "$HOME/.zsh/completion/_dog"
      say "zsh completions → ~/.zsh/completion/_dog"
      say "no auto-loading directory found; add these lines to ~/.zshrc:"
      say '  fpath=(~/.zsh/completion $fpath)'
      say '  autoload -U compinit && compinit'
    fi
    say "if completions don't appear, rebuild zsh's cache: rm -f ~/.zcompdump* && exec zsh"
    ;;
  bash)
    HAVE_BC=""
    for f in /opt/homebrew/etc/profile.d/bash_completion.sh \
             /usr/local/etc/profile.d/bash_completion.sh \
             /usr/share/bash-completion/bash_completion \
             /etc/bash_completion; do
      if [ -f "$f" ]; then HAVE_BC=1; break; fi
    done
    if [ -n "$HAVE_BC" ]; then
      DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
      mkdir -p "$DIR"
      gen bash > "$DIR/dog"
      say "bash completions → $DIR/dog (auto-loaded by bash-completion)"
    else
      mkdir -p "$HOME/.bash_completions"
      gen bash > "$HOME/.bash_completions/dog.bash"
      say "bash completions → ~/.bash_completions/dog.bash"
      say "bash-completion isn't installed; add this line to ~/.bashrc (macOS: ~/.bash_profile):"
      say '  source ~/.bash_completions/dog.bash'
    fi
    ;;
  fish)
    DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions"
    mkdir -p "$DIR"
    gen fish > "$DIR/dog.fish"
    say "fish completions → $DIR/dog.fish"
    ;;
  none)
    say "skipping completions (--completions none)"
    ;;
  *)
    say "unrecognized shell '$COMP_SHELL' — skipping completions"
    say "rerun with: --completions bash|zsh|fish"
    ;;
esac

say "done — try: dog --help"
