#!/bin/bash
# Benchmark dog vs bat across all 17 languages on large fixture files.
# Requires: hyperfine, bat, dog release binary
#
# Usage:
#   ./tests/scripts/bench.sh              # all languages
#   ./tests/scripts/bench.sh javascript   # single language
#   BENCH_RUNS=10 ./tests/scripts/bench.sh  # more runs for accuracy
#   BENCH_SIZE=medium ./tests/scripts/bench.sh  # test medium files instead of large
#   BENCH_WITH_LANG=1 ./tests/scripts/bench.sh  # pass -l flag (skip auto-detection)
#   BENCH_THEME='Nord Dark' ./tests/scripts/bench.sh  # bench dog with a theme (name, not path)
#   BENCH_THEME_DIR=~/.config/zed/themes BENCH_THEME='One Dark Pro' ./tests/scripts/bench.sh
#   BENCH_BAT_THEME='Catppuccin Mocha' ./tests/scripts/bench.sh  # force bat to a specific theme
#   BENCH_BAT_NO_CONFIG=1 ./tests/scripts/bench.sh  # bat ignores ~/.config/bat/config and $BAT_THEME
#   BENCH_PLAIN=1 ./tests/scripts/bench.sh        # dog uses -p (no decorations)
#   BENCH_NO_PAGER=1 ./tests/scripts/bench.sh     # dog + bat pager off (symmetric)
#   BENCH_WARMUP=5 BENCH_RUNS=10 BENCH_SIZE=tiny ./tests/scripts/bench.sh  # combine
#
# IMPORTANT: bat MUST use --color=always or it skips highlighting entirely.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES="$PROJECT_ROOT/tests/fixtures/performance"

# Colors — $'...' so they're literal bytes, no echo -e needed
G=$'\033[38;2;136;169;141m'
R=$'\033[38;2;204;67;61m'
Y=$'\033[38;2;222;169;99m'
W=$'\033[38;2;255;241;224m'
B=$'\033[38;2;208;189;169m'
O=$'\033[38;2;222;117;71m'
Z=$'\033[0m'

# Find dog binary
DOG="${DOG_BIN:-}"
if [[ -z "$DOG" ]]; then
  for candidate in "$PROJECT_ROOT/cli/.build/release/dog" "$PROJECT_ROOT/cli/.build/debug/dog"; do
    if [[ -x "$candidate" ]]; then
      DOG="$candidate"
      break
    fi
  done
fi

if [[ -z "$DOG" || ! -x "$DOG" ]]; then
  echo "${R}Error:${Z} dog binary not found. Run 'swift build -c release' first."
  exit 1
fi

if ! command -v hyperfine &>/dev/null; then
  echo "${R}Error:${Z} hyperfine not found. Install with 'brew install hyperfine'."
  exit 1
fi

if ! command -v bat &>/dev/null; then
  echo "${R}Error:${Z} bat not found. Install with 'brew install bat'."
  exit 1
fi

WARMUP="${BENCH_WARMUP:-2}"
RUNS="${BENCH_RUNS:-5}"
SIZE="${BENCH_SIZE:-large}"
WITH_LANG="${BENCH_WITH_LANG:-0}"
PLAIN="${BENCH_PLAIN:-0}"
NO_PAGER="${BENCH_NO_PAGER:-1}"
THEME_NAME="${BENCH_THEME:-}"
THEME_DIR="${BENCH_THEME_DIR:-}"
BAT_THEME_NAME="${BENCH_BAT_THEME:-}"
BAT_NO_CONFIG="${BENCH_BAT_NO_CONFIG:-0}"
FILTER="${1:-}"

# Theme flags: pass name to dog (resolved by themes[].name match in ~/.config/dog/themes/).
# Quoted so variant names with spaces — "Catppuccin Mocha", "Everforest Dark Hard (blur)" —
# survive the shell split into `dog` args.
THEME_FLAG=""
THEME_LABEL="UtilityDark (built-in)"
if [[ -n "$THEME_NAME" ]]; then
  THEME_FLAG="--theme '$THEME_NAME'"
  THEME_LABEL="$THEME_NAME"
fi
if [[ -n "$THEME_DIR" ]]; then
  THEME_FLAG="$THEME_FLAG --theme-dir '$THEME_DIR'"
  THEME_LABEL="$THEME_LABEL (from $THEME_DIR)"
fi

# Collect results
declare -a LANGS DOG_TIMES BAT_TIMES RATIOS

idx=0
for lang_dir in "$FIXTURES"/*/; do
  lang=$(basename "$lang_dir")

  if [[ -n "$FILTER" && "$lang" != "$FILTER" ]]; then
    continue
  fi

  # Use shell globbing instead of ls | head — ls exits non-zero on no match
  # and pipefail aborts the script. Glob expansion leaves the literal pattern
  # when nothing matches, which we detect via -f on the first candidate.
  shopt -s nullglob
  candidates=("$lang_dir"${SIZE}.*)
  shopt -u nullglob
  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "${Y}skip${Z} ${lang} — no ${SIZE} fixture" >&2
    continue
  fi
  file="${candidates[0]}"

  printf "  benchmarking ${W}${lang}${Z}...\r"

  # Build dog flags
  DOG_FLAGS="--color always"
  [[ "$PLAIN" == "1" ]] && DOG_FLAGS="$DOG_FLAGS -p"
  [[ "$NO_PAGER" == "1" ]] && DOG_FLAGS="$DOG_FLAGS -P"
  [[ -n "$THEME_FLAG" ]] && DOG_FLAGS="$DOG_FLAGS $THEME_FLAG"

  # Build bat extras — pager, theme, config bypass — symmetric with dog flags above.
  # bat auto-disables pager when stdout is non-TTY, but we set it explicitly to remove ambiguity.
  BAT_EXTRAS=""
  [[ "$NO_PAGER" == "1" ]] && BAT_EXTRAS="$BAT_EXTRAS --paging=never"
  [[ "$BAT_NO_CONFIG" == "1" ]] && BAT_EXTRAS="$BAT_EXTRAS --no-config"
  [[ -n "$BAT_THEME_NAME" ]] && BAT_EXTRAS="$BAT_EXTRAS --theme '$BAT_THEME_NAME'"

  # Symmetric decoration control.
  # dog's --plain == bat's -p  (strip decorations, keep pager policy separate).
  # BENCH_PLAIN=1 → both tools strip decorations.
  # BENCH_PLAIN=0 → both tools render with decorations (line numbers, etc.).
  # Pager is controlled separately via BENCH_NO_PAGER (see BAT_EXTRAS above, DOG_FLAGS above).
  BAT_DECOR_FLAG=""
  [[ "$PLAIN" == "1" ]] && BAT_DECOR_FLAG="-p"

  if [[ "$WITH_LANG" == "1" ]]; then
    dog_cmd="$DOG $DOG_FLAGS -l $lang $file > /dev/null"
    bat_cmd="bat $BAT_DECOR_FLAG -l $lang $BAT_EXTRAS --color=always $file > /dev/null"
  else
    dog_cmd="$DOG $DOG_FLAGS $file > /dev/null"
    bat_cmd="bat $BAT_DECOR_FLAG $BAT_EXTRAS --color=always $file > /dev/null"
  fi

  tmpjson=$(mktemp)
  # Keep hyperfine's stdout/stderr visible so failures aren't hidden.
  # Progress lines are verbose but it's worth it — silent failures turned out
  # to be a real source of confusion.
  if ! hyperfine --warmup "$WARMUP" --runs "$RUNS" --export-json "$tmpjson" \
    "$dog_cmd" \
    "$bat_cmd" \
    >&2; then
    echo "${R}hyperfine failed for $lang — see output above${Z}" >&2
    rm -f "$tmpjson"
    continue
  fi

  dog_ms=$(python3 -c "import json; d=json.load(open('$tmpjson')); print(f\"{d['results'][0]['mean']*1000:.0f}\")" 2>/dev/null || echo "?")
  bat_ms=$(python3 -c "import json; d=json.load(open('$tmpjson')); print(f\"{d['results'][1]['mean']*1000:.0f}\")" 2>/dev/null || echo "?")
  rm -f "$tmpjson"

  if [[ "$dog_ms" != "?" && "$bat_ms" != "?" && "$dog_ms" -gt 0 ]]; then
    ratio=$(python3 -c "print(f'{$bat_ms/$dog_ms:.1f}')")
  else
    ratio="?"
  fi

  LANGS[$idx]="$lang"
  DOG_TIMES[$idx]="$dog_ms"
  BAT_TIMES[$idx]="$bat_ms"
  RATIOS[$idx]="$ratio"
  idx=$((idx + 1))
done

printf "                              \r"

# Render
echo ""
lang_flag="auto-detect"
[[ "$WITH_LANG" == "1" ]] && lang_flag="-l"
mode_parts=()
[[ "$PLAIN" == "1" ]] && mode_parts+=("-p")
[[ "$NO_PAGER" == "1" ]] && mode_parts+=("-P") || mode_parts+=("pager")
[[ "$WITH_LANG" == "1" ]] && mode_parts+=("-l")
[[ -n "$THEME_NAME" ]] && mode_parts+=("--theme '$THEME_NAME'")
[[ -n "$THEME_DIR" ]] && mode_parts+=("--theme-dir '$THEME_DIR'")
mode_label=$(IFS=' '; echo "${mode_parts[*]}")
echo "${O}--- dog vs bat benchmark (${SIZE} files, ${mode_label}) ---${Z}"
echo ""
printf "  ${W}%-14s %8s %8s %8s${Z}\n" "Language" "dog" "bat" "Ratio"
printf "  ${B}%-14s %8s %8s %8s${Z}\n" "--------------" "--------" "--------" "--------"

dog_wins=0
bat_wins=0
for ((i=0; i<idx; i++)); do
  lang="${LANGS[$i]}"
  dog="${DOG_TIMES[$i]}ms"
  bat="${BAT_TIMES[$i]}ms"
  ratio="${RATIOS[$i]}x"

  r="${RATIOS[$i]}"
  if [[ "$r" != "?" ]]; then
    above=$(python3 -c "print('g' if $r >= 1.0 else 'r')")
    case "$above" in
      g) rc="$G"; dog_wins=$((dog_wins + 1)) ;;
      r) rc="$R"; bat_wins=$((bat_wins + 1)) ;;
    esac
  else
    rc="$B"
    dog_wins=$((dog_wins + 1))
  fi

  printf "  ${W}%-14s${Z} ${G}%8s${Z} ${Y}%8s${Z} ${rc}%8s${Z}\n" "$lang" "$dog" "$bat" "$ratio"
done

echo ""
if [[ $bat_wins -eq 0 ]]; then
  echo "  ${G}dog wins all ${idx} languages${Z}"
else
  echo "  ${G}dog wins ${dog_wins}/${idx}${Z}, ${R}bat wins ${bat_wins}/${idx}${Z}"
fi

if [[ $idx -gt 0 ]]; then
  ratio_csv=$(IFS=,; echo "${RATIOS[*]}")
  avg=$(python3 -c "
ratios = [$ratio_csv]
ratios = [r for r in ratios if r > 0]
print(f'{sum(ratios)/len(ratios):.1f}')
" 2>/dev/null || echo "?")
  echo "  ${W}Average: ${G}${avg}x faster${Z}"
fi

echo ""
plain_label="off"
[[ "$PLAIN" == "1" ]] && plain_label="on (-p)"
pager_label="on"
[[ "$NO_PAGER" == "1" ]] && pager_label="off (-P)"

# Build bat config label for footer
bat_label="--color=always"
[[ "$NO_PAGER" == "1" ]] && bat_label="$bat_label --paging=never"
[[ "$BAT_NO_CONFIG" == "1" ]] && bat_label="$bat_label --no-config"
if [[ -n "$BAT_THEME_NAME" ]]; then
  bat_label="$bat_label --theme '$BAT_THEME_NAME'"
else
  bat_label="$bat_label (theme from bat config / \$BAT_THEME)"
fi

echo "  ${B}warmup=${WARMUP} runs=${RUNS} size=${SIZE} lang=${lang_flag} plain=${plain_label} pager=${pager_label} dog-theme=${THEME_LABEL} bat=${bat_label}${Z}"
echo ""
