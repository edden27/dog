#!/usr/bin/env python3
"""Full TrueColor grid — every color in one rectangle."""
import sys, colorsys, os

cols = os.get_terminal_size().columns
rows = os.get_terminal_size().lines - 2

for y in range(rows):
    t = y / rows  # 0 at top, 1 at bottom
    if t < 0.5:
        # Top half: full saturation, bright → dark
        s = 1.0
        v = 1.0 - t * 2  # 1.0 → 0.0
    else:
        # Bottom half: dark → bright but desaturated
        s = 1.0 - (t - 0.5) * 2  # 1.0 → 0.0
        v = (t - 0.5) * 2  # 0.0 → 1.0
    for x in range(cols):
        h = x / cols
        r, g, b = [int(c * 255) for c in colorsys.hsv_to_rgb(h, s, v)]
        sys.stdout.write(f'\033[48;2;{r};{g};{b}m ')
    sys.stdout.write('\033[K\n')
sys.stdout.write('\033[0m')
sys.stdout.flush()
