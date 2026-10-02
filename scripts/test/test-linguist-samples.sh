#!/usr/bin/env bash
#
# Verify language detection against GitHub Linguist sample files.
# Downloads one sample per language from linguist's samples/ directory,
# runs dog on each, and verifies it exits 0 (detection + parse succeeded).
#
# Also tests files without extensions (shebangs) and known filenames.
#
# Usage:
#   bash tests/scripts/test-linguist-samples.sh
#
# Requires: curl, dog binary (release build)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SAMPLE_DIR="$PROJECT_DIR/scripts/fixtures/linguist-samples"
DOG="${DOG_BIN:-$PROJECT_DIR/.build/release/dog}"

GREEN='\033[38;2;136;169;141m'
RED='\033[38;2;204;67;61m'
DIM='\033[38;2;208;189;169m'
WHITE='\033[38;2;255;241;224m'
RESET='\033[0m'

if [[ ! -f "$DOG" ]]; then
  echo -e "${DIM}Building release binary...${RESET}"
  (cd "$PROJECT_DIR" && swift build -c release --quiet 2>/dev/null)
fi

mkdir -p "$SAMPLE_DIR"

passed=0
failed=0
skipped=0

echo -e "${WHITE}Linguist sample detection test${RESET}"
echo ""

# ── Part 1: Extension-based detection ──
# Download real linguist sample files and verify dog processes them (exit 0).
# If dog detects the language and parses without error, detection worked.

declare -a EXT_TESTS=(
  # "language|linguist_samples_subdir|filename"
  # Filenames verified against github-linguist/linguist/samples/ (2026-04-06)
  "bash|Shell|invalid-shebang.sh"
  "c|C|hello.c"
  "cpp|C++|hello.cpp"
  "css|CSS|bootstrap.css"
  "go|Go|api.pb.go"
  "html|HTML|pages.html"
  "javascript|JavaScript|bootstrap-modal.js"
  "json|JSON|person.json"
  "lua|Lua|treegen.p8"
  "markdown|Markdown|minimal.md"
  "python|Python|flask-view.py"
  "ruby|Ruby|foo.rb"
  "rust|Rust|main.rs"
  "swift|Swift|section-3.swift"
  "tsx|TSX|import.tsx"
  "typescript|TypeScript|hello.ts"
  "yaml|YAML|229Q.yaml"
)

echo -e "  ${WHITE}Extension detection (real linguist files)${RESET}"

for entry in "${EXT_TESTS[@]}"; do
  IFS='|' read -r lang dir filename <<< "$entry"
  url_path="$dir/$filename"
  sample_path="$SAMPLE_DIR/$filename"

  # Download if not cached
  if [[ ! -f "$sample_path" ]]; then
    url="https://raw.githubusercontent.com/github-linguist/linguist/master/samples/$url_path"
    if ! curl -sfL "$url" -o "$sample_path" 2>/dev/null; then
      echo -e "    ${DIM}SKIP${RESET}  $lang ($filename — download failed)"
      ((skipped++))
      continue
    fi
  fi

  # Run dog without -l — it must auto-detect from extension and not error
  if "$DOG" "$sample_path" > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓${RESET}  ${DIM}$lang${RESET} ($filename)"
    ((passed++))
  else
    echo -e "    ${RED}✗${RESET}  ${DIM}$lang${RESET} ($filename — exit non-zero)"
    ((failed++))
  fi
done

# ── Part 2: Shebang detection ──
# Create temp files with shebangs but NO extension. Dog must detect via shebang.

echo ""
echo -e "  ${WHITE}Shebang detection (extensionless files)${RESET}"

declare -a SHEBANG_TESTS=(
  # "expected_lang|shebang_line|body"
  "python|#!/usr/bin/env python3|import sys; print('hello')"
  "javascript|#!/usr/bin/env node|console.log('hello')"
  "ruby|#!/usr/bin/env ruby|puts 'hello'"
  "bash|#!/bin/bash|echo hello"
  "lua|#!/usr/bin/env lua|print('hello')"
  "swift|#!/usr/bin/env swift|print(\"hello\")"
)

tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

for entry in "${SHEBANG_TESTS[@]}"; do
  IFS='|' read -r lang shebang body <<< "$entry"
  # Create extensionless file with shebang
  tmpfile="$tmpdir/script_$lang"
  printf '%s\n%s\n' "$shebang" "$body" > "$tmpfile"

  if "$DOG" "$tmpfile" > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓${RESET}  ${DIM}$lang${RESET} ($shebang)"
    ((passed++))
  else
    echo -e "    ${RED}✗${RESET}  ${DIM}$lang${RESET} ($shebang — exit non-zero)"
    ((failed++))
  fi
done

# ── Part 3: Known filename detection ──
# Create files with known names (Makefile, .bashrc, etc.) and verify detection.

echo ""
echo -e "  ${WHITE}Filename detection (known names)${RESET}"

declare -a FILENAME_TESTS=(
  # "expected_lang|filename|content"
  "ruby|Gemfile|source 'https://rubygems.org'"
  "ruby|Rakefile|task :default do; end"
  "bash|.bashrc|export PATH=/usr/local/bin"
  "bash|.zshrc|export PATH=/usr/local/bin"
  "json|composer.lock|{\"packages\": []}"
  "yaml|.clang-format|BasedOnStyle: LLVM"
  "swift|Package.swift|// swift-tools-version: 6.2"
  "python|BUILD|load(':defs.bzl', 'py_library')"
)

for entry in "${FILENAME_TESTS[@]}"; do
  IFS='|' read -r lang filename content <<< "$entry"
  tmpfile="$tmpdir/$filename"
  echo "$content" > "$tmpfile"

  if "$DOG" "$tmpfile" > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓${RESET}  ${DIM}$lang${RESET} ($filename)"
    ((passed++))
  else
    echo -e "    ${RED}✗${RESET}  ${DIM}$lang${RESET} ($filename — exit non-zero)"
    ((failed++))
  fi
done

# ── Part 4: Pipe with shebang ──
echo ""
echo -e "  ${WHITE}Pipe detection (stdin shebang)${RESET}"

for entry in "${SHEBANG_TESTS[@]}"; do
  IFS='|' read -r lang shebang body <<< "$entry"
  input=$(printf '%s\n%s\n' "$shebang" "$body")

  if echo "$input" | "$DOG" > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓${RESET}  ${DIM}$lang${RESET} (pipe: $shebang)"
    ((passed++))
  else
    echo -e "    ${RED}✗${RESET}  ${DIM}$lang${RESET} (pipe: $shebang — exit non-zero)"
    ((failed++))
  fi
done

echo ""
total=$((passed + failed + skipped))
echo -e "${DIM}$passed passed, $failed failed, $skipped skipped ($total total)${RESET}"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
