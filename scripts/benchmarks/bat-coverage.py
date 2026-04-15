#!/usr/bin/env python3
"""Measure dog vs bat syntax highlighting coverage on fixture files.

Runs both dog and bat on each fixture language's files and compares what
percentage of non-whitespace bytes receive actual syntax highlighting.

Outputs structured results matching the run-all.sh design:
  (PASS)/(FAIL) header, comparison table, ✓/✗ per language, summary line.

Requires: bat, dog binary (DOG_BIN or cli/.build/release/dog or cli/.build/debug/dog)
"""

import os
import re
import shutil
import subprocess
import sys
import time
import unicodedata

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.normpath(os.path.join(SCRIPT_DIR, "..", ".."))
FIXTURES = os.path.join(PROJECT_ROOT, "tests", "fixtures", "performance")
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")

# UtilityDark palette — explicit RGB only
G = "\033[38;2;136;169;141m"  # green
R = "\033[38;2;204;67;61m"    # red
Y = "\033[38;2;222;169;99m"   # yellow
W = "\033[38;2;255;241;224m"  # white
B = "\033[38;2;208;189;169m"  # beige
Z = "\033[0m"                  # reset


def find_dog():
    """Find dog binary: DOG_BIN env, then release, then debug."""
    env_bin = os.environ.get("DOG_BIN")
    if env_bin and os.access(env_bin, os.X_OK):
        return env_bin
    for path in [
        os.path.join(PROJECT_ROOT, "cli", ".build", "release", "dog"),
        os.path.join(PROJECT_ROOT, "cli", ".build", "debug", "dog"),
    ]:
        if os.access(path, os.X_OK):
            return path
    return None


def detect_default_fg(binary, is_bat):
    """Detect a tool's default foreground color by highlighting plain text."""
    if is_bat:
        cmd = [binary, "--color=always", "--style=plain", "-l", "txt"]
    else:
        cmd = [binary, "--color=always", "-p", "-l", "txt"]
    try:
        result = subprocess.run(
            cmd, input="test", capture_output=True, text=True, timeout=10
        )
        match = re.search(r"\x1b\[([0-9;]+)m", result.stdout)
        return match.group(1) if match else None
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return None


def measure_coverage(fpath, binary, is_bat, default_fg):
    """Return (highlighted_non_ws, total_non_ws) for a single file."""
    with open(fpath, "r", errors="replace") as fh:
        raw = fh.read()
    # Strip any ANSI codes already in the raw source (e.g. bash scripts
    # that assign escape codes to variables) so they don't inflate results.
    raw_clean = ANSI_RE.sub("", raw)
    total_non_ws = len(re.sub(r"\s", "", raw_clean))
    if total_non_ws == 0:
        return 0, 0

    # Count how many ANSI codes exist in the raw source — these are
    # pass-throughs, not highlighting added by the tool.
    raw_codes = ANSI_RE.findall(raw)

    if is_bat:
        cmd = [binary, "--color=always", "--style=plain", "--paging=never", fpath]
    else:
        cmd = [binary, "--color=always", "-p", fpath]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        output = result.stdout
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return 0, total_non_ws

    # If the tool added zero new ANSI codes beyond what's in the raw file,
    # coverage is 0% — the tool isn't highlighting.
    output_codes = ANSI_RE.findall(output)
    if len(output_codes) <= len(raw_codes):
        return 0, total_non_ws

    parts = ANSI_RE.split(output)
    codes = output_codes

    h_bytes = 0
    current_is_highlighted = False

    for i, part in enumerate(parts):
        non_ws = len(re.sub(r"\s", "", part))
        if current_is_highlighted:
            h_bytes += non_ws
        if i < len(codes):
            code_match = re.search(r"\x1b\[([0-9;]+)m", codes[i])
            if code_match:
                cv = code_match.group(1)
                if cv in ("0", ""):
                    current_is_highlighted = False
                elif cv == default_fg:
                    current_is_highlighted = False
                else:
                    current_is_highlighted = True

    return h_bytes, total_non_ws


def measure_lang(lang_dir, binary, is_bat, default_fg):
    """Measure coverage for all files in a language directory."""
    total_bytes = 0
    highlighted_bytes = 0
    file_count = 0

    for f in sorted(os.listdir(lang_dir)):
        fpath = os.path.join(lang_dir, f)
        if not os.path.isfile(fpath):
            continue
        file_count += 1
        h, t = measure_coverage(fpath, binary, is_bat, default_fg)
        highlighted_bytes += h
        total_bytes += t

    if total_bytes > 0:
        return highlighted_bytes / total_bytes * 100, file_count
    return 0.0, file_count


# ── Table rendering ──────────────────────────────────────────────

def vislen(s):
    """Display width of a string, handling multi-byte chars."""
    w = 0
    for c in s:
        eaw = unicodedata.east_asian_width(c)
        w += 2 if eaw in ("F", "W") else 1
    return w


def pad_left(text, width):
    """Left-align text to exact display width."""
    vl = vislen(text)
    return text + " " * max(0, width - vl)


def pad_right(text, width):
    """Right-align text to exact display width."""
    vl = vislen(text)
    return " " * max(0, width - vl) + text


def hline(left, mid, right, widths):
    """Print a horizontal table border."""
    parts = ["\u2500" * (w + 2) for w in widths]
    line = f"    {B}{left}{mid.join(parts)}{right}{Z}"
    print(line)


def row(cells):
    """Print a table row. Each cell is (text, width, color, align)."""
    parts = []
    for text, width, color, align in cells:
        if align == "r":
            padded = pad_right(text, width)
        else:
            padded = pad_left(text, width)
        parts.append(f" {color}{padded}{Z} ")
    line = f"    {B}|{Z}" + f"{B}|{Z}".join(parts) + f"{B}|{Z}"
    # Replace ASCII | with box-drawing │
    line = line.replace("|", "\u2502")
    # Undo replacements inside ANSI codes (none expected, but safe)
    print(line)


def main():
    start = time.time()

    dog_bin = find_dog()
    bat_bin = shutil.which("bat")

    if not dog_bin:
        print(f"  {R}(SKIP){Z}  {W}coverage{Z}  {B}dog binary not found{Z}")
        sys.exit(0)
    if not bat_bin:
        print(f"  {R}(SKIP){Z}  {W}coverage{Z}  {B}bat not found{Z}")
        sys.exit(0)

    if not os.path.isdir(FIXTURES):
        print(f"  {R}(SKIP){Z}  {W}coverage{Z}  {B}fixtures not found{Z}")
        sys.exit(0)

    dog_fg = detect_default_fg(dog_bin, is_bat=False)
    bat_fg = detect_default_fg(bat_bin, is_bat=True)

    if not bat_fg:
        print(f"  {R}(SKIP){Z}  {W}coverage{Z}  {B}could not detect bat default fg{Z}")
        sys.exit(0)

    # Measure all languages
    results = []
    for lang in sorted(os.listdir(FIXTURES)):
        lang_dir = os.path.join(FIXTURES, lang)
        if not os.path.isdir(lang_dir):
            continue
        dog_pct, files = measure_lang(lang_dir, dog_bin, False, dog_fg)
        bat_pct, _ = measure_lang(lang_dir, bat_bin, True, bat_fg)
        if files > 0:
            results.append((lang, dog_pct, bat_pct, files))

    # Score
    dog_wins = 0
    bat_wins = 0
    ties = 0
    pass_count = 0
    fail_count = 0

    for lang, dog_pct, bat_pct, _ in results:
        diff = abs(dog_pct - bat_pct)
        if diff < 0.5:
            ties += 1
            pass_count += 1
        elif dog_pct > bat_pct:
            dog_wins += 1
            pass_count += 1
        else:
            bat_wins += 1
            fail_count += 1

    total = len(results)
    elapsed = time.time() - start

    # ── Output ──

    print()
    if fail_count == 0:
        print(f"  {G}(PASS){Z}  {W}coverage{Z}  {B}{total} languages, dog wins all{Z}")
    else:
        print(f"  {G}(PASS){Z}  {W}coverage{Z}  {B}{dog_wins} of {total} languages won{Z}"
              if dog_wins > bat_wins else
              f"  {R}(FAIL){Z}  {W}coverage{Z}  {B}{dog_wins} of {total} languages won{Z}")
    print()

    # Table
    cols = [14, 7, 7, 32]
    hline("\u250c", "\u252c", "\u2510", cols)
    row([("language", 14, W, "l"), ("dog", 7, W, "r"), ("bat", 7, W, "r"), ("what it means", 32, W, "l")])
    hline("\u251c", "\u253c", "\u2524", cols)

    for lang, dog_pct, bat_pct, _ in results:
        diff = abs(dog_pct - bat_pct)
        if diff < 0.5:
            winner_text = "tied"
            dog_color = B
            meaning_color = B
        elif dog_pct > bat_pct:
            winner_text = f"dog highlights {dog_pct - bat_pct:.0f}% more code"
            dog_color = G
            meaning_color = G
        else:
            winner_text = f"bat highlights {bat_pct - dog_pct:.0f}% more code"
            dog_color = B
            meaning_color = R

        row([
            (lang, 14, B, "l"),
            (f"{dog_pct:.1f}%", 7, dog_color, "r"),
            (f"{bat_pct:.1f}%", 7, G if bat_pct > dog_pct + 0.5 else B, "r"),
            (winner_text, 32, meaning_color, "l"),
        ])

    hline("\u251c", "\u253c", "\u2524", cols)

    # Averages
    avg_dog = sum(r[1] for r in results) / total if total else 0
    avg_bat = sum(r[2] for r in results) / total if total else 0
    avg_diff = avg_dog - avg_bat
    if avg_diff > 0:
        avg_text = f"dog covers {avg_diff:.0f}% more on average"
        avg_color = G
    else:
        avg_text = f"bat covers {-avg_diff:.0f}% more on average"
        avg_color = R

    row([
        ("average", 14, W, "l"),
        (f"{avg_dog:.1f}%", 7, G if avg_dog > avg_bat else B, "r"),
        (f"{avg_bat:.1f}%", 7, G if avg_bat > avg_dog else B, "r"),
        (avg_text, 32, avg_color, "l"),
    ])

    tie_text = f"{ties} tied" if ties else ""
    row([
        ("score", 14, W, "l"),
        (f"{dog_wins}/{total}", 7, G, "r"),
        (f"{bat_wins}/{total}", 7, B, "r"),
        (tie_text, 32, B, "l"),
    ])

    hline("\u2514", "\u2534", "\u2518", cols)

    print()
    print(f"  {B}{pass_count} passed, {fail_count} failed  {elapsed:.1f}s{Z}")

    # Write counts for run-all.sh
    counts_file = os.environ.get("COUNTS_FILE")
    if counts_file:
        with open(counts_file, "a") as f:
            f.write(f"pass={pass_count}\n")
            f.write(f"fail={fail_count}\n")

    sys.exit(1 if fail_count > 0 and bat_wins > dog_wins else 0)


if __name__ == "__main__":
    main()
