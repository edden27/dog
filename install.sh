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

# ── output ───────────────────────────────────────────────────────────────────
# UtilityDark palette (dog's built-in theme). Colors only on a terminal.
TTY=""
if [ -t 1 ] && [ "${TERM:-}" != dumb ] && [ -z "${NO_COLOR:-}" ]; then
  TTY=1
  ACCENT='\033[38;2;238;110;57m'   # EE6E39 keyword orange
  GREEN='\033[38;2;129;159;132m'
  YELLOW='\033[38;2;232;166;85m'
  RED='\033[38;2;204;67;61m'
  DIM='\033[38;2;129;116;100m'
  BOLD='\033[1m'
  UL='\033[4m'
  RESET='\033[0m'
else
  ACCENT=''; GREEN=''; YELLOW=''; RED=''; DIM=''; BOLD=''; UL=''; RESET=''
fi

step() { printf "${ACCENT}▸${RESET} %s\n" "$*"; }
ok()   { printf "${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}!${RESET} %s\n" "$*"; }
note() { printf "  ${DIM}%s${RESET}\n" "$*"; }
fail() { printf "${RED}✗ %s${RESET}\n" "$*" >&2; exit 1; }

# Manual follow-ups collected during the run, replayed after the done line:
# a dim line saying where the command goes and what it does, then the exact
# command last — nothing below it.
TODO=""
todo() {
  [ -n "$TODO" ] && TODO="${TODO}\n"
  TODO="${TODO}  ${DIM}${BOLD}$2${RESET}\n${ACCENT}\$${RESET} $1\n"
}
finish() {
  printf "${GREEN}✓${RESET} done — try: ${ACCENT}dog --help${RESET}\n"
  if [ -n "$TODO" ]; then
    printf '%s\n' "---"
    printf "${YELLOW}${BOLD}${UL}TO FINISH SETUP${RESET}\n\n"
    printf "%b" "$TODO"
  fi
}

printf "${BOLD}${ACCENT}🐶 dog${RESET}${BOLD} installer${RESET}\n"

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)      PREFIX="${2:?--prefix needs a directory}"; shift 2 ;;
    --completions) COMP="${2:?--completions needs bash|zsh|fish|none}"; shift 2 ;;
    *) fail "unknown option: $1" ;;
  esac
done

# ── platform ─────────────────────────────────────────────────────────────────
step "detecting platform"
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
ok "$OS $ARCH"

TARBALL="dog-$OS-$ARCH.tar.gz"
URL="${DOG_INSTALL_URL:-https://github.com/$REPO/releases/latest/download/$TARBALL}"

# ── download ─────────────────────────────────────────────────────────────────
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

step "fetching $TARBALL"
note "$URL"
if command -v curl >/dev/null 2>&1; then
  # on a terminal, let curl draw its progress bar for the one slow step
  if [ -n "$TTY" ]; then
    curl -f#L "$URL" -o "$TMP/$TARBALL"
  else
    curl -fsSL "$URL" -o "$TMP/$TARBALL"
  fi
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

step "installing to $BINDIR"
mkdir -p "$BINDIR"
install -m 755 "$TMP/dog" "$BINDIR/dog"
VERSION="$("$BINDIR/dog" --version)" || fail "installed binary failed to run"
# render smoke test — same idea as the brew formula's test block: pipe a line
# of swift through and make sure highlighted output actually comes back
RENDERED="$(printf 'let x = 1\n' | "$BINDIR/dog" -l swift --color=always --paging=never)" \
  || fail "dog installed but failed to render"
case "$RENDERED" in
  *let*) ;;
  *) fail "dog installed but produced no highlighted output" ;;
esac
ok "dog $VERSION installed"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *)
    warn "$BINDIR is not in your PATH"
    USER_SHELL="$(basename "${SHELL:-}")"
    if [ "$USER_SHELL" = fish ]; then
      todo "fish_add_path $BINDIR" \
           "Run this once to add dog to PATH:"
    else
      case "$USER_SHELL" in
        zsh)  RC="~/.zshrc" ;;
        bash) RC="~/.bashrc"; [ "$OS" = macos ] && RC="~/.bash_profile" ;;
        *)    RC="shell config" ;;
      esac
      todo "export PATH=\"$BINDIR:\$PATH\"" \
           "Place this in your $RC to add dog to PATH:"
    fi
    ;;
esac

# ── completions ──────────────────────────────────────────────────────────────
COMP_SHELL="$COMP"
if [ "$COMP_SHELL" = auto ]; then
  COMP_SHELL="$(basename "${SHELL:-unknown}")"
  [ "$COMP_SHELL" = unknown ] || step "$COMP_SHELL detected"
else
  [ "$COMP_SHELL" = none ] || step "completions for $COMP_SHELL (requested)"
fi

gen() { "$BINDIR/dog" --generate-completion-script "$1"; }

case "$COMP_SHELL" in
  zsh)
    step "generating zsh completions"
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
      ok "zsh completions → $DIR/_dog"
    else
      mkdir -p "$HOME/.zsh/completion"
      gen zsh > "$HOME/.zsh/completion/_dog"
      warn "no auto-loading completion directory found — wrote ~/.zsh/completion/_dog"
      todo 'fpath=(~/.zsh/completion $fpath); autoload -U compinit && compinit' \
           "To finish setting up completions add this line to your ~/.zshrc:"
    fi
    note "if completions don't appear: rm -f ~/.zcompdump* && exec zsh"
    ;;
  bash)
    step "generating bash completions"
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
      ok "bash completions → $DIR/dog (auto-loaded by bash-completion)"
    else
      mkdir -p "$HOME/.bash_completions"
      gen bash > "$HOME/.bash_completions/dog.bash"
      warn "bash-completion isn't installed — wrote ~/.bash_completions/dog.bash"
      BRC="~/.bashrc"; [ "$OS" = macos ] && BRC="~/.bash_profile"
      todo 'source ~/.bash_completions/dog.bash' \
           "To finish setting up completions add this line to your $BRC:"
    fi
    ;;
  fish)
    step "generating fish completions"
    DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions"
    mkdir -p "$DIR"
    gen fish > "$DIR/dog.fish"
    ok "fish completions → $DIR/dog.fish"
    ;;
  none)
    note "skipping completions (--completions none)"
    ;;
  *)
    warn "unrecognized shell '$COMP_SHELL' — skipping completions"
    note "rerun with: --completions bash|zsh|fish"
    ;;
esac

finish
